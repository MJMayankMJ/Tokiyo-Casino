//
//  GameManagerDebug.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import Foundation

extension GameManager {
    
    // MARK: - Debug
    func validateGameState() -> Bool {
        // Check if game can continue
        let playersWithChips = players.filter { $0.chips > 0 }
        if playersWithChips.count < 2 {
            print("Game over: Not enough players with chips")
            return false
        }
        
        // Check deck has enough cards
        if deck.remainingCards < 10 {
            print("Warning: Running low on cards (\(deck.remainingCards) remaining)")
        }
        
        return true
    }
    
    func printGameState() {
        print("=== Game State ===")
        print("Phase: \(currentPhase)")
        print("Pot: $\(mainPot.amount)")
        print("Current bet: $\(currentBet)")
        print("Community cards: \(communityCards.map { $0.description }.joined(separator: ", "))")
        print("Active players: \(activePlayers.count)")
        for player in players {
            let status = player.isFolded ? "FOLDED" : player.isAllIn ? "ALL-IN" : "ACTIVE"
            print("  \(player.name): $\(player.chips) (\(status)) - Bet: $\(player.currentBet)")
        }
        print("================")
    }
}
