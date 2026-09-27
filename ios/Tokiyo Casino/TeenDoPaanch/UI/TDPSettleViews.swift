//
//  TDPSettleViews.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  The settle-up flow from the "532 Khichai Flow" design canvas: the choice
//  between giving up tricks and giving cards, the arranging window, the
//  countdown, and the chips and banner that show a round's changed targets.
//

import UIKit

// MARK: - Option card (settle up, one creditor)

/// A large radio-style choice. Disabled means "locked this round" and shows
/// a lock in place of the radio.
final class TDPOptionCard: UIControl {

    private let radio = UIView()
    private let dot = UIView()
    private let lock = UIImageView(image: UIImage(systemName: "lock.fill"))
    private let titleLabel = UILabel()
    private let chipLabel = TDPChipLabel()
    private let bodyLabel = UILabel()

    init(title: String, chip: String?, body: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 16 * TDPTheme.scale
        layer.cornerCurve = .continuous
        layer.borderWidth = 1.5
        accessibilityTraits = .button
        accessibilityLabel = "\(title). \(body)"

        titleLabel.text = title
        titleLabel.font = TDPTheme.font(15, .semibold)
        titleLabel.textColor = TDPTheme.ink
        chipLabel.text = chip
        chipLabel.isHidden = chip == nil
        bodyLabel.text = body
        bodyLabel.font = TDPTheme.font(13)
        bodyLabel.textColor = TDPTheme.muted
        bodyLabel.numberOfLines = 0

        radio.layer.cornerRadius = 10
        radio.layer.borderWidth = 2
        radio.translatesAutoresizingMaskIntoConstraints = false
        dot.layer.cornerRadius = 5
        dot.translatesAutoresizingMaskIntoConstraints = false
        radio.addSubview(dot)
        lock.tintColor = TDPTheme.muted
        lock.contentMode = .scaleAspectFit
        lock.translatesAutoresizingMaskIntoConstraints = false
        lock.isHidden = true

        let marker = UIView()
        marker.translatesAutoresizingMaskIntoConstraints = false
        marker.addSubview(radio)
        marker.addSubview(lock)

        let top = UIStackView(arrangedSubviews: [titleLabel, UIView(), chipLabel])
        top.alignment = .center
        top.spacing = 8
        let text = UIStackView(arrangedSubviews: [top, bodyLabel])
        text.axis = .vertical
        text.spacing = 5
        let row = UIStackView(arrangedSubviews: [marker, text])
        row.alignment = .top
        row.spacing = 12
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            marker.widthAnchor.constraint(equalToConstant: 20),
            marker.heightAnchor.constraint(equalToConstant: 20),
            radio.topAnchor.constraint(equalTo: marker.topAnchor),
            radio.leadingAnchor.constraint(equalTo: marker.leadingAnchor),
            radio.widthAnchor.constraint(equalToConstant: 20),
            radio.heightAnchor.constraint(equalToConstant: 20),
            dot.centerXAnchor.constraint(equalTo: radio.centerXAnchor),
            dot.centerYAnchor.constraint(equalTo: radio.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 10),
            dot.heightAnchor.constraint(equalToConstant: 10),
            lock.topAnchor.constraint(equalTo: marker.topAnchor, constant: 1),
            lock.leadingAnchor.constraint(equalTo: marker.leadingAnchor, constant: 1),
            lock.widthAnchor.constraint(equalToConstant: 17),
            lock.heightAnchor.constraint(equalToConstant: 17),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14)
        ])
        applyTheme()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (card: TDPOptionCard, _: UITraitCollection) in
            card.applyTheme()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isSelected: Bool { didSet { applyTheme() } }
    override var isEnabled: Bool { didSet { applyTheme() } }
    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.8 : 1 } }

    private func applyTheme() {
        let traits = traitCollection
        let on = isSelected && isEnabled
        layer.borderColor = (on ? TDPTheme.accent : TDPTheme.hairline).resolvedColor(with: traits).cgColor
        backgroundColor = on ? TDPTheme.accentWash : (isEnabled ? TDPTheme.raised : TDPTheme.raisedAlt)
        radio.layer.borderColor = (on ? TDPTheme.accent : TDPTheme.slot).resolvedColor(with: traits).cgColor
        dot.backgroundColor = on ? TDPTheme.accent : .clear
        radio.isHidden = !isEnabled
        lock.isHidden = isEnabled
        titleLabel.textColor = isEnabled ? TDPTheme.ink : TDPTheme.muted
        accessibilityTraits = on ? [.button, .selected] : (isEnabled ? .button : [.button, .notEnabled])
    }
}

