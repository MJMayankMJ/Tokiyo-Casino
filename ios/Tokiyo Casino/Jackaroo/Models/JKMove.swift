//
//  JKMove.swift
//  Tokiyo Casino — Jackaroo
//
//  Every possible action a player can take, plus the card(s) it
//  consumes. The resolver moves the cards to the Fire Pile in one
//  place using this association.
//
//  Tuples cannot synthesize Codable/Hashable inside enum associated
//  values, so 7-split allocations are a struct.
//

import Foundation

/// One marble's share of a 7-split allocation. `steps` is strictly > 0.
public struct JKSplitAllocation: Codable, Hashable {
    public let marble: MarbleID
    public let steps: Int

    public init(marble: MarbleID, steps: Int) {
        self.marble = marble
        self.steps = steps
    }
}

public enum JKMove: Codable, Hashable {
    /// Ace or King fielding a Home marble onto the player's Base cell.
    case fieldFromHome(card: JKCard, marble: MarbleID)

    /// Forward movement. `steps` is the **consumed card value** so a
    /// path that crosses into Safe is still represented as a single
    /// forward move; the resolver knows from state which cells the
    /// marble actually visits.
    case forward(card: JKCard, marble: MarbleID, steps: Int)

    /// Backward 4. Card is always a 4 in the default preset.
    case backward(card: JKCard, marble: MarbleID, steps: Int)

    /// 7 split. 2 entries in `twoOwn`, up to 4 in `multiOwn`.
    case split7(card: JKCard, allocations: [JKSplitAllocation])

    /// Jack swap. Both marbles must be on-track (not Home / Base-
    /// protected / Safe). With handoff engaged, `ownMarble` may belong
    /// to the partner.
    case swap(card: JKCard, ownMarble: MarbleID, otherMarble: MarbleID)

    /// `fiveMode = .anyMarbleOnTrack` only — move any on-track marble
    /// forward 5.
    case anyMarble5(card: JKCard, marble: MarbleID, steps: Int)

    /// Red queen forces a victim to discard. The acting player picks
    /// `victim`; the resolver picks which of the victim's cards is
    /// lost at apply time (using `state.rng`) and logs the choice via
    /// `JKGameLog.redQueenResolved`. The move carries no hidden info.
    case redQueenDiscard(card: JKCard, victim: SeatID)

    /// Whole-hand burn — discards every card in the player's hand.
    case burnHand(cards: [JKCard])

    /// Single-card burn — discards one specific card.
    case burnCard(card: JKCard)
}

extension JKMove {
    /// Every card consumed by this move, for the Fire Pile.
    var consumedCards: [JKCard] {
        switch self {
        case let .fieldFromHome(c, _):       return [c]
        case let .forward(c, _, _):          return [c]
        case let .backward(c, _, _):         return [c]
        case let .split7(c, _):              return [c]
        case let .swap(c, _, _):             return [c]
        case let .anyMarble5(c, _, _):       return [c]
        case let .redQueenDiscard(c, _):     return [c]
        case let .burnHand(cards):           return cards
        case let .burnCard(c):               return [c]
        }
    }

    /// Convenience for the AI scorer + tests.
    var isBurn: Bool {
        switch self {
        case .burnHand, .burnCard: return true
        default: return false
        }
    }
}
