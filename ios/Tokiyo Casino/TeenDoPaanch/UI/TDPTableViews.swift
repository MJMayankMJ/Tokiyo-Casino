//
//  TDPTableViews.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  The pieces of the table, following the "532 Game Screen" handoff:
//  header (round · trump · menu), two opponents across the top, the trick
//  circle in the middle, you, and your hand fanned along an arc.
//

import UIKit

// MARK: - Avatar

/// Rounded-square initial. When it's that player's move it gets the
/// reference's ring: a 2pt gap, a 2pt accent ring, and a soft glow.
final class TDPAvatarView: UIView {

    private let initialLabel = UILabel()
    private let photoView = UIImageView()
    private let ringLayer = CALayer()
    private let side: CGFloat

    /// The player's own profile photo, in place of the initial.
    var photo: UIImage? {
        didSet {
            photoView.image = photo
            photoView.isHidden = photo == nil
        }
    }

    var tint: TDPTheme.Tint = .green { didSet { applyTheme() } }
    var isActive = false { didSet { if oldValue != isActive { updateGlow() } } }

    init(side: CGFloat, radius: CGFloat) {
        self.side = side * TDPTheme.scale
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = radius * TDPTheme.scale
        layer.cornerCurve = .continuous

        initialLabel.font = TDPTheme.font(side * 0.35, .medium)
        initialLabel.textAlignment = .center
        initialLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(initialLabel)

        photoView.contentMode = .scaleAspectFill
        photoView.clipsToBounds = true
        photoView.layer.cornerRadius = radius * TDPTheme.scale
        photoView.layer.cornerCurve = .continuous
        photoView.isHidden = true
        photoView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(photoView)

        ringLayer.borderWidth = 2
        ringLayer.cornerCurve = .continuous
        ringLayer.shadowOffset = .zero
        ringLayer.shadowRadius = 14
        ringLayer.isHidden = true
        layer.addSublayer(ringLayer)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: self.side),
            heightAnchor.constraint(equalToConstant: self.side),
            initialLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            initialLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            photoView.topAnchor.constraint(equalTo: topAnchor),
            photoView.bottomAnchor.constraint(equalTo: bottomAnchor),
            photoView.leadingAnchor.constraint(equalTo: leadingAnchor),
            photoView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        applyTheme()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (avatar: TDPAvatarView, _: UITraitCollection) in
            avatar.applyTheme()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func setName(_ name: String) {
        let first = name.trimmingCharacters(in: .whitespaces).first
        initialLabel.text = first.map { String($0).uppercased() } ?? "?"
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        ringLayer.frame = bounds.insetBy(dx: -4, dy: -4)
        ringLayer.cornerRadius = layer.cornerRadius + 4
    }

    /// Core Animation drops running animations when the app backgrounds.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { updateGlow() }
    }

    private func applyTheme() {
        backgroundColor = tint.fill
        initialLabel.textColor = tint.ink
        let accent = TDPTheme.accent.resolvedColor(with: traitCollection)
        ringLayer.borderColor = accent.cgColor
        ringLayer.shadowColor = accent.cgColor
    }

    private func updateGlow() {
        ringLayer.isHidden = !isActive
        ringLayer.removeAnimation(forKey: "breathe")
        guard isActive else { return }
        ringLayer.shadowOpacity = 0.45
        let pulse = CABasicAnimation(keyPath: "shadowOpacity")
        pulse.fromValue = 0.2
        pulse.toValue = 0.6
        pulse.duration = 1.1
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        ringLayer.add(pulse, forKey: "breathe")
    }
}


/// A quick swell when a number goes up — a trick won shows on the tally.
private func pulseIfIncreased(_ label: UILabel, from old: String?, to new: String) {
    guard let old, old != new, label.window != nil,
          let before = Int(old.split(separator: " ").first ?? ""),
          let after = Int(new.split(separator: " ").first ?? ""), after > before else { return }
    UIView.animate(withDuration: 0.12, animations: {
        label.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
    }) { _ in
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.5,
                       initialSpringVelocity: 0.4, options: []) { label.transform = .identity }
    }
}

