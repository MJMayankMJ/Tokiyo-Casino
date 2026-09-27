//
//  TDPEntryViewController.swift
//  Tokiyo Casino — Teen Do Paanch
//
//  The 5-3-2 start page: who you're playing as, the ways to play, and the
//  tutorial. Starting a game opens a short sheet that fixes the length
//  (and, for pass & play, how many people share the phone) before the deal.
//
//  Everything is offline: bots and pass & play use no network at all, and
//  friends play peer-to-peer over local Wi-Fi / Bluetooth.
//

import UIKit

final class TDPEntryViewController: UIViewController {

    private let identity = TDPIdentityRow()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = TDPTheme.page
        navigationItem.largeTitleDisplayMode = .never
        build()
    }

    private func build() {
        let s = TDPTheme.scale

        // Hero: the name of the game, big and light.
        let eyebrow = UILabel()
        eyebrow.attributedText = NSAttributedString(
            string: "TEEN DO PAANCH",
            attributes: [.font: TDPTheme.font(12, .semibold), .kern: 1.4, .foregroundColor: TDPTheme.muted])
        let title = UILabel()
        title.text = "5 · 3 · 2"
        title.font = .systemFont(ofSize: 60 * s, weight: .light)
        title.textColor = TDPTheme.ink
        let tagline = UILabel()
        tagline.text = "Three players. Ten tricks."
        tagline.font = TDPTheme.font(15)
        tagline.textColor = TDPTheme.muted
        let words = UIStackView(arrangedSubviews: [eyebrow, title, tagline])
        words.axis = .vertical
        words.alignment = .leading
        words.spacing = 2
        let fan = TDPHeroFan()
        let hero = UIStackView(arrangedSubviews: [words, fan])
        hero.alignment = .center

        identity.addTarget(self, action: #selector(didTapIdentity), for: .touchUpInside)

        let bots = TDPModeTile(symbol: "play.fill", title: "Play vs bots", detail: "You and two bots", isPrimary: true)
        bots.addTarget(self, action: #selector(didTapBots), for: .touchUpInside)

        let others = TDPModeList(rows: [
            .init(symbol: "iphone", title: "Pass & play", detail: "Share this phone"),
            .init(symbol: "antenna.radiowaves.left.and.right", title: "Host a table", detail: "Friends nearby join you"),
            .init(symbol: "person.2", title: "Join a table", detail: "Find one nearby")
        ])
        others.onSelect = { [weak self] index in
            switch index {
            case 0: self?.didTapPassAndPlay()
            case 1: self?.didTapHost()
            default: self?.didTapJoin()
            }
        }

        let learn = TDPTutorialEntryTile()
        learn.addTarget(self, action: #selector(didTapRules), for: .touchUpInside)

        var items: [UIView] = [hero, identity, bots, others, learn]
        #if DEBUG
        let debug = UIButton(type: .system)
        debug.setTitle("Debug · khichai", for: .normal)
        debug.titleLabel?.font = TDPTheme.font(12, .medium)
        debug.tintColor = TDPTheme.muted
        debug.addTarget(self, action: #selector(didTapDebugKhichai), for: .touchUpInside)
        items.append(debug)
        #endif

        let stack = UIStackView(arrangedSubviews: items)
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(18, after: hero)
        stack.setCustomSpacing(26, after: identity)
        stack.setCustomSpacing(26, after: others)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Scrolls on a small phone rather than squeezing.
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = false
        scroll.showsVerticalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        view.addSubview(scroll)

        let content = scroll.contentLayoutGuide
        let frame = scroll.frameLayoutGuide
        let wide = stack.widthAnchor.constraint(equalTo: frame.widthAnchor, constant: -40)
        wide.priority = .defaultHigh
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
            stack.centerXAnchor.constraint(equalTo: frame.centerXAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 520),
            wide
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        identity.refresh()
    }

    // MARK: Modes

    @objc private func didTapIdentity() {
        present(ProfileViewController.sheet(), animated: true)
    }

    @objc private func didTapBots() {
        presentSetup(.bots)
    }

    private func didTapPassAndPlay() {
        presentSetup(.passAndPlay)
    }

    private func didTapHost() {
        presentSetup(.host)
    }

    private func didTapJoin() {
        push(TDPLobbyViewController(role: .guest(name: PlayerProfile.name)))
    }

    private func presentSetup(_ mode: TDPNewGameSheet.Mode) {
        let sheet = TDPNewGameSheet(mode: mode)
        sheet.onStart = { [weak self] setup in
            self?.dismiss(animated: true) { self?.start(setup) }
        }
        present(sheet, animated: true)
    }

    private func start(_ setup: TDPNewGameSheet.Setup) {
        let name = PlayerProfile.name
        switch setup.mode {
        case .bots:
            let service = TDPHostService(mode: .practice, hostName: name, targetRounds: setup.rounds)
            push(TDPGameViewController(driver: TDPHostDriver(service: service)))
        case .passAndPlay:
            let service = TDPHostService(mode: .passAndPlay(humanSeats: setup.people),
                                         hostName: name, targetRounds: setup.rounds)
            push(TDPGameViewController(driver: TDPHostDriver(service: service)))
        case .host:
            push(TDPLobbyViewController(role: .host(name: name, rounds: setup.rounds)))
        }
    }

    #if DEBUG
    /// Debug builds: jump straight to settling up in round 2+.
    @objc private func didTapDebugKhichai() {
        let sheet = UIAlertController(
            title: "Debug · khichai",
            message: "You and Player 2 share this phone; Meera is a bot.",
            preferredStyle: .actionSheet)
        for scenario in TDPDebugScenario.allCases {
            sheet.addAction(UIAlertAction(title: scenario.title, style: .default) { [weak self] _ in
                self?.launchDebug(scenario)
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = view
        present(sheet, animated: true)
    }

    private func launchDebug(_ scenario: TDPDebugScenario) {
        let service = TDPHostService(mode: .passAndPlay(humanSeats: 2), hostName: PlayerProfile.name)
        let driver = TDPHostDriver(service: service)       // attach before the first publish
        service.debugStart(with: scenario.makeState(playerName: PlayerProfile.name))
        push(TDPGameViewController(driver: driver))
    }
    #endif

    @objc private func didTapRules() {
        push(TDPTutorialViewController())
    }

    private func push(_ controller: UIViewController) {
        if let nav = navigationController {
            nav.pushViewController(controller, animated: true)
        } else {
            controller.modalPresentationStyle = .fullScreen
            present(controller, animated: true)
        }
    }
}

// MARK: - Hero fan

/// Three cards leaning out of the corner of the title.
private final class TDPHeroFan: UIView {

    private let cards = ["QD", "KH", "AS"].compactMap(Card.init(tdpID:)).map {
        TDPCardButton(card: $0, elevation: .hand)
    }

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        cards.forEach { addSubview($0) }
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 104 * TDPTheme.scale),
            heightAnchor.constraint(equalToConstant: 96 * TDPTheme.scale)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = 44 * TDPTheme.scale
        let size = CGSize(width: w, height: w * 100 / 70)
        for (i, card) in cards.enumerated() {
            let offset = CGFloat(i) - 1
            card.transform = .identity
            card.bounds = CGRect(origin: .zero, size: size)
            card.center = CGPoint(x: bounds.midX + offset * w * 0.5, y: bounds.midY + abs(offset) * 4)
            card.transform = CGAffineTransform(rotationAngle: offset * 14 * .pi / 180)
        }
    }
}

// MARK: - Identity

/// "Playing as Mayank ›" with the profile photo. Opens Profile.
private final class TDPIdentityRow: UIControl {

    private let avatar = ProfileAvatarView(diameter: 30)
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        avatar.isUserInteractionEnabled = false
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right",
                                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)))
        chevron.tintColor = TDPTheme.muted
        let row = UIStackView(arrangedSubviews: [avatar, label, chevron])
        row.spacing = 10
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor)
        ])
        accessibilityTraits = .button
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: PlayerProfile.didChange, object: nil)
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc func refresh() {
        let name = PlayerProfile.name
        avatar.configure(name: name, photo: PlayerProfile.photo)
        let text = NSMutableAttributedString(string: "Playing as ",
                                             attributes: [.font: TDPTheme.font(14), .foregroundColor: TDPTheme.muted])
        text.append(NSAttributedString(string: name,
                                       attributes: [.font: TDPTheme.font(14, .semibold), .foregroundColor: TDPTheme.ink]))
        label.attributedText = text
        accessibilityLabel = "Playing as \(name). Opens your profile."
    }

    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.6 : 1 } }
}

