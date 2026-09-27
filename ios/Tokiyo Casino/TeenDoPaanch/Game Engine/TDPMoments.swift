//
//  TDPMoments.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  The two plays worth a fanfare. Pure rules: the table plays the effect
//  (`TDPMomentEffects`) — a first cut as it's played and won, a steal only
//  once the point is confirmed, as the trick is taken — and the host holds
//  a cut trick a little longer so there's time to enjoy it.
//
//  • First cut — a suit is led for the first time this round and you trump
//    it: you were already out of it.
//  • Steal — you take a trick with a Q or lower while the card just above
//    yours is still out, in someone else's hand. Hold A and Q, win with the
//    Q: a steal. Hold K and Q, win with the Q: no surprise. A card that is
//    already the highest one left isn't a surprise either.
//

import Foundation

enum TDPMoment: Equatable {
    case firstCut
    case steal(Rank)
}

enum TDPMoments {

    /// Suits already led in this round's finished tricks.
    static func ledSuits(_ tricks: [[TDPTrickPlay]]) -> Set<Suit> {
        Set(tricks.compactMap { $0.first?.card.suit })
    }

    /// `play` has just gone onto `trick` (which includes it). A cut is
    /// playing trump on a side suit; the first cut is doing it the first
    /// time that suit is led this round.
    static func isFirstCut(play: TDPTrickPlay, trick: [TDPTrickPlay],
                           trump: Suit?, earlier: [[TDPTrickPlay]]) -> Bool {
        guard let trump, let lead = trick.first, lead.seat != play.seat else { return false }
        let led = lead.card.suit
        return led != trump && play.card.suit == trump && !ledSuits(earlier).contains(led)
    }

    /// For a finished trick won by `winner`, holding `hand` after it: the
    /// rank of a steal, or nil. The winning card must follow the led suit
    /// (trump led counts) and be a Q or lower, and the next card above it
    /// that hasn't been played must be in someone else's hand.
    static func steal(trick: [TDPTrickPlay], winner: TDPSeat, hand: [Card],
                      earlier: [[TDPTrickPlay]]) -> Rank? {
        guard let led = trick.first?.card.suit,
              let won = trick.first(where: { $0.seat == winner })?.card,
              won.suit == led, won.rank <= .queen else { return nil }
        let gone = Set((earlier.flatMap { $0 } + trick).map(\.card.tdpID))
        let nextUp = TDPDeck.build()
            .filter { $0.suit == led && $0.rank > won.rank && !gone.contains($0.tdpID) }
            .min { $0.rank < $1.rank }
        guard let nextUp else { return nil }                   // already the highest left
        return hand.contains(nextUp) ? nil : won.rank
    }

    /// The moment in a finished trick for its winner, if there is one.
    static func moment(trick: [TDPTrickPlay], winner: TDPSeat, winnerHand: [Card],
                       trump: Suit?, earlier: [[TDPTrickPlay]]) -> TDPMoment? {
        guard let play = trick.first(where: { $0.seat == winner }) else { return nil }
        if isFirstCut(play: play, trick: trick, trump: trump, earlier: earlier) { return .firstCut }
        return steal(trick: trick, winner: winner, hand: winnerHand, earlier: earlier).map { .steal($0) }
    }

    // MARK: Host timing

    /// A person just threw down a first cut — give the slam a beat before
    /// the next card lands.
    static func justCut(_ s: TDPGameState) -> Bool {
        guard let play = s.currentTrick.last, s.currentTrick.count > 1,
              s.player(at: play.seat)?.isAI == false else { return false }
        return isFirstCut(play: play, trick: s.currentTrick, trump: s.trump, earlier: s.roundTricks)
    }

    /// A person won the trick on the table with a moment.
    static func pendingMoment(_ s: TDPGameState) -> TDPMoment? {
        guard s.phase == .trickResolve, let winner = s.lastTrickWinnerSeat,
              let player = s.player(at: winner), !player.isAI else { return nil }
        return moment(trick: s.currentTrick, winner: winner, winnerHand: player.hand,
                      trump: s.trump, earlier: s.roundTricks)
    }
}
