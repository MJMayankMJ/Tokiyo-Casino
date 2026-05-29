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
    /// True when a human has disconnected / explicitly left and the
    /// seat is held vacant for them. Treated as folded for the rest of
    /// the current hand and skipped at the next deal so the seat
    /// doesn't get hole cards until they rejoin (clear `isAway`).
    /// Solo poker never sets this; only the multiplayer host service
    /// touches it.
    var isAway: Bool = false
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
            // `isAway` seats are reserved for an offline human. They
            // get reset for the new hand but stay folded + inactive so
            // GameManager's turn loop never tries to deal them in.
            isActive = chips > 0 && !isAway
            hasActed = isAway
            isAllIn = false
            isFolded = isAway
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

    /// Phase 2 — explicit AI profile installed by the difficulty resolver
    /// (`GameManager.applyAIConfigToAISeats`). When set it overrides the
    /// personality-derived profile so a table can run a tuned difficulty mix
    /// while keeping the personality only as the visible label/avatar.
    var aiProfile: AIProfile?

    /// The profile the decision engine should actually use for this seat:
    /// the explicit override if present, otherwise the personality's preset,
    /// otherwise the strongest default. Only meaningful for AI seats.
    var resolvedProfile: AIProfile {
        aiProfile ?? personality?.profile ?? .default
    }
}
