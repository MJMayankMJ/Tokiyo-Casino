//
//  GameManagerTurns.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import Foundation

extension GameManager {
    
    // MARK: - Turn Management
    func processNextTurn() {
        // If somehow no active players, just end the round defensively
        guard !activePlayers.isEmpty else {
            endBettingRound()
            return
        }
        
        guard let current = currentPlayer else {
            endBettingRound()
            return
        }
        
        // If current player cannot act (all-in or folded), skip them
        if current.isAllIn || current.isFolded {
            let bettingPlayers = activePlayers.filter { !$0.isAllIn && !$0.isFolded }
            
            // Nobody left who can bet → end betting round
            if bettingPlayers.isEmpty {
                endBettingRound()
            } else {
                // Move to the next player who can actually act
                currentPlayerIndex = findNextActivePlayerIndex(after: currentPlayerIndex)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.processNextTurn()
                }
            }
            return
        }
        
        // Normal path: current player can act
        delegate?.currentPlayerChanged(current)
        
        if current.isHuman {
            // Wait for human input (bettingControls are shown by currentPlayerChanged)
            return
        }
        
        // AI makes decision after a delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.processAITurn()
        }
    }

    func processAITurn() {
        guard let current = currentPlayer,
              let personality = current.personality else { return }
        
        let gameState = GameState(
            pot: mainPot.amount,
            currentBet: currentBet,
            minRaise: minRaise,
            communityCards: communityCards,
            activePlayers: activePlayers,
            dealerIndex: dealerIndex
        )
        
        let decision = AIEngine.makeDecision(
            for: current,
            gameState: gameState,
            personality: personality
        )
        
        processPlayerAction(decision, for: current)
    }
    
    func moveToNextPlayer() {
        currentPlayerIndex = findNextActivePlayerIndex(after: currentPlayerIndex)
    }
    
    func findNextActivePlayerIndex(after index: Int) -> Int {
        let active = activePlayers
        guard !active.isEmpty else { return -1 }
        
        var nextIndex = (index + 1) % active.count
        var attempts = 0
        
        while attempts < active.count {
            let player = active[nextIndex]
            // FIX: Explicitly skip players who are All-In
            // They are still "active" for winning, but inactive for betting turns
            if !player.isAllIn && !player.isFolded {
                return nextIndex
            }
            nextIndex = (nextIndex + 1) % active.count
            attempts += 1
        }
        
        return -1
    }
    
    func findFirstActivePlayerAfterDealer() -> Int {
        let activePlayerIds = activePlayers.map { $0.id }
        
        // Start from small blind position (dealer + 1)
        var searchIndex = (dealerIndex + 1) % players.count
        var attempts = 0
        
        while attempts < players.count {
            let player = players[searchIndex]
            if let activeIndex = activePlayerIds.firstIndex(of: player.id),
               !player.isAllIn && !player.isFolded {
                return activeIndex
            }
            searchIndex = (searchIndex + 1) % players.count
            attempts += 1
        }
        
        return 0 // Fallback
    }
}