// MARK: - Mode tiles

/// The headline way to play: a filled tile.
private final class TDPModeTile: UIControl {

    init(symbol: String, title: String, detail: String, isPrimary: Bool) {
        super.init(frame: .zero)
        backgroundColor = isPrimary ? TDPTheme.primary : TDPTheme.raised
        layer.cornerRadius = 22 * TDPTheme.scale
        layer.cornerCurve = .continuous
        let ink = isPrimary ? TDPTheme.primaryInk : TDPTheme.ink

        let icon = UIImageView(image: UIImage(systemName: symbol,
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)))
        icon.tintColor = ink
        icon.contentMode = .center
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = TDPTheme.font(18, .semibold)
        titleLabel.textColor = ink
        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.font = TDPTheme.font(13)
        detailLabel.textColor = ink.withAlphaComponent(0.7)
        let text = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        text.axis = .vertical
        text.spacing = 2
        let row = UIStackView(arrangedSubviews: [text, icon])
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 28),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 20 * TDPTheme.scale),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20 * TDPTheme.scale),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])
        accessibilityTraits = .button
        accessibilityLabel = "\(title). \(detail)"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isHighlighted: Bool { didSet { alpha = isHighlighted ? 0.8 : 1 } }
}

/// The other ways to play, as one grouped list.
private final class TDPModeList: UIView {

