//
//  GameManagerBetting.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import Foundation

extension GameManager {
    
    // MARK: - Betting Round Management
    func shouldEndBettingRound() -> Bool {
        let activeBettingPlayers = activePlayers.filter { !$0.isAllIn }
        
        // All but one folded
        if activePlayers.count <= 1 {
            return true
        }
        
        // Everyone is all-in
        if activeBettingPlayers.isEmpty {
            return true
        }
        
        if activeBettingPlayers.count == 1,
           let onlyBettingPlayer = activeBettingPlayers.first,
           activePlayers.contains(where: { $0.isAllIn }),
           onlyBettingPlayer.currentBet >= currentBet {
            return true
        }
        
        // All active players have acted and bets are equal
        for player in activeBettingPlayers {
            if !player.hasActed || (player.currentBet < currentBet && !player.isAllIn) {
                return false
            }
        }
        
        return true
    }
    
    // Enhanced betting round end check
    func endBettingRound() {
        print("Ending betting round. Phase: \(currentPhase)")
        
        // Check if only one player remains (early end)
        let nonFoldedPlayers = players.filter { $0.isActive && !$0.isFolded }
        if nonFoldedPlayers.count == 1 {
            print("Only one player remaining, ending hand early")
            
            if let winner = nonFoldedPlayers.first {
                let winAmount = mainPot.amount
                winner.win(amount: winAmount)
                mainPot.reset()
                
                // 1) Reveal cards (only this non-folded player will show)
                DispatchQueue.main.async {
                    self.delegate?.gameDidEnd()   // → revealAllCards() → only winner gets shown
                }
                
                // 2) Wait same 4 seconds before showing alert
                let revealDelay: TimeInterval = 4.0
                DispatchQueue.main.asyncAfter(deadline: .now() + revealDelay) {
                    self.showWinnerAlert(
                        player: winner,
                        amount: winAmount,
                        handDescription: "All others folded"
                    )
                }
            }
            return
        }

        
        // If everyone who is still in the hand is already all-in,
        // there is no more betting to do on later streets.
        let activeBettingPlayers = activePlayers.filter { !$0.isAllIn && !$0.isFolded }
        if activeBettingPlayers.isEmpty {
            print("All remaining players are all-in – skipping further betting rounds and going to showdown.")
            showdown()
            return
        }
        
        // Normal path: reset for next round
        for player in players {
            player.hasActed = false
            player.currentBet = 0
        }
        currentBet = 0
        lastRaiseAmount = bigBlind
        minRaise = bigBlind
        currentBetAllowsRaises = true
        currentPlayerIndex = 0
        
        // Move to next phase
        switch currentPhase {
        case .preFlop:
            dealFlop()
        case .flop:
            dealTurn()
        case .turn:
            dealRiver()
        case .river:
            showdown()
        default:
            break
        }
    }
    
    // Helper method to reset betting round
    func resetBettingRound() {
        for player in players {
            player.hasActed = false
            player.currentBet = 0
        }
        currentBet = 0
        lastRaiseAmount = bigBlind
        minRaise = bigBlind
        currentBetAllowsRaises = true
        
        // Find first active player after dealer for new betting round
        currentPlayerIndex = findFirstActivePlayerAfterDealer()
    }
}
