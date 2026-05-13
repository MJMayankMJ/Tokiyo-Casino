//
//  PlayerView.swift
//  Tokiyo Casino
//
//  Redesigned to match the Claude Design handoff. AI seats render as a
//  gradient avatar with timer ring, a small name/stack pill, optional
//  status badge, and two tucked face-down hole cards. The human player
//  renders the larger fanned hero cards with a name/stack strip below.
//

import Foundation
import UIKit

class PlayerView: UIView {

    // MARK: - Subviews (AI seat)
    private var avatar: AvatarView?
    private let nameStackPill = UIView()
    private let nameLabel = UILabel()
    private let stackLabel = UILabel()
    private let statusBadge = UILabel()
    private let dealerChip = UILabel()
    private let timerRing = CAShapeLayer()
    private let activeRingBg = CAShapeLayer()
    private let card1 = CardView()
    private let card2 = CardView()
    private let actionLabel = UILabel()
    private var betPill: BetPillView?
    private let turnPill = UIView()
    private let turnPillLabel = UILabel()

    // MARK: - State
    private(set) var player: Player?
    private var isHumanPlayer = false
    private var isDealer = false

    // Layout vars
    private var avatarSize: CGFloat = 44

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupView() {
        backgroundColor = .clear
        clipsToBounds = false

        // Name + stack pill
        nameStackPill.backgroundColor = PokerTheme.glass
        nameStackPill.layer.cornerRadius = 10
        PokerTheme.applyShadowSm(nameStackPill.layer)
        addSubview(nameStackPill)

        nameLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        nameLabel.textColor = PokerTheme.ink
        nameLabel.textAlignment = .center
        nameStackPill.addSubview(nameLabel)

        stackLabel.font = .systemFont(ofSize: 11.5, weight: .bold)
        stackLabel.textColor = PokerTheme.ink
        stackLabel.textAlignment = .center
        nameStackPill.addSubview(stackLabel)

        // Status badge
        statusBadge.font = .systemFont(ofSize: 9, weight: .heavy)
        statusBadge.textAlignment = .center
        statusBadge.layer.cornerRadius = 8
        statusBadge.layer.masksToBounds = true
        statusBadge.isHidden = true
        addSubview(statusBadge)

        // Dealer chip
        dealerChip.text = "D"
        dealerChip.textColor = PokerTheme.ink
        dealerChip.backgroundColor = .white
        dealerChip.font = .systemFont(ofSize: 10, weight: .heavy)
        dealerChip.textAlignment = .center
        dealerChip.layer.cornerRadius = 9
        dealerChip.layer.borderWidth = 1.5
        dealerChip.layer.borderColor = UIColor.black.cgColor
        dealerChip.layer.masksToBounds = true
        dealerChip.isHidden = true
        PokerTheme.applyShadowSm(dealerChip.layer)
        addSubview(dealerChip)

        // Cards — positioned manually via frame in layoutSubviews,
        // so keep autoresizing translation enabled.
        card1.translatesAutoresizingMaskIntoConstraints = true
        card2.translatesAutoresizingMaskIntoConstraints = true
        addSubview(card1)
        addSubview(card2)

        // Action label (transient overlay)
        actionLabel.font = .systemFont(ofSize: 11, weight: .heavy)
        actionLabel.textColor = .white
        actionLabel.textAlignment = .center
        actionLabel.layer.cornerRadius = 10
        actionLabel.layer.masksToBounds = true
        actionLabel.alpha = 0
        addSubview(actionLabel)

        // Your-turn pill (hero only)
        turnPill.backgroundColor = PokerTheme.forest
        turnPill.layer.cornerRadius = 10
        turnPill.isHidden = true
        addSubview(turnPill)
        turnPillLabel.text = "YOUR TURN"
        turnPillLabel.textColor = .white
        turnPillLabel.font = .systemFont(ofSize: 9.5, weight: .heavy)
        turnPillLabel.textAlignment = .center
        turnPillLabel.translatesAutoresizingMaskIntoConstraints = false
        turnPill.addSubview(turnPillLabel)

        // Active glow ring (CA layer behind avatar)
        activeRingBg.fillColor = UIColor.clear.cgColor
        activeRingBg.strokeColor = PokerTheme.border.cgColor
        activeRingBg.lineWidth = 2
        timerRing.fillColor = UIColor.clear.cgColor
        timerRing.strokeColor = PokerTheme.forest.cgColor
        timerRing.lineWidth = 2.5
        timerRing.lineCap = .round
        activeRingBg.isHidden = true
        timerRing.isHidden = true
        layer.addSublayer(activeRingBg)
        layer.addSublayer(timerRing)
    }

    // MARK: - Configure

    func configureWith(player: Player, isDealer: Bool = false) {
        self.player = player
        self.isHumanPlayer = player.isHuman
        self.isDealer = isDealer

        rebuild()
    }

