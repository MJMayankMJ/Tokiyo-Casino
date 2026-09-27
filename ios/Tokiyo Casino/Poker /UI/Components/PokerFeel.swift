//
//  PokerFeel.swift
//  Poker
//
//  What a hand sounds and feels like, in one place so the offline table and
//  the nearby-friends table agree. Every player's move has a sound; only
//  yours has a haptic.
//

import Foundation

enum PokerFeel {

    static func prepare() {
        GameAudio.shared.prepare()
        GameHaptics.shared.prepare()
    }

    /// Someone acted. The other players' moves sound a little further away.
    static func action(_ action: PlayerAction, byYou: Bool) {
        let audio = GameAudio.shared
        let volume: Float = byYou ? 1 : 0.75
        switch action {
        case .fold:
            audio.play(.sweep, volume: volume * 0.8)
            if byYou { GameHaptics.shared.play(.fold) }
        case .check:
            audio.play(.check, volume: volume)
            if byYou { GameHaptics.shared.play(.check) }
        case .call:
            audio.play(.bet, volume: volume)
            if byYou { GameHaptics.shared.play(.chips) }
        case .raise:
            audio.play(.raise, volume: volume)
            if byYou { GameHaptics.shared.play(.chips) }
        case .allIn:
            audio.play(.allIn, volume: volume)
            if byYou { GameHaptics.shared.play(.chips) }
        }
    }

    static func newHand() {
        GameAudio.shared.play(.shuffle)
    }

    /// Two cards to each seat, dealt around the table.
    static func holeCardsDealt(seats: Int) {
        GameAudio.shared.play(.deal, times: min(max(seats, 2) * 2, 10), every: 0.07, delay: 0.25)
    }

    /// The flop, turn or river landing, one card at a time.
    static func communityCards(new count: Int) {
        guard count > 0 else { return }
        GameAudio.shared.play(.flip, times: count, every: 0.08)
    }

    /// Felt, not heard — a ping every turn gets old fast.
    static func yourTurn() {
        GameHaptics.shared.play(.yourTurn)
    }

    /// The chips slide to the winner; if that's you, you feel it too.
    static func potWon(byYou: Bool) {
        GameAudio.shared.play(.pot, volume: byYou ? 1 : 0.7)
        if byYou { GameHaptics.shared.play(.win) }
    }

    static func showdownFlip() {
        GameAudio.shared.play(.flip, volume: 0.6)
    }
}
