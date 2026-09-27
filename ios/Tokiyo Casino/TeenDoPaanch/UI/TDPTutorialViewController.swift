//
//  TDPTutorialViewController.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  How to play, shown rather than told: eight short scenes built from the
//  table's own cards, chips and avatars, one idea each. Four of them answer
//  back — tap the card the rule asks for and the scene says whether it's
//  right.
//

import UIKit

// MARK: - Screen

final class TDPTutorialViewController: UIViewController, UIScrollViewDelegate {

    private let scenes: [TDPTutorialScene] = [
        TDPDeckScene(), TDPTargetsScene(), TDPTrumpCallScene(), TDPFollowSuitScene(),
        TDPTrumpItScene(), TDPScoringScene(), TDPPullScene(), TDPGiveUpScene()
    ]
    private lazy var progress = TDPTutorialProgress(count: scenes.count)
    private let scroll = UIScrollView()
    private let backButton = TDPButton(title: "Back", style: .secondary)
    private let nextButton = TDPButton(title: "Next", style: .primary)
    private var page = 0
    private var laidOutWidth: CGFloat = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = TDPTheme.page
        title = "How to play"
        navigationItem.largeTitleDisplayMode = .never

        scroll.isPagingEnabled = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.delegate = self
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let pages = UIStackView(arrangedSubviews: scenes.map { TDPTutorialPage(scene: $0) })
        pages.axis = .horizontal
        pages.distribution = .fillEqually
        pages.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(pages)

        backButton.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(didTapNext), for: .touchUpInside)
        let buttons = UIStackView(arrangedSubviews: [backButton, nextButton])
        buttons.spacing = 10
        buttons.distribution = .fillEqually
        buttons.translatesAutoresizingMaskIntoConstraints = false

        [progress, scroll, buttons].forEach { view.addSubview($0) }
        let safe = view.safeAreaLayoutGuide
        let wide = buttons.widthAnchor.constraint(equalTo: safe.widthAnchor, constant: -40)
        wide.priority = .defaultHigh
        NSLayoutConstraint.activate([
            progress.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            progress.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progress.widthAnchor.constraint(equalTo: buttons.widthAnchor),

            scroll.topAnchor.constraint(equalTo: progress.bottomAnchor, constant: 18),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: buttons.topAnchor, constant: -14),

            pages.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            pages.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            pages.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            pages.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            pages.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
            pages.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor,
                                         multiplier: CGFloat(scenes.count)),

            buttons.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttons.widthAnchor.constraint(lessThanOrEqualToConstant: 520),
            buttons.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -12),
            wide
        ])
        land(on: 0)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Rotation or a split-view resize: stay on the same page.
        let width = scroll.bounds.width
        guard width > 0, width != laidOutWidth else { return }
        laidOutWidth = width
        scroll.contentOffset = CGPoint(x: CGFloat(page) * width, y: 0)
    }

    // MARK: Paging

    private func land(on index: Int) {
        let changed = index != page
        page = max(0, min(index, scenes.count - 1))
        if changed { scenes[page].reset() }
        progress.set(page)
        backButton.isEnabled = page > 0
        nextButton.setTitle(page == scenes.count - 1 ? "Let's play" : "Next", for: .normal)
    }

    private func go(to index: Int) {
        let width = scroll.bounds.width
        guard width > 0 else { return }
        land(on: index)
        scroll.setContentOffset(CGPoint(x: CGFloat(page) * width, y: 0), animated: true)
    }

    private func pageUnderScroll() -> Int {
        Int((scroll.contentOffset.x / max(scroll.bounds.width, 1)).rounded())
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { land(on: pageUnderScroll()) }

    @objc private func didTapBack() { go(to: page - 1) }

    @objc private func didTapNext() {
        guard page < scenes.count - 1 else {
            navigationController?.popViewController(animated: true)
            return
        }
        go(to: page + 1)
    }
}

// MARK: - Page

/// One scene on its stage, with a title and a single line beneath.
private final class TDPTutorialPage: UIView {

    init(scene: TDPTutorialScene) {
        super.init(frame: .zero)

        let stage = TDPTutorialStage()
        scene.translatesAutoresizingMaskIntoConstraints = false
        stage.addSubview(scene)

        let titleLabel = UILabel()
        titleLabel.text = scene.title
        titleLabel.font = TDPTheme.font(24, .semibold)
        titleLabel.textColor = TDPTheme.ink
        titleLabel.numberOfLines = 0

        let bodyLabel = UILabel()
        bodyLabel.text = scene.body
        bodyLabel.font = TDPTheme.font(15)
        bodyLabel.textColor = TDPTheme.muted
        bodyLabel.numberOfLines = 0

        for label in [titleLabel, bodyLabel] {
            label.setContentCompressionResistancePriority(.required, for: .vertical)
        }

        let column = UIStackView(arrangedSubviews: [stage, titleLabel, bodyLabel])
        column.axis = .vertical
        column.spacing = 8
        column.setCustomSpacing(22, after: stage)
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)