// MARK: - Two-way switch (settle up, several creditors)

final class TDPSegmentedChoice: UIControl {

    private let first = UIButton(type: .custom)
    private let second = UIButton(type: .custom)
    private(set) var selectedIndex = 0

    init(first firstTitle: String, second secondTitle: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = TDPTheme.raisedAlt
        layer.cornerRadius = 13
        layer.cornerCurve = .continuous
        for (button, title) in [(first, firstTitle), (second, secondTitle)] {
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = TDPTheme.font(13, .semibold)
            button.layer.cornerRadius = 10
            button.layer.cornerCurve = .continuous
            button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
        }
        let row = UIStackView(arrangedSubviews: [first, second])
        row.spacing = 3
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            first.heightAnchor.constraint(equalToConstant: 44)
        ])
        applyState()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Locks the first segment ("give up") for this round.
    var isFirstEnabled = true { didSet { first.isEnabled = isFirstEnabled; applyState() } }

    func select(_ index: Int) {
        selectedIndex = index
        applyState()
    }

    @objc private func tapped(_ sender: UIButton) {
        let index = sender === first ? 0 : 1
        guard index != selectedIndex else { return }
        select(index)
        sendActions(for: .valueChanged)
    }

    private func applyState() {
        for (index, button) in [first, second].enumerated() {
            let on = index == selectedIndex
            button.backgroundColor = on ? TDPTheme.raised : .clear
            button.setTitleColor(on ? TDPTheme.ink : TDPTheme.muted, for: .normal)
            button.setTitleColor(TDPTheme.muted.withAlphaComponent(0.5), for: .disabled)
            button.accessibilityTraits = on ? [.button, .selected] : .button
        }
    }
}

// MARK: - Chip

/// Small mono tag, e.g. "5 → 3" beside a changed target.
final class TDPChipLabel: UILabel {

    var isAccent = false {
        didSet {
            textColor = isAccent ? TDPTheme.accent : TDPTheme.inkSoft
            backgroundColor = isAccent ? TDPTheme.accentWash : TDPTheme.raisedAlt
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        font = TDPTheme.mono(11, .medium)
        textColor = TDPTheme.inkSoft
        backgroundColor = TDPTheme.raisedAlt
        layer.cornerRadius = 6
        layer.cornerCurve = .continuous
        clipsToBounds = true
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var intrinsicContentSize: CGSize {
        let base = super.intrinsicContentSize
        return text?.isEmpty ?? true ? .zero : CGSize(width: base.width + 12, height: base.height + 6)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.insetBy(dx: 6, dy: 3))
    }
}

// MARK: - Countdown ring

final class TDPCountdownView: UIView {

    private let track = CAShapeLayer()
    private let progress = CAShapeLayer()
    private let numberLabel = UILabel()
    private let unitLabel = UILabel()
    private var lastFraction: CGFloat = 1

    init(diameter: CGFloat) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        for ring in [track, progress] {
            ring.fillColor = UIColor.clear.cgColor
            ring.lineWidth = 3
            ring.lineCap = .round
            layer.addSublayer(ring)
        }
        numberLabel.font = TDPTheme.mono(diameter * 0.34, .medium)
        numberLabel.textColor = TDPTheme.ink
        unitLabel.attributedText = NSAttributedString(
            string: "SECONDS",
            attributes: [.font: TDPTheme.font(10, .medium), .kern: 0.9, .foregroundColor: TDPTheme.muted])
        let stack = UIStackView(arrangedSubviews: [numberLabel, unitLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: diameter),
            heightAnchor.constraint(equalToConstant: diameter),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        applyTheme()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: TDPCountdownView, _: UITraitCollection) in
            view.applyTheme()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath(arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
                                radius: bounds.width / 2 - 2,
                                startAngle: -.pi / 2, endAngle: 1.5 * .pi, clockwise: true).cgPath
        track.path = path
        progress.path = path
    }

