//
//  JKLegalMoveGenerator.swift
//  Tokiyo Casino — Jackaroo
//
//  Pure function: (state, seat) → [JKMove]. No mutation, no RNG.
//  The resolver is what actually applies a move.
//
//  This file is intentionally long and explicit. Jackaroo has a lot of
//  edge cases — protected Base, blockades, Safe entry, cannot-pass-own,
//  partner handoff, 7-split partitions — and they're all easier to
//  audit when they live in one place.
//

import Foundation

public struct JKLegalMoveGenerator {
    public let graph: JKBoardGraph

    public init(graph: JKBoardGraph) {
        self.graph = graph
    }

    /// Top-level entry point.
    public func moves(in state: JKGameState, for seat: SeatID) -> [JKMove] {
        let player = state.players[seat]
        guard state.winner == nil else { return [] }

        var out: [JKMove] = []

        // We enumerate over **unique cards** in hand — duplicates would
        // just produce identical move trees. The chooser layer can
        // re-attach a specific copy from `player.hand` when applying.
        var seen = Set<JKCard>()
        for card in player.hand where seen.insert(card).inserted {
            out += movesForCard(card, seat: seat, state: state)
        }

        if out.isEmpty && state.rules.burnOnNoMove && !player.hand.isEmpty {
            switch state.rules.burnScope {
            case .wholeHand:
                out = [.burnHand(cards: player.hand)]
            case .singleCard:
                // One option per unique card so the UI can highlight
                // each dead card individually; the player picks which
                // to burn.
                var unique = Set<JKCard>()
                for card in player.hand where unique.insert(card).inserted {
                    out.append(.burnCard(card: card))
                }
            }
        }

        return out
    }

    // MARK: - Card dispatch

    private func movesForCard(_ card: JKCard,
                              seat: SeatID,
                              state: JKGameState) -> [JKMove] {
        switch card.rank {
        case .ace:   return acemoves(card: card, seat: seat, state: state)
        case .king:  return kingMoves(card: card, seat: seat, state: state)
        case .queen: return queenMoves(card: card, seat: seat, state: state)
        case .jack:  return jackMoves(card: card, seat: seat, state: state)
        case .seven: return sevenMoves(card: card, seat: seat, state: state)
        case .four:  return fourMoves(card: card, seat: seat, state: state)
        case .five:  return fiveMoves(card: card, seat: seat, state: state)
        case .two, .three, .six, .eight, .nine, .ten:
            return plainForwardMoves(card: card,
                                     steps: card.rank.simpleFaceValue,
                                     seat: seat,
                                     state: state)
        }
    }

    // MARK: - Ace

    private func acemoves(card: JKCard, seat: SeatID, state: JKGameState) -> [JKMove] {
        var out: [JKMove] = []
        // Field from Home
        for m in state.ownableMarbles(of: seat) {
            if case .home = m.position, canField(marble: m, seat: seat, state: state) {
                out.append(.fieldFromHome(card: card, marble: m.id))
            }
        }
        // Forward 1 / 11
        let allowOne = state.rules.aceSplit == .oneOrEleven || state.rules.aceSplit == .oneOnly
        let allowEleven = state.rules.aceSplit == .oneOrEleven || state.rules.aceSplit == .elevenOnly
        for m in state.ownableMarbles(of: seat) {
            if allowOne {
                out += forwardMovesForMarble(card: card, marble: m,
                                             steps: 1, seat: seat, state: state)
            }
            if allowEleven {
                out += forwardMovesForMarble(card: card, marble: m,
                                             steps: 11, seat: seat, state: state)
            }
        }
        return out
    }

    // MARK: - King

    private func kingMoves(card: JKCard, seat: SeatID, state: JKGameState) -> [JKMove] {
        var out: [JKMove] = []
        for m in state.ownableMarbles(of: seat) {
            if case .home = m.position, canField(marble: m, seat: seat, state: state) {
                out.append(.fieldFromHome(card: card, marble: m.id))
            }
        }
        if state.rules.kingMode == .fieldOrThirteenCapture {
            for m in state.ownableMarbles(of: seat) {
                out += forwardMovesForMarble(card: card, marble: m,
                                             steps: 13, seat: seat, state: state)
            }
        }
        return out
    }

    // MARK: - Queen