// MARK: - Opponent

/// Avatar with name, "won / quota" and card count. The right-hand opponent
/// is mirrored, as in the reference.
final class TDPOpponentBadge: UIView {

    enum Side { case left, right }

    let avatar = TDPAvatarView(side: 52, radius: 18)
    private let nameLabel = UILabel()
    private let tallyLabel = UILabel()
    private let chipLabel = TDPChipLabel()
    private let detailLabel = UILabel()

    init(side: Side) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = TDPTheme.font(15, .medium)
        nameLabel.textColor = TDPTheme.ink
        tallyLabel.font = TDPTheme.mono(13)
        detailLabel.font = TDPTheme.font(11)
        detailLabel.textColor = TDPTheme.muted
        let alignment: NSTextAlignment = side == .left ? .left : .right
        [nameLabel, tallyLabel, detailLabel].forEach { $0.textAlignment = alignment }

        // The chip sits on the inside edge, next to the tally.
        let tallyRow = UIStackView(arrangedSubviews: side == .left ? [tallyLabel, chipLabel] : [chipLabel, tallyLabel])
        tallyRow.spacing = 6
        tallyRow.alignment = .center
        let info = UIStackView(arrangedSubviews: [nameLabel, tallyRow, detailLabel])
        info.axis = .vertical
        info.spacing = 4
        info.alignment = side == .left ? .leading : .trailing

        let row = UIStackView(arrangedSubviews: side == .left ? [avatar, info] : [info, avatar])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func configure(name: String, tally: String, quotaMet: Bool, detail: String,
                   isActive: Bool, tint: TDPTheme.Tint, isOffline: Bool, chip: String? = nil) {
        nameLabel.text = name
        pulseIfIncreased(tallyLabel, from: tallyLabel.text, to: tally)
        tallyLabel.text = tally
        chipLabel.text = chip
        chipLabel.isHidden = chip == nil
        chipLabel.invalidateIntrinsicContentSize()
        tallyLabel.textColor = quotaMet ? TDPTheme.accent : TDPTheme.inkSoft
        detailLabel.text = detail
        avatar.setName(name)
        avatar.tint = tint
        avatar.isActive = isActive
        alpha = isOffline ? 0.5 : 1
        accessibilityLabel = "\(name), \(tally) tricks, \(detail)"
    }
}

// MARK: - You

final class TDPSelfBadge: UIView {

    let avatar = TDPAvatarView(side: 44, radius: 16)
    private let nameLabel = UILabel()
    private let tallyLabel = UILabel()
    /// Where a claimed trick lands.
    var tallyView: UIView { tallyLabel }
    private let chipLabel = TDPChipLabel()
    private let statusLabel = UILabel()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = TDPTheme.font(15, .medium)
        nameLabel.textColor = TDPTheme.ink
        tallyLabel.font = TDPTheme.mono(13)
        statusLabel.font = TDPTheme.font(12)

        chipLabel.isAccent = true
        let top = UIStackView(arrangedSubviews: [nameLabel, tallyLabel, chipLabel])
        top.axis = .horizontal
        top.spacing = 10
        top.alignment = .center

        let info = UIStackView(arrangedSubviews: [top, statusLabel])
        info.axis = .vertical
        info.spacing = 3
        info.alignment = .leading

        let row = UIStackView(arrangedSubviews: [avatar, info])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func configure(name: String, tally: String, quotaMet: Bool, status: String,
                   statusIsAction: Bool, isActive: Bool, chip: String? = nil, photo: UIImage? = nil) {
        avatar.photo = photo
        nameLabel.text = name
        pulseIfIncreased(tallyLabel, from: tallyLabel.text, to: tally)
        tallyLabel.text = tally
        chipLabel.text = chip
        chipLabel.isHidden = chip == nil
        chipLabel.invalidateIntrinsicContentSize()
        tallyLabel.textColor = quotaMet ? TDPTheme.accent : TDPTheme.inkSoft
        statusLabel.text = status
        statusLabel.textColor = statusIsAction ? TDPTheme.accent : TDPTheme.muted
        avatar.setName(name == "You" ? "Y" : name)
        avatar.tint = .green
        avatar.isActive = isActive
    }
}

