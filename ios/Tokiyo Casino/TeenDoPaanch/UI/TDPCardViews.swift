//
//  TDPCardViews.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  Cards and buttons for the table. Cards are drawn, not bitmaps: rank and
//  a small suit stacked top-left, one large suit bottom-right — the
//  reference's minimal face — using Poker's vector suit glyphs so both
//  games share the same suit shapes.
//

import UIKit

// MARK: - Suit glyph

/// Poker's `SuitView` bakes its fill into a `CGColor`, which does not follow
/// a light/dark switch on its own. This wrapper re-resolves the tint.
final class TDPSuitGlyph: UIView {

    private let shape = SuitView(frame: .zero)

    var suit: Suit { didSet { shape.glyph = SuitView.glyph(for: suit) } }
    var tint: UIColor { didSet { applyTheme() } }

    init(suit: Suit, tint: UIColor) {
        self.suit = suit
        self.tint = tint
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        shape.glyph = SuitView.glyph(for: suit)
        addSubview(shape)
        applyTheme()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (glyph: TDPSuitGlyph, _: UITraitCollection) in
            glyph.applyTheme()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        shape.frame = bounds
    }

    private func applyTheme() {
        shape.color = tint.resolvedColor(with: traitCollection)
    }
}

// MARK: - Card

/// One playing card. Laid out by frame — the hand fan and the trick table
/// both position cards with transforms, so there are no size constraints.
final class TDPCardButton: UIButton {

    enum Elevation { case hand, table }

    private(set) var card: Card?
    let isFaceDown: Bool
    private let elevation: Elevation
    /// The player's pick for 5-3-2 in Profile, unless a preview asks for one.
    let design: CardDesign

    private let rankLabel = UILabel()
    /// Classic only: the big rank under the centre suit.
    private let centerRank = UILabel()
    private var smallSuit: TDPSuitGlyph?
    private var bigSuit: TDPSuitGlyph?
    private var backArt: CardBackView?
    private let dimView = UIView()
    private let ringLayer = CALayer()

    /// Outline marking the card that won the trick, or the card just pulled.
    var ringColor: UIColor? { didSet { applyTheme() } }
    private(set) var isPlayable = true

    init(card: Card?, faceDown: Bool = false, elevation: Elevation = .hand, design: CardDesign? = nil) {
        self.card = card
        self.isFaceDown = faceDown || card == nil
        self.elevation = elevation
        self.design = design ?? PlayerProfile.cardDesign(for: .teenDoPaanch)
        let size = elevation == .hand ? TDPTheme.handCard : TDPTheme.tableCard
        super.init(frame: CGRect(origin: .zero, size: size))
        layer.cornerCurve = .continuous

        if isFaceDown {
            backgroundColor = .clear          // the back draws its own ground
            let art = CardBackView(design: self.design) { $0 * 0.145 }
            addSubview(art)
            backArt = art
            accessibilityLabel = "Face-down card"
        } else if let card {
            backgroundColor = TDPTheme.cardFace
            let ink = TDPTheme.isRed(card.suit) ? TDPTheme.suitRed : TDPTheme.suitBlack
            rankLabel.text = card.rank.shortString
            rankLabel.textColor = ink
            rankLabel.isUserInteractionEnabled = false
            addSubview(rankLabel)
            let small = TDPSuitGlyph(suit: card.suit, tint: ink)
            let big = TDPSuitGlyph(suit: card.suit, tint: ink)
            addSubview(small)
            addSubview(big)
            smallSuit = small
            bigSuit = big
            if self.design == .classic {
                centerRank.text = card.rank.shortString
                centerRank.textColor = ink
                centerRank.textAlignment = .center
                centerRank.isUserInteractionEnabled = false
                addSubview(centerRank)
            }
            accessibilityLabel = "\(card.rank.shortString) of \(TDPTheme.suitName(card.suit))"
        }

        dimView.backgroundColor = TDPTheme.cardDim
        dimView.isUserInteractionEnabled = false
        dimView.isHidden = true
        dimView.layer.cornerCurve = .continuous
        addSubview(dimView)

        ringLayer.borderWidth = 2.5
        ringLayer.cornerCurve = .continuous
        ringLayer.isHidden = true
        layer.addSublayer(ringLayer)

        applyTheme()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (card: TDPCardButton, _: UITraitCollection) in
            card.applyTheme()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// `dimmed` defaults to "not playable". Pass `false` to disable a card
    /// without greying it — used while you're waiting, so your hand stays
    /// readable when it isn't your turn.
    func setPlayable(_ playable: Bool, dimmed: Bool? = nil) {
        isPlayable = playable
        isEnabled = playable
        dimView.isHidden = !(dimmed ?? !playable)
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        let radius = w * 0.145
        layer.cornerRadius = radius
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
        dimView.frame = bounds
        dimView.layer.cornerRadius = radius
        ringLayer.frame = bounds.insetBy(dx: -3, dy: -3)
        ringLayer.cornerRadius = radius + 3

        if isFaceDown {
            backArt?.frame = bounds
            return
        }
        if design == .classic {
            layoutClassicFace()
            return
        }

        // Rank and small suit share a column, centred on each other.
        rankLabel.attributedText = NSAttributedString(
            string: rankLabel.text ?? "",
            attributes: [.font: UIFont.systemFont(ofSize: w * 0.275, weight: .semibold),
                         .kern: -0.02 * w * 0.275,
                         .foregroundColor: rankLabel.textColor as Any]
        )
        rankLabel.sizeToFit()
        let smallSide = w * 0.215
        let column = max(rankLabel.bounds.width, smallSide)
        let left = w * 0.105
        rankLabel.frame.origin = CGPoint(x: left + (column - rankLabel.bounds.width) / 2, y: w * 0.075)
        smallSuit?.frame = CGRect(x: left + (column - smallSide) / 2,
                                  y: rankLabel.frame.maxY - w * 0.02,
                                  width: smallSide, height: smallSide)
        let bigSide = w * 0.42
        bigSuit?.frame = CGRect(x: w - bigSide - w * 0.1,
                                y: bounds.height - bigSide - w * 0.08,
                                width: bigSide, height: bigSide)
    }

    /// Poker's face: a small index in the corner, and a big suit over a big
    /// rank in the middle — the same proportions as Poker's own cards.
    private func layoutClassicFace() {
        let w = bounds.width
        let unit = w / 64
        let indexFont = UIFont.systemFont(ofSize: 14 * unit, weight: .heavy)
        rankLabel.attributedText = NSAttributedString(
            string: rankLabel.text ?? "",
            attributes: [.font: indexFont, .foregroundColor: rankLabel.textColor as Any])
        rankLabel.sizeToFit()
        let indexWidth = max(rankLabel.bounds.width, 10 * unit)
        rankLabel.frame.origin = CGPoint(x: 7 * unit + (indexWidth - rankLabel.bounds.width) / 2, y: 5 * unit)
        let smallSide = 10 * unit
        smallSuit?.frame = CGRect(x: 7 * unit + (indexWidth - smallSide) / 2, y: rankLabel.frame.maxY + unit,
                                  width: smallSide, height: smallSide)

        let suitSide = (w * 0.30).rounded()
        let rankSize = (w * 0.42).rounded()
        let gap = 4 * unit
        let top = (bounds.height - (suitSide + gap + rankSize)) / 2 + 4 * unit
        bigSuit?.frame = CGRect(x: (w - suitSide) / 2, y: top, width: suitSide, height: suitSide)
        centerRank.font = .systemFont(ofSize: rankSize, weight: .heavy)
        centerRank.frame = CGRect(x: 0, y: top + suitSide + gap - unit, width: w, height: rankSize + 2 * unit)
    }

    private func applyTheme() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = TDPTheme.shadowOpacity(for: traitCollection)
        switch elevation {
        case .hand:
            layer.shadowOffset = CGSize(width: -3, height: 2)   // ref: -3px 2px 10px
            layer.shadowRadius = 5
        case .table:
            layer.shadowOffset = CGSize(width: 0, height: 6)    // ref: 0 6px 18px
            layer.shadowRadius = 9
        }
        ringLayer.isHidden = ringColor == nil
        ringLayer.borderColor = ringColor?.resolvedColor(with: traitCollection).cgColor
    }
}

