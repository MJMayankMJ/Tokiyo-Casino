//
//  JKAIEngine.swift
//  Tokiyo Casino — Jackaroo
//
//  Heuristic move picker (Phase 4). Scores every candidate move with the
//  feature set from JACKAROO_TECH_SPEC.md §6 and picks the best, biased
//  by the acting seat's personality. No search, no hidden-hand sampling.
//
//  Determinism: scoring is a pure function of `state`, and the bluffer's
//  10% "take the 2nd-best" roll is derived from a hash of the state — so
//  a game replays identically from its seed.
//

import Foundation

/// A move-selection policy. The engine asks its policy for the AI's move.
public protocol JKAIPolicy {
    func chooseMove(for seat: SeatID, moves: [JKMove], state: JKGameState) -> JKMove?
}

/// Phase 1–3 stub: first non-burn move (else first). Kept as a fast,
/// deterministic baseline for property / perf tests.
public struct JKFirstLegalAI: JKAIPolicy {
    public init() {}
    public func chooseMove(for seat: SeatID, moves: [JKMove], state: JKGameState) -> JKMove? {
        moves.first(where: { !$0.isBurn }) ?? moves.first
    }
}

public struct JKAIEngine: JKAIPolicy {

    public let graph: JKBoardGraph

    public init(graph: JKBoardGraph = JKBoardGraph()) {
        self.graph = graph
    }

    // MARK: - Selection

    public func chooseMove(for seat: SeatID, moves: [JKMove], state: JKGameState) -> JKMove? {
        guard !moves.isEmpty else { return nil }
        // Never burn while any real move exists (the generator only emits a
        // burn when nothing else is possible, but we enforce it anyway).
        let nonBurn = moves.filter { !$0.isBurn }
        let pool = nonBurn.isEmpty ? moves : nonBurn

        let weights = Weights.forPersonality(personality(of: seat, in: state))
        let scores = pool.map { score($0, for: seat, in: state, weights: weights) }

        // First strict maximum — earlier (generator-order) ties win, which
        // keeps replay deterministic.
        var best = 0
        for i in 1..<scores.count where scores[i] > scores[best] { best = i }

        // Bluffer occasionally takes the second-best, deterministically.
        if personality(of: seat, in: state) == .bluffer, pool.count > 1,
           deterministicRoll(state: state, seat: seat) < 0.10 {
            var second = best == 0 ? 1 : 0
            for i in 0..<scores.count where i != best && scores[i] > scores[second] { second = i }
            return pool[second]
        }
        return pool[best]
    }

    // MARK: - Weights

    struct Weights {
        var progress = 1.0
        var capture = 1.0
        var blockade = 1.0
        var threat = 1.0
        var handFlex = 1.0
        var partner = 1.0

        static func forPersonality(_ p: JKPersonality) -> Weights {
            switch p {
            case .balanced:
                return Weights()
            case .tightAggressive:
                return Weights(progress: 1.0, capture: 2.2, blockade: 2.0,
                               threat: 1.0, handFlex: 1.0, partner: 1.0)
            case .loosePassive:
                return Weights(progress: 1.6, capture: 0.3, blockade: 0.6,
                               threat: 1.2, handFlex: 1.0, partner: 1.2)
            case .bluffer:
                return Weights()
            }
        }
    }

    // MARK: - Scoring

    func score(_ move: JKMove, for seat: SeatID, in state: JKGameState,
               weights: Weights) -> Double {
        if move.isBurn { return -50 }

        // Simulate the move on a throwaway copy. Drop the log first so the
        // copy is cheap and `after.log` holds only this move's events.
        var after = state
        after.log = []
        var resolver = JKMoveResolver(graph: graph)
        resolver.apply(move, by: seat, to: &after)

        let ours = ourSeats(for: seat, in: state)

        // progressDelta — Safe-distance reduction across ownable marbles,
        // weighted ×3 for a marble newly entering Safe.
        var progressDelta = 0.0
        for before in state.marbles where ours.contains(before.owner) {
            guard let aft = after.marbles.first(where: { $0.id == before.id }) else { continue }
            var delta = Double(progress(aft) - progress(before))
            if case .safe = aft.position, !isSafe(before.position) { delta *= 3 }
            progressDelta += delta
        }

        // captureBonus — 5 × distance-from-home of each marble we send back.
        var captureBonus = 0.0
        for event in after.log {
            if case let .captured(mid, by) = event, by == seat,
               let victim = state.marbles.first(where: { $0.id == mid }) {
                captureBonus += 5.0 * Double(max(1, progress(victim)))
            }
        }

        // blockadeBonus — +2 per new blockade with its front on a chokepoint.
        let blockadeBonus = 2.0 * Double(chokepointBlockades(for: seat, in: after)
                                         - chokepointBlockades(for: seat, in: state))

        // threatPenalty — our moved marbles parking just ahead of an enemy.
        let threatPenalty = threat(for: move, seat: seat, after: after)

        // handFlexibility — spending a Jack/King/Ace costs a point.
        let handFlex = isHighValueCard(move) ? 1.0 : 0.0

        // partnerSupport — advancing a partner's marble (post-handoff).
        var partnerSupport = 0.0
        if let owner = primaryMovedOwner(move, in: state),
           owner == JKTeam.partner(of: seat), owner != seat {
            partnerSupport = 1.0
        }

        return progressDelta * weights.progress
            + captureBonus * weights.capture
            + blockadeBonus * weights.blockade
            - threatPenalty * weights.threat
            - handFlex * weights.handFlex
            + partnerSupport * weights.partner
    }