    /// Drains smoothly toward the next whole second rather than jumping.
    func set(seconds: Int, of total: Int) {
        numberLabel.text = "\(max(0, seconds))"
        accessibilityLabel = "\(seconds) seconds left"
        let from = lastFraction
        let to = CGFloat(max(0, seconds - 1)) / CGFloat(max(1, total))
        let drain = CABasicAnimation(keyPath: "strokeEnd")
        drain.fromValue = from
        drain.toValue = to
        drain.duration = 1
        progress.strokeEnd = to
        progress.add(drain, forKey: "drain")
        lastFraction = to
    }

    func reset() { lastFraction = 1; progress.strokeEnd = 1 }

    private func applyTheme() {
        track.strokeColor = TDPTheme.hairline.resolvedColor(with: traitCollection).cgColor
        progress.strokeColor = TDPTheme.accent.resolvedColor(with: traitCollection).cgColor
    }
}

// MARK: - Arranging your cards

/// The debtor's 10 cards laid flat, two rows of five, reordered by
/// long-press-and-drag. The order is what the puller picks from, blind.
final class TDPArrangeView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    /// Sent on every change so the host always holds the latest order.
    var onReorder: (([String]) -> Void)?
    var onDone: (([String]) -> Void)?

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    let countdown = TDPCountdownView(diameter: 132 * TDPTheme.scale)
    private let hintLabel = UILabel()
    private let grid: UICollectionView
    private let shuffleButton = TDPButton(title: "Shuffle", style: .secondary)
    private let doneButton = TDPButton(title: "Done", style: .primary)

    private var cards: [Card] = []
    private var isDragging = false
    /// The order we last sent. Until the host echoes it back, an older
    /// order arriving on a countdown tick must not undo the player's move.
    private var awaitingEcho: [String]?

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 12
        grid = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = "Arrange your cards"
        titleLabel.font = TDPTheme.font(20, .semibold)
        titleLabel.textColor = TDPTheme.ink
        titleLabel.textAlignment = .center
        subtitleLabel.font = TDPTheme.font(13)
        subtitleLabel.textColor = TDPTheme.muted
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        hintLabel.text = "Hold and drag to move a card"
        hintLabel.font = TDPTheme.font(12)
        hintLabel.textColor = TDPTheme.muted
        hintLabel.textAlignment = .center

        grid.backgroundColor = .clear
        grid.clipsToBounds = false
        grid.isScrollEnabled = false
        grid.dataSource = self
        grid.delegate = self
        grid.register(TDPArrangeCell.self, forCellWithReuseIdentifier: TDPArrangeCell.reuseID)
        grid.translatesAutoresizingMaskIntoConstraints = false
        let press = UILongPressGestureRecognizer(target: self, action: #selector(handleDrag(_:)))
        press.minimumPressDuration = 0.12
        grid.addGestureRecognizer(press)

        shuffleButton.addTarget(self, action: #selector(didShuffle), for: .touchUpInside)
        doneButton.addTarget(self, action: #selector(didFinish), for: .touchUpInside)
        let buttons = UIStackView(arrangedSubviews: [shuffleButton, doneButton])
        buttons.spacing = 10
        buttons.distribution = .fillEqually

        let heading = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        heading.axis = .vertical
        heading.spacing = 5

        [heading, countdown, grid, hintLabel, buttons].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        let s = TDPTheme.scale
        let card = TDPTheme.handCard
        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            heading.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            heading.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

            countdown.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 16 * s),
            countdown.centerXAnchor.constraint(equalTo: centerXAnchor),

            grid.topAnchor.constraint(equalTo: countdown.bottomAnchor, constant: 22 * s),
            grid.centerXAnchor.constraint(equalTo: centerXAnchor),
            grid.widthAnchor.constraint(equalToConstant: card.width * 5 + 8 * 4),
            grid.heightAnchor.constraint(equalToConstant: card.height * 2 + 12),

            hintLabel.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 14),
            hintLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            hintLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

            buttons.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            buttons.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            buttons.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            buttons.topAnchor.constraint(greaterThanOrEqualTo: hintLabel.bottomAnchor, constant: 12)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: Updates

    func configure(cards incoming: [Card], puller: String, count: Int, seconds: Int?) {
        subtitleLabel.text = "\(puller) picks \(count), blind"
        if let seconds { countdown.set(seconds: seconds, of: 10) }

        let incomingIDs = incoming.map(\.tdpID)
        if let echo = awaitingEcho {
            if echo == incomingIDs { awaitingEcho = nil }
            return                                   // stale order on a tick
        }
        guard !isDragging, incomingIDs != cards.map(\.tdpID) else { return }
        cards = incoming
        grid.reloadData()
    }

    /// Dropped when the window closes so no face-up cards linger unseen.
    func clear() {
        cards = []
        awaitingEcho = nil
        grid.reloadData()
        countdown.reset()
    }

    private func sendOrder() {
        let ids = cards.map(\.tdpID)
        awaitingEcho = ids
        onReorder?(ids)
    }

    @objc private func didShuffle() {
        cards.shuffle()
        grid.performBatchUpdates({ grid.reloadSections(IndexSet(integer: 0)) })
        UISelectionFeedbackGenerator().selectionChanged()
        sendOrder()
    }

    @objc private func didFinish() {
        awaitingEcho = nil
        onDone?(cards.map(\.tdpID))
    }

    @objc private func handleDrag(_ gesture: UILongPressGestureRecognizer) {
        let point = gesture.location(in: grid)
        switch gesture.state {
        case .began:
            guard let path = grid.indexPathForItem(at: point) else { return }
            isDragging = grid.beginInteractiveMovementForItem(at: path)
            if isDragging { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        case .changed:
            grid.updateInteractiveMovementTargetPosition(point)
        case .ended:
            grid.endInteractiveMovement()
            isDragging = false
            sendOrder()
        default:
            grid.cancelInteractiveMovement()
            isDragging = false
        }
    }

    // MARK: Grid

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        cards.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TDPArrangeCell.reuseID, for: indexPath)
        (cell as? TDPArrangeCell)?.show(cards[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool { true }

    func collectionView(_ collectionView: UICollectionView, moveItemAt source: IndexPath, to destination: IndexPath) {
        let card = cards.remove(at: source.item)
        cards.insert(card, at: destination.item)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        TDPTheme.handCard
    }
}

private final class TDPArrangeCell: UICollectionViewCell {
    static let reuseID = "TDPArrangeCell"
    private var card: TDPCardButton?

    func show(_ value: Card) {
        card?.removeFromSuperview()
        let view = TDPCardButton(card: value, elevation: .hand)
        view.isUserInteractionEnabled = false
        view.frame = contentView.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(view)
        card = view
    }
}

// MARK: - Banner

/// "Meera gave up 2 tricks · You need 5 · Meera needs 1". Shown over the circle
/// at the start of play when targets changed while settling up.
final class TDPBannerView: UIView {

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = TDPTheme.raised
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        layer.borderWidth = 1
        isUserInteractionEnabled = false
        titleLabel.font = TDPTheme.font(14, .semibold)
        titleLabel.textColor = TDPTheme.ink
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        subtitleLabel.font = TDPTheme.font(12)
        subtitleLabel.textColor = TDPTheme.muted
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14)
        ])
        applyTheme()
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: TDPBannerView, _: UITraitCollection) in
            view.applyTheme()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func configure(title: String, subtitle: String?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = subtitle?.isEmpty ?? true
    }

    private func applyTheme() {
        layer.borderColor = TDPTheme.hairline.resolvedColor(with: traitCollection).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = traitCollection.userInterfaceStyle == .dark ? 0.4 : 0.12
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 18
    }
}