// MARK: - Header

final class TDPTrumpPill: UIView {

    private let glyph = TDPSuitGlyph(suit: .spades, tint: TDPTheme.ink)
    private var shownTrump: Suit?
    private let unknownLabel = UILabel()
    private let titleLabel = UILabel()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = TDPTheme.raised
        layer.cornerCurve = .continuous

        let well = UIView()
        well.translatesAutoresizingMaskIntoConstraints = false
        glyph.translatesAutoresizingMaskIntoConstraints = false
        unknownLabel.translatesAutoresizingMaskIntoConstraints = false
        unknownLabel.text = "?"
        unknownLabel.font = TDPTheme.font(13, .semibold)
        unknownLabel.textColor = TDPTheme.muted
        unknownLabel.textAlignment = .center
        well.addSubview(glyph)
        well.addSubview(unknownLabel)

        titleLabel.font = TDPTheme.font(12)
        titleLabel.textColor = TDPTheme.muted

        let row = UIStackView(arrangedSubviews: [well, titleLabel])
        row.axis = .horizontal
        row.spacing = 7
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        let side = 15 * TDPTheme.scale
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 30 * TDPTheme.scale),
            well.widthAnchor.constraint(equalToConstant: side),
            well.heightAnchor.constraint(equalToConstant: side),
            glyph.topAnchor.constraint(equalTo: well.topAnchor),
            glyph.bottomAnchor.constraint(equalTo: well.bottomAnchor),
            glyph.leadingAnchor.constraint(equalTo: well.leadingAnchor),
            glyph.trailingAnchor.constraint(equalTo: well.trailingAnchor),
            unknownLabel.centerXAnchor.constraint(equalTo: well.centerXAnchor),
            unknownLabel.centerYAnchor.constraint(equalTo: well.centerYAnchor),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10 * TDPTheme.scale),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12 * TDPTheme.scale)
        ])
        configure(trump: nil, detail: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    func configure(trump: Suit?, detail: String?) {
        if let trump, trump != shownTrump, window != nil {
            UIView.animate(withDuration: 0.14, animations: {
                self.transform = CGAffineTransform(scaleX: 1.12, y: 1.12)
            }) { _ in
                UIView.animate(withDuration: 0.32, delay: 0, usingSpringWithDamping: 0.55,
                               initialSpringVelocity: 0.4, options: []) { self.transform = .identity }
            }
        }
        shownTrump = trump
        glyph.isHidden = trump == nil
        unknownLabel.isHidden = trump != nil
        if let trump {
            glyph.suit = trump
            glyph.tint = TDPTheme.isRed(trump) ? TDPTheme.trumpRed : TDPTheme.ink
        }
        titleLabel.text = detail.map { "Trump · \($0)" } ?? "Trump"
        accessibilityLabel = trump.map { "Trump is \(TDPTheme.suitName($0))" } ?? "Trump not called yet"
    }
}

/// 40pt circle with two bars — the reference's menu affordance.
final class TDPMenuButton: UIControl {

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = TDPTheme.raised
        let side = 40 * TDPTheme.scale
        layer.cornerRadius = side / 2
        accessibilityLabel = "Menu"
        accessibilityTraits = .button