    // MARK: - Feature helpers

    private var trackLen: Int { graph.trackCells.count }

    /// Monotonic "how far home" score: Home = 0, on track grows toward the
    /// Safe gate, in Safe is beyond the whole track.
    private func progress(_ m: JKMarble) -> Int {
        switch m.position {
        case .home:
            return 0
        case .track(let cell):
            // distanceToSafeGate is measured in the player's travel direction.
            let d = graph.distanceToSafeGate(from: cell, for: m.owner, direction: .cw)
            return trackLen - d
        case .safe(let lane):
            return trackLen + 1 + lane
        }
    }

    private func isSafe(_ p: JKPosition) -> Bool {
        if case .safe = p { return true }
        return false
    }

    private func ourSeats(for seat: SeatID, in state: JKGameState) -> Set<SeatID> {
        var s: Set<SeatID> = [seat]
        if state.rules.partnerHandoff && state.handoffEngaged[seat] {
            s.insert(JKTeam.partner(of: seat))
        }
        return s
    }

    /// Pairs of own marbles on consecutive track cells whose front cell is
    /// a Base or Safe gate (a chokepoint worth holding).
    private func chokepointBlockades(for seat: SeatID, in state: JKGameState) -> Int {
        var count = 0
        let reverse: JKDirection = state.direction == .cw ? .ccw : .cw
        for cell in 0..<trackLen {
            guard isChokepoint(cell) else { continue }
            guard ownMarble(at: cell, seat: seat, in: state),
                  let behind = graph.next(from: cell, direction: reverse),
                  ownMarble(at: behind, seat: seat, in: state) else { continue }
            count += 1
        }
        return count
    }

    private func isChokepoint(_ cell: CellID) -> Bool {
        switch graph.trackCells[cell] {
        case .base, .safeGate: return true
        default: return false
        }
    }

    private func ownMarble(at cell: CellID, seat: SeatID, in state: JKGameState) -> Bool {
        state.marbles.contains { m in
            m.owner == seat && m.position == .track(cell)
        }
    }

    private func threat(for move: JKMove, seat: SeatID, after: JKGameState) -> Double {
        let n = trackLen
        var penalty = 0.0
        for id in movedMarbleIDs(move) {
            guard let m = after.marbles.first(where: { $0.id == id }),
                  case .track(let cell) = m.position else { continue }
            for opp in after.marbles where (opp.owner % 2) != (seat % 2) {
                guard case .track(let oc) = opp.position else { continue }
                // Steps an opponent at `oc` would walk forward to reach `cell`.
                let dist = after.direction == .cw ? (cell - oc + n) % n : (oc - cell + n) % n
                if dist >= 1 && dist <= 6 {
                    penalty += Double((6 - dist) * 2)
                }
            }
        }
        return penalty
    }

    private func isHighValueCard(_ move: JKMove) -> Bool {
        guard let card = move.consumedCards.first else { return false }
        switch card.rank {
        case .jack, .king, .ace: return true
        default: return false
        }
    }

    private func movedMarbleIDs(_ move: JKMove) -> [MarbleID] {
        switch move {
        case let .fieldFromHome(_, m), let .forward(_, m, _),
             let .backward(_, m, _), let .anyMarble5(_, m, _):
            return [m]
        case let .split7(_, allocs):
            return allocs.map { $0.marble }
        case let .swap(_, own, other):
            return [own, other]
        case .redQueenDiscard, .burnHand, .burnCard:
            return []
        }
    }

    private func primaryMovedOwner(_ move: JKMove, in state: JKGameState) -> SeatID? {
        guard let id = movedMarbleIDs(move).first else { return nil }
        return state.marbles.first(where: { $0.id == id })?.owner
    }

    private func personality(of seat: SeatID, in state: JKGameState) -> JKPersonality {
        if case let .ai(personality) = state.players[seat].kind { return personality }
        return .balanced
    }

    /// Deterministic pseudo-random in [0,1) from the current state — lets
    /// the bluffer vary without breaking replay.
    private func deterministicRoll(state: JKGameState, seat: SeatID) -> Double {
        var h = state.seed
        h = h &+ (UInt64(state.log.count) &* 0x9E37_79B9_7F4A_7C15)
        h = h &+ (UInt64(seat) &* 0xD1B5_4A32_D192_ED03)
        h = (h ^ (h >> 30)) &* 0xBF58_476D_1CE4_E5B9
        h = (h ^ (h >> 27)) &* 0x94D0_49BB_1331_11EB
        h = h ^ (h >> 31)
        return Double(h % 1000) / 1000.0
    }
}
