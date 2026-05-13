//
//  GameViewControllerSummary.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import UIKit

extension GameViewController {
    
    @objc func showDelayedWinnerAlert(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let player = userInfo["player"] as? Player,
              let amount = userInfo["amount"] as? Int,
              let handDescription = userInfo["handDescription"] as? String else {
            return
        }
        
        // Store winner info for the summary
        handWinners.append((player: player, amount: amount, handDescription: handDescription))
        
        // Show the summary after a small delay to ensure all winners are collected
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showGameSummary()
        }
    }
    
    // MARK: - Game Summary
    func showGameSummary() {
        guard !handWinners.isEmpty else { return }
        
        // Create player summaries
        var summaries: [PlayerSummary] = []
        
        for player in gameManager.players {
            let category: PlayerSummary.PlayerCategory
            var handDescription: String?
            
            // Determine category
            if let winnerInfo = handWinners.first(where: { $0.player.id == player.id }) {
                category = .winner
                handDescription = winnerInfo.handDescription
            } else if player.isFolded {
                category = .folded
            } else {
                category = .lost
                // Evaluate hand for lost players
                let allCards = player.holeCards + gameManager.communityCards
                let evaluation = HandEvaluator.evaluateBestHand(from: allCards)
                handDescription = evaluation.description
            }
            
            summaries.append(PlayerSummary(
                player: player,
                handDescription: handDescription,
                category: category
            ))
        }
        
        // Create and present summary view controller
        let summaryVC = GameSummaryViewController(
            playerSummaries: summaries,
            totalPot: handWinners.reduce(0) { $0 + $1.amount }, // Total pot from all winners
            communityCards: gameManager.communityCards
        )
        
        summaryVC.modalPresentationStyle = .fullScreen
        
        summaryVC.onNewGame = { [weak self] in
            self?.startNewHand()
        }
        
        // ⬇️ When leaving to Menu from the summary, settle net chips → coins
        summaryVC.onMenu = { [weak self] in
            self?.settleCoinsIfNeeded()
            self?.dismiss(animated: true)
        }
        
        present(summaryVC, animated: true)
    }
    
    // MARK: - Coins settlement (Poker $ ↔︎ Tokyo Coins 1:1)
    func settleCoinsIfNeeded() {
        guard !hasSettledCoins,
              let human = gameManager?.humanPlayer else { return }
        
        let delta = human.chips - initialBuyIn    // net won/lost in dollars == coins
        hasSettledCoins = true
        
        if delta > 0 {
            CoinsManager.shared.addCoins(amount: Int64(delta)) { _ in }
        } else if delta < 0 {
            CoinsManager.shared.deductCoins(amount: Int64(-delta)) { _ in }
        }
    }
}