        let bars = (0..<2).map { _ -> UIView in
            let bar = UIView()
            bar.backgroundColor = TDPTheme.inkSoft
            bar.layer.cornerRadius = 0.75
            bar.isUserInteractionEnabled = false
            bar.translatesAutoresizingMaskIntoConstraints = false
            addSubview(bar)
            return bar
        }
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: side),
            heightAnchor.constraint(equalToConstant: side),
            bars[0].centerXAnchor.constraint(equalTo: centerXAnchor),
            bars[1].centerXAnchor.constraint(equalTo: centerXAnchor),
            bars[0].bottomAnchor.constraint(equalTo: centerYAnchor, constant: -2),
            bars[1].topAnchor.constraint(equalTo: centerYAnchor, constant: 2),
            bars[0].widthAnchor.constraint(equalToConstant: 14 * TDPTheme.scale),
            bars[1].widthAnchor.constraint(equalToConstant: 14 * TDPTheme.scale),
            bars[0].heightAnchor.constraint(equalToConstant: 1.5),
            bars[1].heightAnchor.constraint(equalToConstant: 1.5)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? TDPTheme.raisedAlt : TDPTheme.raised }
    }
}

final class TDPHeaderView: UIView {

    private let roundLabel = UILabel()
    private let scoreLabel = UILabel()
    let trumpPill = TDPTrumpPill()
    let menuButton = TDPMenuButton()
    /// The round and score block opens the score sheet.
    var onScoresTap: (() -> Void)?

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        scoreLabel.font = TDPTheme.mono(13)
        scoreLabel.textColor = TDPTheme.inkSoft

        let left = UIStackView(arrangedSubviews: [roundLabel, scoreLabel])
        left.axis = .vertical
        left.spacing = 3
        left.translatesAutoresizingMaskIntoConstraints = false
        left.isAccessibilityElement = true
        left.accessibilityTraits = .button
        left.accessibilityHint = "Shows the scores"
        left.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapScores)))
        scoreBlock = left
        addSubview(left)
        addSubview(trumpPill)
        addSubview(menuButton)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 44 * TDPTheme.scale),
            left.leadingAnchor.constraint(equalTo: leadingAnchor),
            left.centerYAnchor.constraint(equalTo: centerYAnchor),
            trumpPill.centerXAnchor.constraint(equalTo: centerXAnchor),
            trumpPill.centerYAnchor.constraint(equalTo: centerYAnchor),
            trumpPill.leadingAnchor.constraint(greaterThanOrEqualTo: left.trailingAnchor, constant: 8),
            trumpPill.trailingAnchor.constraint(lessThanOrEqualTo: menuButton.leadingAnchor, constant: -8),
            menuButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            menuButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private weak var scoreBlock: UIView?

    @objc private func didTapScores() { onScoresTap?() }

    /// `points` is the classic score: one per trick taken this session.
    func configure(round: Int, of total: Int, points: Int, trump: Suit?, trumpDetail: String?) {
        scoreBlock?.accessibilityLabel = "Round \(round) of \(total), score \(points)"
        let size = 11 * TDPTheme.scale
        roundLabel.attributedText = NSAttributedString(
            string: "ROUND \(round) / \(total)",
            attributes: [.font: UIFont.systemFont(ofSize: size, weight: .medium),
                         .kern: 0.08 * size,                       // ref letter-spacing .08em
                         .foregroundColor: TDPTheme.muted]
        )
        scoreLabel.text = "Score \(points)"
        trumpPill.configure(trump: trump, detail: trumpDetail)
    }
}

enum TDPFormat {
    /// "+2", "0", "−1" — a true minus sign sits better in the mono face.
    static func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : value < 0 ? "\u{2212}\(-value)" : "0"
    }

    /// Text-presentation suit, as the reference uses in its caption.
    static func symbol(_ suit: Suit) -> String { suit.symbol + "\u{FE0E}" }
}

// MARK: - Trick table

/// Dashed outline marking where the next card will land.
final class TDPDashedSlotView: UIView {

    private let dash = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        dash.fillColor = UIColor.clear.cgColor
        dash.lineWidth = 1.5
        dash.lineDashPattern = [5, 4]
        layer.addSublayer(dash)
        applyTheme()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (slot: TDPDashedSlotView, _: UITraitCollection) in
            slot.applyTheme()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        dash.frame = bounds
        // Not laid out yet: a zero-size rounded rect is NaN to CoreGraphics.
        guard bounds.width > 2, bounds.height > 2 else { dash.path = nil; return }
        dash.path = UIBezierPath(roundedRect: bounds.insetBy(dx: 0.75, dy: 0.75),
                                 cornerRadius: bounds.width * 0.143).cgPath
    }

    private func applyTheme() {
        dash.strokeColor = TDPTheme.slot.resolvedColor(with: traitCollection).cgColor
    }
}

