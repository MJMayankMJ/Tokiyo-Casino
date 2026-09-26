//
//  TDPLegalMoves.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  Follow-suit enforcement and trick resolution. Pure functions over the
//  state — no mutation.
//

import Foundation

enum TDPLegalMoves {

    static func legalCards(_ state: TDPGameState, seat: TDPSeat) -> [Card] {
        guard state.phase == .play,
              state.currentTurnSeat == seat,
              let player = state.player(at: seat)
        else { return [] }

        // Leading.
        if state.currentTrick.isEmpty {
            return player.hand
        }

        // Following — must follow the led suit when able.
        guard let lead = state.leadSuit else { return player.hand }
        let followers = player.hand.filter { $0.suit == lead }
        return followers.isEmpty ? player.hand : followers
    }

    static func validate(_ state: TDPGameState, seat: TDPSeat, cardID: String) -> TDPError? {
        guard state.phase == .play else { return TDPError("It is not time to play a card.") }
        guard state.currentTurnSeat == seat else { return TDPError("It is not your turn.") }
        guard let player = state.player(at: seat) else { return TDPError("Unknown player.") }
        guard let card = player.hand.first(where: { $0.tdpID == cardID }) else {
            return TDPError("You do not hold that card.")
        }

        if state.currentTrick.isEmpty {
            return nil
        }

        if let lead = state.leadSuit,
           player.hand.contains(where: { $0.suit == lead }),
           card.suit != lead {
            return TDPError("You must follow \(lead.rawValue).")
        }
        return nil
    }

    /// Highest trump wins; otherwise the highest card of the led suit.
    /// A discard of a third suit can never win.
    static func trickWinner(plays: [TDPTrickPlay], trump: Suit, leadSuit: Suit) -> TDPSeat? {
        let trumps = plays.filter { $0.card.suit == trump }
        let pool = trumps.isEmpty ? plays.filter { $0.card.suit == leadSuit } : trumps
        guard var best = pool.first else { return nil }
        for play in pool.dropFirst() where play.card.rank > best.card.rank {
            best = play
        }
        return best.seat
    }

    /// The card currently winning the in-progress trick, if any.
    static func winningCardSoFar(_ state: TDPGameState) -> Card? {
        guard let lead = state.leadSuit, let trump = state.trump, !state.currentTrick.isEmpty else { return nil }
        let trumps = state.currentTrick.filter { $0.card.suit == trump }
        let pool = trumps.isEmpty ? state.currentTrick.filter { $0.card.suit == lead } : trumps
        guard var best = pool.first?.card else { return nil }
        for play in pool.dropFirst() where play.card.rank > best.rank {
            best = play.card
        }
        return best
    }
}
