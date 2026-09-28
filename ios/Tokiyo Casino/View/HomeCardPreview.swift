import UIKit

/// Foreground cards above the portrait. A fixed-width logical canvas lets the
/// real table effects keep their geometry while fitting inside the artwork.
final class HomeCardPreview: UIView {
    enum Kind { case firstCut, royalFlush }
    let kind: Kind
    private let canvas = UIView()
    private let stage = UIView()
    private let overlay = UIView()
    private let edgeMask = CAGradientLayer()
    private var cutEffects: TDPMomentEffects?
    private var pokerEffects: PokerMomentEffects?
    private var cutCards: [TDPCardButton] = []
    private var pokerCards: [CardView] = []
    private var generation = 0
    private(set) var isPlaying = false
    private let trump = Card(suit: .hearts, rank: .jack)

    init(kind: Kind) {
        self.kind = kind
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        clipsToBounds = true
        edgeMask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor]
        edgeMask.locations = [0, 0.10, 1]
        edgeMask.startPoint = CGPoint(x: 0, y: 0.5)
        edgeMask.endPoint = CGPoint(x: 1, y: 0.5)
        layer.mask = edgeMask
        addSubview(canvas)
        canvas.addSubview(stage)
        canvas.addSubview(overlay)
        stage.isUserInteractionEnabled = false
        overlay.isUserInteractionEnabled = false
        switch kind {
        case .firstCut:
            cutCards = [Card(suit: .spades, rank: .king), Card(suit: .spades, rank: .ten), trump].map {
                let card = TDPCardButton(card: $0, elevation: .table, design: .minimal)
                card.isUserInteractionEnabled = false
                stage.addSubview(card)
                return card
            }
            cutCards.last?.isHidden = true
        case .royalFlush:
            pokerCards = [Rank.ten, .jack, .queen, .king, .ace].map { rank in
                let card = CardView()
                card.design = .minimal
                card.style = .hero
                card.setCard(Card(suit: .spades, rank: rank), faceUp: rank != .queen)
                card.isUserInteractionEnabled = false
                stage.addSubview(card)
                return card
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        edgeMask.frame = bounds
        CATransaction.commit()
        guard bounds.width > 0, !isPlaying else { return }
        let scale = bounds.width / 320
        canvas.bounds = CGRect(x: 0, y: 0, width: 320, height: bounds.height / scale)
        canvas.center = CGPoint(x: bounds.midX, y: bounds.midY)
        canvas.transform = CGAffineTransform(scaleX: scale, y: scale)
        stage.frame = canvas.bounds
        overlay.frame = canvas.bounds
        let floor = canvas.bounds.height - 82
        for (index, card) in cutCards.enumerated() {
            card.bounds = CGRect(x: 0, y: 0, width: 84, height: 120)
            card.center = CGPoint(x: [108, 188, 161][index], y: floor + [0, 5, -8][index])
            card.transform = CGAffineTransform(rotationAngle: [-0.22, 0.20, -0.04][index])
            card.layoutIfNeeded()
        }
        for (index, card) in pokerCards.enumerated() {
            if index < 3 {
                // The flop sits higher and a little left of the player's hand.
                card.bounds = CGRect(x: 0, y: 0, width: 57, height: 81)
                card.center = CGPoint(x: 94 + CGFloat(index) * 62,
                                      y: canvas.bounds.height - 132 - CGFloat(index) * 5)
                card.transform = CGAffineTransform(rotationAngle: -0.15 + CGFloat(index) * 0.05)
            } else {
                // Two larger hole cards in the foreground; keep the face clear.
                card.bounds = CGRect(x: 0, y: 0, width: 73, height: 104)
                card.center = CGPoint(x: index == 3 ? 152 : 217,
                                      y: canvas.bounds.height - (index == 3 ? 61 : 57))
                card.transform = CGAffineTransform(rotationAngle: index == 3 ? -0.20 : 0.13)
            }
            card.layoutIfNeeded()
        }
    }

    /// Completes once, after about a second. Reduced Motion retains a brief
    /// face reveal and skips the throw, shake, flash, and particle sequence.
    func play(completion: @escaping () -> Void) {
        guard !isPlaying else { return }
        layoutIfNeeded()
        isPlaying = true
        generation += 1
        let token = generation
        let finish = { [weak self] in
            guard let self, self.generation == token, self.isPlaying else { return }
            self.isPlaying = false
            completion()
        }
        if UIAccessibility.isReduceMotionEnabled || isHidden {
            cutCards.last?.isHidden = false
            pokerCards.dropFirst(2).first?.forceShowCard()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: finish)
            return
        }
        switch kind {
        case .firstCut:
            guard let card = cutCards.last else { finish(); return }
            card.isHidden = false
            let effects = TDPMomentEffects(stage: stage, overlay: overlay, compact: true)
            cutEffects = effects
            effects.previewCut(card, card: trump, trump: .hearts, completion: finish)
        case .royalFlush:
            guard let flopCard = pokerCards.dropFirst(2).first else { finish(); return }
            GameAudio.shared.play(.flip)
            UIView.transition(with: flopCard, duration: 0.16, options: .transitionFlipFromLeft) {
                flopCard.forceShowCard()
            } completion: { [weak self] _ in
                guard let self, self.generation == token else { return }
                let effects = PokerMomentEffects(previewStage: self.stage, overlay: self.overlay)
                self.pokerEffects = effects
                effects.previewRoyalFlush(self.pokerCards, completion: finish)
            }
        }
    }

    func reset() {
        generation += 1
        isPlaying = false
        cutEffects?.cancel()
        pokerEffects?.cancel()
        cutEffects = nil
        pokerEffects = nil
        stage.layer.removeAllAnimations()
        for card in stage.subviews {
            card.layer.removeAllAnimations()
            card.layer.mask = nil
            card.alpha = 1
        }
        cutCards.last?.isHidden = true
        if let flopCard = pokerCards.dropFirst(2).first, let card = flopCard.card {
            flopCard.setCard(card, faceUp: false)
        }
        setNeedsLayout()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { reset() }
    }
}