/// The circle in the middle. Cards land at the reference's three spots —
/// left opponent up-left, right opponent up-right, you below — scaled to
/// whatever diameter the screen allows.
final class TDPTrickTableView: UIView {

    enum Spot: Hashable { case left, right, bottom }

    let captionLabel = UILabel()
    private let ring = CAShapeLayer()
    private let slot = TDPDashedSlotView()
    private var slotSpot: Spot?
    private var cards: [Spot: TDPCardButton] = [:]
    private var cardIDs: [Spot: String] = [:]
    private var laidOutSize: CGSize = .zero
    /// The winner already given its lift, so a re-render doesn't repeat it.
    private var poppedWinner: Spot?

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = false
        ring.fillColor = UIColor.clear.cgColor
        ring.lineWidth = 1
        layer.addSublayer(ring)

        captionLabel.font = TDPTheme.font(12)
        captionLabel.textColor = TDPTheme.muted
        captionLabel.textAlignment = .center
        addSubview(captionLabel)

        slot.isHidden = true
        addSubview(slot)

        applyTheme()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (table: TDPTrickTableView, _: UITraitCollection) in
            table.applyTheme()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: Geometry (reference coordinates are for a 280pt circle)

    private var unit: CGFloat { bounds.width / 280 }
    private var cardSize: CGSize { CGSize(width: 70 * unit, height: 100 * unit) }

    private func placement(_ spot: Spot) -> (center: CGPoint, angle: CGFloat) {
        let c = CGPoint(x: bounds.midX, y: bounds.midY)
        switch spot {
        case .left:   return (CGPoint(x: c.x - 50 * unit, y: c.y - 40 * unit), -9 * .pi / 180)
        case .right:  return (CGPoint(x: c.x + 50 * unit, y: c.y - 40 * unit), 9 * .pi / 180)
        case .bottom: return (CGPoint(x: c.x, y: c.y + 46 * unit), -2 * .pi / 180)
        }
    }

    /// Direction a card travels from — toward the seat that played it.
    private func origin(_ spot: Spot) -> CGPoint {
        switch spot {
        case .left:   return CGPoint(x: -150 * unit, y: -120 * unit)
        case .right:  return CGPoint(x: 150 * unit, y: -120 * unit)
        case .bottom: return CGPoint(x: 0, y: 210 * unit)
        }
    }

    private func place(_ view: UIView, at spot: Spot, rotated: Bool = true) {
        let p = placement(spot)
        view.bounds = CGRect(origin: .zero, size: cardSize)
        view.center = p.center
        view.transform = rotated ? CGAffineTransform(rotationAngle: p.angle) : .identity
    }

    // MARK: Update

    func configure(plays: [(spot: Spot, card: Card)], pending: Spot?, winner: Spot?,
                   caption: String, animated: Bool) {
        captionLabel.text = caption
        let wanted = Dictionary(plays.map { ($0.spot, $0.card.tdpID) }, uniquingKeysWith: { a, _ in a })

        for (spot, view) in cards where wanted[spot] != cardIDs[spot] {
            view.removeFromSuperview()
            cards[spot] = nil
            cardIDs[spot] = nil
        }

        let canAnimate = animated && bounds.width > 0
        for play in plays where cards[play.spot] == nil {
            let view = TDPCardButton(card: play.card, elevation: .table)
            view.isUserInteractionEnabled = false
            addSubview(view)
            cards[play.spot] = view
            cardIDs[play.spot] = play.card.tdpID
            guard bounds.width > 0 else { continue }
            place(view, at: play.spot)
            if canAnimate {
                let from = origin(play.spot)
                let final = view.center
                view.center = CGPoint(x: final.x + from.x, y: final.y + from.y)
                view.alpha = 0
                UIView.animate(withDuration: 0.34, delay: 0, usingSpringWithDamping: 0.86,
                               initialSpringVelocity: 0.3, options: [.beginFromCurrentState]) {
                    view.center = final
                    view.alpha = 1
                }
            }
        }

        // Latest card on top, like a real pile.
        for play in plays { if let view = cards[play.spot] { bringSubviewToFront(view) } }
        for (spot, view) in cards { view.ringColor = spot == winner ? TDPTheme.accent : nil }
        if let winner, winner != poppedWinner, let view = cards[winner] {
            poppedWinner = winner
            let rest = view.transform
            UIView.animate(withDuration: 0.16, delay: 0.05, options: [.curveEaseOut]) {
                view.transform = rest.scaledBy(x: 1.08, y: 1.08)
            } completion: { _ in
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6,
                               initialSpringVelocity: 0.3, options: []) {
                    view.transform = rest
                }
            }
        }
        if winner == nil { poppedWinner = nil }

