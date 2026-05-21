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

        // Felt container. The JSX handoff has a 360×480 table container and an
        // oval felt inset by 18px; layoutFelt keeps those two spaces separate.
        feltView.backgroundColor = PokerTheme.felt
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
        // Constrain the design table container to 360×480, scaling down only
        // when a smaller device or the expanded action panel requires it.
        let designRatio: CGFloat = 480.0 / 360.0
        let edgePad: CGFloat = 16
        let maxW = max(0, bounds.width  - edgePad * 2)
        let maxH = max(0, bounds.height - edgePad * 2)

        var tableW = min(360, maxW)
        var tableH = tableW * designRatio
        if tableH > maxH {
            tableH = maxH
            tableW = tableH / designRatio
        }
        designFrame = CGRect(
            x: bounds.midX - tableW / 2,
            y: bounds.midY - tableH / 2,
            width: tableW,
            height: tableH
        )
        designScale = tableW / 360.0

        let feltInset = 18 * designScale
        let feltFrame = designFrame.insetBy(dx: feltInset, dy: feltInset)
        feltView.frame = feltFrame
        let corner = 160 * designScale
        feltView.layer.cornerRadius = corner
        feltView.layer.shadowPath = UIBezierPath(roundedRect: feltView.bounds,
                                                 cornerRadius: corner).cgPath

        // Inner border
        let inner = feltView.bounds.insetBy(dx: 14 * designScale, dy: 14 * designScale)
        feltInnerBorder.frame = inner
        feltInnerBorder.layer.cornerRadius = max(0, corner - 14 * designScale)

        // Pot pill — table-container relative top y=138 in poker.jsx.
        let potTop = designFrame.minY + 138 * designScale
        let potSize = potPill.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let potW = max(120 * designScale, potSize.width)
        let potH = 30 * designScale
        potPill.frame = CGRect(x: designFrame.midX - potW / 2, y: potTop, width: potW, height: potH)

        // Community cards — table-container relative top y=222 in poker.jsx.
        let commTop = designFrame.minY + 222 * designScale
        let cardW: CGFloat = 36 * designScale
        let cardH: CGFloat = 50 * designScale
        let gap: CGFloat = 5 * designScale
        let totalW = cardW * 5 + gap * 4
        let startX = designFrame.midX - totalW / 2
        for (i, cv) in communityCardViews.enumerated() {
            cv.frame = CGRect(
                x: startX + CGFloat(i) * (cardW + gap),
                y: commTop,
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
            let baseSize = player.isHuman ? humanPlayerBaseSize : aiPlayerBaseSize
            let size = CGSize(width: baseSize.width * designScale, height: baseSize.height * designScale)
            playerView.frame = CGRect(origin: .zero, size: size)
            addSubview(playerView)
            playerViews.append(playerView)
            let side = cardSide(forPlayerIndex: index, totalPlayers: players.count)
            playerView.configureWith(player: player, isDealer: index == dealerIndex, cardSide: side)
        }

        DispatchQueue.main.async {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
    }

    func updatePlayerPositions() {
        let table = designFrame
        guard table.width > 0 else { return }

        for (index, playerView) in playerViews.enumerated() {
            let seatIndex = visualSeatIndex(forPlayerIndex: index, totalPlayers: playerViews.count)
            guard seatIndex < playerPositions.count else { continue }

            let pos = playerPositions[seatIndex]
            let isHuman = index == 0
            let baseSize = isHuman ? humanPlayerBaseSize : aiPlayerBaseSize
            let size = CGSize(width: baseSize.width * designScale, height: baseSize.height * designScale)
            playerView.bounds = CGRect(origin: .zero, size: size)

            let cx = table.minX + table.width * pos.x
            var cy = table.minY + table.height * pos.y

            if isHuman {
                // Hero overhangs the table container's bottom edge by 10pt (mirrors the
                // design's `bottom: -10` on the HeroZone wrapper). Cards fan
                // upward into the felt, the name strip sits at felt's bottom.
                cy = table.maxY + 10 * designScale - size.height / 2 + humanPlayerVerticalShift
            }

            playerView.center = CGPoint(x: cx, y: cy)
            playerView.setNeedsLayout()
        }
    }

    func updateBetPillPositions() {
        guard !players.isEmpty else { return }
        let table = designFrame
        guard table.width > 0 else { return }

        for (index, player) in players.enumerated() {
            let seatIndex = visualSeatIndex(forPlayerIndex: index, totalPlayers: players.count)
            guard seatIndex < betPillPositions.count else { continue }
            guard let pill = betPills[player.id] else { continue }
            let pos = betPillPositions[seatIndex]
            let size = pill.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            pill.bounds.size = CGSize(width: max(56 * designScale, size.width), height: 24 * designScale)
            pill.center = CGPoint(
                x: table.minX + table.width * pos.x,
                y: table.minY + table.height * pos.y
            )
        }
    }

    /// Shows or hides a bet pill near the player's seat.
    func updateBetPill(for player: Player, atIndex index: Int) {
        if player.isHuman {
            if let existing = betPills[player.id] {
                existing.removeFromSuperview()
                betPills.removeValue(forKey: player.id)
            }
            return
        }
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