    private func queenMoves(card: JKCard, seat: SeatID, state: JKGameState) -> [JKMove] {
        var out: [JKMove] = []
        for m in state.ownableMarbles(of: seat) {
            out += forwardMovesForMarble(card: card, marble: m,
                                         steps: 12, seat: seat, state: state)
        }
        if state.rules.queenMode == .blackTwelveRedDiscard && card.suit.isRed {
            // Red Queen forces a victim discard. Victim is any opponent
            // with at least one card in hand. The resolver picks which
            // card is lost using state.rng — we never expose that here.
            for opp in 0..<4 where opp != seat && !state.players[opp].hand.isEmpty {
                out.append(.redQueenDiscard(card: card, victim: opp))
            }
        }
        return out
    }

    // MARK: - Jack

    private func jackMoves(card: JKCard, seat: SeatID, state: JKGameState) -> [JKMove] {
        switch state.rules.jackMode {
        case .swapOpponentOnly:
            return jackSwaps(card: card, seat: seat, state: state)
        case .redElevenBlackSwap:
            if card.suit.isRed {
                // Red Jack = forward 11 — same path checks as Ace's 11.
                var out: [JKMove] = []
                for m in state.ownableMarbles(of: seat) {
                    out += forwardMovesForMarble(card: card, marble: m,
                                                 steps: 11, seat: seat, state: state)
                }
                return out
            } else {
                return jackSwaps(card: card, seat: seat, state: state)
            }
        }
    }

    private func jackSwaps(card: JKCard, seat: SeatID, state: JKGameState) -> [JKMove] {
        var out: [JKMove] = []
        let own = state.ownableMarbles(of: seat).filter { isSwappable($0, state: state) }
        for o in own {
            // Opponent marbles = every other marble that is also swappable
            // and isn't owned by the acting seat. Partner marbles ARE
            // swappable from the partner's perspective when handoff is
            // engaged; we keep it simple here and treat partner marbles
            // as own.
            let opponents = state.marbles.filter { m in
                m.owner != seat
                && (!state.handoffEngaged[seat] || m.owner != JKTeam.partner(of: seat))
                && isSwappable(m, state: state)
            }
            for opp in opponents {
                out.append(.swap(card: card, ownMarble: o.id, otherMarble: opp.id))
            }
        }
        return out
    }

    private func isSwappable(_ m: JKMarble, state: JKGameState) -> Bool {
        switch m.position {
        case .home, .safe: return false
        case .track(let cell):
            // Cannot swap a marble that sits on its owner's Base
            // (protected). Cannot swap a front-of-blockade marble either.
            if isOwnBaseProtected(cell: cell, owner: m.owner, state: state) { return false }
            if isBlockadeFront(cell: cell, owner: m.owner, state: state) { return false }
            return true
        }
    }

    // MARK: - Seven (split)

    private func sevenMoves(card: JKCard, seat: SeatID, state: JKGameState) -> [JKMove] {
        let movable = state.ownableMarbles(of: seat).filter { canAdvance($0) }
        switch state.rules.sevenMode {
        case .twoOwn:
            return sevenTwoOwn(card: card, seat: seat, state: state, movable: movable)
        case .multiOwn:
            return sevenMultiOwn(card: card, seat: seat, state: state, movable: movable)
        }
    }

    private func canAdvance(_ m: JKMarble) -> Bool {
        switch m.position {
        case .home: return false
        case .track, .safe: return true
        }
    }

    private func sevenTwoOwn(card: JKCard, seat: SeatID,
                             state: JKGameState, movable: [JKMarble]) -> [JKMove] {
        var out: [JKMove] = []
        // Enumerate ordered pairs of distinct marbles × partitions (a, 7−a).
        for i in movable.indices {
            for j in movable.indices where j != i {
                let a = movable[i]
                let b = movable[j]
                // 1 ≤ s ≤ 6 ; single-marble allocation (7,0) excluded in twoOwn
                for s in 1...6 {
                    let allocs = [JKSplitAllocation(marble: a.id, steps: s),
                                  JKSplitAllocation(marble: b.id, steps: 7 - s)]
                    if splitIsLegal(allocs, seat: seat, state: state) {
                        out.append(.split7(card: card, allocations: allocs))
                    }
                }
            }
        }
        // Deduplicate — (a:3, b:4) and (b:4, a:3) are the same allocation.
        return stableUnique(out)
    }

