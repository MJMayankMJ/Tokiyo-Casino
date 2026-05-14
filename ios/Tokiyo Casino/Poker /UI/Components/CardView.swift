//
//  CardView.swift
//  Poker
//


import UIKit
#if DEBUG
import SwiftUI
#endif

class CardView: UIView {

    enum Style { case face, hero }

    /// Showdown highlight — winning cards stay bright with a warm amber border
    /// and gold glow; unused cards fade to a beige tint with reduced opacity.
    enum HighlightState { case none, winning, unused }

    private(set) var card: Card?
    private(set) var isFaceUp: Bool = false

    /// When set, the next setCard call will render with hero styling.
    var style: Style = .face { didSet { rebuild() } }

    var highlightState: HighlightState = .none {
        didSet {
            guard oldValue != highlightState else { return }
            applyHighlight()
        }
    }

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
        applyDefaultShadow()

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
        rankLabel.adjustsFontSizeToFitWidth = true
        rankLabel.minimumScaleFactor = 0.78
        rankLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rankLabel)

        // Corner (hero only)
        suitCorner.isHidden = true
        suitCorner.translatesAutoresizingMaskIntoConstraints = false
        addSubview(suitCorner)

        cornerRankLabel.isHidden = true
        cornerRankLabel.textAlignment = .center
        cornerRankLabel.font = .systemFont(ofSize: 14, weight: .heavy)
        cornerRankLabel.adjustsFontSizeToFitWidth = true
        cornerRankLabel.minimumScaleFactor = 0.72
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
            // Direct translation of poker.jsx's hero Card:
            // top-left index at 8/6, corner suit 10, main suit w*0.30,
            // rank w*0.42, and a 4pt vertical gap in a centered column.
            let designScale = w / 64.0
            let cornerRankFont = 14 * designScale
            let cornerSuitSize = 10 * designScale
            let cornerRankW = card?.rank == .ten ? 18 * designScale : 12 * designScale
            cornerRankLabel.font = .systemFont(ofSize: cornerRankFont, weight: .heavy)
            cornerRankLabel.frame = CGRect(
                x: 8 * designScale,
                y: 6 * designScale,
                width: cornerRankW,
                height: cornerRankFont
            )
            suitCorner.frame = CGRect(
                x: cornerRankLabel.frame.minX + (cornerRankW - cornerSuitSize) / 2,
                y: cornerRankLabel.frame.maxY + 1 * designScale,
                width: cornerSuitSize,
                height: cornerSuitSize
            )

            let suitSize = CGFloat(Int((w * 0.30).rounded()))
            let rankFontSize = CGFloat(Int((w * 0.42).rounded()))
            let gap = 4 * designScale
            let groupHeight = suitSize + gap + rankFontSize
            let groupY = (h - groupHeight) / 2
            suitCenter.frame = CGRect(x: (w - suitSize) / 2, y: groupY, width: suitSize, height: suitSize)
            rankLabel.font = .systemFont(ofSize: rankFontSize, weight: .heavy)
            rankLabel.frame = CGRect(
                x: 0,
                y: suitCenter.frame.maxY + gap - 1 * designScale,
                width: w,
                height: rankFontSize + 2 * designScale
            )
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

        // Re-apply any active showdown highlight so a reveal/flip doesn't
        // overwrite the amber glow.
        applyHighlight()
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
        // Reset visual side-effects of any highlight while showing the back.
        applyDefaultShadow()
        alpha = 1.0
    }

    private func applyDefaultShadow() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
    }

    private func applyHighlight() {
        guard isFaceUp else {
            applyDefaultShadow()
            alpha = 1.0
            return
        }
        switch highlightState {
        case .none:
            applyDefaultShadow()
            alpha = 1.0
            backgroundColor = .white
            layer.borderColor = UIColor.black.withAlphaComponent(0.04).cgColor
            layer.borderWidth = 0.5
        case .winning:
            // Bright white face, warm amber border, soft golden glow.
            layer.shadowColor = PokerTheme.amber.cgColor
            layer.shadowOpacity = 0.75
            layer.shadowOffset = CGSize(width: 0, height: 2)
            layer.shadowRadius = 14
            alpha = 1.0
            backgroundColor = .white
            layer.borderColor = PokerTheme.amber.cgColor
            layer.borderWidth = 1.6
        case .unused:
            // Faded warm beige tint, reduced opacity, soft shadow.
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.08
            layer.shadowOffset = CGSize(width: 0, height: 2)
            layer.shadowRadius = 4
            alpha = 0.55
            backgroundColor = PokerTheme.surfaceAlt
            layer.borderColor = UIColor.black.withAlphaComponent(0.04).cgColor
            layer.borderWidth = 0.5
        }
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

#if DEBUG
private struct CardViewPreviewSample {
    let card: Card
    let style: CardView.Style
    let faceUp: Bool
    let tilt: CGFloat
    let size: CGSize
}

private final class CardViewPreviewCanvas: UIView {
    private let samples: [CardViewPreviewSample]
    private let cardViews: [CardView]

    init(samples: [CardViewPreviewSample]) {
        self.samples = samples
        self.cardViews = samples.map { sample in
            let view = CardView()
            view.style = sample.style
            view.setCard(sample.card, faceUp: sample.faceUp)
            view.transform = CGAffineTransform(rotationAngle: sample.tilt * .pi / 180)
            return view
        }
        super.init(frame: .zero)
        backgroundColor = PokerTheme.felt
        layer.cornerRadius = 18
        clipsToBounds = true
        cardViews.forEach(addSubview)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !cardViews.isEmpty else { return }

        let totalWidth = samples.reduce(CGFloat.zero) { $0 + $1.size.width } - CGFloat(max(0, samples.count - 1)) * 12
        var x = (bounds.width - totalWidth) / 2
        let y = (bounds.height - samples.map(\.size.height).max()!) / 2

        for (index, cardView) in cardViews.enumerated() {
            cardView.transform = .identity
            cardView.frame = CGRect(origin: CGPoint(x: x, y: y), size: samples[index].size)
            cardView.transform = CGAffineTransform(rotationAngle: samples[index].tilt * .pi / 180)
            x += samples[index].size.width - 12
        }
    }
}

private struct CardViewPreview: UIViewRepresentable {
    let samples: [CardViewPreviewSample]

    func makeUIView(context: Context) -> CardViewPreviewCanvas {
        CardViewPreviewCanvas(samples: samples)
    }

    func updateUIView(_ uiView: CardViewPreviewCanvas, context: Context) {}
}

struct PokerCardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CardViewPreview(samples: [
                .init(card: Card(suit: .hearts, rank: .ace), style: .hero, faceUp: true, tilt: -7, size: CGSize(width: 64, height: 92)),
                .init(card: Card(suit: .spades, rank: .king), style: .hero, faceUp: true, tilt: 7, size: CGSize(width: 64, height: 92)),
            ])
            .previewLayout(.fixed(width: 300, height: 190))
            .previewDisplayName("Hero Pair")

            CardViewPreview(samples: [
                .init(card: Card(suit: .hearts, rank: .ace), style: .hero, faceUp: true, tilt: -4, size: CGSize(width: 76, height: 110)),
                .init(card: Card(suit: .diamonds, rank: .ten), style: .hero, faceUp: true, tilt: 0, size: CGSize(width: 76, height: 110)),
                .init(card: Card(suit: .clubs, rank: .queen), style: .hero, faceUp: true, tilt: 4, size: CGSize(width: 76, height: 110)),
            ])
            .previewLayout(.fixed(width: 360, height: 210))
            .previewDisplayName("Hero Ranks")

            CardViewPreview(samples: [
                .init(card: Card(suit: .spades, rank: .two), style: .hero, faceUp: true, tilt: -7, size: CGSize(width: 56, height: 80)),
                .init(card: Card(suit: .hearts, rank: .nine), style: .hero, faceUp: true, tilt: 7, size: CGSize(width: 56, height: 80)),
                .init(card: Card(suit: .clubs, rank: .king), style: .face, faceUp: true, tilt: 0, size: CGSize(width: 42, height: 58)),
                .init(card: Card(suit: .diamonds, rank: .three), style: .face, faceUp: false, tilt: 0, size: CGSize(width: 42, height: 58)),
            ])
            .previewLayout(.fixed(width: 340, height: 170))
            .previewDisplayName("Mixed Sizes")
        }
    }
}
#endif