    private func rebuild() {
        guard let player else { return }

        // Recreate the avatar with the player's hue (avoids stale gradients)
        avatar?.removeFromSuperview()
        let av: AvatarView
        avatarSize = isHumanPlayer ? 36 : 44
        av = AvatarView(name: player.name, hue: hueFor(player: player), size: avatarSize)
        avatar = av
        addSubview(av)

        nameLabel.text = player.name
        stackLabel.text = "$\(ChipFormatter.string(player.chips))"

        dealerChip.isHidden = !isDealer

        // Cards: human face up, AI face down (cards are revealed at showdown)
        let hasHole = player.holeCards.count >= 2
        card1.isHidden = !hasHole
        card2.isHidden = !hasHole
        card1.style = isHumanPlayer ? .hero : .face
        card2.style = isHumanPlayer ? .hero : .face
        if hasHole {
            card1.setCard(player.holeCards[0], faceUp: isHumanPlayer)
            card2.setCard(player.holeCards[1], faceUp: isHumanPlayer)
        }

        updateStatusBadge()
        setNeedsLayout()
    }

    func updateChips() {
        guard let player else { return }
        stackLabel.text = "$\(ChipFormatter.string(player.chips))"
    }

    private func updateStatusBadge() {
        guard let player else { return }
        if player.isFolded {
            showBadge(text: "FOLDED", color: PokerTheme.muted)
            alpha = 0.55
            return
        }
        alpha = 1.0
        if player.isAllIn {
            showBadge(text: "ALL-IN", color: PokerTheme.amber)
            return
        }
        statusBadge.isHidden = true
    }

    private func showBadge(text: String, color: UIColor) {
        statusBadge.text = "  \(text)  "
        statusBadge.textColor = color
        statusBadge.backgroundColor = PokerTheme.glass
        statusBadge.isHidden = false
    }

    private func hueFor(player: Player) -> CGFloat {
        if player.isHuman { return 210 }
        // Spread the AI players across the wheel deterministically.
        let palette: [CGFloat] = [12, 290, 35, 250, 340, 160]
        return palette[player.id % palette.count]
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        if isHumanPlayer {
            layoutHumanPlayer()
        } else {
            layoutAIPlayer()
        }
    }

    private func layoutAIPlayer() {
        let w = bounds.width
        let h = bounds.height

        let av = avatar
        let avX = (w - avatarSize) / 2
        let avY: CGFloat = 6
        av?.frame = CGRect(x: avX, y: avY, width: avatarSize, height: avatarSize)

        // Active ring path (behind avatar)
        let ringInset: CGFloat = 4
        let ringRect = CGRect(
            x: avX - ringInset,
            y: avY - ringInset,
            width: avatarSize + ringInset * 2,
            height: avatarSize + ringInset * 2
        )
        let ringPath = UIBezierPath(ovalIn: ringRect).cgPath
        activeRingBg.path = ringPath
        timerRing.path = ringPath
        activeRingBg.frame = bounds
        timerRing.frame = bounds

        // Dealer chip — bottom-right of avatar
        dealerChip.frame = CGRect(x: avX + avatarSize - 4, y: avY + avatarSize - 14, width: 18, height: 18)

        // Name/stack pill below avatar
        let pillW: CGFloat = 80
        let pillH: CGFloat = 30
        let pillY = avY + avatarSize + 6
        nameStackPill.frame = CGRect(x: (w - pillW) / 2, y: pillY, width: pillW, height: pillH)
        nameLabel.frame = CGRect(x: 4, y: 3, width: pillW - 8, height: 12)
        stackLabel.frame = CGRect(x: 4, y: 14, width: pillW - 8, height: 14)

        // Status badge under pill
        if !statusBadge.isHidden {
            statusBadge.sizeToFit()
            var sz = statusBadge.frame.size
            sz.height = 16
            statusBadge.frame = CGRect(x: (w - sz.width) / 2, y: pillY + pillH + 4, width: sz.width, height: sz.height)
        }

        // Tucked cards — to the right of the avatar
        let cardW: CGFloat = 24
        let cardH: CGFloat = 32
        let cardsX = w / 2 + avatarSize / 2 - 4
        let cardsY = avY + 6
        card1.frame = CGRect(x: cardsX, y: cardsY, width: cardW, height: cardH)
        card2.frame = CGRect(x: cardsX + cardW - 11, y: cardsY, width: cardW, height: cardH)
        card1.transform = CGAffineTransform(rotationAngle: -12 * .pi / 180)
        card2.transform = CGAffineTransform(rotationAngle: 4 * .pi / 180)

        // Action overlay above pill
        if actionLabel.alpha > 0.0 {
            let sz = actionLabel.sizeThatFits(CGSize(width: w, height: 22))
            let aw = max(60, min(w, sz.width + 16))
            actionLabel.frame = CGRect(x: (w - aw) / 2, y: avY - 10, width: aw, height: 22)
        }

        turnPill.isHidden = true
        _ = h
    }

