//
//  HandHistoryTracker.swift
//  Poker — AI / Phase 3
//
//  Passive observer of the game lifecycle that folds structured events into an
//  in-memory `ActionLog` and per-seat `OpponentStats` (POKER_AI_DESIGN.md §6.1).
//  It is driven by `GameManager` calling `handStarted` / `streetBegan` /
//  `recordAction` / `handEnded`; no game-rules code is rewritten.
//
//  Critically, `recordAction` must be called with the pre-action `callAmount`
//  snapshotted *before* `executeAction` mutates `currentBet` / the pot — the
//  `playerDidAct` delegate fires too late to reconstruct it (see §6.1). The
//  caller also passes `raisedBet`, computed from whether the action increased
//  the table bet, so an all-in that raises is classified as aggression while an
//  all-in that merely calls is a call.
//
//  Stats reset per session (the tracker lives on `GameManager`), matching the
//  "opponent model resets per session" decision in §10.
//

import Foundation

// MARK: - Street

/// Poker street used for stat attribution. Distinct from `GamePhase` (which also
/// carries `.waiting` / `.showdown`); `from(_:)` maps the betting phases.
enum PokerStreet: String {
    case preflop, flop, turn, river

    static func from(_ phase: GamePhase) -> PokerStreet? {
        switch phase {
        case .preFlop: return .preflop
        case .flop:    return .flop
        case .turn:    return .turn
        case .river:   return .river
        case .waiting, .showdown: return nil
        }
    }
}

// MARK: - Action classification

/// How an action counts for stats. Derived from the resolved action plus whether
/// it increased the table bet (so all-ins land in the right bucket).
enum ActionClass {
    case fold, check, call, aggressive
}

// MARK: - Event log

/// Structured events forming the per-session hand history (the `ActionLog`).
/// Carries enough to replay/debug a hand — blinds, board per street, the running
/// aggressor, and the winning seats — while the live stats are accumulated
/// incrementally as events arrive (see `statsBySeat`). Mirrors the event set in
/// POKER_AI_DESIGN.md §6.1.
enum HandEvent {
    case handStarted(handId: Int, button: Int, smallBlind: Int, bigBlind: Int, seats: [Int])
    case streetBegan(handId: Int, street: PokerStreet, board: [Card])
    case playerActed(handId: Int, seat: Int, street: PokerStreet, action: ActionClass, amountToCall: Int, isVoluntary: Bool, isFacingRaise: Bool)
    case aggressorChanged(handId: Int, street: PokerStreet, seat: Int)
    case handEnded(handId: Int, wentToShowdown: Bool, winners: [Int])
}

// MARK: - Tracker

final class HandHistoryTracker {

    /// Ordered event log (ActionLog). Kept for debug/inspection and to test the
    /// derivation independently of the incremental accumulator.
    private(set) var log: [HandEvent] = []

    /// Accumulated raw stats per seat id, folded over the events above.
    private(set) var statsBySeat: [Int: OpponentStats] = [:]

    /// Notional baseline used as the Bayesian prior when building a model for a
    /// seat with thin data (typically the human, who has no real profile).
    let priorProfile: AIProfile

    init(priorProfile: AIProfile = .populationBaseline) {
        self.priorProfile = priorProfile
    }

    // MARK: Per-hand running state

    private var handId = 0
    private var currentStreet: PokerStreet = .preflop
    private var seatsDealt: [Int] = []

    private var preflopAggressor: Int?
    private var preflopRaiseCount = 0          // open = 1, 3-bet = 2, ...

    private var streetAggressor: Int?          // last bettor/raiser this street
    private var streetHasBet = false
    private var flopCbettor: Int?              // preflop aggressor who bet the flop first

    private var foldedThisHand: Set<Int> = []
    private var sawFlopThisHand: Set<Int> = []
    private var vpipCounted: Set<Int> = []
    private var pfrCounted: Set<Int> = []
    private var faced3betCounted: Set<Int> = []
    private var facedCbetCounted: Set<Int> = []

    // MARK: Lifecycle

    /// Begin a new hand. `seats` are the ids actually dealt in this hand.
    func handStarted(button: Int, smallBlind: Int = 0, bigBlind: Int = 0, seats: [Int]) {
        handId += 1
        currentStreet = .preflop
        seatsDealt = seats
        preflopAggressor = nil
        preflopRaiseCount = 0
        streetAggressor = nil
        streetHasBet = false
        flopCbettor = nil
        foldedThisHand = []
        sawFlopThisHand = []
        vpipCounted = []
        pfrCounted = []
        faced3betCounted = []
        facedCbetCounted = []

        for seat in seats {
            statsBySeat[seat, default: .init()].handsDealt += 1
        }
        log.append(.handStarted(handId: handId, button: button, smallBlind: smallBlind, bigBlind: bigBlind, seats: seats))
    }

    /// A new betting street started. Resets per-street aggression state and, on
    /// the flop, marks which dealt-in seats saw the flop (WTSD denominator).
    func streetBegan(_ street: PokerStreet, board: [Card] = []) {
        currentStreet = street
        streetAggressor = nil
        streetHasBet = false
        if street == .flop {
            flopCbettor = nil
            for seat in seatsDealt where !foldedThisHand.contains(seat) {
                markSawFlop(seat)
            }
        }
        log.append(.streetBegan(handId: handId, street: street, board: board))
    }

