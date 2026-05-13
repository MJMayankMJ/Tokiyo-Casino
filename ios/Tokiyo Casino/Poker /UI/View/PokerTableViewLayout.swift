//
//  PokerTableViewLayout.swift
//  Poker
//
//  Felt shape, pot pill placement, community row layout, seat positioning.
//

import UIKit

extension PokerTableView {

    // MARK: - Setup

    func setupView() {
        backgroundColor = .clear

        // Felt container
        feltView.backgroundColor = PokerTheme.felt
        feltView.layer.cornerRadius = 160
        feltView.layer.masksToBounds = false
        feltView.layer.shadowColor = UIColor.black.cgColor
        feltView.layer.shadowOpacity = 0.18
        feltView.layer.shadowOffset = CGSize(width: 0, height: 10)
        feltView.layer.shadowRadius = 22
        addSubview(feltView)

        // Inner ring border for depth
        feltInnerBorder.layer.borderColor = PokerTheme.borderStrong.cgColor
        feltInnerBorder.layer.borderWidth = 1
        feltInnerBorder.layer.cornerRadius = 150
        feltInnerBorder.isUserInteractionEnabled = false
        feltView.addSubview(feltInnerBorder)

        // Hidden compatibility labels
        potLabel.isHidden = true
        addSubview(potLabel)
        phaseLabel.isHidden = true
        addSubview(phaseLabel)

        // Pot pill (above center)
        addSubview(potPill)

        // Community card row — positioned manually via frame in layoutFelt.
        for _ in 0..<5 {
            let cv = CardView()
            cv.style = .face
            cv.isHidden = true
            cv.translatesAutoresizingMaskIntoConstraints = true
            communityCardViews.append(cv)
            addSubview(cv)
        }
    }

    // MARK: - Layout

    func layoutFelt() {
        // Constrain the felt to the design's 360×480 aspect (≈1.33 tall/wide)
        // so the seat positions translate from the design without distortion.
        let designRatio: CGFloat = 480.0 / 360.0
        let edgePad: CGFloat = 16
        let maxW = max(0, bounds.width  - edgePad * 2)
        let maxH = max(0, bounds.height - edgePad * 2)

        var feltW = maxW
        var feltH = feltW * designRatio
        if feltH > maxH {
            feltH = maxH
            feltW = feltH / designRatio
        }
        let feltFrame = CGRect(
            x: bounds.midX - feltW / 2,
            y: bounds.midY - feltH / 2,
            width: feltW,
            height: feltH
        )
        feltView.frame = feltFrame
        let corner = min(feltW, feltH) * 0.45
        feltView.layer.cornerRadius = corner
        feltView.layer.shadowPath = UIBezierPath(roundedRect: feltView.bounds,
                                                 cornerRadius: corner).cgPath

        // Inner border
        let inner = feltView.bounds.insetBy(dx: 14, dy: 14)
        feltInnerBorder.frame = inner
        feltInnerBorder.layer.cornerRadius = max(0, corner - 14)

        // Pot pill — felt-relative (matches y=138/480 in the design)
        let potY = feltFrame.minY + feltFrame.height * (138.0 / 480.0)
        let potSize = potPill.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        potPill.bounds.size = CGSize(width: max(120, potSize.width), height: 30)
        potPill.center = CGPoint(x: feltFrame.midX, y: potY)

        // Community cards — felt-relative (matches y=240/480 in the design)
        let commY = feltFrame.minY + feltFrame.height * (240.0 / 480.0)
        let cardW: CGFloat = 36
        let cardH: CGFloat = 50
        let gap: CGFloat = 6
        let totalW = cardW * 5 + gap * 4
        let startX = feltFrame.midX - totalW / 2
        for (i, cv) in communityCardViews.enumerated() {
            cv.frame = CGRect(
                x: startX + CGFloat(i) * (cardW + gap),
                y: commY - cardH / 2,
                width: cardW,
                height: cardH
            )
        }
    }

