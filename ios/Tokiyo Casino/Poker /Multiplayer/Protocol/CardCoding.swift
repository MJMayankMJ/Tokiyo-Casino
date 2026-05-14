//
//  CardCoding.swift
//  Tokiyo Casino — Offline Friends Poker
//
//  Codable bridge for the existing `Card` value type. The wire form is a
//  small JSON object with lowercase suit/rank strings so Android decoders
//  can map onto their own enums without parsing platform-specific blobs.
//

import Foundation

struct CardDTO: Codable, Equatable, Hashable {

    /// One of: "hearts" | "diamonds" | "clubs" | "spades".
    let suit: String

    /// One of: "2".."10" | "jack" | "queen" | "king" | "ace".
    let rank: String

    init(suit: String, rank: String) {
        self.suit = suit
        self.rank = rank
    }
}

extension Card {
    var dto: CardDTO { CardDTO(suit: suit.rawValue, rank: rank.string) }

    init?(dto: CardDTO) {
        guard let suit = Suit(rawValue: dto.suit) else { return nil }
        guard let rank = Rank.fromString(dto.rank) else { return nil }
        self.init(suit: suit, rank: rank)
    }
}

extension Rank {
    /// Inverse of `string`. Tolerates both the long form ("ace") and the
    /// short single-character form ("A") to forgive minor Android client
    /// drift; the canonical Tokiyo wire form is the long form.
    static func fromString(_ raw: String) -> Rank? {
        switch raw.lowercased() {
        case "2": return .two
        case "3": return .three
        case "4": return .four
        case "5": return .five
        case "6": return .six
        case "7": return .seven
        case "8": return .eight
        case "9": return .nine
        case "10", "t": return .ten
        case "jack", "j": return .jack
        case "queen", "q": return .queen
        case "king", "k": return .king
        case "ace", "a": return .ace
        default: return nil
        }
    }
}