    private func sevenMultiOwn(card: JKCard, seat: SeatID,
                               state: JKGameState, movable: [JKMarble]) -> [JKMove] {
        var out: [JKMove] = []
        let ids = movable.map { $0.id }
        // Generate every composition of 7 over 1...4 distinct marbles.
        // Branching is bounded (4! × 7-choose-k ≈ small) so brute force is fine.
        for k in 1...min(4, ids.count) {
            generateCompositions(target: 7, parts: k) { steps in
                // Map steps to distinct marble subsets.
                forEachCombination(ids, k: k) { subset in
                    var alloc: [JKSplitAllocation] = []
                    for (idx, s) in steps.enumerated() {
                        alloc.append(JKSplitAllocation(marble: subset[idx], steps: s))
                    }
                    if splitIsLegal(alloc, seat: seat, state: state) {
                        out.append(.split7(card: card, allocations: alloc))
                    }
                }
            }
        }
        return stableUnique(out)
    }

    /// Walk the allocations against a *running copy* of state so each
    /// sub-step respects the previous sub-steps' effects (a marble
    /// captured by step 1 isn't in the way for step 2). We don't apply
    /// captures — we only need to know the path is valid.
    private func splitIsLegal(_ allocs: [JKSplitAllocation],
                              seat: SeatID,
                              state: JKGameState) -> Bool {
        var working = state
        for alloc in allocs {
            guard let marble = working.marbles.first(where: { $0.id == alloc.marble }) else { return false }
            guard let outcome = walkForward(marble: marble,
                                            steps: alloc.steps,
                                            seat: seat,
                                            state: working) else { return false }
            // Apply just the marble move to the working copy. Captures
            // are handled implicitly because the captured marble's cell
            // becomes empty in the working copy.
            updateMarble(in: &working, id: alloc.marble, position: outcome.destination)
            if let captured = outcome.capture {
                updateMarble(in: &working, id: captured, position: .home(slot: 0))
            }
        }
        return true
    }

    // MARK: - Four (backward)

    private func fourMoves(card: JKCard, seat: SeatID, state: JKGameState) -> [JKMove] {
        var out: [JKMove] = []
        for m in state.ownableMarbles(of: seat) {
            if let path = walkBackward(marble: m, steps: 4, seat: seat, state: state) {
                _ = path   // path is reusable later but we only need legality here
                out.append(.backward(card: card, marble: m.id, steps: 4))
            }
        }
        return out
    }

    // MARK: - Five

    private func fiveMoves(card: JKCard, seat: SeatID, state: JKGameState) -> [JKMove] {
        var out = plainForwardMoves(card: card, steps: 5, seat: seat, state: state)
        if state.rules.fiveMode == .anyMarbleOnTrack {
            for m in state.marbles where m.owner != seat {
                // Only on-track marbles are eligible — Safe + Home are off-limits.
                if case .track = m.position {
                    out += forwardMovesForMarble(card: card, marble: m,
                                                 steps: 5, seat: seat, state: state,
                                                 moveCase: .anyMarble5)
                }
            }
        }
        return out
    }

    // MARK: - Plain forward (2,3,5,6,8,9,10)

    private func plainForwardMoves(card: JKCard, steps: Int,
                                   seat: SeatID, state: JKGameState) -> [JKMove] {
        var out: [JKMove] = []
        for m in state.ownableMarbles(of: seat) {
            out += forwardMovesForMarble(card: card, marble: m,
                                         steps: steps, seat: seat, state: state)
        }
        return out
    }

    // MARK: - Forward path enumerator

    private enum MoveCase { case forward, anyMarble5 }