    struct Row { let symbol: String; let title: String; let detail: String }

    var onSelect: ((Int) -> Void)?

    init(rows: [Row]) {
        super.init(frame: .zero)
        backgroundColor = TDPTheme.raised
        layer.cornerRadius = 22 * TDPTheme.scale
        layer.cornerCurve = .continuous
        clipsToBounds = true

        let stack = UIStackView()
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        for (index, row) in rows.enumerated() {
            if index > 0 {
                let rule = UIView()
                rule.backgroundColor = TDPTheme.hairline
                rule.translatesAutoresizingMaskIntoConstraints = false
                let inset = UIView()
                inset.addSubview(rule)
                NSLayoutConstraint.activate([
                    inset.heightAnchor.constraint(equalToConstant: 1),
                    rule.topAnchor.constraint(equalTo: inset.topAnchor),
                    rule.bottomAnchor.constraint(equalTo: inset.bottomAnchor),
                    rule.leadingAnchor.constraint(equalTo: inset.leadingAnchor, constant: 64),
                    rule.trailingAnchor.constraint(equalTo: inset.trailingAnchor)
                ])
                stack.addArrangedSubview(inset)
            }
            let control = TDPModeRow(row: row)
            control.tag = index
            control.addTarget(self, action: #selector(didTap(_:)), for: .touchUpInside)
            stack.addArrangedSubview(control)
        }
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func didTap(_ sender: UIControl) { onSelect?(sender.tag) }
}

private final class TDPModeRow: UIControl {

    init(row: TDPModeList.Row) {
        super.init(frame: .zero)
        let well = UIView()
        well.backgroundColor = TDPTheme.raisedAlt
        well.layer.cornerRadius = 12
        well.layer.cornerCurve = .continuous
        well.translatesAutoresizingMaskIntoConstraints = false
        let icon = UIImageView(image: UIImage(systemName: row.symbol,
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)))
        icon.tintColor = TDPTheme.inkSoft
        icon.contentMode = .center
        icon.translatesAutoresizingMaskIntoConstraints = false
        well.addSubview(icon)

        let title = UILabel()
        title.text = row.title
        title.font = TDPTheme.font(16, .medium)
        title.textColor = TDPTheme.ink
        let detail = UILabel()
        detail.text = row.detail
        detail.font = TDPTheme.font(13)
        detail.textColor = TDPTheme.muted
        let text = UIStackView(arrangedSubviews: [title, detail])
        text.axis = .vertical
        text.spacing = 1
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right",
                                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
        chevron.tintColor = TDPTheme.muted
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let line = UIStackView(arrangedSubviews: [well, text, chevron])
        line.spacing = 14
        line.alignment = .center
        line.isUserInteractionEnabled = false
        line.translatesAutoresizingMaskIntoConstraints = false
        addSubview(line)
        NSLayoutConstraint.activate([
            well.widthAnchor.constraint(equalToConstant: 36),
            well.heightAnchor.constraint(equalToConstant: 36),
            icon.centerXAnchor.constraint(equalTo: well.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: well.centerYAnchor),
            line.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            line.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            line.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            line.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18)
        ])
        accessibilityTraits = .button
        accessibilityLabel = "\(row.title). \(row.detail)"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? TDPTheme.raisedAlt : .clear }
    }
}

// MARK: - New game sheet

/// Fixes the length before the deal — and, for pass & play, how many
/// people share the phone. Remembers the last choice.
final class TDPNewGameSheet: UIViewController {

    enum Mode { case bots, passAndPlay, host }

    struct Setup {
        let mode: Mode
        let rounds: Int
        let people: Int
    }

    static let roundChoices = [3, 6, 9]
    private static let roundsKey = "tdp.newGame.rounds"
    private static let peopleKey = "tdp.newGame.people"

    var onStart: ((Setup) -> Void)?

    private let mode: Mode
    private let rounds = TDPPillPicker(options: roundChoices.map(String.init))
    private let people = TDPPillPicker(options: ["2", "3"])