        slotSpot = pending
        slot.isHidden = pending == nil
        if let pending, bounds.width > 0 { place(slot, at: pending, rotated: false) }
        bringSubviewToFront(captionLabel)
    }

    /// The card on the table at `spot`, if one has been played there.
    func cardView(at spot: Spot) -> TDPCardButton? {
        cards[spot]
    }

    /// Hands the trick's cards over — still on screen, no longer tracked —
    /// for an effect to carry off instead of the usual sweep.
    func takeCards() -> [TDPCardButton] {
        let views = Array(cards.values)
        cards.removeAll()
        cardIDs.removeAll()
        return views
    }

    #if DEBUG
    /// A loose card at `spot` that the trick doesn't track — for replaying
    /// the big moments from the debug menu.
    func debugPlace(_ card: Card, at spot: Spot) -> TDPCardButton {
        let view = TDPCardButton(card: card, elevation: .table)
        view.isUserInteractionEnabled = false
        addSubview(view)
        place(view, at: spot)
        return view
    }
    #endif

    /// Sweeps the finished trick toward whoever won it.
    func collect(toward spot: Spot?) {
        let views = Array(cards.values)
        cards.removeAll()
        cardIDs.removeAll()
        guard !views.isEmpty else { return }
        let target = spot.map(origin) ?? .zero
        let center = CGPoint(x: bounds.midX + target.x * 0.9, y: bounds.midY + target.y * 0.9)
        UIView.animate(withDuration: 0.38, delay: 0, options: [.curveEaseIn]) {
            for view in views {
                view.center = center
                view.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
                view.alpha = 0
            }
        } completion: { _ in
            views.forEach { $0.removeFromSuperview() }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        ring.frame = bounds
        ring.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 0.5, dy: 0.5)).cgPath
        captionLabel.frame = CGRect(x: -60, y: -30 * TDPTheme.scale,
                                    width: bounds.width + 120, height: 18 * TDPTheme.scale)
        guard bounds.size != laidOutSize else { return }
        laidOutSize = bounds.size
        for (spot, view) in cards { place(view, at: spot) }
        if let slotSpot { place(slot, at: slotSpot, rotated: false) }
    }

    private func applyTheme() {
        ring.strokeColor = TDPTheme.hairline.resolvedColor(with: traitCollection).cgColor
    }
}

// MARK: - Hand

/// Your cards, fanned along an arc exactly as the reference does it: each
/// card rotates about a point 700pt below its top edge, the spread is 5° a
/// card up to 25° total, playable cards lift 14pt and the selected card 34.
final class TDPHandFanView: UIView {

    enum Lift { case none, hint, selected }

    struct Item {
        let key: String
        let card: Card?
        let tag: Int
        var enabled: Bool
        var dimmed: Bool
        var lift: Lift
        var highlighted: Bool
    }

    var onTap: ((TDPCardButton) -> Void)?

