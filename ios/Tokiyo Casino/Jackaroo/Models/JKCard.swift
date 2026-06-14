//
//  JKCard.swift
//  Tokiyo Casino — Jackaroo
//
//  Jackaroo needs Codable cards (for replay, autosave, log). The Poker
//  module's `Card` / `Suit` / `Rank` are not Codable — they were defined
//  before Jackaroo existed and adding `Codable` to them would touch
//  unrelated code. So we keep a Jackaroo-local card type and bridge
//  to / from the Poker types at the UI boundary (PokerDesign.CardView
//  takes a `Card`).
//
//  See JACKAROO_TECH_SPEC.md §2 for the rationale.
//

import Foundation

// MARK: - Suit + Rank

public enum JKSuit: String, Codable, CaseIterable, Hashable {
    case hearts, diamonds, clubs, spades

    /// Red suits trigger the `redElevenBlackSwap` / `blackTwelveRedDiscard`
    /// rule variants. Default preset doesn't use them.
    var isRed: Bool { self == .hearts || self == .diamonds }
}

public enum JKRank: Int, Codable, CaseIterable, Comparable, Hashable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack = 11, queen, king, ace

    public static func < (l: JKRank, r: JKRank) -> Bool { l.rawValue < r.rawValue }

    /// Face value used by simple forward / backward moves. Aces and
    /// the variant cards (J/Q/K) are handled by dedicated paths and
    /// should not be read through this property.
    var simpleFaceValue: Int { rawValue }
}

// MARK: - Card

public struct JKCard: Codable, Hashable, Equatable {
    public let suit: JKSuit
    public let rank: JKRank

    public init(suit: JKSuit, rank: JKRank) {
        self.suit = suit
        self.rank = rank
    }

    /// Display string used in logs + debug. UI uses the Poker `CardView`
    /// atom via `asPokerCard`.
    var debugDescription: String {
        let r: String
        switch rank {
        case .jack:  r = "J"
        case .queen: r = "Q"
        case .king:  r = "K"
        case .ace:   r = "A"
        default:     r = String(rank.rawValue)
        }
        let s: String
        switch suit {
        case .hearts:   s = "♥"
        case .diamonds: s = "♦"
        case .clubs:    s = "♣"
        case .spades:   s = "♠"
        }
        return "\(r)\(s)"
    }
}

// MARK: - Accessibility

extension JKCard {
    /// Spoken card name for VoiceOver, e.g. "Ace of spades".
    var accessibleName: String {
        let rankWord: String
        switch rank {
        case .ace: rankWord = "Ace"
        case .king: rankWord = "King"
        case .queen: rankWord = "Queen"
        case .jack: rankWord = "Jack"
        default: rankWord = String(rank.rawValue)
        }
        let suitWord: String
        switch suit {
        case .hearts: suitWord = "hearts"
        case .diamonds: suitWord = "diamonds"
        case .clubs: suitWord = "clubs"
        case .spades: suitWord = "spades"
        }
        return "\(rankWord) of \(suitWord)"
    }
}

// MARK: - Bridge to Poker module types

// These map the Jackaroo-local Codable types to the existing Poker types
// so the visual `CardView` / `SuitView` atoms keep working without forks.

extension JKSuit {
    var asPokerSuit: Suit {
        switch self {
        case .hearts:   return .hearts
        case .diamonds: return .diamonds
        case .clubs:    return .clubs
        case .spades:   return .spades
        }
    }

    init(_ poker: Suit) {
        switch poker {
        case .hearts:   self = .hearts
        case .diamonds: self = .diamonds
        case .clubs:    self = .clubs
        case .spades:   self = .spades
        }
    }
}

extension JKRank {
    /// Raw values line up 1:1 (2…14) between the two enums, so the
    /// init can never fail in practice — we still trap if it does
    /// so the bug surfaces immediately.
    var asPokerRank: Rank {
        guard let r = Rank(rawValue: self.rawValue) else {
            fatalError("JKRank \(self.rawValue) has no Poker Rank counterpart")
        }
        return r
    }

    init(_ poker: Rank) {
        guard let j = JKRank(rawValue: poker.rawValue) else {
            fatalError("Poker Rank \(poker.rawValue) has no JKRank counterpart")
        }
        self = j
    }
}

extension JKCard {
    var asPokerCard: Card { Card(suit: suit.asPokerSuit, rank: rank.asPokerRank) }

    init(_ poker: Card) {
        self.init(suit: JKSuit(poker.suit), rank: JKRank(poker.rank))
    }
}

// MARK: - Deck helpers

extension JKCard {
    /// A fresh 52-card deck in canonical order. Shufflers seed their own
    /// RNG; we never use `Array.shuffle()` because that pulls from the
    /// system RNG which breaks replay determinism.
    static func freshDeck() -> [JKCard] {
        var out: [JKCard] = []
        out.reserveCapacity(52)
        for suit in JKSuit.allCases {
            for rank in JKRank.allCases {
                out.append(JKCard(suit: suit, rank: rank))
            }
        }
        return out
    }
}