    /// Generates all forward-move variants for a single marble — both
    /// the on-track destination and the Safe-entry destination (if
    /// crossing the owner's gate). Filtering for legality is done
    /// inside `walkForward`.
    private func forwardMovesForMarble(card: JKCard,
                                       marble: JKMarble,
                                       steps: Int,
                                       seat: SeatID,
                                       state: JKGameState,
                                       moveCase: MoveCase = .forward) -> [JKMove] {
        var out: [JKMove] = []
        if let _ = walkForward(marble: marble, steps: steps, seat: seat, state: state,
                               preferSafeEntry: false) {
            switch moveCase {
            case .forward:
                out.append(.forward(card: card, marble: marble.id, steps: steps))
            case .anyMarble5:
                out.append(.anyMarble5(card: card, marble: marble.id, steps: steps))
            }
        }
        // Safe-entry variant when applicable. Only applies to the marble's
        // own owner (not partner — handoff transfers control but a marble
        // can only enter ITS owner's Safe).
        let owner = marble.owner
        if owner == seat || (state.handoffEngaged[seat] && owner == JKTeam.partner(of: seat)) {
            if case .track = marble.position {
                if let outcome = walkForward(marble: marble, steps: steps,
                                             seat: seat, state: state,
                                             preferSafeEntry: true),
                   case .safe = outcome.destination {
                    switch moveCase {
                    case .forward:
                        // Use a distinct move? No — both variants share
                        // the same case; the resolver decides Safe entry
                        // by re-walking with `preferSafeEntry=true`. We
                        // emit a separate move only if the destination
                        // diverges from the on-track variant.
                        out.append(.forward(card: card, marble: marble.id, steps: steps))
                    case .anyMarble5:
                        break // any-marble-5 cannot enter Safe (other owners' Safes are off-limits)
                    }
                }
            } else if case .safe = marble.position {
                if walkForward(marble: marble, steps: steps, seat: seat, state: state,
                               preferSafeEntry: true) != nil {
                    if moveCase == .forward {
                        out.append(.forward(card: card, marble: marble.id, steps: steps))
                    }
                }
            }
        }
        return stableUnique(out)   // dedupe — track + safe variants may collapse
    }

    /// Order-preserving dedupe. `Array(Set(...))` is non-deterministic
    /// across Swift runs because Set iteration is randomized; that
    /// breaks replay. This keeps first occurrences in input order.
    private func stableUnique(_ moves: [JKMove]) -> [JKMove] {
        var seen = Set<JKMove>()
        var out: [JKMove] = []
        out.reserveCapacity(moves.count)
        for m in moves where seen.insert(m).inserted {
            out.append(m)
        }
        return out
    }

    // MARK: - Path validation walker

    /// Outcome of a successful walk: where the marble lands, the path
    /// it took, and which marble (if any) gets captured at the
    /// destination.
    struct WalkOutcome {
        let destination: JKPosition
        let path: [CellID]            // cell IDs visited along the way (excludes start)
        let capture: MarbleID?
    }

    /// Returns `nil` if the walk is illegal.
    func walkForward(marble: JKMarble,
                     steps: Int,
                     seat: SeatID,
                     state: JKGameState,
                     preferSafeEntry: Bool = true) -> WalkOutcome? {
        guard steps > 0 else { return nil }
        let direction = state.direction
        let rules = state.rules

        switch marble.position {
        case .home:
            return nil   // can't walk a Home marble; use fieldFromHome
        case .safe(let lane):
            // Inside Safe — pure deeper-advance.
            let endLane = lane + steps
            if endLane > 3 { return nil }   // overshoot lane bounds
            // Every cell from lane+1 ... endLane must be empty.
            for li in (lane + 1)...endLane {
                if safeOccupant(owner: marble.owner, lane: li, state: state) != nil {
                    return nil
                }
            }
            return WalkOutcome(destination: .safe(lane: endLane), path: [], capture: nil)

        case .track(let startCell):
            let owner = marble.owner
            let mayEnterOwnSafe =
                (owner == seat || (rules.partnerHandoff && state.handoffEngaged[seat]
                                   && owner == JKTeam.partner(of: seat)))
                && preferSafeEntry

            // Walk step by step. We need to detect when we cross the
            // marble's owner's Safe gate; at that point we have a
            // choice (stay on track for one more step OR enter Safe).
            var current = startCell
            var path: [CellID] = []
            var stepsLeft = steps

            while stepsLeft > 0 {
                guard let nxt = graph.next(from: current, direction: direction) else { return nil }

                // Check whether `nxt` would be the cell *just past* the
                // Safe gate. The "gate" is itself a track cell. If we
                // just *arrived at* the gate cell as a pass-through and
                // are about to step further, that further step can
                // instead become a Safe entry.
                // Concretely: if `current == graph.safeGateCell[owner]`
                // and we still have steps to go, we may divert into Safe
                // here. The "remaining" steps go inside Safe.
                if mayEnterOwnSafe,
                   current == graph.safeGateCell[owner],
                   stepsLeft >= 1 {
                    if let outcome = trySafeEntryFromGate(owner: owner,
                                                         stepsInsideSafe: stepsLeft,
                                                         state: state,
                                                         pathSoFar: path) {
                        return outcome
                    }
                }

                // Check intermediate blockers.
                if let blocker = trackBlocker(at: nxt, mover: marble, state: state) {
                    // The blocker is on our path. If this is the final
                    // step, captures are still possible (handled below);
                    // otherwise we're blocked.
                    if stepsLeft > 1 {
                        // Mid-path blocker — illegal regardless of type.
                        switch blocker {
                        case .blockade, .protectedBase, .ownMarble, .opponent:
                            return nil
                        }
                    }
                }

                current = nxt
                path.append(current)
                stepsLeft -= 1
            }

            // Final landing checks.
            if let blocker = trackBlocker(at: current, mover: marble, state: state) {
                switch blocker {
                case .blockade, .protectedBase, .ownMarble:
                    return nil
                case .opponent(let oid):
                    return WalkOutcome(destination: .track(current),
                                       path: path,
                                       capture: oid)
                }
            }
            return WalkOutcome(destination: .track(current), path: path, capture: nil)
        }
    }