    /// Record a resolved action. `callAmount` is the pre-action amount-to-call;
    /// `raisedBet` is true iff the action increased the table's current bet.
    func recordAction(seat: Int, action: PlayerAction, callAmount: Int, raisedBet: Bool) {
        let cls = classify(action, raisedBet: raisedBet)
        let facingBet = callAmount > 0

        if currentStreet == .preflop {
            recordPreflop(seat: seat, cls: cls, facingBet: facingBet)
        } else {
            recordPostflop(seat: seat, cls: cls, facingBet: facingBet)
        }

        applyStateTransition(seat: seat, cls: cls)

        log.append(.playerActed(
            handId: handId, seat: seat, street: currentStreet, action: cls,
            amountToCall: callAmount, isVoluntary: isVoluntary(cls, facingBet: facingBet),
            isFacingRaise: facingBet
        ))
    }

    /// End the current hand. `wentToShowdown` is true when the hand was decided
    /// at showdown (river bet matched, or all-in run-out) rather than everyone
    /// else folding.
    func handEnded(wentToShowdown: Bool, winners: [Int] = []) {
        if wentToShowdown {
            for seat in seatsDealt where !foldedThisHand.contains(seat) {
                // Safety net: an all-in-preflop run-out skips `streetBegan(.flop)`,
                // so backfill sawFlop for anyone reaching showdown.
                markSawFlop(seat)
                statsBySeat[seat, default: .init()].wentToShowdown += 1
            }
        }
        log.append(.handEnded(handId: handId, wentToShowdown: wentToShowdown, winners: winners))
    }

    // MARK: Model access

    /// Blended model for a seat (empty stats + prior if the seat is unknown).
    func model(for seat: Int) -> OpponentModel {
        OpponentModel(stats: statsBySeat[seat] ?? .init(), prior: priorProfile)
    }

    func rawStats(for seat: Int) -> OpponentStats {
        statsBySeat[seat] ?? .init()
    }

    /// Seat that made the last bet/raise on the current street, if any. The
    /// exploit layer uses this to adapt against the actual pressure source in a
    /// multi-human game rather than an arbitrary opponent.
    var currentAggressorSeat: Int? { streetAggressor }

    // MARK: Derivation helpers

    private func recordPreflop(seat: Int, cls: ActionClass, facingBet: Bool) {
        // Fold to 3-bet: the seat is responding when ≥2 preflop raises already
        // happened (open + reraise). Count the opportunity once per hand.
        if preflopRaiseCount >= 2 && facingBet && !faced3betCounted.contains(seat) {
            faced3betCounted.insert(seat)
            statsBySeat[seat, default: .init()].faced3bet += 1
            if cls == .fold { statsBySeat[seat]!.foldedTo3bet += 1 }
        }

        switch cls {
        case .aggressive:
            countOnce(seat, in: &pfrCounted) { $0.pfrCount += 1 }
            countOnce(seat, in: &vpipCounted) { $0.vpipCount += 1 }
        case .call where facingBet:
            countOnce(seat, in: &vpipCounted) { $0.vpipCount += 1 }
        default:
            break
        }
    }

    private func recordPostflop(seat: Int, cls: ActionClass, facingBet: Bool) {
        switch cls {
        case .aggressive: statsBySeat[seat, default: .init()].postflopBets += 1
        case .call:       statsBySeat[seat, default: .init()].postflopCalls += 1
        default:          break
        }

        // Fold to c-bet: only on the flop, only against the preflop aggressor's
        // continuation bet, counted once per hand per seat.
        if currentStreet == .flop, facingBet, seat != flopCbettor,
           let agg = streetAggressor, agg == flopCbettor,
           !facedCbetCounted.contains(seat) {
            facedCbetCounted.insert(seat)
            statsBySeat[seat, default: .init()].facedCbet += 1
            if cls == .fold { statsBySeat[seat]!.foldedToCbet += 1 }
        }
    }

    private func applyStateTransition(seat: Int, cls: ActionClass) {
        switch cls {
        case .aggressive:
            if currentStreet == .preflop {
                preflopRaiseCount += 1
                preflopAggressor = seat
            } else if currentStreet == .flop, !streetHasBet, seat == preflopAggressor {
                flopCbettor = seat       // preflop aggressor's first flop bet = c-bet
            }
            streetAggressor = seat
            streetHasBet = true
            log.append(.aggressorChanged(handId: handId, street: currentStreet, seat: seat))
        case .fold:
            foldedThisHand.insert(seat)
        default:
            break
        }
    }

    private func markSawFlop(_ seat: Int) {
        guard !sawFlopThisHand.contains(seat) else { return }
        sawFlopThisHand.insert(seat)
        statsBySeat[seat, default: .init()].sawFlop += 1
    }

    private func countOnce(_ seat: Int, in set: inout Set<Int>, _ bump: (inout OpponentStats) -> Void) {
        guard !set.contains(seat) else { return }
        set.insert(seat)
        bump(&statsBySeat[seat, default: .init()])
    }

    private func classify(_ action: PlayerAction, raisedBet: Bool) -> ActionClass {
        switch action {
        case .fold:  return .fold
        case .check: return .check
        default:     return raisedBet ? .aggressive : .call
        }
    }

    private func isVoluntary(_ cls: ActionClass, facingBet: Bool) -> Bool {
        switch cls {
        case .aggressive: return true
        case .call:       return facingBet
        case .fold, .check: return false
        }
    }
}