    func setupPlayers(_ players: [Player], dealerIndex: Int) {
        self.players = players

        // Remove existing player views
        playerViews.forEach { $0.removeFromSuperview() }
        playerViews.removeAll()

        // Remove bet pills
        betPills.values.forEach { $0.removeFromSuperview() }
        betPills.removeAll()

        // Create new player views with proper sizing
        for (index, player) in players.enumerated() {
            let playerView = PlayerView()
            let size = player.isHuman ? humanPlayerSize : aiPlayerSize
            playerView.frame = CGRect(origin: .zero, size: size)
            addSubview(playerView)
            playerViews.append(playerView)
            playerView.configureWith(player: player, isDealer: index == dealerIndex)
        }

        DispatchQueue.main.async {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
    }

    func updatePlayerPositions() {
        let felt = feltView.frame
        guard felt.width > 0 else { return }

        for (index, playerView) in playerViews.enumerated() {
            guard index < playerPositions.count else { continue }

            let pos = playerPositions[index]
            let isHuman = index == 0
            let size = isHuman ? humanPlayerSize : aiPlayerSize
            playerView.bounds = CGRect(origin: .zero, size: size)

            let cx = felt.minX + felt.width * pos.x
            var cy = felt.minY + felt.height * pos.y

            if isHuman {
                // Hero overhangs felt's bottom edge by 10pt (mirrors the
                // design's `bottom: -10` on the HeroZone wrapper). Cards fan
                // upward into the felt, the name strip sits at felt's bottom.
                cy = felt.maxY + 10 - size.height / 2 + humanPlayerVerticalShift
            }

            playerView.center = CGPoint(x: cx, y: cy)
            playerView.setNeedsLayout()
        }
    }

    func updateBetPillPositions() {
        guard !players.isEmpty else { return }
        let felt = feltView.frame
        guard felt.width > 0 else { return }

        for (index, player) in players.enumerated() {
            guard index < betPillPositions.count else { continue }
            guard let pill = betPills[player.id] else { continue }
            let pos = betPillPositions[index]
            let size = pill.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            pill.bounds.size = CGSize(width: max(56, size.width), height: 24)
            pill.center = CGPoint(
                x: felt.minX + felt.width * pos.x,
                y: felt.minY + felt.height * pos.y
            )
        }
    }

    /// Shows or hides a bet pill near the player's seat.
    func updateBetPill(for player: Player, atIndex index: Int) {
        let hasBet = !player.isFolded && player.currentBet > 0
        if hasBet {
            let color: UIColor
            if player.isAllIn { color = PokerTheme.amber }
            else { color = chipColor(forPlayerIndex: index) }
            if let existing = betPills[player.id] {
                existing.setAmount(player.currentBet)
            } else {
                let pill = BetPillView(amount: player.currentBet, chipColor: color)
                betPills[player.id] = pill
                addSubview(pill)
                setNeedsLayout()
            }
        } else if let existing = betPills[player.id] {
            UIView.animate(withDuration: 0.2, animations: {
                existing.alpha = 0
            }) { _ in
                existing.removeFromSuperview()
                self.betPills.removeValue(forKey: player.id)
            }
        }
    }

    private func chipColor(forPlayerIndex idx: Int) -> UIColor {
        let palette: [UIColor] = [
            PokerTheme.Chip.green,
            PokerTheme.Chip.red,
            PokerTheme.Chip.purple,
            PokerTheme.Chip.gold,
            PokerTheme.Chip.blue,
            PokerTheme.Chip.purple,
        ]
        return palette[idx % palette.count]
    }

    /// Kept for compatibility with GameViewControllerActions, but a no-op:
    /// the table re-flows naturally when the betting controls expand (the
    /// stack view collapses/expands and the felt resizes), so no manual
    /// vertical shift is needed.
    func adjustHumanPlayerPosition(shiftUp: Bool) {
        _ = shiftUp
        humanPlayerVerticalShift = 0
    }
}
