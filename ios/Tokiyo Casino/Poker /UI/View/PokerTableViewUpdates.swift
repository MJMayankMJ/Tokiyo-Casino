//
//  PokerTableViewUpdates.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import UIKit

extension PokerTableView {
    
    // MARK: - Updates
    func updatePlayers(_ players: [Player], dealerIndex: Int) {
        self.players = players
        
        print("PokerTableView: updatePlayers called with \(players.count) players")
        
        for (index, player) in players.enumerated() {
            if index < playerViews.count {
                playerViews[index].configureWith(player: player, isDealer: index == dealerIndex)
                playerViews[index].showBet(player.currentBet)
            }
        }
    }
    
    func showCommunityCards(_ cards: [Card]) {
        print("Showing \(cards.count) community cards")
        
        for (index, card) in cards.enumerated() {
            if index < communityCardViews.count {
                let cardView = communityCardViews[index]
                cardView.setCard(card, faceUp: true)
                cardView.isHidden = false
                
                // Enhanced animation with better timing
                cardView.alpha = 0
                cardView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1).rotated(by: .pi)
                
                UIView.animate(
                    withDuration: 0.6,
                    delay: Double(index) * 0.2,
                    usingSpringWithDamping: 0.6,
                    initialSpringVelocity: 0.8,
                    options: [.curveEaseOut]
                ) {
                    cardView.alpha = 1
                    cardView.transform = .identity
                }
            }
        }
    }
    
    func updatePot(_ amount: Int) {
        potLabel.text = "Pot: $\(amount)"
        
        // Enhanced pot animation
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
            self.potLabel.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
        } completion: { _ in
            UIView.animate(withDuration: 0.3) {
                self.potLabel.transform = .identity
            }
        }
    }
    
    func updatePhase(_ phase: GamePhase) {
        phaseLabel.text = phase.description
        
        // Color based on phase
        switch phase {
        case .waiting:
            phaseLabel.backgroundColor = UIColor.gray.withAlphaComponent(0.6)
        case .preFlop:
            phaseLabel.backgroundColor = UIColor.blue.withAlphaComponent(0.6)
        case .flop:
            phaseLabel.backgroundColor = UIColor.green.withAlphaComponent(0.6)
        case .turn:
            phaseLabel.backgroundColor = UIColor.orange.withAlphaComponent(0.6)
        case .river:
            phaseLabel.backgroundColor = UIColor.red.withAlphaComponent(0.6)
        case .showdown:
            phaseLabel.backgroundColor = UIColor.purple.withAlphaComponent(0.6)
        }
        
        // Animation
        UIView.animate(withDuration: 0.4) {
            self.phaseLabel.alpha = 0.4
        } completion: { _ in
            UIView.animate(withDuration: 0.4) {
                self.phaseLabel.alpha = 1.0
            }
        }
    }
    
    func showPlayerAction(_ player: Player, action: PlayerAction) {
        for (index, p) in players.enumerated() where p.id == player.id {
            if index < playerViews.count {
                playerViews[index].showAction(action)
                playerViews[index].showBet(player.currentBet)
            }
        }
    }
    
    func highlightCurrentPlayer(_ player: Player) {
        for (index, p) in players.enumerated() {
            if index < playerViews.count {
                let isCurrent = p.id == player.id
                playerViews[index].setHighlighted(isCurrent)
            }
        }
    }
    
    func showWinner(_ winner: Player) {
        print("PokerTableView: showWinner called for \(winner.name)")
        
        // Find and animate the winner
        for (index, p) in players.enumerated() where p.id == winner.id {
            if index < playerViews.count {
                print("PokerTableView: Found winner at index \(index)")
                playerViews[index].showWinAnimation()
            }
        }
    }

    func revealAllCards() {
        print("Revealing all player cards - Total players: \(playerViews.count)")
        
        for (index, playerView) in playerViews.enumerated() {
            let delay = Double(index) * 0.3
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                playerView.revealCards()
            }
        }
    }
    
    func clearTable() {
        // Hide and reset community cards
        for cardView in communityCardViews {
            UIView.animate(withDuration: 0.2) {
                cardView.alpha = 0
                cardView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
            } completion: { _ in
                cardView.isHidden = true
                cardView.alpha = 1
                cardView.transform = .identity
            }
        }
        
        // Reset pot
        potLabel.text = "Pot: $0"
        
        // Reset phase
        phaseLabel.text = "Waiting..."
        phaseLabel.backgroundColor = UIColor.gray.withAlphaComponent(0.6)
        
        // Reset player highlights
        for playerView in playerViews {
            playerView.setHighlighted(false)
        }
    }
}
