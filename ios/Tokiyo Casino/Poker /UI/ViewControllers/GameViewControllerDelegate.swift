//
//  GameViewControllerDelegate.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import UIKit

// MARK: - GameManagerDelegate
extension GameViewController: GameManagerDelegate {
    func gameDidStart() {
        addHapticFeedback(.light)
        if tableView.playerViews.isEmpty {
            tableView.setupPlayers(gameManager.players, dealerIndex: gameManager.dealerIndex)
        } else {
            tableView.updatePlayers(gameManager.players, dealerIndex: gameManager.dealerIndex)
        }
    }
    
    func gamePhaseDidChange(_ phase: GamePhase) {
        addHapticFeedback(.light)
        tableView.updatePhase(phase)
        topInfoBar?.setInfo(
            blinds: "\(gameManager.smallBlind)/\(gameManager.bigBlind)",
            hand: nil,
            phase: phase.description
        )

        // Special effects for showdown
        if phase == .showdown {
            addHapticFeedback(.heavy)
        }
    }
    
    func playerDidAct(_ player: Player, action: PlayerAction) {
        // Different haptics for different actions
        switch action {
        case .fold:
            addHapticFeedback(.medium)
        case .check:
            addHapticFeedback(.light)
        case .call:
            addHapticFeedback(.light)
        case .raise:
            addHapticFeedback(.heavy)
        case .allIn:
            addHapticFeedback(.heavy)
            // Add a second haptic for all-in emphasis
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.addHapticFeedback(.heavy)
            }
        }
        
        tableView.showPlayerAction(player, action: action)
        tableView.updatePlayers(gameManager.players, dealerIndex: gameManager.dealerIndex)
    }
    
    func playerDidWin(_ player: Player, amount: Int, handDescription: String) {
        // Animation only; summary/alerts triggered later
        addSuccessFeedback()
        tableView.showWinner(player)
    }
    
    func gameDidEnd() {
        addHapticFeedback(.medium)
        
        // Hide betting controls immediately and reset position
        hideBettingControls()
        
        // Reveal all cards (human + AI)
        tableView.revealAllCards()
        
        // Little staggered haptics for flare
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.addHapticFeedback(.light) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.addHapticFeedback(.light) }
    }
    
    func cardsDealt() {
        addHapticFeedback(.light)
        tableView.showCommunityCards(gameManager.communityCards)
        tableView.updatePlayers(gameManager.players, dealerIndex: gameManager.dealerIndex)
    }
    
    func potDidUpdate(_ amount: Int) {
        addHapticFeedback(.light)
        tableView.updatePot(amount)
        bettingControls.setPot(amount)
    }
    
    func currentPlayerChanged(_ player: Player) {
        addHapticFeedback(.light)
        tableView.highlightCurrentPlayer(player)

        if player.isHuman {
            if player.isAllIn {
                hideBettingControls()
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.showBettingControls()
            }
        } else {
            hideBettingControls()
        }
    }
}
