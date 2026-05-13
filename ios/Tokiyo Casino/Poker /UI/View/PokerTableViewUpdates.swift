//
//  PokerTableViewUpdates.swift
//  Poker
//

import UIKit

extension PokerTableView {

    // MARK: - Updates
    func updatePlayers(_ players: [Player], dealerIndex: Int) {
        self.players = players
        for (index, player) in players.enumerated() {
            if index < playerViews.count {
                let side = index < cardSides.count ? cardSides[index] : .right
                playerViews[index].configureWith(player: player, isDealer: index == dealerIndex, cardSide: side)
                updateBetPill(for: player, atIndex: index)
            }
        }
        setNeedsLayout()
    }

    func showCommunityCards(_ cards: [Card]) {
        for (index, card) in cards.enumerated() {
            if index < communityCardViews.count {
                let cardView = communityCardViews[index]
                cardView.style = .face
                cardView.setCard(card, faceUp: true)
                cardView.isHidden = false

                // Deal animation: drop in and settle
                cardView.alpha = 0
                cardView.transform = CGAffineTransform(translationX: 0, y: -28)
                    .rotated(by: -.pi / 12)
                    .scaledBy(x: 0.6, y: 0.6)

                UIView.animate(
                    withDuration: 0.48,
                    delay: Double(index) * 0.08,
                    usingSpringWithDamping: 0.78,
                    initialSpringVelocity: 0.7,
                    options: [.curveEaseOut]
                ) {
                    cardView.alpha = 1
                    cardView.transform = .identity
                }
            }
        }
    }

    func updatePot(_ amount: Int) {
        potPill.setAmount(amount)
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.4) {
            self.potPill.transform = CGAffineTransform(scaleX: 1.10, y: 1.10)
        } completion: { _ in
            UIView.animate(withDuration: 0.25) {
                self.potPill.transform = .identity
            }
        }
    }

    func updatePhase(_ phase: GamePhase) {
        // No on-felt phase chip in the new design; the phase is shown in the
        // top info bar by the view controller. Keep label in sync for callers.
        phaseLabel.text = phase.description
    }

    func showPlayerAction(_ player: Player, action: PlayerAction) {
        for (index, p) in players.enumerated() where p.id == player.id {
            if index < playerViews.count {
                playerViews[index].showAction(action)
                updateBetPill(for: player, atIndex: index)
            }
        }
    }

    func highlightCurrentPlayer(_ player: Player) {
        for (index, p) in players.enumerated() {
            if index < playerViews.count {
                playerViews[index].setHighlighted(p.id == player.id)
            }
        }
    }

    func showWinner(_ winner: Player) {
        for (index, p) in players.enumerated() where p.id == winner.id {
            if index < playerViews.count {
                playerViews[index].showWinAnimation()
            }
        }
    }

    func revealAllCards() {
        for (index, playerView) in playerViews.enumerated() {
            let delay = Double(index) * 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                playerView.revealCards()
            }
        }
    }

    func clearTable() {
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

        potPill.setAmount(0)
        phaseLabel.text = "Waiting"

        // Remove bet pills
        for pill in betPills.values {
            UIView.animate(withDuration: 0.2, animations: { pill.alpha = 0 }) { _ in
                pill.removeFromSuperview()
            }
        }
        betPills.removeAll()

        for playerView in playerViews {
            playerView.setHighlighted(false)
            playerView.resetCardPresentation()
        }
    }
}