    /// Try to divert into the owner's Safe at the gate. `stepsInsideSafe`
    /// is what's left after standing on the gate cell.
    private func trySafeEntryFromGate(owner: SeatID,
                                      stepsInsideSafe: Int,
                                      state: JKGameState,
                                      pathSoFar: [CellID]) -> WalkOutcome? {
        guard stepsInsideSafe >= 1 else { return nil }
        // The lane has 4 cells (0..3). We enter at lane index 0 on the
        // first inside-step and proceed deeper.
        let endLane = stepsInsideSafe - 1
        if endLane > 3 { return nil }

        // Check Safe-mode constraint on landing depth.
        // "deepest empty cell" = highest lane index that is currently empty.
        let deepestEmpty: Int? = {
            for li in stride(from: 3, through: 0, by: -1) {
                if safeOccupant(owner: owner, lane: li, state: state) == nil {
                    return li
                }
            }
            return nil
        }()
        guard let deepest = deepestEmpty else { return nil }  // lane full

        // No jumping inside the lane — every cell from 0…endLane must be empty.
        for li in 0...endLane {
            if safeOccupant(owner: owner, lane: li, state: state) != nil {
                return nil
            }
        }

        switch state.rules.safeEntryMode {
        case .cardValueAtMostRemaining:
            if endLane > deepest { return nil }
        case .exactOnly:
            if endLane != deepest { return nil }
        case .overflowAroundTrack:
            // Overflow handled by the caller — if the marble can't enter
            // exactly, the engine would re-walk with preferSafeEntry=false
            // and continue on the track. Here we still allow Safe entry
            // when it fits cleanly.
            if endLane > deepest { return nil }
        }

        return WalkOutcome(destination: .safe(lane: endLane),
                           path: pathSoFar,
                           capture: nil)
    }

    // MARK: - Backward walker

    /// 4-card style backward move. Backward never enters Safe; marbles
    /// inside Safe cannot move backward at all.
    func walkBackward(marble: JKMarble,
                      steps: Int,
                      seat: SeatID,
                      state: JKGameState) -> WalkOutcome? {
        guard case .track(let startCell) = marble.position else { return nil }
        guard steps > 0 else { return nil }
        let reverse: JKDirection = state.direction == .cw ? .ccw : .cw
        var current = startCell
        var path: [CellID] = []
        for _ in 0..<steps {
            guard let nxt = graph.next(from: current, direction: reverse) else { return nil }
            if let blocker = trackBlocker(at: nxt, mover: marble, state: state),
               case .ownMarble = blocker {
                // Mid-path own marble is only a blocker when `cannotPassOwn`
                // is on. If it's the final step we'd land on own marble
                // regardless — illegal.
                return nil
            }
            current = nxt
            path.append(current)
        }
        if let blocker = trackBlocker(at: current, mover: marble, state: state) {
            switch blocker {
            case .blockade, .protectedBase, .ownMarble:
                return nil
            case .opponent(let oid):
                return WalkOutcome(destination: .track(current),
                                   path: path,
                                   capture: oid)
            }
        }
        return WalkOutcome(destination: .track(current), path: path, capture: nil)
    }

    // MARK: - Blocker classification

    enum Blocker {
        case ownMarble                 // any same-owner marble (relevant when cannotPassOwn)
        case blockade                  // 2-marble consecutive blockade — front cell
        case protectedBase             // owner's own marble sitting on its Base cell
        case opponent(MarbleID)
    }

