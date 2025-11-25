//
//  AIEngine.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import Foundation

// MARK: - AI Decision Engine
class AIEngine {
    
    // MARK: - Main Decision Method
    static func makeDecision(
        for player: Player,
        gameState: GameState,
        personality: AIPersonality
    ) -> PlayerAction {
        
        let handStrength = calculateHandStrength(
            player: player,
            communityCards: gameState.communityCards
        )
        
        let potOdds = calculatePotOdds(
            pot: gameState.pot,
            callAmount: gameState.currentBet - player.currentBet
        )
        
        let position = calculatePosition(
            player: player,
            dealerIndex: gameState.dealerIndex,
            playerCount: gameState.activePlayers.count
        )
        
        // Decision based on personality
        switch personality {
        case .tightAggressive:
            return tightAggressiveStrategy(
                handStrength: handStrength,
                potOdds: potOdds,
                position: position,
                gameState: gameState,
                player: player
            )
            
        case .loosePassive:
            return loosePassiveStrategy(
                handStrength: handStrength,
                potOdds: potOdds,
                gameState: gameState,
                player: player
            )
            
        case .balanced:
            return balancedStrategy(
                handStrength: handStrength,
                potOdds: potOdds,
                position: position,
                gameState: gameState,
                player: player
            )
            
        case .bluffer:
            return blufferStrategy(
                handStrength: handStrength,
                gameState: gameState,
                player: player
            )
        }
    }
    
    // MARK: - Hand Strength Calculation
    private static func calculateHandStrength(player: Player, communityCards: [Card]) -> Double {
        if communityCards.isEmpty {
            // Pre-flop hand strength
            return calculatePreFlopStrength(holeCards: player.holeCards)
        }
        
        // Post-flop hand strength
        let allCards = player.holeCards + communityCards
        let evaluation = HandEvaluator.evaluateBestHand(from: allCards)
        
        // Convert hand rank to strength (0.0 to 1.0)
        let baseStrength = Double(evaluation.rank.rawValue) / 10.0
        
        // Add kicker strength
        let kickerBonus = evaluation.kickers.first.map { Double($0.rawValue) / 140.0 } ?? 0
        
        return min(baseStrength + kickerBonus, 1.0)
    }
    
    private static func calculatePreFlopStrength(holeCards: [Card]) -> Double {
        guard holeCards.count == 2 else { return 0.0 }
        
        let card1 = holeCards[0]
        let card2 = holeCards[1]
        
        // Pocket pairs
        if card1.rank == card2.rank {
            let pairValue = Double(card1.rank.rawValue)
            return 0.5 + (pairValue / 14.0) * 0.4
        }
        
        // Suited cards
        let suited = card1.suit == card2.suit
        let suitedBonus = suited ? 0.1 : 0.0
        
        // High cards
        let highCard = max(card1.rank.rawValue, card2.rank.rawValue)
        let lowCard = min(card1.rank.rawValue, card2.rank.rawValue)
        
        // Connected cards (straights potential)
        let gap = highCard - lowCard
        let connectedBonus: Double
        switch gap {
        case 1: connectedBonus = 0.08  // Connected
        case 2: connectedBonus = 0.04  // One gap
        case 3: connectedBonus = 0.02  // Two gaps
        default: connectedBonus = 0.0
        }
        
        // Ace combinations
        let hasAce = card1.rank == .ace || card2.rank == .ace
        let aceBonus = hasAce ? 0.1 : 0.0
        
        // Base strength from card values
        let baseStrength = (Double(highCard + lowCard) / 28.0) * 0.4
        
        return min(baseStrength + suitedBonus + connectedBonus + aceBonus, 0.95)
    }
    
    // MARK: - Pot Odds Calculation
    private static func calculatePotOdds(pot: Int, callAmount: Int) -> Double {
        guard callAmount > 0 else { return 1.0 }
        return Double(callAmount) / Double(pot + callAmount)
    }
    
    // MARK: - Position Calculation
    private static func calculatePosition(player: Player, dealerIndex: Int, playerCount: Int) -> Position {
        // Position relative to dealer
        // Early: First 1/3 of players
        // Middle: Second 1/3 of players
        // Late: Last 1/3 of players (including dealer)
        
        let playerPosition = (player.id - dealerIndex + playerCount) % playerCount
        let positionRatio = Double(playerPosition) / Double(playerCount)
        
        if positionRatio < 0.33 {
            return .early
        } else if positionRatio < 0.67 {
            return .middle
        } else {
            return .late
        }
    }
    
    // MARK: - AI Strategies
    
    private static func tightAggressiveStrategy(
        handStrength: Double,
        potOdds: Double,
        position: Position,
        gameState: GameState,
        player: Player
    ) -> PlayerAction {
        
        let positionBonus = position.bonus
        let effectiveStrength = handStrength + positionBonus
        
        // Fold weak hands
        if effectiveStrength < 0.45 {
            return gameState.currentBet > player.currentBet ? .fold : .check
        }
        
        // Raise with strong hands
        if effectiveStrength > 0.75 {
            let raiseAmount = calculateRaiseAmount(
                pot: gameState.pot,
                minRaise: gameState.minRaise,
                maxRaise: player.chips,
                aggression: 0.8
            )
            if raiseAmount > 0 {
                return .raise(raiseAmount)
            }
        }
        
        // Call with good odds
        if effectiveStrength > 0.6 && potOdds < handStrength {
            return .call
        }
        
        return gameState.currentBet > player.currentBet ? .fold : .check
    }
    
