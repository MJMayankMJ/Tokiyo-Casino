//
//  CardDesign.swift
//  Tokiyo Casino
//
//  The looks a deck can take, chosen per game in Profile. Each game draws
//  its own cards, but every game knows every design, and the backs are
//  drawn here so they match wherever they appear.
//

import UIKit

/// A deck's look: face and back together.
enum CardDesign: String, CaseIterable {
    /// Poker's original: a checkered back, a big suit and rank in the middle.
    case classic
    /// 5-3-2's original: a plain back with the Tokiyo sparkle, the index in
    /// the corner and one big suit.
    case minimal

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .minimal: return "Minimal"
        }
    }

    var detail: String {
        switch self {
        case .classic: return "Checkered back, big centre suit"
        case .minimal: return "Plain back, corner index"
        }
    }
}

/// Every game with cards. A new game adds a case and picks its default.
enum CardGame: String, CaseIterable {
    case poker
    case teenDoPaanch

    var title: String {
        switch self {
        case .poker:        return "Poker"
        case .teenDoPaanch: return "5-3-2"
        }
    }

    /// What each game looked like before designs could be chosen.
    var defaultDesign: CardDesign {
        switch self {
        case .poker:        return .classic
        case .teenDoPaanch: return .minimal
        }
    }
}

// MARK: - Back

/// A card back in either design. Drawn, so it stays crisp at every size and
/// follows light and dark.
final class CardBackView: UIView {

    var design: CardDesign { didSet { setNeedsDisplay() } }
    /// Card width → corner radius, so the back matches its card exactly.
    private let cornerRadius: (CGFloat) -> CGFloat

    init(design: CardDesign, cornerRadius: @escaping (CGFloat) -> CGFloat) {
        self.design = design
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (back: CardBackView, _: UITraitCollection) in
            back.setNeedsDisplay()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func draw(_ rect: CGRect) {
        guard bounds.width > 0 else { return }
        let radius = cornerRadius(bounds.width)
        switch design {
        case .classic: drawClassic(radius: radius)
        case .minimal: drawMinimal(radius: radius)
        }
    }

    /// Poker's back: a small diagonal checker inside a thin ring.
    private func drawClassic(radius: CGFloat) {
        let traits = traitCollection
        let ground = PokerTheme.cardBackBg.resolvedColor(with: traits)
        let ink = PokerTheme.cardBack.resolvedColor(with: traits)

        let outer = UIBezierPath(roundedRect: bounds, cornerRadius: radius)
        ground.setFill()
        outer.fill()

        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.saveGState()
        UIBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), cornerRadius: max(2, radius - 2)).addClip()
        ink.setFill()
        let tile: CGFloat = 6
        var y: CGFloat = 0
        var row = 0
        while y < bounds.height {
            var x: CGFloat = row % 2 == 0 ? 0 : tile
            while x < bounds.width {
                UIRectFill(CGRect(x: x, y: y, width: tile, height: tile))
                x += tile * 2
            }
            y += tile
            row += 1
        }
        ctx.restoreGState()

        let ring = UIBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), cornerRadius: radius)
        ring.lineWidth = 1
        ink.setStroke()
        ring.stroke()
    }

    /// 5-3-2's back: one colour, an inset hairline and the Tokiyo sparkle.
    private func drawMinimal(radius: CGFloat) {
        let traits = traitCollection
        let w = bounds.width

        TDPTheme.cardBack.resolvedColor(with: traits).setFill()
        UIBezierPath(roundedRect: bounds, cornerRadius: radius).fill()

        let inset = w * 0.09
        let frame = UIBezierPath(roundedRect: bounds.insetBy(dx: inset, dy: inset),
                                 cornerRadius: max(2, radius - inset * 0.7))
        frame.lineWidth = max(1, w * 0.016)
        TDPTheme.cardBackLine.resolvedColor(with: traits).setStroke()
        frame.stroke()

        TDPTheme.cardBackMark.resolvedColor(with: traits).setFill()
        Self.sparkle(at: CGPoint(x: bounds.midX, y: bounds.midY), size: w * 0.14).fill()
    }

    /// The four-point sparkle from the Tokiyo logo, with softly pinched sides.
    static func sparkle(at c: CGPoint, size s: CGFloat) -> UIBezierPath {
        let k = s * 0.14
        let path = UIBezierPath()
        path.move(to: CGPoint(x: c.x, y: c.y - s))
        path.addQuadCurve(to: CGPoint(x: c.x + s, y: c.y), controlPoint: CGPoint(x: c.x + k, y: c.y - k))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y + s), controlPoint: CGPoint(x: c.x + k, y: c.y + k))
        path.addQuadCurve(to: CGPoint(x: c.x - s, y: c.y), controlPoint: CGPoint(x: c.x - k, y: c.y + k))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y - s), controlPoint: CGPoint(x: c.x - k, y: c.y - k))
        path.close()
        return path
    }
}