// MARK: - Buttons

/// Capsule button. Primary is Poker's amber in light and the reference's
/// green in dark; secondary is raised chrome with a hairline.
final class TDPButton: UIButton {

    enum Style { case primary, secondary, quiet }

    let style: Style

    init(title: String, style: Style = .primary) {
        self.style = style
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setTitle(title, for: .normal)
        titleLabel?.font = TDPTheme.font(15, .semibold)
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.75
        titleLabel?.lineBreakMode = .byTruncatingTail
        layer.cornerCurve = .continuous

        switch style {
        case .primary:
            backgroundColor = TDPTheme.primary
            setTitleColor(TDPTheme.primaryInk, for: .normal)
        case .secondary:
            backgroundColor = TDPTheme.raised
            setTitleColor(TDPTheme.ink, for: .normal)
            layer.borderWidth = 1
        case .quiet:
            backgroundColor = .clear
            setTitleColor(TDPTheme.muted, for: .normal)
        }
        applyTheme()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (button: TDPButton, _: UITraitCollection) in
            button.applyTheme()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var intrinsicContentSize: CGSize {
        let base = super.intrinsicContentSize
        return CGSize(width: base.width + 36 * TDPTheme.scale,
                      height: max(46 * TDPTheme.scale, base.height + 20))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.72 : (isEnabled ? 1 : 0.45) }
    }

    override var isEnabled: Bool {
        didSet { alpha = isEnabled ? 1 : 0.45 }
    }

    private func applyTheme() {
        layer.borderColor = TDPTheme.hairline.resolvedColor(with: traitCollection).cgColor
        if style == .secondary {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = traitCollection.userInterfaceStyle == .dark ? 0 : 0.08
            layer.shadowOffset = CGSize(width: 0, height: 1)
            layer.shadowRadius = 2
        }
    }
}

/// A suit to call as trump. Square-ish chip with the glyph in its colour.
final class TDPSuitButton: UIButton {

    let suit: Suit
    private let glyph: TDPSuitGlyph

    init(suit: Suit) {
        self.suit = suit
        self.glyph = TDPSuitGlyph(suit: suit, tint: TDPTheme.isRed(suit) ? TDPTheme.trumpRed : TDPTheme.ink)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = TDPTheme.raisedAlt
        layer.cornerRadius = 14 * TDPTheme.scale
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        glyph.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glyph)
        accessibilityLabel = "Trump \(TDPTheme.suitName(suit))"
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 56 * TDPTheme.scale),
            glyph.centerXAnchor.constraint(equalTo: centerXAnchor),
            glyph.centerYAnchor.constraint(equalTo: centerYAnchor),
            glyph.widthAnchor.constraint(equalToConstant: 26 * TDPTheme.scale),
            glyph.heightAnchor.constraint(equalToConstant: 26 * TDPTheme.scale)
        ])
        applyTheme()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (button: TDPSuitButton, _: UITraitCollection) in
            button.applyTheme()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1 }
    }

    private func applyTheme() {
        layer.borderColor = TDPTheme.hairline.resolvedColor(with: traitCollection).cgColor
    }
}
