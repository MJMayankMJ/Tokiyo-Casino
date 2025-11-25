//
//  HandEvaluator.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import Foundation

// MARK: - Hand Rank
enum HandRank: Int, Comparable {
    case highCard = 1
    case onePair = 2
    case twoPair = 3
    case threeOfAKind = 4
    case straight = 5
    case flush = 6
    case fullHouse = 7
    case fourOfAKind = 8
    case straightFlush = 9
    case royalFlush = 10
    
    static func < (lhs: HandRank, rhs: HandRank) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var description: String {
        switch self {
        case .highCard: return "High Card"
        case .onePair: return "One Pair"
        case .twoPair: return "Two Pair"
        case .threeOfAKind: return "Three of a Kind"
        case .straight: return "Straight"
        case .flush: return "Flush"
        case .fullHouse: return "Full House"
        case .fourOfAKind: return "Four of a Kind"
        case .straightFlush: return "Straight Flush"
        case .royalFlush: return "Royal Flush"
        }
    }
}

// MARK: - Hand Evaluation
struct HandEvaluation {
    let rank: HandRank
    let cards: [Card]  // Best 5 cards
    let kickers: [Rank] // For tie breaking
    let value: Int // Numeric value for comparison
    
    var description: String {
        return rank.description
    }
}

// MARK: - Hand Evaluator
class HandEvaluator {
    
    // Evaluate best 5-card hand from up to 7 cards
    static func evaluateBestHand(from cards: [Card]) -> HandEvaluation {
        guard cards.count >= 5 else {
            return HandEvaluation(
                rank: .highCard,
                cards: cards.sorted { $0.rank.rawValue > $1.rank.rawValue },
                kickers: cards.map { $0.rank }.sorted(by: >),
                value: calculateHighCardValue(cards)
            )
        }
        
        // Generate all 5-card combinations
        let combinations = generateCombinations(cards, choose: 5)
        var bestEvaluation: HandEvaluation?
        
        for combo in combinations {
            let evaluation = evaluateFiveCards(combo)
            if bestEvaluation == nil || evaluation.value > bestEvaluation!.value {
                bestEvaluation = evaluation
            }
        }
        
        return bestEvaluation!
    }
    
    // Generate combinations
    private static func generateCombinations(_ cards: [Card], choose k: Int) -> [[Card]] {
        guard k > 0 else { return [[]] }
        guard k <= cards.count else { return [] }
        
        if k == cards.count { return [cards] }
        
        var result: [[Card]] = []
        
        for i in 0...(cards.count - k) {
            let current = cards[i]
            let remaining = Array(cards[(i + 1)...])
            let subCombinations = generateCombinations(remaining, choose: k - 1)
            
            for subCombo in subCombinations {
                result.append([current] + subCombo)
            }
        }
        
        return result
    }
    
