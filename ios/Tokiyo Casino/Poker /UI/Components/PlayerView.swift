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

    enum TuckedCardSide {
        case left
        case right
    }

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
    private var isHighlighted = false
    private var cardSide: TuckedCardSide = .right
    private var showsRevealedOpponentCards = false

    // Layout vars
    private var avatarSize: CGFloat = 44

    /// iPad scales a seat's inner content (avatar, name/stack pill, text,
    /// tucked cards) along with the felt. iPhone keeps 1.0, so every metric
    /// below multiplies out to its original value and the phone is untouched.
    var contentScale: CGFloat = 1.0 {
        didSet {
            guard contentScale != oldValue else { return }
            if player != nil { rebuild() }   // recreate avatar/fonts at new size
            setNeedsLayout()
        }
    }

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
        turnPill.backgroundColor = PokerTheme.primaryAction
        turnPill.layer.cornerRadius = 10
        turnPill.isHidden = true
        addSubview(turnPill)
        turnPillLabel.text = "YOUR TURN · 12s"
        turnPillLabel.textColor = PokerTheme.primaryActionText
        turnPillLabel.font = .systemFont(ofSize: 9.5, weight: .heavy)
        turnPillLabel.textAlignment = .center
        turnPillLabel.adjustsFontSizeToFitWidth = true
        turnPillLabel.minimumScaleFactor = 0.85
        turnPillLabel.translatesAutoresizingMaskIntoConstraints = true
        turnPill.addSubview(turnPillLabel)

        // Active glow ring (CA layer behind avatar)
        activeRingBg.fillColor = UIColor.clear.cgColor
        activeRingBg.strokeColor = PokerTheme.border.cgColor
        activeRingBg.lineWidth = 2
        timerRing.fillColor = UIColor.clear.cgColor
        timerRing.strokeColor = PokerTheme.primaryAction.cgColor
        timerRing.lineWidth = 2.5
        timerRing.lineCap = .round
        activeRingBg.isHidden = true
        timerRing.isHidden = true
        layer.addSublayer(activeRingBg)
        layer.addSublayer(timerRing)
    }

    // MARK: - Configure

    func configureWith(player: Player, isDealer: Bool = false, cardSide: TuckedCardSide = .right) {
        self.player = player
        self.isHumanPlayer = player.isHuman
        self.isDealer = isDealer
        self.cardSide = cardSide

        rebuild()
    }

    private func rebuild() {
        guard let player else { return }

        // Recreate the avatar with the player's hue (avoids stale gradients)
        avatar?.removeFromSuperview()
        let av: AvatarView
        avatarSize = (isHumanPlayer ? 36 : 44) * contentScale
        av = AvatarView(name: player.name, hue: hueFor(player: player), size: avatarSize)
        avatar = av
        addSubview(av)

        // Name/stack + ancillary type scales with the seat (×1 on iPhone → unchanged).
        nameLabel.font = .systemFont(ofSize: 10 * contentScale, weight: .semibold)
        stackLabel.font = .systemFont(ofSize: 11.5 * contentScale, weight: .bold)
        statusBadge.font = .systemFont(ofSize: 9 * contentScale, weight: .heavy)
        dealerChip.font = .systemFont(ofSize: 10 * contentScale, weight: .heavy)
        actionLabel.font = .systemFont(ofSize: 11 * contentScale, weight: .heavy)
        turnPillLabel.font = .systemFont(ofSize: 9.5 * contentScale, weight: .heavy)
        nameLabel.text = player.name
        stackLabel.text = "$\(ChipFormatter.string(player.chips))"

        dealerChip.isHidden = !isDealer

        // Cards: human face up, AI face down (cards are revealed at showdown)
        let hasHole = player.holeCards.count >= 2
        if !hasHole || player.isFolded {
            showsRevealedOpponentCards = false
        }
        card1.isHidden = !hasHole || player.isFolded
        card2.isHidden = !hasHole || player.isFolded
        card1.style = isHumanPlayer ? .hero : .face
        card2.style = isHumanPlayer ? .hero : .face
        if hasHole {
            card1.setCard(player.holeCards[0], faceUp: isHumanPlayer)
            card2.setCard(player.holeCards[1], faceUp: isHumanPlayer)
        }

        updateStatusBadge()
        updateHeroBetPill()
        setNeedsLayout()
    }

    func updateChips() {
        guard let player else { return }
        stackLabel.text = "$\(ChipFormatter.string(player.chips))"
        updateHeroBetPill()
    }

    private func updateStatusBadge() {
        guard let player else { return }
        // Multiplayer: a human seat held vacant for an offline player.
        // Show a distinct "AWAY" label so the table doesn't conflate
        // this with a regular fold. Solo poker never sets `isAway`.
        if player.isAway {
            showBadge(text: "AWAY", color: PokerTheme.muted)
            alpha = 0.40
            return
        }
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
        if isHighlighted && !isHumanPlayer {
            showBadge(text: "12s", color: PokerTheme.primaryAction)
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

    private func updateHeroBetPill() {
        guard isHumanPlayer, let player else {
            betPill?.removeFromSuperview()
            betPill = nil
            return
        }
        guard !player.isFolded, player.currentBet > 0 else {
            betPill?.removeFromSuperview()
            betPill = nil
            return
        }

        if let betPill {
            betPill.setAmount(player.currentBet)
        } else {
            let pill = BetPillView(amount: player.currentBet, chipColor: PokerTheme.Chip.green,
                                   scale: DeviceLayout.pick(1.0, pad: contentScale))
            betPill = pill
            addSubview(pill)
        }
        setNeedsLayout()
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
        // `s` scales the seat's fixed metrics with the felt (1.0 on iPhone).
        // `avatarSize` already includes `s`, so only the additive constants
        // below need multiplying.
        let s = contentScale

        let av = avatar
        let avX = (w - avatarSize) / 2
        let avY: CGFloat = 6 * s
        av?.frame = CGRect(x: avX, y: avY, width: avatarSize, height: avatarSize)

        // Active ring path (behind avatar)
        let ringInset: CGFloat = 4 * s
        let ringRect = CGRect(
            x: avX - ringInset,
            y: avY - ringInset,
            width: avatarSize + ringInset * 2,
            height: avatarSize + ringInset * 2
        )
        let ringPath = UIBezierPath(ovalIn: ringRect).cgPath
        activeRingBg.path = ringPath
        timerRing.path = ringPath
        activeRingBg.lineWidth = 2 * s
        timerRing.lineWidth = 2.5 * s
        activeRingBg.frame = bounds
        timerRing.frame = bounds

        // Dealer chip — bottom-right of avatar
        let dealer: CGFloat = 18 * s
        dealerChip.layer.cornerRadius = dealer / 2
        dealerChip.frame = CGRect(x: avX + avatarSize - 4 * s, y: avY + avatarSize - 14 * s, width: dealer, height: dealer)

        // Name/stack pill below avatar
        let pillW: CGFloat = 80 * s
        let pillH: CGFloat = 30 * s
        let pillY = avY + avatarSize + 6 * s
        nameStackPill.layer.cornerRadius = 10 * s
        nameStackPill.frame = CGRect(x: (w - pillW) / 2, y: pillY, width: pillW, height: pillH)
        nameLabel.frame = CGRect(x: 4 * s, y: 3 * s, width: pillW - 8 * s, height: 12 * s)
        stackLabel.frame = CGRect(x: 4 * s, y: 14 * s, width: pillW - 8 * s, height: 14 * s)

        // Status badge under pill
        if !statusBadge.isHidden {
            statusBadge.layer.cornerRadius = 8 * s
            statusBadge.sizeToFit()
            var sz = statusBadge.frame.size
            sz.height = 16 * s
            statusBadge.frame = CGRect(x: (w - sz.width) / 2, y: pillY + pillH + 4 * s, width: sz.width, height: sz.height)
        }

        if showsRevealedOpponentCards {
            // Showdown: cards come forward and grow enough to read, instead of
            // staying hidden behind the avatar.
            let cardW: CGFloat = 38 * s
            let cardH: CGFloat = 54 * s
            let overlap: CGFloat = 10 * s
            let groupW = cardW * 2 - overlap
            let cardsX = (w - groupW) / 2
            let cardsY = max(-6 * s, avY - 4 * s)
            setCardFrame(card1, frame: CGRect(x: cardsX, y: cardsY, width: cardW, height: cardH), degrees: -7)
            setCardFrame(card2, frame: CGRect(x: cardsX + cardW - overlap, y: cardsY, width: cardW, height: cardH), degrees: 7)
            bringSubviewToFront(card1)
            bringSubviewToFront(card2)
            bringSubviewToFront(dealerChip)
        } else {
            // Tucked cards — fixed anchor per side, matching poker.jsx's cardSide.
            let cardW: CGFloat = 24 * s
            let cardH: CGFloat = 32 * s
            let groupW = cardW * 2 - 11 * s
            let cardsX: CGFloat
            let firstTilt: CGFloat
            let secondTilt: CGFloat
            switch cardSide {
            case .right:
                cardsX = w / 2 + avatarSize / 2 - 16 * s
                firstTilt = -12
                secondTilt = 4
            case .left:
                cardsX = w / 2 - avatarSize / 2 - groupW + 16 * s
                firstTilt = -4
                secondTilt = 12
            }
            let cardsY = avY + 6 * s
            setCardFrame(card1, frame: CGRect(x: cardsX, y: cardsY, width: cardW, height: cardH), degrees: firstTilt)
            setCardFrame(card2, frame: CGRect(x: cardsX + cardW - 11 * s, y: cardsY, width: cardW, height: cardH), degrees: secondTilt)
            if let av {
                bringSubviewToFront(av)
            }
            bringSubviewToFront(dealerChip)
        }

        // Action overlay above pill
        if actionLabel.alpha > 0.0 {
            let sz = actionLabel.sizeThatFits(CGSize(width: w, height: 22 * s))
            let aw = max(60 * s, min(w, sz.width + 16 * s))
            actionLabel.layer.cornerRadius = 10 * s
            actionLabel.frame = CGRect(x: (w - aw) / 2, y: avY - 10 * s, width: aw, height: 22 * s)
        }

        turnPill.isHidden = true
        _ = h
    }

    private func layoutHumanPlayer() {
        let w = bounds.width
        let h = bounds.height

        // Fanned hero cards (centered, slightly above the name bar). On iPhone
        // the scale is capped at 1.0 (unchanged); iPad lifts the cap so the hero
        // seat — cards, strip and text — grows to fill the larger felt.
        let cap: CGFloat = DeviceLayout.isPad ? 1.7 : 1.0
        let scale = max(0.82, min(cap, w / 360.0))
        let cardW: CGFloat = 64 * scale
        let cardH: CGFloat = 92 * scale
        let cardsY: CGFloat = 4 * scale
        let totalCardsW = cardW * 2 - 14 * scale
        let cardsX = (w - totalCardsW) / 2
        setCardFrame(card1, frame: CGRect(x: cardsX, y: cardsY, width: cardW, height: cardH), degrees: -7)
        setCardFrame(card2, frame: CGRect(x: cardsX + cardW - 14 * scale, y: cardsY, width: cardW, height: cardH), degrees: 7)
        card1.layer.shadowOpacity = 0.22
        card1.layer.shadowRadius = 14
        card2.layer.shadowOpacity = 0.22
        card2.layer.shadowRadius = 14

        // Name/stack strip
        let stripY = cardsY + cardH + 6 * scale
        let stripH: CGFloat = 44 * scale
        let strip = CGRect(x: 14 * scale, y: stripY, width: w - 28 * scale, height: stripH)
        nameStackPill.frame = strip
        nameStackPill.backgroundColor = .clear
        nameStackPill.layer.cornerRadius = 14 * scale
        nameStackPill.layer.shadowOpacity = 0

        // Avatar inside the strip (small)
        let av = avatar
        let smallAv: CGFloat = 36 * scale
        av?.frame = CGRect(x: strip.minX + 6 * scale, y: strip.minY + (stripH - smallAv) / 2, width: smallAv, height: smallAv)

        // Name/stack labels next to avatar
        let textX = (av?.frame.maxX ?? strip.minX) + 8 * scale
        nameLabel.textAlignment = .left
        stackLabel.textAlignment = .left
        nameLabel.frame = CGRect(x: textX - strip.minX, y: 6 * scale, width: strip.width / 2, height: 14 * scale)
        stackLabel.frame = CGRect(x: textX - strip.minX, y: 22 * scale, width: strip.width / 2, height: 16 * scale)

        // Dealer chip near avatar (small overlay)
        if !dealerChip.isHidden {
            let dealer: CGFloat = 18 * scale
            dealerChip.layer.cornerRadius = dealer / 2
            dealerChip.frame = CGRect(x: (av?.frame.maxX ?? strip.minX) - 2 * scale, y: (av?.frame.maxY ?? strip.minY) - 14 * scale, width: dealer, height: dealer)
        }

        // YOUR TURN pill in the center of the name strip.
        let turnH: CGFloat = 26 * scale
        let desiredTurnW = turnPillLabel.intrinsicContentSize.width + 28 * scale
        let turnW = min(strip.width - 96 * scale, max(128 * scale, desiredTurnW))
        turnPill.frame = CGRect(x: strip.midX - turnW / 2, y: stripY + (stripH - turnH) / 2, width: turnW, height: turnH)
        turnPill.layer.cornerRadius = turnH / 2
        turnPillLabel.frame = turnPill.bounds
        turnPill.bringSubviewToFront(turnPillLabel)

        if let betPill {
            let fit = betPill.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            let pillW = max(64 * scale, fit.width)
            let pillH = 24 * scale
            betPill.frame = CGRect(
                x: strip.maxX - pillW - 6 * scale,
                y: stripY + (stripH - pillH) / 2,
                width: pillW,
                height: pillH
            )
            bringSubviewToFront(betPill)
        }

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
        isHighlighted = highlighted
        if isHumanPlayer {
            turnPill.isHidden = !highlighted
            setNeedsLayout()
            return
        }
        activeRingBg.isHidden = !highlighted
        timerRing.isHidden = !highlighted
        updateStatusBadge()
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

    func resetCardPresentation() {
        showsRevealedOpponentCards = false
        if !isHumanPlayer {
            card1.style = .face
            card2.style = .face
        }
        clearCardHighlights()
        setNeedsLayout()
    }

    /// Apply showdown highlight. Cards belonging to the winning hand stay
    /// bright with an amber border/glow; the other (or folded) hole cards
    /// fade. Call with `winningCards` containing every Card present in the
    /// winner's best 5-card hand.
    func applyShowdownHighlight(winningCards: [Card], anyHighlight: Bool) {
        guard let player else { return }
        // Don't touch folded players visually — their cards are hidden.
        if player.isFolded { return }

        for cv in [card1, card2] {
            guard let c = cv.card else {
                cv.highlightState = .none
                continue
            }
            if winningCards.contains(c) {
                cv.highlightState = .winning
            } else {
                cv.highlightState = anyHighlight ? .unused : .none
            }
        }
    }

    func clearCardHighlights() {
        card1.highlightState = .none
        card2.highlightState = .none
    }

    func revealCards() {
        guard let player else { return }
        guard !player.isFolded, player.holeCards.count >= 2 else { return }
        if !isHumanPlayer {
            showsRevealedOpponentCards = true
        }
        card1.style = isHumanPlayer ? .hero : .face
        card2.style = isHumanPlayer ? .hero : .face
        setNeedsLayout()
        card1.revealCard()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.setNeedsLayout()
            self.card2.revealCard()
        }
    }

    func forceRevealCards() {
        guard let player else { return }
        guard player.holeCards.count >= 2 else { return }
        if !isHumanPlayer {
            showsRevealedOpponentCards = true
        }
        card1.style = isHumanPlayer ? .hero : .face
        card2.style = isHumanPlayer ? .hero : .face
        setNeedsLayout()
        card1.forceShowCard()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.setNeedsLayout()
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

    private func setCardFrame(_ cardView: CardView, frame: CGRect, degrees: CGFloat) {
        cardView.transform = .identity
        cardView.frame = frame
        cardView.transform = CGAffineTransform(rotationAngle: degrees * .pi / 180)
    }
}
