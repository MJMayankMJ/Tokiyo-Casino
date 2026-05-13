//
//  CardView.swift
//  Poker
//
//  Redesigned to match the Claude Design handoff. Cards render with the
//  cream/white face, large center rank, suit pictogram and (for hero) a
//  small corner glyph. Face-down cards use a themed champagne checker.
//

import UIKit

class CardView: UIView {

    enum Style { case face, hero }

    private(set) var card: Card?
    private(set) var isFaceUp: Bool = false

    /// When set, the next setCard call will render with hero styling.
    var style: Style = .face { didSet { rebuild() } }

    // Layers / subviews
    private let cardBack = CALayer()
    private let cardBackPattern = CALayer()
    private let suitCenter = SuitView()
    private let suitCorner = SuitView()
    private let rankLabel = UILabel()
    private let cornerRankLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupView() {
        backgroundColor = .clear
        clipsToBounds = false

        // Soft drop shadow on the view
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8

        // Back layers (themed checker)
        cardBack.backgroundColor = PokerTheme.cardBackBg.cgColor
        cardBackPattern.backgroundColor = UIColor.clear.cgColor
        layer.addSublayer(cardBack)
        cardBack.addSublayer(cardBackPattern)

        // Center suit / rank
        suitCenter.translatesAutoresizingMaskIntoConstraints = false
        addSubview(suitCenter)

        rankLabel.textAlignment = .center
        rankLabel.font = .systemFont(ofSize: 18, weight: .heavy)
        rankLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rankLabel)

        // Corner (hero only)
        suitCorner.isHidden = true
        suitCorner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(suitCorner)

        cornerRankLabel.isHidden = true
        cornerRankLabel.textAlignment = .center
        cornerRankLabel.font = .systemFont(ofSize: 14, weight: .heavy)
        cornerRankLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cornerRankLabel)

        showBack()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let w = bounds.width
        let h = bounds.height
        let radius = max(4, w * 0.18)
        layer.cornerRadius = radius

        cardBack.frame = bounds
        cardBack.cornerRadius = radius
        cardBack.masksToBounds = true

        cardBackPattern.frame = bounds.insetBy(dx: 2, dy: 2)
        cardBackPattern.cornerRadius = max(2, radius - 2)
        cardBackPattern.masksToBounds = true

        // Refresh checker pattern image at current size
        if isFaceUp == false {
            applyCheckerPattern()
        }

        // Layout face contents
        switch style {
        case .face:
            // suit on top, rank below
            let suitSize = max(8, w * 0.36)
            suitCenter.frame = CGRect(x: (w - suitSize) / 2, y: h * 0.16, width: suitSize, height: suitSize)
            let rankFontSize = max(10, w * 0.46)
            rankLabel.font = .systemFont(ofSize: rankFontSize, weight: .heavy)
            rankLabel.frame = CGRect(x: 0, y: h * 0.50, width: w, height: h * 0.45)
        case .hero:
            // big rank center, suit just above + corner glyph at top-left
            let suitSize = max(10, w * 0.30)
            suitCenter.frame = CGRect(x: (w - suitSize) / 2, y: h * 0.22, width: suitSize, height: suitSize)
            let rankFontSize = max(12, w * 0.42)
            rankLabel.font = .systemFont(ofSize: rankFontSize, weight: .heavy)
            rankLabel.frame = CGRect(x: 0, y: h * 0.52, width: w, height: h * 0.42)
            cornerRankLabel.frame = CGRect(x: 6, y: 4, width: 14, height: 16)
            suitCorner.frame = CGRect(x: 6 + 2, y: 20, width: 10, height: 10)
        }
    }

    // MARK: - Public API

    func setCard(_ card: Card, faceUp: Bool = true) {
        self.card = card
        self.isFaceUp = faceUp
        rebuild()
    }

    /// Animated face-up flip.
    func revealCard() {
        guard card != nil else { return }
        isFaceUp = true
        UIView.transition(with: self, duration: 0.5, options: .transitionFlipFromLeft) {
            self.rebuild()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Instant face-up.
    func forceShowCard() {
        guard card != nil else { return }
        isFaceUp = true
        rebuild()
    }

    // MARK: - Private

    private func rebuild() {
        if isFaceUp, let card {
            showFace(card)
        } else {
            showBack()
        }
        setNeedsLayout()
    }

    private func showFace(_ card: Card) {
        // Show face elements, hide back
        backgroundColor = .white
        layer.borderColor = UIColor.black.withAlphaComponent(0.04).cgColor
        layer.borderWidth = 0.5

        cardBack.isHidden = true

        let color = SuitView.color(for: card.suit)
        suitCenter.glyph = SuitView.glyph(for: card.suit)
        suitCenter.color = color
        suitCenter.isHidden = false

        rankLabel.text = card.rank.shortString
        rankLabel.textColor = color
        rankLabel.isHidden = false

        if style == .hero {
            cornerRankLabel.text = card.rank.shortString
            cornerRankLabel.textColor = color
            cornerRankLabel.isHidden = false

            suitCorner.glyph = SuitView.glyph(for: card.suit)
            suitCorner.color = color
            suitCorner.isHidden = false
        } else {
            cornerRankLabel.isHidden = true
            suitCorner.isHidden = true
        }
    }

    private func showBack() {
        backgroundColor = .clear
        layer.borderWidth = 0

        cardBack.isHidden = false
        suitCenter.isHidden = true
        rankLabel.isHidden = true
        cornerRankLabel.isHidden = true
        suitCorner.isHidden = true
        applyCheckerPattern()
    }

    private func applyCheckerPattern() {
        // Bake a small repeating checker image for the back. We use it as
        // `contents` on a CALayer; this stays crisp because the layer is masked
        // to the card's rounded rect and the pattern size scales with the card.
        let tile: CGFloat = 6
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: tile * 2, height: tile * 2))
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            // background
            cg.setFillColor(PokerTheme.cardBackBg.resolvedColor(with: traitCollection).cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: tile * 2, height: tile * 2))
            // diagonal checker
            cg.setFillColor(PokerTheme.cardBack.resolvedColor(with: traitCollection).cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: tile, height: tile))
            cg.fill(CGRect(x: tile, y: tile, width: tile, height: tile))
        }
        cardBackPattern.contents = image.cgImage
        cardBackPattern.contentsGravity = .resize
        // Repeating tile via a pattern color is more authentic — set it as a contents image
        // with `contentsScale` so it's not stretched.
        cardBackPattern.contentsScale = UIScreen.main.scale
        // Use a CALayer of patternColor for a true tiling effect:
        cardBackPattern.backgroundColor = UIColor(patternImage: image).cgColor
        cardBackPattern.contents = nil

        // Subtle ring
        cardBack.borderColor = PokerTheme.cardBack.cgColor
        cardBack.borderWidth = 1
    }
}