    private var views: [String: TDPCardButton] = [:]
    private var items: [Item] = []
    private var laidOutSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func setItems(_ newItems: [Item], animated: Bool) {
        let keys = Set(newItems.map(\.key))

        for (key, view) in views where !keys.contains(key) {
            views[key] = nil
            guard animated else { view.removeFromSuperview(); continue }
            UIView.animate(withDuration: 0.2) {
                view.alpha = 0
                view.transform = view.transform.translatedBy(x: 0, y: -50)
            } completion: { _ in
                view.removeFromSuperview()
            }
        }

        var appearing: Set<String> = []
        for item in newItems where views[item.key] == nil {
            let view = TDPCardButton(card: item.card, faceDown: item.card == nil, elevation: .hand)
            view.addTarget(self, action: #selector(didTap(_:)), for: .touchUpInside)
            addSubview(view)
            views[item.key] = view
            appearing.insert(item.key)
        }

        for item in newItems {
            guard let view = views[item.key] else { continue }
            view.tag = item.tag
            view.setPlayable(item.enabled, dimmed: item.dimmed)
            view.ringColor = item.highlighted ? TDPTheme.accent : nil
            bringSubviewToFront(view)     // left-to-right stacking, rightmost on top
        }

        items = newItems
        applyLayout(animated: animated, appearing: appearing)
    }

    @objc private func didTap(_ sender: TDPCardButton) {
        onTap?(sender)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != laidOutSize else { return }
        laidOutSize = bounds.size
        applyLayout(animated: false, appearing: [])
    }

    private func applyLayout(animated: Bool, appearing: Set<String>) {
        guard bounds.width > 0 else { return }
        let s = TDPTheme.scale
        let size = TDPTheme.handCard
        let n = items.count
        let total = min(25.0, Double(max(n - 1, 0)) * 5.0)
        let step = n > 1 ? total / Double(n - 1) : 0
        let center = CGPoint(x: bounds.midX, y: 46 * s + size.height / 2)
        // The reference's transform-origin is 700px below the card's top.
        let pivot = 700 * s - size.height / 2

        var targets: [(TDPCardButton, CGAffineTransform)] = []
        var dealt: [(TDPCardButton, CGAffineTransform)] = []
        for (index, item) in items.enumerated() {
            guard let view = views[item.key] else { continue }
            let degrees = -total / 2 + Double(index) * step
            let lift: CGFloat
            switch item.lift {
            case .none:     lift = 0
            case .hint:     lift = -14 * s
            case .selected: lift = -34 * s
            }
            // CSS: rotate(θ) translateY(lift) about a far-below origin.
            let transform = CGAffineTransform.identity
                .translatedBy(x: 0, y: pivot)
                .rotated(by: CGFloat(degrees) * .pi / 180)
                .translatedBy(x: 0, y: lift - pivot)
            view.bounds = CGRect(origin: .zero, size: size)
            view.center = center
            if appearing.contains(item.key) && animated {
                // New cards drop in from above, as if just dealt.
                view.transform = transform.translatedBy(x: 0, y: -70 * s).rotated(by: 0.08)
                view.alpha = 0
                dealt.append((view, transform))
            } else {
                targets.append((view, transform))
            }
        }

        let apply = {
            for (view, transform) in targets {
                view.transform = transform
                view.alpha = 1
            }
        }
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0,
                           options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState],
                           animations: apply)
        } else {
            apply()
        }
        // Dealt cards land one after another, left to right.
        for (order, (view, transform)) in dealt.enumerated() {
            UIView.animate(withDuration: 0.36, delay: Double(order) * 0.06,
                           usingSpringWithDamping: 0.82, initialSpringVelocity: 0.4,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                view.transform = transform
                view.alpha = 1
            }
        }
    }
}

// MARK: - Prompt sheet

/// Raised card for the decisions the reference doesn't show: calling trump,
/// settling a debt, the pull, and the round summary. It sits over the trick
/// circle, which is always empty at those moments.
final class TDPPromptCard: UIView {

    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    let bodyStack = UIStackView()
    let primaryRow = UIStackView()
    let secondaryRow = UIStackView()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = TDPTheme.raised
        layer.cornerRadius = 22 * TDPTheme.scale
        layer.cornerCurve = .continuous
        layer.borderWidth = 1

