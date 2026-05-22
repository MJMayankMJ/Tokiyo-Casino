//
//  JKTestHelpers.swift
//  Tokiyo CasinoTests — Jackaroo Phase 1
//
//  Tiny fixture helpers so every test reads as state-setup → expected
//  moves, without 30 lines of init boilerplate up top.
//

import Foundation
@testable import Tokiyo_Casino

enum JKFixture {
    /// Empty board: 4 humans, all marbles in Home, deck untouched.
    static func makeState(rules: JKRulesPreset = .jawakerBasic,
                          dealer: SeatID = 0,
                          seed: UInt64 = 0xCAFE_F00D) -> JKGameState {
        let players = (0..<4).map { JKPlayer(seat: $0, name: "P\($0)", kind: .human) }
        var marbles: [JKMarble] = []
        for seat in 0..<4 {
            for slot in 0..<4 {
                marbles.append(JKMarble(id: seat * 4 + slot,
                                         owner: seat,
                                         position: .home(slot: slot)))
            }
        }
        return JKGameState(players: players,
                           marbles: marbles,
                           dealer: dealer,
                           rules: rules,
                           seed: seed)
    }

    /// Put `marbleID` on `cell` and clear the matching Home slot.
    static func place(_ marbleID: MarbleID, at position: JKPosition,
                      in state: inout JKGameState) {
        guard let idx = state.marbles.firstIndex(where: { $0.id == marbleID }) else {
            preconditionFailure("Unknown marble \(marbleID)")
        }
        state.marbles[idx].position = position
    }

    /// Stuff the active seat's hand with the given cards.
    static func setHand(_ cards: [JKCard], for seat: SeatID,
                        in state: inout JKGameState) {
        state.players[seat].hand = cards
        state.currentSeat = seat
        state.phase = .playing
    }

    static let aceSpades = JKCard(suit: .spades, rank: .ace)
    static let twoHearts = JKCard(suit: .hearts, rank: .two)
    static let fourClubs = JKCard(suit: .clubs, rank: .four)
    static let sevenHearts = JKCard(suit: .hearts, rank: .seven)
    static let jackSpades = JKCard(suit: .spades, rank: .jack)
    static let queenSpades = JKCard(suit: .spades, rank: .queen)
    static let kingSpades = JKCard(suit: .spades, rank: .king)
}
