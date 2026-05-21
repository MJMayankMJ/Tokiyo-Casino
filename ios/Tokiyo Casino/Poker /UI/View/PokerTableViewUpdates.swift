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
                let side = cardSide(forPlayerIndex: index, totalPlayers: players.count)
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

    // MARK: - Showdown highlights

    /// Marks the cards in `winningCards` with the warm amber highlight on
    /// both the community row and the winning player's hole cards; everything
    /// else dims to the faded beige treatment.
    /// `winnerPlayerId` is the seat that owns the winning hand — only that
    /// player's unused hole card (if any) is dimmed; other non-folded players
    /// keep their cards bright but un-highlighted so the user can still read
    /// the showdown.
    func highlightWinningCards(_ winningCards: [Card], winnerPlayerId: Int?) {
        // Community cards
        for cv in communityCardViews {
            guard let c = cv.card, !cv.isHidden else {
                cv.highlightState = .none
                continue
            }
            cv.highlightState = winningCards.contains(c) ? .winning : .unused
        }
        // Player hole cards — only fade the winner's unused card; for losers
        // we leave their two cards bright but unhighlighted so the user can
        // still read them. The banner makes the actual winner obvious.
        for (index, pv) in playerViews.enumerated() {
            guard index < players.count else { continue }
            let p = players[index]
            if p.id == winnerPlayerId {
                pv.applyShowdownHighlight(winningCards: winningCards, anyHighlight: true)
            } else {
                pv.clearCardHighlights()
            }
        }
    }

    func clearWinningHighlights() {
        for cv in communityCardViews { cv.highlightState = .none }
        for pv in playerViews { pv.clearCardHighlights() }
    }

    // MARK: - Round-result banner

    /// Shows the compact result banner over the felt and auto-dismisses
    /// after `duration`. Banner is positioned between the pot pill and the
    /// community row so it doesn't cover either.
    func showRoundResultBanner(entries: [RoundResultBanner.Entry],
                               duration: TimeInterval,
                               completion: @escaping () -> Void) {
        resultBanner?.removeFromSuperview()
        let banner = RoundResultBanner(entries: entries)
        banner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(banner)
        resultBanner = banner

        // Anchor the banner just above the community card row so multi-winner
        // entries can stack upward without ever covering the highlighted
        // cards. The pot pill can be briefly overlapped — it's not a card.
        let communityTop = communityCardViews.first?.frame.minY ?? designFrame.midY
        let maxW = min(designFrame.width - 40 * designScale, 280 * designScale)
        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: centerXAnchor),
            banner.bottomAnchor.constraint(equalTo: topAnchor, constant: communityTop - 8 * designScale),
            banner.widthAnchor.constraint(lessThanOrEqualToConstant: maxW),
        ])
        banner.presentAnimated()

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self else { completion(); return }
            if self.resultBanner === banner {
                banner.dismissAnimated { [weak self] in
                    self?.resultBanner = nil
                    completion()
                }
            } else {
                completion()
            }
        }
    }

    func dismissRoundResultBanner() {
        guard let banner = resultBanner else { return }
        resultBanner = nil
        banner.dismissAnimated {}
    }

    // MARK: - Pot animation

    /// Animates a snapshot of the pot pill flying toward the winner's seat.
    func animatePotTo(playerId: Int) {
        guard let index = players.firstIndex(where: { $0.id == playerId }),
              index < playerViews.count else { return }
        let target = playerViews[index]

        guard let snapshot = potPill.snapshotView(afterScreenUpdates: false) else { return }
        snapshot.frame = potPill.frame
        addSubview(snapshot)

        let destination = convert(target.center, from: target.superview)
        UIView.animate(
            withDuration: 0.85,
            delay: 0,
            usingSpringWithDamping: 0.85,
            initialSpringVelocity: 0.6,
            options: [.curveEaseInOut]
        ) {
            snapshot.center = destination
            snapshot.transform = CGAffineTransform(scaleX: 0.45, y: 0.45)
            snapshot.alpha = 0.0
        } completion: { _ in
            snapshot.removeFromSuperview()
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

        // Drop any showdown overlays from the previous hand.
        clearWinningHighlights()
        resultBanner?.removeFromSuperview()
        resultBanner = nil
    }
}
