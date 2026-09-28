import UIKit

/// The Home header's brand: the app icon's hand — A♠, K♥, Q♦ fanned — and
/// the "ToKiyo" sticker beside it. Each card is its own image so the hand
/// can move.
///
/// A small secret: tap it and the hand fans out and settles with one soft
/// card flick. Five quick taps gather the cards and flick them back out one
/// by one. It does nothing else.
final class TokiyoLogoView: UIView {

    /// Where each card sits in the icon artwork (a 1024-unit canvas).
    private struct Seat {
        let image: String
        let x: CGFloat, y: CGFloat
        let angle: CGFloat
        let width: CGFloat, height: CGFloat
        /// Which way it swings when the hand fans out: -1 left, 1 right, 0 lifts.
        let swing: CGFloat
    }

    /// Back to front, as in the icon: the K sits on top.
    private static let seats = [
        Seat(image: "TokiyoCardA", x: 262, y: 410, angle: -14, width: 286, height: 400, swing: -1),
        Seat(image: "TokiyoCardQ", x: 762, y: 410, angle: 14, width: 286, height: 400, swing: 1),
        Seat(image: "TokiyoCardK", x: 512, y: 366, angle: 0, width: 318, height: 446, swing: 0),
    ]
    /// Icon units to points.
    private static let unit: CGFloat = 0.082
    private static let fanWidth: CGFloat = 66.4
    private static let wordSize = CGSize(width: 91.4, height: 42)
    private static let height: CGFloat = 44

    private let cards: [UIImageView]
    private let word = UIImageView(image: UIImage(named: "TokiyoWordmark"))
    private var streak = 0
    private var lastTap: CFTimeInterval = 0

    override init(frame: CGRect) {
        cards = Self.seats.map { UIImageView(image: UIImage(named: $0.image)) }
        super.init(frame: frame)
        for (card, seat) in zip(cards, Self.seats) {
            card.bounds.size = CGSize(width: seat.width * Self.unit, height: seat.height * Self.unit)
            card.layer.shadowPath = UIBezierPath(roundedRect: card.bounds,
                                                 cornerRadius: card.bounds.width * 0.105).cgPath
            card.layer.shadowOffset = CGSize(width: 0, height: 1.2)
            card.layer.shadowRadius = 1.6
            card.transform = Self.rest(seat)
            addSubview(card)
        }
        addSubview(word)
        applyShadows()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: TokiyoLogoView, _: UITraitCollection) in
            view.applyShadows()
        }

        isAccessibilityElement = true
        accessibilityLabel = "Tokiyo Cards"
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: Self.fanWidth + Self.wordSize.width, height: Self.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let midY = bounds.midY
        for (card, seat) in zip(cards, Self.seats) {
            card.center = CGPoint(x: Self.fanWidth / 2 + (seat.x - 512) * Self.unit,
                                  y: midY + (seat.y - 386) * Self.unit)
        }
        word.bounds.size = Self.wordSize
        word.center = CGPoint(x: Self.fanWidth + Self.wordSize.width / 2, y: midY + 1)
    }

    private func applyShadows() {
        let dark = traitCollection.userInterfaceStyle == .dark
        let color = dark ? UIColor.black : UIColor(red: 112 / 255, green: 70 / 255, blue: 28 / 255, alpha: 1)
        for card in cards {
            card.layer.shadowColor = color.cgColor
            card.layer.shadowOpacity = dark ? 0.6 : 0.3
        }
    }

    // MARK: The secret

    @objc private func tapped() {
        let now = CACurrentMediaTime()
        streak = now - lastTap < 0.6 ? streak + 1 : 1
        lastTap = now
        if streak >= 5 {
            streak = 0
            riffle()
        } else {
            fan()
        }
    }

    /// The hand opens a little wider, the K lifts, then everything settles.
    private func fan() {
        GameAudio.shared.play(.flip, volume: 0.5)
        GameHaptics.shared.play(.select)
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        UIView.animate(withDuration: 0.14, delay: 0,
                       options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]) {
            for (card, seat) in zip(self.cards, Self.seats) {
                card.transform = CGAffineTransform(translationX: seat.swing * 3, y: seat.swing == 0 ? -3 : -1)
                    .rotated(by: Self.radians(seat.angle + seat.swing * 9))
            }
            self.word.transform = CGAffineTransform(translationX: 0, y: -2)
        } completion: { _ in
            self.settle(damping: 0.55)
        }
    }

    /// Five quick taps: the cards gather under the K, then fly back out a
    /// touch too far and settle — a flick for each card as it goes.
    private func riffle() {
        GameHaptics.shared.play(.select)
        guard !UIAccessibility.isReduceMotionEnabled else {
            flickOut()
            return
        }
        let king = Self.seats[2]
        UIView.animate(withDuration: 0.2, delay: 0,
                       options: [.curveEaseIn, .beginFromCurrentState, .allowUserInteraction]) {
            for (card, seat) in zip(self.cards, Self.seats) {
                card.transform = CGAffineTransform(translationX: (king.x - seat.x) * Self.unit,
                                                   y: (king.y - seat.y) * Self.unit - 2)
            }
            self.word.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
        } completion: { _ in
            self.flickOut()
            self.settle(damping: 0.42)
        }
    }

    private func flickOut() {
        for (i, pitch) in [Float(1), 1.05, 1.1].enumerated() {
            GameAudio.shared.play(.flip, volume: 0.4, pitch: pitch, delay: Double(i) * 0.06)
        }
    }

    private func settle(damping: CGFloat) {
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: damping, initialSpringVelocity: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction]) {
            for (card, seat) in zip(self.cards, Self.seats) { card.transform = Self.rest(seat) }
            self.word.transform = .identity
        }
    }

    private static func rest(_ seat: Seat) -> CGAffineTransform {
        CGAffineTransform(rotationAngle: radians(seat.angle))
    }

    private static func radians(_ degrees: CGFloat) -> CGFloat { degrees * .pi / 180 }
}