    private static func loosePassiveStrategy(
        handStrength: Double,
        potOdds: Double,
        gameState: GameState,
        player: Player
    ) -> PlayerAction {
        
        // Only fold very weak hands
        if handStrength < 0.2 && gameState.currentBet > player.currentBet {
            let callAmount = gameState.currentBet - player.currentBet
            if callAmount > player.chips / 3 {
                return .fold
            }
        }
        
        // Occasionally raise with very strong hands
        if handStrength > 0.8 && Double.random(in: 0...1) < 0.2 {
            let raiseAmount = gameState.minRaise
            if raiseAmount <= player.chips {
                return .raise(raiseAmount)
            }
        }
        
        // Call most of the time
        if gameState.currentBet > player.currentBet {
            let callAmount = gameState.currentBet - player.currentBet
            if callAmount <= player.chips / 2 {
                return .call
            }
        }
        
        return gameState.currentBet > player.currentBet ? .call : .check
    }
    
    private static func balancedStrategy(
        handStrength: Double,
        potOdds: Double,
        position: Position,
        gameState: GameState,
        player: Player
    ) -> PlayerAction {
        
        let random = Double.random(in: 0...1)
        let positionFactor = position.bonus
        let effectiveStrength = handStrength + positionFactor
        
        // Strong hands - raise most of the time
        if effectiveStrength > 0.75 {
            if random < 0.7 {
                let raiseAmount = calculateRaiseAmount(
                    pot: gameState.pot,
                    minRaise: gameState.minRaise,
                    maxRaise: player.chips,
                    aggression: 0.6
                )
                if raiseAmount > 0 {
                    return .raise(raiseAmount)
                }
            }
            return .call
        }
        
        // Medium hands - mix of calls and occasional raises
        if effectiveStrength > 0.5 {
            // Bluff occasionally in late position
            if position == .late && random < 0.2 {
                let bluffAmount = gameState.minRaise
                if bluffAmount <= player.chips / 2 {
                    return .raise(bluffAmount)
                }
            }
            
            if potOdds < handStrength {
                return .call
            }
        }
        
        // Weak hands - fold to aggression
        if effectiveStrength < 0.35 && gameState.currentBet > player.currentBet {
            return .fold
        }
        
        return gameState.currentBet > player.currentBet ? .call : .check
    }
    
    private static func blufferStrategy(
        handStrength: Double,
        gameState: GameState,
        player: Player
    ) -> PlayerAction {
        
        let bluffChance = 0.3
        let random = Double.random(in: 0...1)
        
        // Bluff with weak hands
        if handStrength < 0.4 && random < bluffChance {
            let bluffAmount = calculateRaiseAmount(
                pot: gameState.pot,
                minRaise: gameState.minRaise,
                maxRaise: player.chips,
                aggression: 0.9
            )
            if bluffAmount > 0 && bluffAmount <= player.chips / 2 {
                return .raise(bluffAmount)
            }
        }
        
        // Play strong hands very aggressively
        if handStrength > 0.65 {
            let raiseAmount = calculateRaiseAmount(
                pot: gameState.pot,
                minRaise: gameState.minRaise,
                maxRaise: player.chips,
                aggression: 1.0
            )
            if raiseAmount > 0 {
                return .raise(raiseAmount)
            }
            return .call
        }
        
        // Semi-bluff with medium hands
        if handStrength > 0.4 && random < 0.4 {
            if gameState.currentBet == player.currentBet {
                let betAmount = gameState.pot / 2
                if betAmount > gameState.minRaise && betAmount <= player.chips / 3 {
                    return .raise(betAmount)
                }
            }
            return .call
        }
        
        // Fold very weak hands to big bets
        let callAmount = gameState.currentBet - player.currentBet
        if handStrength < 0.3 && callAmount > player.chips / 4 {
            return .fold
        }
        
        return gameState.currentBet > player.currentBet ? .call : .check
    }

    
    // MARK: - Helper Methods
    
    private static func calculateRaiseAmount(
        pot: Int,
        minRaise: Int,
        maxRaise: Int,
        aggression: Double
    ) -> Int {
        
        // Calculate raise based on pot size and aggression
        let potPercentage = 0.5 + (aggression * 0.5) // 50% to 100% of pot
        let targetRaise = Int(Double(pot) * potPercentage)
        
        // Ensure it's within valid range
        let validRaise = max(minRaise, min(targetRaise, maxRaise))
        
        // Add some randomness
        let variance = Double.random(in: 0.8...1.2)
        let finalRaise = Int(Double(validRaise) * variance)
        
        return max(minRaise, min(finalRaise, maxRaise))
    }
}

// MARK: - Supporting Types

enum Position {
    case early
    case middle
    case late
    
    var bonus: Double {
        switch self {
        case .early: return 0.0
        case .middle: return 0.05
        case .late: return 0.1
        }
    }
}

struct GameState {
    let pot: Int
    let currentBet: Int
    let minRaise: Int
    let communityCards: [Card]
    let activePlayers: [Player]
    let dealerIndex: Int
}