    init(mode: Mode) {
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.custom { _ in mode == .passAndPlay ? 430 : 340 }]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 28
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = TDPTheme.page

        let (heading, detail, action): (String, String, String) = {
            switch mode {
            case .bots:        return ("Play vs bots", "You and two bots.", "Deal")
            case .passAndPlay: return ("Pass & play", "Hand the phone round; bots fill empty seats.", "Deal")
            case .host:        return ("Host a table", "Friends nearby join. Bots fill empty seats.", "Open table")
            }
        }()
        let title = UILabel()
        title.text = heading
        title.font = TDPTheme.font(24, .semibold)
        title.textColor = TDPTheme.ink
        let subtitle = UILabel()
        subtitle.text = detail
        subtitle.font = TDPTheme.font(14)
        subtitle.textColor = TDPTheme.muted
        subtitle.numberOfLines = 0

        let defaults = UserDefaults.standard
        let savedRounds = defaults.integer(forKey: Self.roundsKey)
        rounds.selectedIndex = Self.roundChoices.firstIndex(of: savedRounds) ?? 0
        people.selectedIndex = defaults.integer(forKey: Self.peopleKey) == 3 ? 1 : 0

        var items: [UIView] = [title, subtitle]
        if mode == .passAndPlay {
            items += [eyebrow("People on this phone"), people]
        }
        let roundsNote = UILabel()
        roundsNote.text = "Everyone deals the same number of times."
        roundsNote.font = TDPTheme.font(12)
        roundsNote.textColor = TDPTheme.muted
        items += [eyebrow("Rounds"), rounds, roundsNote]

        let start = TDPButton(title: action, style: .primary)
        start.addTarget(self, action: #selector(didTapStart), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: items)
        stack.axis = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(4, after: title)
        stack.setCustomSpacing(24, after: subtitle)
        if mode == .passAndPlay { stack.setCustomSpacing(22, after: people) }
        stack.translatesAutoresizingMaskIntoConstraints = false
        [stack, start].forEach { view.addSubview($0) }
        let readable = view.readableContentGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: readable.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: readable.trailingAnchor, constant: -4),
            start.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            start.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            start.topAnchor.constraint(greaterThanOrEqualTo: stack.bottomAnchor, constant: 20),
            start.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            start.heightAnchor.constraint(equalToConstant: 54 * TDPTheme.scale)
        ])
    }

    private func eyebrow(_ text: String) -> UILabel {
        let label = UILabel()
        label.attributedText = NSAttributedString(
            string: text.uppercased(),
            attributes: [.font: TDPTheme.font(11, .semibold), .kern: 1.2, .foregroundColor: TDPTheme.muted])
        return label
    }

    @objc private func didTapStart() {
        let count = Self.roundChoices[rounds.selectedIndex]
        let humans = people.selectedIndex == 1 ? 3 : 2
        UserDefaults.standard.set(count, forKey: Self.roundsKey)
        UserDefaults.standard.set(humans, forKey: Self.peopleKey)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onStart?(Setup(mode: mode, rounds: count, people: humans))
    }
}

/// A row of equal pills; one is chosen.
final class TDPPillPicker: UIControl {

    private var buttons: [UIButton] = []
    var selectedIndex = 0 { didSet { applyState() } }

    init(options: [String]) {
        super.init(frame: .zero)
        backgroundColor = TDPTheme.raisedAlt
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        let row = UIStackView()
        row.spacing = 4
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        for (index, option) in options.enumerated() {
            let button = UIButton(type: .custom)
            button.setTitle(option, for: .normal)
            button.titleLabel?.font = TDPTheme.mono(17, .medium)
            button.layer.cornerRadius = 12
            button.layer.cornerCurve = .continuous
            button.tag = index
            button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            row.addArrangedSubview(button)
            buttons.append(button)
        }
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            heightAnchor.constraint(equalToConstant: 52 * TDPTheme.scale)
        ])
        applyState()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    @objc private func tapped(_ sender: UIButton) {
        guard sender.tag != selectedIndex else { return }
        selectedIndex = sender.tag
        UISelectionFeedbackGenerator().selectionChanged()
        sendActions(for: .valueChanged)
    }

    private func applyState() {
        for (index, button) in buttons.enumerated() {
            let on = index == selectedIndex
            button.backgroundColor = on ? TDPTheme.raised : .clear
            button.setTitleColor(on ? TDPTheme.ink : TDPTheme.muted, for: .normal)
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOpacity = on ? 0.08 : 0
            button.layer.shadowOffset = CGSize(width: 0, height: 1)
            button.layer.shadowRadius = 2
            button.accessibilityTraits = on ? [.button, .selected] : .button
        }
    }
}