        // The stage grows with the screen; on a small phone it gives way to
        // the words, which never truncate.
        let roomy = stage.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.7)
        roomy.priority = .defaultHigh
        let wide = column.widthAnchor.constraint(equalTo: widthAnchor, constant: -40)
        wide.priority = .defaultHigh

        NSLayoutConstraint.activate([
            column.topAnchor.constraint(equalTo: topAnchor),
            column.centerXAnchor.constraint(equalTo: centerXAnchor),
            column.widthAnchor.constraint(lessThanOrEqualToConstant: 520),
            wide,
            column.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
            roomy,
            stage.heightAnchor.constraint(lessThanOrEqualToConstant: 460 * TDPTheme.scale),
            stage.heightAnchor.constraint(greaterThanOrEqualToConstant: 240),
            scene.topAnchor.constraint(equalTo: stage.topAnchor),
            scene.bottomAnchor.constraint(equalTo: stage.bottomAnchor),
            scene.leadingAnchor.constraint(equalTo: stage.leadingAnchor),
            scene.trailingAnchor.constraint(equalTo: stage.trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
}

/// The raised panel a scene plays out on.
private final class TDPTutorialStage: UIView {

    init() {
        super.init(frame: .zero)
        backgroundColor = TDPTheme.raised
        layer.cornerRadius = 26 * TDPTheme.scale
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        applyTheme()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (stage: TDPTutorialStage, _: UITraitCollection) in
            stage.applyTheme()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func applyTheme() {
        layer.borderColor = TDPTheme.hairline.resolvedColor(with: traitCollection).cgColor
    }
}

/// One capsule per scene; the ones you've seen are filled.
private final class TDPTutorialProgress: UIView {

    private let segments: [UIView]

    init(count: Int) {
        segments = (0..<count).map { _ in UIView() }
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let row = UIStackView(arrangedSubviews: segments)
        row.spacing = 6
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        segments.forEach { $0.layer.cornerRadius = 2 }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 4),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        accessibilityTraits = .updatesFrequently
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func set(_ index: Int) {
        UIView.animate(withDuration: 0.2) {
            for (i, segment) in self.segments.enumerated() {
                segment.backgroundColor = i <= index ? TDPTheme.accent : TDPTheme.slot
            }
        }
        accessibilityLabel = "Step \(index + 1) of \(segments.count)"
    }
}

// MARK: - Feedback pill

/// The line under a "try it" scene: what to do, then right or wrong.
final class TDPTutorialPill: UILabel {

    enum Tone { case ask, good, bad }

    override init(frame: CGRect) {
        super.init(frame: frame)
        font = TDPTheme.font(13, .semibold)
        textAlignment = .center
        adjustsFontSizeToFitWidth = true
        minimumScaleFactor = 0.8
        clipsToBounds = true
        layer.cornerCurve = .continuous
        say("", .ask)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func say(_ message: String, _ tone: Tone, animated: Bool = false) {
        let apply = {
            self.text = message
            switch tone {
            case .ask:
                self.textColor = TDPTheme.inkSoft
                self.backgroundColor = TDPTheme.raisedAlt
            case .good:
                self.textColor = TDPTheme.accent
                self.backgroundColor = TDPTheme.accentWash
            case .bad:
                self.textColor = TDPTheme.warn
                self.backgroundColor = TDPTheme.warn.withAlphaComponent(0.12)
            }
        }
        if animated {
            UIView.transition(with: self, duration: 0.2, options: .transitionCrossDissolve, animations: apply)
        } else {
            apply()
        }
        superview?.setNeedsLayout()
        accessibilityLabel = message
    }

    override var intrinsicContentSize: CGSize {
        let base = super.intrinsicContentSize
        return CGSize(width: base.width + 28, height: 34 * TDPTheme.scale)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.insetBy(dx: 14, dy: 0))
    }
}

// MARK: - Scene base

/// A scene lays its cards out by hand in `layoutSubviews`, from its own
/// state, so an animation is just "change the state, lay out again".
class TDPTutorialScene: UIView {

    let title: String
    let body: String
    let pill = TDPTutorialPill()

    init(title: String, body: String) {
        self.title = title
        self.body = body
        super.init(frame: .zero)
        pill.isHidden = true
        addSubview(pill)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Back to the opening state, each time the page comes into view.
    func reset() {}

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = pill.intrinsicContentSize
        let width = min(size.width, bounds.width - 24)
        pill.bounds = CGRect(x: 0, y: 0, width: width, height: size.height)
        pill.center = CGPoint(x: bounds.midX, y: bounds.maxY - 16 * TDPTheme.scale - size.height / 2)
        bringSubviewToFront(pill)
    }

    // MARK: Helpers

    func makeCard(_ id: String?, faceDown: Bool = false) -> TDPCardButton {
        let view = TDPCardButton(card: id.flatMap(Card.init(tdpID:)), faceDown: faceDown, elevation: .hand)
        view.isUserInteractionEnabled = false
        addSubview(view)
        return view
    }

    /// A card `width` wide at the table's 70 × 100 proportions.
    func cardSize(_ width: CGFloat) -> CGSize { CGSize(width: width, height: width * 100 / 70) }

    func place(_ view: UIView, size: CGSize, center: CGPoint, degrees: CGFloat = 0) {
        view.transform = .identity
        view.bounds = CGRect(origin: .zero, size: size)
        view.center = center
        view.transform = CGAffineTransform(rotationAngle: degrees * .pi / 180)
    }

    /// Spreads `count` cards evenly around `centerX`.
    func spread(_ count: Int, width: CGFloat, step: CGFloat, centerX: CGFloat) -> [CGFloat] {
        let total: CGFloat = width + step * CGFloat(max(count - 1, 0))
        let first: CGFloat = centerX - total / 2 + width / 2
        return (0..<count).map { (index: Int) -> CGFloat in first + CGFloat(index) * step }
    }

    func relayout(animated: Bool) {
        setNeedsLayout()
        guard animated else { layoutIfNeeded(); return }
        UIView.animate(withDuration: 0.38, delay: 0, usingSpringWithDamping: 0.84,
                       initialSpringVelocity: 0.2, options: [.beginFromCurrentState]) {
            self.layoutIfNeeded()
        }
    }

    func shake(_ view: UIView) {
        let shake = CAKeyframeAnimation(keyPath: "position.x")
        shake.values = [0, -9, 9, -6, 6, -2, 0]
        shake.isAdditive = true
        shake.duration = 0.4
        view.layer.add(shake, forKey: "shake")
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    func caption(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = TDPTheme.font(12, .medium)
        label.textColor = TDPTheme.muted
        label.textAlignment = .center
        addSubview(label)
        return label
    }

    func name(_ card: Card) -> String { card.rank.shortString + TDPFormat.symbol(card.suit) }
}

// MARK: - 1 · The deck

final class TDPDeckScene: TDPTutorialScene {

    private var ladder: [TDPCardButton] = []
    private var sevens: [TDPCardButton] = []
    private let ladderChip = TDPChipLabel()
    private let sevensChip = TDPChipLabel()

    init() {
        super.init(title: "30 cards",
                   body: "8 up to Ace in every suit, plus the 7\u{2665}\u{FE0E} and 7\u{2660}\u{FE0E}. Ace is high.")
        ladder = ["8S", "9S", "10S", "JS", "QS", "KS", "AS"].map { makeCard($0) }
        sevens = ["7H", "7S"].map { makeCard($0) }
        ladderChip.text = "8 \u{2192} A  in all four suits"
        sevensChip.text = "the only two 7s"
        [ladderChip, sevensChip].forEach { addSubview($0) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width, h = bounds.height
        let cw = min(58 * TDPTheme.scale, w * 0.16)
        let size = cardSize(cw)

        let step = min(cw * 0.66, (w - 48 - cw) / 6)
        let y1 = h * 0.30
        for (i, (view, x)) in zip(ladder, spread(7, width: cw, step: step, centerX: w / 2)).enumerated() {
            let offset = CGFloat(i) - 3
            place(view, size: size, center: CGPoint(x: x, y: y1 + abs(offset) * 3), degrees: offset * 3.5)
        }
        let chip1 = ladderChip.intrinsicContentSize
        ladderChip.frame = CGRect(x: (w - chip1.width) / 2, y: y1 + size.height / 2 + 22,
                                  width: chip1.width, height: chip1.height)

        let y2 = h * 0.76
        let chip2 = sevensChip.intrinsicContentSize
        let group = cw * 2 + 8 + 14 + chip2.width
        let left = (w - group) / 2
        place(sevens[0], size: size, center: CGPoint(x: left + cw / 2, y: y2), degrees: -4)
        place(sevens[1], size: size, center: CGPoint(x: left + cw * 1.5 + 8, y: y2), degrees: 4)
        sevensChip.frame = CGRect(x: left + cw * 2 + 22, y: y2 - chip2.height / 2,
                                  width: chip2.width, height: chip2.height)
    }
}

// MARK: - 2 · Targets

final class TDPTargetsScene: TDPTutorialScene {

    private let ring = CAShapeLayer()
    private let middle = UILabel()
    private let you = TDPSeatTag(name: "You", target: 5, role: "calls trump", tint: .green)
    private let left = TDPSeatTag(name: "Meera", target: 3, role: "next player", tint: .amber)
    private let right = TDPSeatTag(name: "Rohan", target: 2, role: "dealer", tint: .blue)

    init() {
        super.init(title: "5 · 3 · 2",
                   body: "Each seat has a target: 5 for the trump caller, 3 for the next player, 2 for the dealer. Seats rotate every round.")
        ring.fillColor = UIColor.clear.cgColor
        ring.lineWidth = 1
        layer.insertSublayer(ring, at: 0)
        let text = NSMutableAttributedString(string: "10 tricks\n",
                                             attributes: [.font: TDPTheme.font(17, .semibold),
                                                          .foregroundColor: TDPTheme.ink])
        text.append(NSAttributedString(string: "5 + 3 + 2 = 10",
                                       attributes: [.font: TDPTheme.mono(12),
                                                    .foregroundColor: TDPTheme.muted]))
        middle.attributedText = text
        middle.numberOfLines = 2
        middle.textAlignment = .center
        [middle, you, left, right].forEach { addSubview($0) }
        applyTheme()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (scene: TDPTargetsScene, _: UITraitCollection) in
            scene.applyTheme()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func applyTheme() {
        ring.strokeColor = TDPTheme.hairline.resolvedColor(with: traitCollection).cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width, h = bounds.height
        let c = CGPoint(x: w / 2, y: h * 0.47)
        let radius = min(w, h) * 0.28
        ring.frame = bounds
        ring.path = UIBezierPath(arcCenter: c, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: true).cgPath
        middle.sizeToFit()
        middle.center = c

        for (tag, point) in [(left, CGPoint(x: w * 0.26, y: h * 0.15)),
                             (right, CGPoint(x: w * 0.74, y: h * 0.15)),
                             (you, CGPoint(x: w * 0.5, y: h * 0.84))] {
            let size = tag.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            tag.bounds = CGRect(origin: .zero, size: size)
            tag.center = point
        }
    }
}

/// Avatar, a big target number, and who they are.
private final class TDPSeatTag: UIView {

    init(name: String, target: Int, role: String, tint: TDPTheme.Tint) {
        super.init(frame: .zero)
        backgroundColor = TDPTheme.raised       // hides the ring behind it
        let avatar = TDPAvatarView(side: 40, radius: 14)
        avatar.setName(name)
        avatar.tint = tint
        let number = UILabel()
        number.text = "\(target)"
        number.font = TDPTheme.mono(28, .semibold)
        number.textColor = TDPTheme.ink
        let who = UILabel()
        who.text = "\(name) · \(role)"
        who.font = TDPTheme.font(11, .medium)
        who.textColor = TDPTheme.muted
        let text = UIStackView(arrangedSubviews: [number, who])
        text.axis = .vertical
        text.spacing = -2
        let row = UIStackView(arrangedSubviews: [avatar, text])
        row.spacing = 10
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4)
        ])
        isAccessibilityElement = true
        accessibilityLabel = "\(name), \(role), needs \(target) tricks"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
}

// MARK: - 3 · Calling trump

final class TDPTrumpCallScene: TDPTutorialScene {

    private let five = ["AS", "KS", "9S", "QH", "8D"]
    private var cards: [TDPCardButton] = []
    private let suitRow = UIStackView()
    private var suitButtons: [TDPSuitButton] = []
    private let later = UILabel()
    private var chosen: Suit?

    init() {
        super.init(title: "Call trump",
                   body: "The trump caller sees five cards and names trump. The other five arrive after.")
        cards = five.map { makeCard($0) }
        suitRow.spacing = 8
        suitRow.distribution = .fillEqually
        addSubview(suitRow)
        for suit in [Suit.spades, .hearts, .diamonds, .clubs] {
            let button = TDPSuitButton(suit: suit)
            button.addTarget(self, action: #selector(didPick(_:)), for: .touchUpInside)
            suitRow.addArrangedSubview(button)
            suitButtons.append(button)
        }
        later.text = "Your first five"
        later.font = TDPTheme.font(12, .medium)
        later.textColor = TDPTheme.muted
        later.textAlignment = .center
        addSubview(later)
        pill.isHidden = false
        reset()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func reset() {
        chosen = nil
        cards.forEach { $0.setPlayable(true, dimmed: false) }
        suitButtons.forEach { $0.backgroundColor = TDPTheme.raisedAlt }
        pill.say("Tap a suit to call it", .ask)
        relayout(animated: false)
    }

    @objc private func didPick(_ sender: TDPSuitButton) {
        chosen = sender.suit
        UISelectionFeedbackGenerator().selectionChanged()
        suitButtons.forEach { $0.backgroundColor = $0 === sender ? TDPTheme.accentWash : TDPTheme.raisedAlt }
        for view in cards { view.setPlayable(true, dimmed: view.card?.suit != sender.suit) }
        let held = five.compactMap(Card.init(tdpID:)).filter { $0.suit == sender.suit }.count
        let glyph = TDPFormat.symbol(sender.suit)
        switch held {
        case 3...: pill.say("Strong — three \(glyph), ace and king", .good, animated: true)
        case 0:    pill.say("Risky — you hold no \(glyph)", .bad, animated: true)
        default:   pill.say("Legal, but only one \(glyph) in hand", .ask, animated: true)
        }
        relayout(animated: true)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width, h = bounds.height
        let cw = min(56 * TDPTheme.scale, (w - 64) / 5)
        let size = cardSize(cw)
        let y = h * 0.30
        for (view, x) in zip(cards, spread(5, width: cw, step: cw + 6, centerX: w / 2)) {
            let lift: CGFloat = chosen != nil && view.card?.suit == chosen ? -10 : 0
            place(view, size: size, center: CGPoint(x: x, y: y + lift))
        }
        later.sizeToFit()
        later.center = CGPoint(x: w / 2, y: y - size.height / 2 - 18)

        let rowWidth = min(w - 40, 300 * TDPTheme.scale)
        let rowHeight = 56 * TDPTheme.scale
        suitRow.frame = CGRect(x: (w - rowWidth) / 2, y: h * 0.62 - rowHeight / 2, width: rowWidth, height: rowHeight)
    }
}

// MARK: - 4 · Follow suit

final class TDPFollowSuitScene: TDPTutorialScene {

    private let led = "KH"
    private let answer = "9H"
    private var ledCard: TDPCardButton!
    private var hand: [TDPCardButton] = []
    private let slot = TDPDashedSlotView()
    private var ledCaption: UILabel!
    private var played = false

    init() {
        super.init(title: "Follow suit",
                   body: "If you hold the suit that was led, you must play it.")
        ledCard = makeCard(led)
        ledCaption = caption("Meera led")
        addSubview(slot)
        hand = ["AS", answer, "QD", "JC"].map { id in
            let view = makeCard(id)
            view.isUserInteractionEnabled = true
            view.addTarget(self, action: #selector(didTap(_:)), for: .touchUpInside)
            return view
        }
        pill.isHidden = false
        reset()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func reset() {
        played = false
        hand.forEach { $0.setPlayable(true, dimmed: false); $0.ringColor = nil }
        pill.say("Tap the card you must play", .ask)
        relayout(animated: false)
    }

    @objc private func didTap(_ sender: TDPCardButton) {
        guard !played, let card = sender.card else { return }
        guard card.tdpID == answer else {
            shake(sender)
            pill.say("You have a \(TDPFormat.symbol(.hearts)) — it must be that", .bad, animated: true)
            return
        }
        played = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        hand.forEach { $0.setPlayable($0 === sender, dimmed: $0 !== sender) }
        sender.isEnabled = false
        pill.say("Right — hearts were led, so a heart it is", .good, animated: true)
        relayout(animated: true)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width, h = bounds.height
        let tableSize = cardSize(min(64 * TDPTheme.scale, w * 0.18))
        let ledPoint = CGPoint(x: w * 0.40, y: h * 0.27)
        let mine = CGPoint(x: w * 0.60, y: h * 0.29)
        place(ledCard, size: tableSize, center: ledPoint, degrees: -7)
        ledCaption.sizeToFit()
        ledCaption.center = CGPoint(x: ledPoint.x - 6, y: ledPoint.y - tableSize.height / 2 - 14)
        place(slot, size: tableSize, center: mine)
        slot.isHidden = played

        let cw = min(56 * TDPTheme.scale, w * 0.155)
        let size = cardSize(cw)
        let xs = spread(hand.count, width: cw, step: cw + 10, centerX: w / 2)
        for (i, view) in hand.enumerated() {
            if played && view.card?.tdpID == answer {
                place(view, size: tableSize, center: mine, degrees: 6)
                bringSubviewToFront(view)
            } else {
                let offset = CGFloat(i) - CGFloat(hand.count - 1) / 2
                let lift: CGFloat = played ? 0 : -6
                place(view, size: size, center: CGPoint(x: xs[i], y: h * 0.66 + abs(offset) * 3 + lift),
                      degrees: offset * 4)
            }
        }
    }
}

// MARK: - 5 · Trump it

final class TDPTrumpItScene: TDPTutorialScene {

    private let answer = "8S"
    private let trump = TDPTrumpPill()
    private var ledCard: TDPCardButton!
    private var secondCard: TDPCardButton!
    private var ledCaption: UILabel!
    private let slot = TDPDashedSlotView()
    private var hand: [TDPCardButton] = []
    private var played = false

    init() {
        super.init(title: "No suit? Trump it",
                   body: "Can't follow? Any trump beats every card of another suit — even a small one. Or throw anything away.")
        trump.configure(trump: .spades, detail: nil)
        addSubview(trump)
        ledCard = makeCard("AD")
        secondCard = makeCard("KD")
        ledCaption = caption("led")
        addSubview(slot)
        hand = ["AC", answer, "KH"].map { id in
            let view = makeCard(id)
            view.isUserInteractionEnabled = true
            view.addTarget(self, action: #selector(didTap(_:)), for: .touchUpInside)
            return view
        }
        NSLayoutConstraint.activate([
            trump.centerXAnchor.constraint(equalTo: centerXAnchor),
            trump.topAnchor.constraint(equalTo: topAnchor, constant: 16 * TDPTheme.scale)
        ])
        pill.isHidden = false
        reset()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func reset() {
        played = false
        hand.forEach { $0.setPlayable(true, dimmed: false); $0.ringColor = nil }
        pill.say("No diamonds in hand. Win the trick.", .ask)
        relayout(animated: false)
    }

    @objc private func didTap(_ sender: TDPCardButton) {
        guard !played, let card = sender.card else { return }
        guard card.tdpID == answer else {
            shake(sender)
            pill.say("\(name(card)) loses — only a trump beats A\(TDPFormat.symbol(.diamonds))", .bad, animated: true)
            return
        }
        played = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        hand.forEach { $0.setPlayable($0 === sender, dimmed: $0 !== sender) }
        sender.isEnabled = false
        sender.ringColor = TDPTheme.accent
        pill.say("8\(TDPFormat.symbol(.spades)) wins — a trump beats any diamond", .good, animated: true)
        relayout(animated: true)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width, h = bounds.height
        let tableSize = cardSize(min(60 * TDPTheme.scale, w * 0.165))
        let ledPoint = CGPoint(x: w * 0.34, y: h * 0.36)
        place(ledCard, size: tableSize, center: ledPoint, degrees: -9)
        place(secondCard, size: tableSize, center: CGPoint(x: w * 0.66, y: h * 0.36), degrees: 9)
        ledCaption.sizeToFit()
        ledCaption.center = CGPoint(x: ledPoint.x - 8, y: ledPoint.y - tableSize.height / 2 - 12)
        let mine = CGPoint(x: w * 0.5, y: h * 0.43)
        place(slot, size: tableSize, center: mine)
        slot.isHidden = played

        let cw = min(56 * TDPTheme.scale, w * 0.155)
        let size = cardSize(cw)
        let xs = spread(hand.count, width: cw, step: cw + 12, centerX: w / 2)
        for (i, view) in hand.enumerated() {
            if played && view.card?.tdpID == answer {
                place(view, size: tableSize, center: mine, degrees: -2)
                bringSubviewToFront(view)
            } else {
                let offset = CGFloat(i) - 1
                place(view, size: size, center: CGPoint(x: xs[i], y: h * 0.72 + abs(offset) * 3 - (played ? 0 : 6)),
                      degrees: offset * 5)
            }
        }
    }
}

// MARK: - 6 · Scoring

final class TDPScoringScene: TDPTutorialScene {

    private let column = UIStackView()

    init() {
        super.init(title: "Over or under",
                   body: "One point per trick. Beat your target and next round you pull cards from whoever fell short.")
        column.axis = .vertical
        column.spacing = 12
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)

        let rows: [(String, TDPTheme.Tint, Int, Int)] = [
            ("You", .green, 6, 5), ("Meera", .amber, 1, 3), ("Rohan", .blue, 3, 2)
        ]
        for row in rows { column.addArrangedSubview(scoreRow(name: row.0, tint: row.1, tricks: row.2, target: row.3)) }

        let divider = UIView()
        divider.backgroundColor = TDPTheme.hairline
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        column.addArrangedSubview(divider)
        column.setCustomSpacing(14, after: divider)

        let next = UILabel()
        next.attributedText = NSAttributedString(
            string: "NEXT ROUND",
            attributes: [.font: TDPTheme.font(11, .semibold), .kern: 0.9, .foregroundColor: TDPTheme.muted])
        column.addArrangedSubview(next)
        column.setCustomSpacing(8, after: next)
        column.addArrangedSubview(pullLine("You pull 1 card from Meera"))
        column.addArrangedSubview(pullLine("Rohan pulls 1 card from Meera"))

        let wide = column.widthAnchor.constraint(equalTo: widthAnchor, constant: -48)
        wide.priority = .defaultHigh
        NSLayoutConstraint.activate([
            column.centerXAnchor.constraint(equalTo: centerXAnchor),
            column.centerYAnchor.constraint(equalTo: centerYAnchor),
            column.widthAnchor.constraint(lessThanOrEqualToConstant: 320 * TDPTheme.scale),
            wide
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    private func scoreRow(name: String, tint: TDPTheme.Tint, tricks: Int, target: Int) -> UIView {
        let avatar = TDPAvatarView(side: 32, radius: 11)
        avatar.setName(name)
        avatar.tint = tint
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = TDPTheme.font(15, .medium)
        nameLabel.textColor = TDPTheme.ink

        let tally = UILabel()
        let text = NSMutableAttributedString(string: "\(tricks)",
                                             attributes: [.font: TDPTheme.mono(17, .semibold), .foregroundColor: TDPTheme.ink])
        text.append(NSAttributedString(string: " / \(target)",
                                       attributes: [.font: TDPTheme.mono(13), .foregroundColor: TDPTheme.muted]))
        tally.attributedText = text

        let delta = tricks - target
        let chip = TDPChipLabel()
        chip.text = TDPFormat.signed(delta)
        chip.textAlignment = .center
        chip.textColor = delta >= 0 ? TDPTheme.accent : TDPTheme.warn
        chip.backgroundColor = delta >= 0 ? TDPTheme.accentWash : TDPTheme.warn.withAlphaComponent(0.12)
        chip.widthAnchor.constraint(equalToConstant: 40 * TDPTheme.scale).isActive = true

        let row = UIStackView(arrangedSubviews: [avatar, nameLabel, UIView(), tally, chip])
        row.spacing = 12
        row.alignment = .center
        row.setCustomSpacing(10, after: tally)
        row.isAccessibilityElement = true
        row.accessibilityLabel = "\(name): \(tricks) tricks, target \(target), \(TDPFormat.signed(delta))"
        return row
    }

    private func pullLine(_ text: String) -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "arrow.turn.down.right"))
        icon.tintColor = TDPTheme.accent
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)
        let label = UILabel()
        label.text = text
        label.font = TDPTheme.font(14)
        label.textColor = TDPTheme.inkSoft
        let row = UIStackView(arrangedSubviews: [icon, label])
        row.spacing = 8
        row.alignment = .center
        return row
    }
}

// MARK: - 7 · Khichai

final class TDPPullScene: TDPTutorialScene {

    private enum Step { case pick, give, done }

    private let drawnID = "AS"
    private var step = Step.pick
    private var fan: [TDPCardButton] = []
    private var hand: [TDPCardButton] = []
    private var gap = 0
    private var fanCaption: UILabel!
    private var handCaption: UILabel!

    init() {
        super.init(title: "Khichai — the pull",
                   body: "Pull one card blind from whoever owes you, then hand back any card — even the one you pulled.")
        fanCaption = caption("Meera's hand")
        handCaption = caption("Your hand")
        pill.isHidden = false
        reset()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func reset() {
        (fan + hand).forEach { $0.removeFromSuperview() }
        step = .pick
        gap = 0
        fan = (0..<6).map { _ in
            let view = makeCard(nil, faceDown: true)
            view.isUserInteractionEnabled = true
            view.addTarget(self, action: #selector(didPull(_:)), for: .touchUpInside)
            return view
        }
        hand = ["9H", "JC", "8D", "10C"].map { interactiveHandCard($0) }
        hand.forEach { $0.setPlayable(false, dimmed: false) }
        pill.say("Meera owes you one — tap a card", .ask)
        relayout(animated: false)
    }

    private func interactiveHandCard(_ id: String) -> TDPCardButton {
        let view = makeCard(id)
        view.isUserInteractionEnabled = true
        view.addTarget(self, action: #selector(didGive(_:)), for: .touchUpInside)
        return view
    }

    /// Swaps `old` for `new` in place with a card flip.
    private func flip(_ old: TDPCardButton, to new: TDPCardButton, then: @escaping () -> Void) {
        new.transform = .identity
        new.bounds = old.bounds
        new.center = old.center
        new.transform = old.transform
        new.isHidden = true
        UIView.transition(from: old, to: new, duration: 0.32,
                          options: [.transitionFlipFromRight, .showHideTransitionViews]) { _ in
            old.removeFromSuperview()
            then()
        }
    }

    @objc private func didPull(_ sender: TDPCardButton) {
        guard step == .pick, let index = fan.firstIndex(where: { $0 === sender }) else { return }
        step = .give
        fan.forEach { $0.isEnabled = false }
        let drawn = interactiveHandCard(drawnID)
        drawn.ringColor = TDPTheme.accent
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        flip(sender, to: drawn) { [self] in
            fan.remove(at: index)
            gap = index
            hand.append(drawn)
            hand.forEach { $0.setPlayable(true, dimmed: false) }
            pill.say("You got A\(TDPFormat.symbol(.spades)) — now give any card back", .good, animated: true)
            relayout(animated: true)
        }
    }

    @objc private func didGive(_ sender: TDPCardButton) {
        guard step == .give, let index = hand.firstIndex(where: { $0 === sender }),
              let card = sender.card else { return }
        step = .done
        hand.forEach { $0.isEnabled = false }
        let back = makeCard(nil, faceDown: true)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        flip(sender, to: back) { [self] in
            hand.remove(at: index)
            fan.insert(back, at: min(gap, fan.count))
            hand.forEach { $0.setPlayable(false, dimmed: false) }
            let message = card.tdpID == drawnID
                ? "Done — even the pulled card can go back"
                : "Done — you keep the ace, Meera gets \(name(card))"
            pill.say(message, .good, animated: true)
            relayout(animated: true)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width, h = bounds.height

        let fw = min(46 * TDPTheme.scale, w * 0.13)
        let fanSize = cardSize(fw)
        let fanY = h * 0.25
        let fxs = spread(fan.count, width: fw, step: fw * 0.74, centerX: w / 2)
        for (i, view) in fan.enumerated() {
            let offset = CGFloat(i) - CGFloat(fan.count - 1) / 2
            let lift: CGFloat = step == .pick ? -4 : 0
            place(view, size: fanSize, center: CGPoint(x: fxs[i], y: fanY + abs(offset) * 2.5 + lift),
                  degrees: offset * 5)
        }
        fanCaption.sizeToFit()
        fanCaption.center = CGPoint(x: w / 2, y: fanY - fanSize.height / 2 - 16)

        let hw = min(52 * TDPTheme.scale, (w - 72) / 5)
        let handSize = cardSize(hw)
        let handY = h * 0.63
        let hxs = spread(hand.count, width: hw, step: hw + 6, centerX: w / 2)
        for (i, view) in hand.enumerated() {
            let offset = CGFloat(i) - CGFloat(hand.count - 1) / 2
            let lift: CGFloat = step == .give ? -6 : 0
            place(view, size: handSize, center: CGPoint(x: hxs[i], y: handY + abs(offset) * 2 + lift),
                  degrees: offset * 3)
        }
        handCaption.sizeToFit()
        handCaption.center = CGPoint(x: w / 2, y: handY - handSize.height / 2 - 16)
    }
}

// MARK: - 8 · Paying in tricks

final class TDPGiveUpScene: TDPTutorialScene {

    private let tricksTile = TDPTutorialTile(symbol: "flag.fill", title: "Give up 2 tricks", detail: "target 5 \u{2192} 7")
    private let cardsTile = TDPTutorialTile(symbol: "rectangle.portrait.on.rectangle.portrait.fill",
                                            title: "Give 2 cards", detail: "pulled blind")
    private let owe = UILabel()

    init() {
        super.init(title: "Or pay in tricks",
                   body: "Owe cards? You can raise your own target instead — just never to the same player two rounds running.")
        owe.text = "You owe Meera 2"
        owe.font = TDPTheme.font(17, .semibold)
        owe.textColor = TDPTheme.ink
        owe.textAlignment = .center

        let tiles = UIStackView(arrangedSubviews: [tricksTile, cardsTile])
        tiles.spacing = 10
        tiles.distribution = .fillEqually

        let lock = UIImageView(image: UIImage(systemName: "lock.fill"))
        lock.tintColor = TDPTheme.muted
        lock.contentMode = .scaleAspectFit
        let lockText = UILabel()
        lockText.text = "Not twice in a row to the same player"
        lockText.font = TDPTheme.font(12)
        lockText.textColor = TDPTheme.muted
        lockText.adjustsFontSizeToFitWidth = true
        lockText.minimumScaleFactor = 0.85
        let lockRow = UIStackView(arrangedSubviews: [lock, lockText])
        lockRow.spacing = 6
        lockRow.alignment = .center

        let column = UIStackView(arrangedSubviews: [owe, tiles, lockRow])
        column.axis = .vertical
        column.alignment = .center
        column.spacing = 16
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)

        for tile in [tricksTile, cardsTile] {
            tile.addTarget(self, action: #selector(didPick(_:)), for: .touchUpInside)
        }
        let wide = tiles.widthAnchor.constraint(equalTo: widthAnchor, constant: -32)
        wide.priority = .defaultHigh
        NSLayoutConstraint.activate([
            column.centerXAnchor.constraint(equalTo: centerXAnchor),
            column.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -22 * TDPTheme.scale),
            column.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -32),
            tiles.widthAnchor.constraint(lessThanOrEqualToConstant: 340 * TDPTheme.scale),
            wide,
            lock.widthAnchor.constraint(equalToConstant: 12),
            lock.heightAnchor.constraint(equalToConstant: 12)
        ])
        pill.isHidden = false
        reset()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func reset() {
        tricksTile.isSelected = false
        cardsTile.isSelected = false
        pill.say("Pick one", .ask)
    }

    @objc private func didPick(_ sender: TDPTutorialTile) {
        UISelectionFeedbackGenerator().selectionChanged()
        tricksTile.isSelected = sender === tricksTile
        cardsTile.isSelected = sender === cardsTile
        if sender === tricksTile {
            pill.say("No cards move — you need 7, Meera needs 1", .good, animated: true)
        } else {
            pill.say("Meera pulls 2 cards from your hand, blind", .good, animated: true)
        }
    }
}

/// A big square choice: icon, title, one short detail.
private final class TDPTutorialTile: UIControl {

    private let icon: UIImageView
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()

    init(symbol: String, title: String, detail: String) {
        icon = UIImageView(image: UIImage(systemName: symbol,
                                          withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)))
        super.init(frame: .zero)
        layer.cornerRadius = 18 * TDPTheme.scale
        layer.cornerCurve = .continuous
        layer.borderWidth = 1.5
        icon.contentMode = .scaleAspectFit
        titleLabel.text = title
        titleLabel.font = TDPTheme.font(15, .semibold)
        titleLabel.textColor = TDPTheme.ink
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8
        detailLabel.text = detail
        detailLabel.font = TDPTheme.mono(12)
        detailLabel.textColor = TDPTheme.muted
        let stack = UIStackView(arrangedSubviews: [icon, titleLabel, detailLabel])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.setCustomSpacing(14, after: icon)
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            icon.heightAnchor.constraint(equalToConstant: 24),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        ])
        accessibilityTraits = .button
        accessibilityLabel = "\(title), \(detail)"
        applyTheme()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (tile: TDPTutorialTile, _: UITraitCollection) in
            tile.applyTheme()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isSelected: Bool { didSet { applyTheme() } }
    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.8 : 1 } }

    private func applyTheme() {
        let traits = traitCollection
        backgroundColor = isSelected ? TDPTheme.accentWash : TDPTheme.raisedAlt
        layer.borderColor = (isSelected ? TDPTheme.accent : TDPTheme.hairline).resolvedColor(with: traits).cgColor
        icon.tintColor = isSelected ? TDPTheme.accent : TDPTheme.inkSoft
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}

// MARK: - Entry tile

/// "How to play" on the mode screen: a tiny fan and one line.
final class TDPTutorialEntryTile: UIControl {

    private let fanBox = TDPMiniFan(ids: ["QD", "KH", "AS"])

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = TDPTheme.raised
        layer.cornerRadius = 18 * TDPTheme.scale
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        accessibilityTraits = .button
        accessibilityLabel = "How to play. Eight short scenes."

        let title = UILabel()
        title.text = "How to play"
        title.font = TDPTheme.font(15, .semibold)
        title.textColor = TDPTheme.ink
        let detail = UILabel()
        detail.text = "8 short scenes, with cards"
        detail.font = TDPTheme.font(12)
        detail.textColor = TDPTheme.muted
        let text = UIStackView(arrangedSubviews: [title, detail])
        text.axis = .vertical
        text.spacing = 2

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right",
                                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)))
        chevron.tintColor = TDPTheme.muted
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [fanBox, text, chevron])
        row.spacing = 14
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            fanBox.widthAnchor.constraint(equalToConstant: 56),
            fanBox.heightAnchor.constraint(equalToConstant: 44),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
        applyTheme()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (tile: TDPTutorialEntryTile, _: UITraitCollection) in
            tile.applyTheme()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.75 : 1 } }

    private func applyTheme() {
        layer.borderColor = TDPTheme.hairline.resolvedColor(with: traitCollection).cgColor
    }
}

/// Three small cards, fanned.
private final class TDPMiniFan: UIView {

    private let cards: [TDPCardButton]

    init(ids: [String]) {
        cards = ids.compactMap(Card.init(tdpID:)).map { TDPCardButton(card: $0, elevation: .hand) }
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        cards.forEach { addSubview($0) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = CGSize(width: bounds.height * 0.6, height: bounds.height * 0.84)
        let middle = CGFloat(cards.count - 1) / 2
        for (i, card) in cards.enumerated() {
            let offset = CGFloat(i) - middle
            card.transform = .identity
            card.bounds = CGRect(origin: .zero, size: size)
            card.center = CGPoint(x: bounds.midX + offset * size.width * 0.45, y: bounds.midY + abs(offset) * 2)
            card.transform = CGAffineTransform(rotationAngle: offset * 12 * .pi / 180)
        }
    }
}
