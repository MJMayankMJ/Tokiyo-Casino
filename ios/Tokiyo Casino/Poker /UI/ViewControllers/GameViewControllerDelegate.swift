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
        PokerFeel.newHand()
        if tableView.playerViews.isEmpty {
            tableView.setupPlayers(gameManager.players, dealerIndex: gameManager.dealerIndex)
        } else {
            tableView.updatePlayers(gameManager.players, dealerIndex: gameManager.dealerIndex)
        }
    }
    
    func gamePhaseDidChange(_ phase: GamePhase) {
        tableView.updatePhase(phase)
        topInfoBar?.setInfo(
            blinds: "\(gameManager.smallBlind)/\(gameManager.bigBlind)",
            hand: nil,
            phase: phase.description
        )

    }
    
    func playerDidAct(_ player: Player, action: PlayerAction) {
        PokerFeel.action(action, byYou: player.isHuman)
        tableView.showPlayerAction(player, action: action)
        tableView.updatePlayers(gameManager.players, dealerIndex: gameManager.dealerIndex)
    }
    
    func playerDidWin(_ player: Player, amount: Int, handDescription: String) {
        // Animation only; summary/alerts triggered later
        PokerFeel.potWon(byYou: player.isHuman)
        tableView.showWinner(player)
    }
    
    func gameDidEnd() {
        // Hide betting controls immediately and reset position
        hideBettingControls()
        
        // Reveal all cards (human + AI)
        tableView.revealAllCards()
        
    }
    
    func cardsDealt() {
        let shown = tableView.communityCardViews.filter { !$0.isHidden && $0.card != nil }.count
        let fresh = gameManager.communityCards.count - shown
        if gameManager.communityCards.isEmpty {
            PokerFeel.holeCardsDealt(seats: gameManager.players.count)
        } else {
            PokerFeel.communityCards(new: fresh)
        }
        tableView.showCommunityCards(gameManager.communityCards)
        tableView.updatePlayers(gameManager.players, dealerIndex: gameManager.dealerIndex)
    }
    
    func potDidUpdate(_ amount: Int) {
        tableView.updatePot(amount)
        bettingControls.setPot(amount)
    }
    
    func currentPlayerChanged(_ player: Player) {
        tableView.highlightCurrentPlayer(player)

        if player.isHuman {
            if player.isAllIn {
                hideBettingControls()
                return
            }
            PokerFeel.yourTurn()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.showBettingControls()
            }
        } else {
            hideBettingControls()
        }
    }
}