    private func layoutHumanPlayer() {
        let w = bounds.width
        let h = bounds.height

        // Fanned hero cards (centered, slightly above the name bar)
        let cardW: CGFloat = 64
        let cardH: CGFloat = 92
        let cardsY: CGFloat = 4
        let totalCardsW = cardW * 2 - 14
        let cardsX = (w - totalCardsW) / 2
        card1.frame = CGRect(x: cardsX, y: cardsY, width: cardW, height: cardH)
        card2.frame = CGRect(x: cardsX + cardW - 14, y: cardsY, width: cardW, height: cardH)
        // tilt out
        card1.transform = CGAffineTransform(rotationAngle: -7 * .pi / 180)
        card2.transform = CGAffineTransform(rotationAngle: 7 * .pi / 180)
        card1.layer.shadowOpacity = 0.22
        card1.layer.shadowRadius = 14
        card2.layer.shadowOpacity = 0.22
        card2.layer.shadowRadius = 14

        // Name/stack strip
        let stripY = cardsY + cardH + 6
        let stripH: CGFloat = 44
        let strip = CGRect(x: 12, y: stripY, width: w - 24, height: stripH)
        nameStackPill.frame = strip
        nameStackPill.backgroundColor = .clear
        nameStackPill.layer.shadowOpacity = 0

        // Avatar inside the strip (small)
        let av = avatar
        let smallAv: CGFloat = 36
        av?.frame = CGRect(x: strip.minX + 6, y: strip.minY + (stripH - smallAv) / 2, width: smallAv, height: smallAv)

        // Name/stack labels next to avatar
        let textX = (av?.frame.maxX ?? strip.minX) + 8
        nameLabel.textAlignment = .left
        stackLabel.textAlignment = .left
        nameLabel.frame = CGRect(x: textX - strip.minX, y: 6, width: strip.width / 2, height: 14)
        stackLabel.frame = CGRect(x: textX - strip.minX, y: 22, width: strip.width / 2, height: 16)

        // Dealer chip near avatar (small overlay)
        if !dealerChip.isHidden {
            dealerChip.frame = CGRect(x: (av?.frame.maxX ?? strip.minX) - 2, y: (av?.frame.maxY ?? strip.minY) - 14, width: 18, height: 18)
        }

        // YOUR TURN pill on the right
        turnPill.frame = CGRect(x: strip.maxX - 84 - strip.minX + strip.minX, y: stripY + 12, width: 88, height: 20)
        turnPillLabel.frame = turnPill.bounds.insetBy(dx: 6, dy: 0)
        turnPill.bringSubviewToFront(turnPillLabel)

        // No tucked cards / status badge for human
        statusBadge.isHidden = true
        activeRingBg.isHidden = true
        timerRing.isHidden = true

        _ = h
    }

    // MARK: - Public surfaces consumed by GameViewController

    func showAction(_ action: PlayerAction) {
        actionLabel.text = action.description
        actionLabel.backgroundColor = backgroundFor(action: action)

        actionLabel.alpha = 0
        actionLabel.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.actionLabel.alpha = 1
            self.actionLabel.transform = .identity
            self.setNeedsLayout()
        }
        UIView.animate(withDuration: 0.3, delay: 2.5, options: []) {
            self.actionLabel.alpha = 0
        }
    }

    private func backgroundFor(action: PlayerAction) -> UIColor {
        switch action {
        case .fold:  return PokerTheme.coral
        case .check: return PokerTheme.forest
        case .call:  return PokerTheme.Chip.blue
        case .raise: return PokerTheme.amber
        case .allIn: return PokerTheme.Chip.purple
        }
    }

    func showBet(_ amount: Int) {
        // Bet pills are now rendered by the PokerTableView between the seat
        // and the pot. The seat itself doesn't show them locally — but we keep
        // the API for compatibility.
        _ = amount
    }

    func setHighlighted(_ highlighted: Bool) {
        if isHumanPlayer {
            turnPill.isHidden = !highlighted
            return
        }
        activeRingBg.isHidden = !highlighted
        timerRing.isHidden = !highlighted
        if highlighted {
            // Pulse the ring (opacity)
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 0.45
            pulse.toValue = 1.0
            pulse.duration = 0.8
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            timerRing.add(pulse, forKey: "pulse")
        } else {
            timerRing.removeAllAnimations()
        }
    }

    func revealCards() {
        guard let player else { return }
        guard !player.isFolded, player.holeCards.count >= 2 else { return }
        card1.style = .hero
        card2.style = .hero
        card1.revealCard()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.card2.revealCard()
        }
    }

    func forceRevealCards() {
        guard let player else { return }
        guard player.holeCards.count >= 2 else { return }
        card1.style = .hero
        card2.style = .hero
        card1.forceShowCard()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.card2.forceShowCard()
        }
    }

    func showWinAnimation() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        UIView.animate(withDuration: 0.5, animations: {
            self.transform = CGAffineTransform(scaleX: 1.10, y: 1.10)
            self.nameStackPill.backgroundColor = PokerTheme.amber.withAlphaComponent(0.85)
        }) { _ in
            UIView.animate(withDuration: 0.5) {
                self.transform = .identity
                self.nameStackPill.backgroundColor = PokerTheme.glass
            }
        }
    }
}

