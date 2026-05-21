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
        hideBettingControls()
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
        hideBettingControls()
        gameManager.processPlayerAction(action, for: currentPlayer)
    }
    
    func showBettingControls() {
        guard let humanPlayer = gameManager.humanPlayer,
              humanPlayer.id == gameManager.currentPlayer?.id else { return }
        
        let validActions = gameManager.getValidActions(for: humanPlayer)
        let callAmount = gameManager.currentBet - humanPlayer.currentBet
        let minRaise = gameManager.minRaise
        let maxRaise = max(0, humanPlayer.chips - max(callAmount, 0))
        
        // Shift human player view up to make space for betting controls
        tableView.adjustHumanPlayerPosition(shiftUp: true)
        
        // Small delay to let player view animate first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.bettingControls.isHidden = false
            self.bettingControls.updateForActions(
                validActions,
                callAmount: callAmount,
                minRaise: minRaise,
                maxRaise: maxRaise,
                currentBet: self.gameManager.currentBet,
                allInTotal: humanPlayer.currentBet + humanPlayer.chips
            )
            self.bettingControlsHeightConstraint?.constant = self.bettingControls.preferredHeight
            UIView.animate(withDuration: 0.24, delay: 0, options: [.curveEaseInOut]) {
                self.view.layoutIfNeeded()
            }
        }
    }
    
    func hideBettingControls() {
        bettingControls.isHidden = true
        bettingControlsHeightConstraint?.constant = 0
        UIView.animate(withDuration: 0.20, delay: 0, options: [.curveEaseInOut]) {
            self.view.layoutIfNeeded()
        }
        
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

        let soundTitle = SoundManager.isMuted ? "Unmute Sound" : "Mute Sound"
        alert.addAction(UIAlertAction(title: soundTitle, style: .default) { [weak self] _ in
            self?.addHapticFeedback(.light)
            SoundManager.setMuted(!SoundManager.isMuted)
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

    @objc func rulesTapped() {
        addHapticFeedback(.light)
        present(PokerRulesViewController(), animated: true)
    }

    // MARK: - Hand details (top-right icon)
    @objc func handDetailsTapped() {
        guard hasCompletedFirstHand, let summary = lastHandSummary else { return }
        addHapticFeedback(.light)

        let vc = GameSummaryViewController(
            playerSummaries: summary.playerSummaries,
            totalPot: summary.totalPot,
            communityCards: summary.communityCards
        )
        vc.onClose = { [weak self] in
            self?.addHapticFeedback(.light)
        }
        present(vc, animated: true)
    }

    /// Keeps the top-right details icon enabled only when there is a
    /// completed hand to inspect.
    func refreshHandDetailsButton() {
        guard let bar = topInfoBar else { return }
        let enabled = hasCompletedFirstHand && lastHandSummary != nil
        bar.menuButton.isEnabled = enabled
        bar.menuButton.alpha = enabled ? 1.0 : 0.4
    }
}
