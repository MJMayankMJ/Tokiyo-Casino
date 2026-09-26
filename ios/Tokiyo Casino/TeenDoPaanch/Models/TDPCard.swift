//
//  TDPCard.swift
//  Tokiyo Casino — Teen Do Paanch (5-3-2)
//
//  The 30-card Teen Do Paanch pack and its ordering rules. Reuses the
//  shared `Card`/`Suit`/`Rank` value types from Poker so we inherit the
//  existing card art (`imageName`) for free.
//
//  Pack: 8..A in every suit (28) + 7♥ + 7♠ = 30.
//  Rank, high → low: A K Q J 10 9 8 7.
//

import Foundation

// MARK: - Wire coding

/// Compact `Codable` form so every multiplayer payload can carry cards
/// directly: "AS", "10H", "7D". Additive to the shared `Card` type — no
/// behavioural change for Poker.
extension Card: Codable {

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        guard let card = Card(tdpID: raw) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath,
                      debugDescription: "Unrecognised card id: \(raw)")
            )
        }
        self = card
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(tdpID)
    }
}

/// `Suit` is a `String`-backed enum, so this is the synthesised conformance.
/// Additive to the shared Poker type — no behavioural change there.
extension Suit: Codable {}

extension Suit {
    /// Single-letter wire code.
    var tdpCode: String {
        switch self {
        case .spades:   return "S"
        case .hearts:   return "H"
        case .diamonds: return "D"
        case .clubs:    return "C"
        }
    }

    static func tdpFromCode(_ code: String) -> Suit? {
        switch code.uppercased() {
        case "S": return .spades
        case "H": return .hearts
        case "D": return .diamonds
        case "C": return .clubs
        default:  return nil
        }
    }

    /// Bridge-style tie-break used when the "highest of three" trump rule
    /// hits a rank tie: ♠ > ♥ > ♦ > ♣.
    var tdpTieBreak: Int {
        switch self {
        case .spades:   return 4
        case .hearts:   return 3
        case .diamonds: return 2
        case .clubs:    return 1
        }
    }

    /// Display order used when fanning a hand.
    var tdpSortOrder: Int {
        switch self {
        case .spades:   return 0
        case .hearts:   return 1
        case .diamonds: return 2
        case .clubs:    return 3
        }
    }
}

extension Card {

    /// Stable identity, e.g. "AS", "10H", "7♠" → "7S".
    var tdpID: String { "\(rank.shortString)\(suit.tdpCode)" }

    init?(tdpID: String) {
        guard tdpID.count >= 2 else { return nil }
        let suitCode = String(tdpID.suffix(1))
        let rankPart = String(tdpID.dropLast())
        guard let suit = Suit.tdpFromCode(suitCode),
              let rank = Rank.tdpFromShort(rankPart) else { return nil }
        self.init(suit: suit, rank: rank)
    }

    /// Ace-high comparison. Rank first, then the suit tie-break.
    static func tdpIsHigher(_ a: Card, than b: Card) -> Bool {
        if a.rank != b.rank { return a.rank > b.rank }
        return a.suit.tdpTieBreak > b.suit.tdpTieBreak
    }
}

extension Rank {
    static func tdpFromShort(_ raw: String) -> Rank? {
        switch raw.uppercased() {
        case "7":  return .seven
        case "8":  return .eight
        case "9":  return .nine
        case "10": return .ten
        case "J":  return .jack
        case "Q":  return .queen
        case "K":  return .king
        case "A":  return .ace
        default:   return nil
        }
    }
}

// MARK: - Pack

enum TDPDeck {

    static let size = 30

    /// Ranks present in the pack, low → high.
    static let ranks: [Rank] = [.seven, .eight, .nine, .ten, .jack, .queen, .king, .ace]

    /// Builds the 30-card pack in a deterministic order. Sevens exist only
    /// in hearts and spades.
    static func build() -> [Card] {
        var deck: [Card] = []
        for suit in [Suit.spades, .hearts, .diamonds, .clubs] {
            for rank in ranks {
                if rank == .seven && (suit == .clubs || suit == .diamonds) { continue }
                deck.append(Card(suit: suit, rank: rank))
            }
        }
        return deck
    }

    /// True if the card belongs in a Teen Do Paanch pack.
    static func contains(_ card: Card) -> Bool {
        guard ranks.contains(card.rank) else { return false }
        if card.rank == .seven { return card.suit == .hearts || card.suit == .spades }
        return true
    }

    /// Fisher–Yates driven by the seeded RNG so a seed replays exactly.
    static func shuffled(_ deck: [Card], rng: inout TDPRNG) -> [Card] {
        var next = deck
        guard next.count > 1 else { return next }
        for i in stride(from: next.count - 1, to: 0, by: -1) {
            let j = rng.int(upperBound: i + 1)
            next.swapAt(i, j)
        }
        return next
    }

    /// Highest card by rank, breaking rank ties on suit.
    static func highest(_ cards: [Card]) -> Card? {
        guard var best = cards.first else { return nil }
        for card in cards.dropFirst() where Card.tdpIsHigher(card, than: best) {
            best = card
        }
        return best
    }

    /// Display sort: ♠ ♥ ♦ ♣, each descending by rank.
    static func sortHand(_ cards: [Card]) -> [Card] {
        cards.sorted { a, b in
            if a.suit != b.suit { return a.suit.tdpSortOrder < b.suit.tdpSortOrder }
            return a.rank > b.rank
        }
    }
}
