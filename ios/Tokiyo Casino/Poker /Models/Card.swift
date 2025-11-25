//
//  Card.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import UIKit

// MARK: - Suit
enum Suit: String, CaseIterable {
    case hearts = "hearts"
    case diamonds = "diamonds"
    case clubs = "clubs"
    case spades = "spades"
    
    var symbol: String {
        switch self {
        case .hearts: return "♥"
        case .diamonds: return "♦"
        case .clubs: return "♣"
        case .spades: return "♠"
        }
    }
    
    var color: UIColor {
        switch self {
        case .hearts, .diamonds: return .red
        case .clubs, .spades: return .black
        }
    }
}

// MARK: - Rank
enum Rank: Int, CaseIterable, Comparable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack, queen, king, ace
    
    static func < (lhs: Rank, rhs: Rank) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var string: String {
        switch self {
        case .jack: return "jack"
        case .queen: return "queen"
        case .king: return "king"
        case .ace: return "ace"
        default: return "\(rawValue)"
        }
    }
    
    var shortString: String {
        switch self {
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        default: return "\(rawValue)"
        }
    }
}

extension Rank {
    var imageString: String {
        switch self {
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .ten: return "10"
        case .jack: return "jack"
        case .queen: return "queen"
        case .king: return "king"
        case .ace: return "ace"
        }
    }
}

// MARK: - Card
struct Card: Equatable, Hashable {
    let suit: Suit
    let rank: Rank
    
    var imageName: String {
        // Based on your assets, use the format: "rank_of_suit_w"
        return "\(rank.imageString)_of_\(suit.rawValue)_w"
    }
    
    var description: String {
        return "\(rank.shortString)\(suit.symbol)"
    }
}


// MARK: - Deck
class Deck {
    private var cards: [Card] = []
    
    init() {
        reset()
    }
    
    func reset() {
        cards = []
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                cards.append(Card(suit: suit, rank: rank))
            }
        }
        shuffle()
    }
    
    func shuffle() {
        cards.shuffle()
    }
    
    func deal() -> Card? {
        return cards.isEmpty ? nil : cards.removeFirst()
    }
    
    func dealMultiple(_ count: Int) -> [Card] {
        var dealtCards: [Card] = []
        for _ in 0..<count {
            if let card = deal() {
                dealtCards.append(card)
            }
        }
        return dealtCards
    }
    
    var remainingCards: Int {
        return cards.count
    }
}