    // Evaluate exactly 5 cards
    private static func evaluateFiveCards(_ cards: [Card]) -> HandEvaluation {
        let sortedCards = cards.sorted { $0.rank.rawValue > $1.rank.rawValue }
        
        // Check for flush
        let isFlush = checkFlush(cards)
        
        // Check for straight
        let straightHighCard = checkStraight(sortedCards)
        let isWheel = checkWheel(sortedCards) // A-2-3-4-5
        let isStraight = straightHighCard != nil || isWheel
        
        // Count ranks
        let rankGroups = Dictionary(grouping: cards, by: { $0.rank })
        let counts = rankGroups.mapValues { $0.count }.sorted { $0.value > $1.value }
        
        // Determine hand rank and value
        if isFlush && isStraight {
            if straightHighCard == .ace && sortedCards[1].rank == .king {
                // Royal Flush
                return HandEvaluation(
                    rank: .royalFlush,
                    cards: sortedCards,
                    kickers: [],
                    value: 900000000
                )
            }
            // Straight Flush
            let highValue = isWheel ? 5 : (straightHighCard?.rawValue ?? 0)
            return HandEvaluation(
                rank: .straightFlush,
                cards: sortedCards,
                kickers: [],
                value: 800000000 + highValue * 100000
            )
        }
        
        if counts.first?.value == 4 {
            // Four of a Kind
            let quad = counts.first!.key
            let kicker = rankGroups.keys.first { $0 != quad }!
            return HandEvaluation(
                rank: .fourOfAKind,
                cards: sortedCards,
                kickers: [kicker],
                value: 700000000 + quad.rawValue * 100000 + kicker.rawValue
            )
        }
        
        if counts.first?.value == 3 && counts.dropFirst().first?.value == 2 {
            // Full House
            let trips = counts.first!.key
            let pair = counts.dropFirst().first!.key
            return HandEvaluation(
                rank: .fullHouse,
                cards: sortedCards,
                kickers: [],
                value: 600000000 + trips.rawValue * 100000 + pair.rawValue * 1000
            )
        }
        
        if isFlush {
            // Flush
            let values = sortedCards.map { $0.rank.rawValue }
            return HandEvaluation(
                rank: .flush,
                cards: sortedCards,
                kickers: sortedCards.map { $0.rank },
                value: 500000000 + calculateKickerValue(values)
            )
        }
        
        if isStraight {
            // Straight
            let highValue = isWheel ? 5 : (straightHighCard?.rawValue ?? 0)
            return HandEvaluation(
                rank: .straight,
                cards: sortedCards,
                kickers: [],
                value: 400000000 + highValue * 100000
            )
        }
        
        if counts.first?.value == 3 {
            // Three of a Kind
            let trips = counts.first!.key
            let kickers = rankGroups.keys.filter { $0 != trips }.sorted(by: >)
            return HandEvaluation(
                rank: .threeOfAKind,
                cards: sortedCards,
                kickers: kickers,
                value: 300000000 + trips.rawValue * 100000 + calculateKickerValue(kickers.map { $0.rawValue })
            )
        }
        
        if counts.first?.value == 2 && counts.dropFirst().first?.value == 2 {
            // Two Pair
            let pairs = counts.prefix(2).map { $0.key }.sorted(by: >)
            let kicker = rankGroups.keys.first { !pairs.contains($0) }!
            return HandEvaluation(
                rank: .twoPair,
                cards: sortedCards,
                kickers: [kicker],
                value: 200000000 + pairs[0].rawValue * 100000 + pairs[1].rawValue * 1000 + kicker.rawValue
            )
        }
        
        if counts.first?.value == 2 {
            // One Pair
            let pair = counts.first!.key
            let kickers = rankGroups.keys.filter { $0 != pair }.sorted(by: >)
            return HandEvaluation(
                rank: .onePair,
                cards: sortedCards,
                kickers: kickers,
                value: 100000000 + pair.rawValue * 100000 + calculateKickerValue(kickers.map { $0.rawValue })
            )
        }
        
        // High Card
        return HandEvaluation(
            rank: .highCard,
            cards: sortedCards,
            kickers: sortedCards.map { $0.rank },
            value: calculateKickerValue(sortedCards.map { $0.rank.rawValue })
        )
    }
    
    // Helper functions
    private static func checkFlush(_ cards: [Card]) -> Bool {
        return cards.allSatisfy { $0.suit == cards[0].suit }
    }
    
    private static func checkStraight(_ sortedCards: [Card]) -> Rank? {
        let ranks = sortedCards.map { $0.rank.rawValue }
        for i in 0..<ranks.count - 1 {
            if ranks[i] - ranks[i + 1] != 1 {
                return nil
            }
        }
        return sortedCards[0].rank
    }
    
    private static func checkWheel(_ sortedCards: [Card]) -> Bool {
        let ranks = sortedCards.map { $0.rank }
        return ranks[0] == .ace &&
               ranks[1] == .five &&
               ranks[2] == .four &&
               ranks[3] == .three &&
               ranks[4] == .two
    }
    
    private static func calculateKickerValue(_ values: [Int]) -> Int {
        var result = 0
        var multiplier = 10000
        for value in values.prefix(5) {
            result += value * multiplier
            multiplier /= 100
        }
        return result
    }
    
    private static func calculateHighCardValue(_ cards: [Card]) -> Int {
        let sorted = cards.sorted { $0.rank.rawValue > $1.rank.rawValue }
        return calculateKickerValue(sorted.map { $0.rank.rawValue })
    }
}
