//
//  TDPAIEngine.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  Decides the next action for an AI seat.
//
//  The AI reads ONLY its own hand plus public state (trump, the trick in
//  progress, tricks won, quotas, scores). It never touches another seat's
//  `hand`, and its khichai draw passes `fanIndex: nil` so the engine picks
//  at random — an AI creditor cannot see what it is pulling.
//

import Foundation

enum TDPAIDifficulty: String, Codable {
    case easy
    case medium

    var label: String {
        switch self {
        case .easy:   return "Easy"
        case .medium: return "Medium"
        }
    }
}

enum TDPAIEngine {

    /// The next action for `seat`, or nil if it is not this seat's move.
    static func nextAction(state: TDPGameState,
                           seat: TDPSeat,
                           difficulty: TDPAIDifficulty = .medium) -> TDPAction? {
        guard let me = state.player(at: seat) else { return nil }

        switch state.phase {
        case .lobby:
            return me.isReady ? nil : .setReady(seat: seat, ready: true)

        case .dealerDraw:
            return state.dealerDrawPending.contains(seat) ? .drawForDealer(seat: seat) : nil

        case .trumpSelect:
            guard state.trumpSelectorSeat == seat else { return nil }
            return trumpAction(hand: me.hand, seat: seat, difficulty: difficulty)

        case .khichai:
            guard let step = state.khichaiCurrent, step.creditorSeat == seat else { return nil }
            guard let drawn = step.drawnCard else {
                // fanIndex nil → the engine draws blind on our behalf.
                return .khichaiDraw(seat: seat, fanIndex: nil)
            }
            return khichaiDecision(hand: me.hand, drawn: drawn, trump: state.trump, seat: seat)

        case .play:
            guard state.currentTurnSeat == seat else { return nil }
            let legal = TDPLegalMoves.legalCards(state, seat: seat)
            guard let card = choosePlay(state: state, me: me, legal: legal, difficulty: difficulty) else { return nil }
            return .playCard(seat: seat, cardID: card.tdpID)

        default:
            return nil
        }
    }

    // MARK: Trump

    private static func trumpAction(hand: [Card], seat: TDPSeat, difficulty: TDPAIDifficulty) -> TDPAction {
        let (bestSuit, bestScore) = bestTrumpSuit(hand)
        guard difficulty != .easy else {
            return .selectTrumpSuit(seat: seat, suit: bestSuit)
        }
        // The selector owes 5 of 10 tricks. With nothing to build on, take
        // the escape hatch that leaks least rather than naming a bad suit.
        if bestScore < 11 {
            return .selectTrumpHighestOfThree(seat: seat)
        }
        return .selectTrumpSuit(seat: seat, suit: bestSuit)
    }

    /// Length is worth more than height here: a 30-card pack means a 4-card
    /// trump holding usually controls the suit.
    static func bestTrumpSuit(_ hand: [Card]) -> (suit: Suit, score: Int) {
        var scores: [Suit: Int] = [:]
        for card in hand {
            var value = 2                       // length
            switch card.rank {
            case .ace:   value += 4
            case .king:  value += 3
            case .queen: value += 2
            case .jack:  value += 1
            default:     break
            }
            scores[card.suit, default: 0] += value
        }
        // Longer suits in the pack (♠/♥ have 8 cards) are marginally better.
        for suit in [Suit.spades, .hearts] where scores[suit] != nil {
            scores[suit]! += 1
        }
        let best = scores.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return lhs.key.tdpTieBreak < rhs.key.tdpTieBreak
        }
        return (best?.key ?? .spades, best?.value ?? 0)
    }

    // MARK: Khichai

    private static func khichaiDecision(hand: [Card], drawn: Card, trump: Suit?, seat: TDPSeat) -> TDPAction? {
        let candidates = TDPKhichai.legalReturns(hand: hand, drawn: drawn)
        guard let worst = candidates.min(by: { cardValue($0, trump: trump) < cardValue($1, trump: trump) }) else {
            return nil
        }
        return .khichaiReturn(seat: seat, cardID: worst.tdpID)
    }

    private static func cardValue(_ card: Card, trump: Suit?) -> Int {
        var value = card.rank.rawValue
        if let trump, card.suit == trump { value += 20 }
        return value
    }

    // MARK: Card play

    private static func choosePlay(state: TDPGameState,
                                   me: TDPPlayer,
                                   legal: [Card],
                                   difficulty: TDPAIDifficulty) -> Card? {
        guard !legal.isEmpty else { return nil }
        guard difficulty != .easy else {
            // Use the replayable game RNG rather than process-global
            // randomness. Playing this card changes the next legal-card list.
            var rng = state.rng
            return legal[rng.int(upperBound: legal.count)]
        }

        let trump = state.trump
        let quota = state.quota(at: me.seat)
        // Delta is unbounded upward, so there is never a reason to duck for
        // our own sake — but hitting quota is the priority.
        let stillNeeds = me.tricksWon < quota

        // Leading.
        if state.currentTrick.isEmpty {
            let nonTrump = trump.map { t in legal.filter { $0.suit != t } } ?? legal
            let pool = nonTrump.isEmpty ? legal : nonTrump
            // Behind quota: lead strength to force tricks out. Otherwise
            // bleed low cards and keep the winners for later.
            return stillNeeds ? highest(pool) : lowest(pool)
        }

        let best = TDPLegalMoves.winningCardSoFar(state)
        let isLastToPlay = state.currentTrick.count == TDPRoles.seatCount - 1

        // Following suit.
        if let lead = state.leadSuit, legal.allSatisfy({ $0.suit == lead }) {
            let winners = legal.filter { card in
                guard let best else { return true }
                // Only beats the leader if the leader isn't already trumped.
                return best.suit != trump && card.rank > best.rank
            }
            if !winners.isEmpty && (stillNeeds || isLastToPlay) {
                return lowest(winners)          // win as cheaply as possible
            }
            return lowest(legal)
        }

        // Void in the led suit — trump in if it takes the trick and we need it.
        if let trump, stillNeeds {
            let trumps = legal.filter { $0.suit == trump }
            if !trumps.isEmpty {
                let sufficient: [Card]
                if let best, best.suit == trump {
                    sufficient = trumps.filter { $0.rank > best.rank }
                } else {
                    sufficient = trumps
                }
                if !sufficient.isEmpty { return lowest(sufficient) }
            }
        }

        // Otherwise discard the least useful card, keeping trumps back.
        let discards = trump.map { t in legal.filter { $0.suit != t } } ?? legal
        return lowest(discards.isEmpty ? legal : discards)
    }

    private static func lowest(_ cards: [Card]) -> Card? {
        cards.min { $0.rank < $1.rank }
    }

    private static func highest(_ cards: [Card]) -> Card? {
        cards.max { $0.rank < $1.rank }
    }
}
