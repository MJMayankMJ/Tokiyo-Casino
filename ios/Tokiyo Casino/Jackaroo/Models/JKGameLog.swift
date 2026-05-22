//
//  JKGameLog.swift
//  Tokiyo Casino — Jackaroo
//
//  Append-only event log. Together with the initial seed it's enough
//  to replay an entire game deterministically.
//

import Foundation

public enum JKGameLog {
    public enum Event: Codable, Hashable {
        case dealStart(dealer: SeatID, cardsPerSeat: Int)
        case played(seat: SeatID, move: JKMove)
        case marbleMoved(MarbleID, from: JKPosition, to: JKPosition, via: [CellID])
        case captured(MarbleID, by: SeatID)
        case swapped(MarbleID, MarbleID, by: SeatID)
        case redQueenResolved(victim: SeatID, discardedCard: JKCard)
        case handoffEngaged(seat: SeatID)
        case burned(seat: SeatID, cards: [JKCard])
        case reshuffled
        case gameOver(winner: JKTeam)
    }
}
