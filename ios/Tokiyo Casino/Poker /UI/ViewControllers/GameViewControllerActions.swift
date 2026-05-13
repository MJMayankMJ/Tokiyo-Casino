//
//  GameViewControllerActions.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import UIKit

extension GameViewController {
    
    // MARK: - Game Actions
    func startNewHand() {
        newHandButton.isHidden = true
        bettingControls.isHidden = true
        handWinners = [] // Reset winners for new hand
        
        // Reset human player position
        tableView.adjustHumanPlayerPosition(shiftUp: false)
        
        // Clear table with animation
        tableView.clearTable()
        
        // Add preparation haptic
        addHapticFeedback(.medium)
        
        // Start new hand after table is cleared
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.gameManager.startNewHand()
        }
    }
    
    func handlePlayerAction(_ action: PlayerAction) {
        guard let currentPlayer = gameManager.currentPlayer,
              currentPlayer.isHuman else { return }
        
        // Hide controls immediately to prevent double-clicking or UI glitches
        bettingControls.isHidden = true
        gameManager.processPlayerAction(action, for: currentPlayer)
    }
    
    func showBettingControls() {
        guard let humanPlayer = gameManager.humanPlayer,
              humanPlayer.id == gameManager.currentPlayer?.id else { return }
        
        let validActions = gameManager.getValidActions(for: humanPlayer)
        let callAmount = gameManager.currentBet - humanPlayer.currentBet
        let minRaise = gameManager.minRaise
        let maxRaise = humanPlayer.chips
        
        // Shift human player view up to make space for betting controls
        tableView.adjustHumanPlayerPosition(shiftUp: true)
        
        // Small delay to let player view animate first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.bettingControls.updateForActions(
                validActions,
                callAmount: callAmount,
                minRaise: minRaise,
                maxRaise: maxRaise
            )
            self.bettingControls.isHidden = false
        }
    }
    
    func hideBettingControls() {
        bettingControls.isHidden = true
        
        // Reset human player position with animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.tableView.adjustHumanPlayerPosition(shiftUp: false)
        }
    }
    
    // MARK: - Actions
    @objc func menuTapped() {
        addHapticFeedback(.light)
        
        let alert = UIAlertController(title: "Menu", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "New Game", style: .default) { [weak self] _ in
            self?.addHapticFeedback(.medium)
            self?.setupGame()
        })
        
        alert.addAction(UIAlertAction(title: "Exit to Menu", style: .default) { [weak self] _ in
            // 💰 Settle coins when exiting the Poker screen
            self?.settleCoinsIfNeeded()
            self?.addHapticFeedback(.medium)
            self?.dismiss(animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.addHapticFeedback(.light)
        })
        
        present(alert, animated: true)
    }

    @objc func newHandTapped() {
        addHapticFeedback(.medium)
        startNewHand()
    }
    
    @objc func muteTapped() {
        addHapticFeedback(.light)
        SoundManager.setMuted(!SoundManager.isMuted)
    }
}