        titleLabel.font = TDPTheme.font(17, .semibold)
        titleLabel.textColor = TDPTheme.ink
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        subtitleLabel.font = TDPTheme.font(13)
        subtitleLabel.textColor = TDPTheme.muted
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        bodyStack.axis = .vertical
        bodyStack.spacing = 10
        for row in [primaryRow, secondaryRow] {
            row.axis = .horizontal
            row.spacing = 8
            row.distribution = .fillEqually
        }

        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel, bodyStack, primaryRow, secondaryRow])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(5, after: titleLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let pad = 18 * TDPTheme.scale
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: pad),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -pad),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: pad),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -pad)
        ])
        applyTheme()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (card: TDPPromptCard, _: UITraitCollection) in
            card.applyTheme()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func reset(title: String, subtitle: String?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = subtitle?.isEmpty ?? true
        for stack in [bodyStack, primaryRow, secondaryRow] {
            stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        }
    }

    /// Hides whichever rows ended up empty.
    func finish() {
        bodyStack.isHidden = bodyStack.arrangedSubviews.isEmpty
        primaryRow.isHidden = primaryRow.arrangedSubviews.isEmpty
        secondaryRow.isHidden = secondaryRow.arrangedSubviews.isEmpty
    }

    private func applyTheme() {
        layer.borderColor = TDPTheme.hairline.resolvedColor(with: traitCollection).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = traitCollection.userInterfaceStyle == .dark ? 0.45 : 0.14
        layer.shadowOffset = CGSize(width: 0, height: 10)
        layer.shadowRadius = 22
    }
}

// MARK: - Toast

final class TDPToastView: UIView {

    private let label = UILabel()
    private var hideWork: DispatchWorkItem?

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = TDPTheme.raised
        layer.cornerCurve = .continuous
        isUserInteractionEnabled = false
        alpha = 0
        label.font = TDPTheme.font(13, .medium)
        label.textColor = TDPTheme.warn
        label.numberOfLines = 2
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.height / 2, 18)
    }

    func show(_ text: String) {
        label.text = text
        hideWork?.cancel()
        UIView.animate(withDuration: 0.18) { self.alpha = 1 }
        let work = DispatchWorkItem { [weak self] in
            UIView.animate(withDuration: 0.25) { self?.alpha = 0 }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }
}

// MARK: - Pass & play curtain

final class TDPHandoffCurtain: UIView {

    private let avatar = TDPAvatarView(side: 64, radius: 22)
    private let nameLabel = UILabel()
    var onReveal: (() -> Void)?

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        // Fully opaque — a translucent curtain would show the hand beneath.
        backgroundColor = TDPTheme.page
        isHidden = true

        let passLabel = UILabel()
        passLabel.text = "Pass the phone to"
        passLabel.font = TDPTheme.font(14)
        passLabel.textColor = TDPTheme.muted
        nameLabel.font = TDPTheme.font(26, .semibold)
        nameLabel.textColor = TDPTheme.ink
        let hint = UILabel()
        hint.text = "Tap when they're holding it"
        hint.font = TDPTheme.font(13)
        hint.textColor = TDPTheme.muted

        let stack = UIStackView(arrangedSubviews: [avatar, passLabel, nameLabel, hint])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.setCustomSpacing(18, after: avatar)
        stack.setCustomSpacing(22, after: nameLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTap)))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func present(name: String) {
        nameLabel.text = name
        avatar.setName(name)
        avatar.tint = .green
        // No fade-in: the cards underneath are already rendered, and even a
        // few frames of a half-transparent curtain would show them.
        layer.removeAllAnimations()
        alpha = 1
        isHidden = false
    }

    @objc private func didTap() {
        UIView.animate(withDuration: 0.18) {
            self.alpha = 0
        } completion: { _ in
            self.isHidden = true
        }
        onReveal?()
    }
}
