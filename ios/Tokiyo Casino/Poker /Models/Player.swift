//
//  Player.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import Foundation

// MARK: - Player Action
enum PlayerAction {
    case fold
    case check
    case call
    case raise(Int)
    case allIn
    
    var description: String {
        switch self {
        case .fold: return "Fold"
        case .check: return "Check"
        case .call: return "Call"
        case .raise(let amount): return "Raise $\(amount)"
        case .allIn: return "All In"
        }
    }
}

// MARK: - Player Type
enum PlayerType {
    case human
    case ai(personality: AIPersonality)
}

// MARK: - AI Personality
enum AIPersonality: CaseIterable {
    case tightAggressive
    case loosePassive
    case balanced
    case bluffer
    
    var name: String {
        switch self {
        case .tightAggressive: return "Shark"
        case .loosePassive: return "Fish"
        case .balanced: return "Pro"
        case .bluffer: return "Maniac"

        }
    }
    
    var description: String {
        switch self {
        case .tightAggressive: return "Plays few hands but bets aggressively"
        case .loosePassive: return "Plays many hands but rarely raises"
        case .balanced: return "Adapts strategy based on situation"
        case .bluffer: return "Frequently bluffs with weak hands"
        }
    }
    
    var avatar: String {
        switch self {
        case .tightAggressive: return "🦈"
        case .loosePassive: return "🐠"
        case .balanced: return "🎯"
        case .bluffer: return "😈"
        }
    }
}

// MARK: - Player
class Player {
    let id: Int
    let name: String
    let type: PlayerType
    var chips: Int
    var holeCards: [Card] = []
    var currentBet: Int = 0
    var isActive: Bool = true
    var hasActed: Bool = false
    var isAllIn: Bool = false
    var isFolded: Bool = false
    var winnings: Int = 0
    var lastAction: PlayerAction?
    var totalInvested: Int = 0
    
    // Statistics
    var handsPlayed: Int = 0
    var handsWon: Int = 0
    var biggestPot: Int = 0
    
    init(id: Int, name: String, type: PlayerType, chips: Int) {
        self.id = id
        self.name = name
        self.type = type
        self.chips = chips
    }
    
        func reset() {
            holeCards = []
            currentBet = 0
            isActive = chips > 0
            hasActed = false
            isAllIn = false
            isFolded = false
            winnings = 0
            lastAction = nil
            totalInvested = 0 // Reset investment
        }
        
        // UPDATE bet()
        func bet(amount: Int) -> Int {
            let actualBet = max(0, min(amount, chips))
            chips -= actualBet
            currentBet += actualBet
            totalInvested += actualBet // Track total investment
            
            if chips == 0 {
                isAllIn = true
            }
            
            return actualBet
        }
    
  
    
    func win(amount: Int) {
        chips += amount
        let isFirstWinThisHand = (winnings == 0)
        winnings += amount
        if isFirstWinThisHand {
            handsWon += 1
        }
        if winnings > biggestPot {
            biggestPot = winnings
        }
    }
    
    var isHuman: Bool {
        if case .human = type {
            return true
        }
        return false
    }
    
    var personality: AIPersonality? {
        if case .ai(let personality) = type {
            return personality
        }
        return nil
    }
}