    /// Classify whatever sits at `cell` from the perspective of the
    /// mover (whose owner is `mover.owner`). Returns `nil` for empty.
    private func trackBlocker(at cell: CellID,
                              mover: JKMarble,
                              state: JKGameState) -> Blocker? {
        guard let occupant = state.marbles.first(where: {
            if case .track(let c) = $0.position { return c == cell }
            return false
        }) else { return nil }

        if isOwnBaseProtected(cell: cell, owner: occupant.owner, state: state),
           occupant.owner != mover.owner {
            return .protectedBase
        }
        if isBlockadeFront(cell: cell, owner: occupant.owner, state: state),
           occupant.owner != mover.owner {
            return .blockade
        }
        if occupant.owner == mover.owner {
            // Own-blockade is also protected.
            if state.rules.cannotPassOwn {
                return .ownMarble
            }
            // If we land on our own marble, it's always illegal.
            return .ownMarble
        }
        return .opponent(occupant.id)
    }

    private func isOwnBaseProtected(cell: CellID,
                                    owner: SeatID,
                                    state: JKGameState) -> Bool {
        guard let baseID = graph.baseCell[owner] else { return false }
        return cell == baseID
    }

    /// "Two consecutive marbles" — `front` is the cell. If the
    /// preceding track cell (in walking direction) is occupied by the
    /// same owner, this is a blockade and `front` is protected.
    private func isBlockadeFront(cell: CellID,
                                 owner: SeatID,
                                 state: JKGameState) -> Bool {
        // Look one cell *behind* `cell` (in current walking direction).
        // For default seat order this is `cell - 1`.
        let prev = graph.next(from: cell, direction: state.direction == .cw ? .ccw : .cw)
        guard let p = prev else { return false }
        return state.marbles.contains { m in
            if case .track(let c) = m.position, c == p, m.owner == owner { return true }
            return false
        }
    }

    private func safeOccupant(owner: SeatID,
                              lane: Int,
                              state: JKGameState) -> MarbleID? {
        for m in state.marbles where m.owner == owner {
            if case .safe(let li) = m.position, li == lane { return m.id }
        }
        return nil
    }

    // MARK: - Fielding

    private func canField(marble: JKMarble, seat: SeatID, state: JKGameState) -> Bool {
        let owner = marble.owner
        guard let baseID = graph.baseCell[owner] else { return false }
        let occupant = state.marbles.first(where: {
            if case .track(let c) = $0.position { return c == baseID }
            return false
        })
        // Empty Base — always fine.
        // Own marble on Base — blocked (own-blockade applies; can't field on top).
        // Opponent on Base — capture is fine because the Base belongs to
        //   the fielder, not the opponent. The Base is only "protected"
        //   for whoever's Base it is, but here we ARE that whoever.
        guard let occ = occupant else { return true }
        return occ.owner != owner
    }

    // MARK: - Helpers

    private func updateMarble(in state: inout JKGameState, id: MarbleID, position: JKPosition) {
        if let idx = state.marbles.firstIndex(where: { $0.id == id }) {
            state.marbles[idx].position = position
        }
    }

    /// Compositions of `target` into `parts` strictly positive integers.
    /// Calls `body` once per composition.
    private func generateCompositions(target: Int, parts: Int,
                                      body: ([Int]) -> Void) {
        var current: [Int] = []
        func recurse(remaining: Int, partsLeft: Int) {
            if partsLeft == 1 {
                if remaining >= 1 {
                    body(current + [remaining])
                }
                return
            }
            for v in 1...(remaining - (partsLeft - 1)) {
                current.append(v)
                recurse(remaining: remaining - v, partsLeft: partsLeft - 1)
                current.removeLast()
            }
        }
        if target >= parts { recurse(remaining: target, partsLeft: parts) }
    }

    private func forEachCombination<T>(_ items: [T], k: Int,
                                       body: ([T]) -> Void) {
        guard k <= items.count else { return }
        var idxs = Array(0..<k)
        func emit() {
            body(idxs.map { items[$0] })
        }
        emit()
        while true {
            var i = k - 1
            while i >= 0 && idxs[i] == items.count - k + i { i -= 1 }
            if i < 0 { return }
            idxs[i] += 1
            for j in (i + 1)..<k { idxs[j] = idxs[j - 1] + 1 }
            emit()
        }
    }
}
