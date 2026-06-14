//
//  JackarooMenuViewController.swift
//  Tokiyo Casino — Jackaroo (Phase 3)
//
//  Setup screen for Jackaroo. Pick Solo vs AI or Hot-Seat (2–4 humans
//  on one device), with the ruleset locked to Jawaker Basic in V1
//  (variant presets are Phase 5). Mirrors Poker's MenuViewController.
//

import UIKit

final class JackarooMenuViewController: UIViewController {

    private let backdrop = MPPageBackgroundView()
    private let backButton = MPBackPill()
    private let scrollView = UIScrollView()
    private let titleBlock = MPTitleView(eyebrow: "Board Game", title: "Jackaroo",
                                         subtitle: "Solo vs AI, or pass-and-play")

    private let modeEyebrow = mpSectionEyebrow("Mode")
    private let modePicker = JKSegment(items: ["Solo vs AI", "Hot-Seat"])

    private let playersEyebrow = mpSectionEyebrow("Human players")
    private let playerPicker = MPPlayerPicker(value: 2, options: [2, 3, 4])
    private let playersSection = UIStackView()

    private let rulesetEyebrow = mpSectionEyebrow("Ruleset")
    private let presetChip = JKLockedChip(title: "Jawaker Basic")

    private let startButton = MPPrimaryButton(title: "Start Game")
    private let rulesButton = MPSecondaryButton(title: "How to play")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = MPTheme.pageBg
        setupUI()
        updateModeVisibility()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        MPNavigationChrome.hideSystemBackBar(for: self, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        MPNavigationChrome.restoreSystemBackBarIfLeaving(self, animated: animated)
    }

    private func setupUI() {
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(backdrop, at: 0)

        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        let center = UIStackView()
        center.axis = .vertical
        center.alignment = .fill
        center.spacing = 18
        center.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(center)

        titleBlock.translatesAutoresizingMaskIntoConstraints = false

        modePicker.onChange = { [weak self] _ in self?.updateModeVisibility() }

        playersSection.axis = .vertical
        playersSection.alignment = .fill
        playersSection.spacing = 8
        playersSection.addArrangedSubview(wrapEyebrow(playersEyebrow))
        playersSection.addArrangedSubview(playerPicker)

        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        rulesButton.addTarget(self, action: #selector(rulesTapped), for: .touchUpInside)

        center.addArrangedSubview(titleBlock)
        center.setCustomSpacing(28, after: titleBlock)
        center.addArrangedSubview(makeSection(modeEyebrow, modePicker))
        center.addArrangedSubview(playersSection)
        center.addArrangedSubview(makeSection(rulesetEyebrow, presetChip))
        center.setCustomSpacing(28, after: center.arrangedSubviews.last!)
        let cta = UIStackView(arrangedSubviews: [startButton, rulesButton])
        cta.axis = .vertical
        cta.spacing = 10
        center.addArrangedSubview(cta)

        let preferredWidth = center.widthAnchor.constraint(
            equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        preferredWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            center.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            preferredWidth,
            center.widthAnchor.constraint(lessThanOrEqualToConstant: 560),
            center.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            center.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
        ])
    }

    private func makeSection(_ eyebrow: UILabel, _ control: UIView) -> UIStackView {
        let s = UIStackView(arrangedSubviews: [wrapEyebrow(eyebrow), control])
        s.axis = .vertical
        s.alignment = .fill
        s.spacing = 8
        return s
    }

    private func wrapEyebrow(_ eyebrow: UILabel) -> UIView {
        let header = UIView()
        eyebrow.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(eyebrow)
        NSLayoutConstraint.activate([
            eyebrow.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 4),
            eyebrow.topAnchor.constraint(equalTo: header.topAnchor),
            eyebrow.bottomAnchor.constraint(equalTo: header.bottomAnchor),
        ])
        return header
    }

    private func updateModeVisibility() {
        let isHotSeat = modePicker.selectedIndex == 1
        UIView.animate(withDuration: 0.2) {
            self.playersSection.isHidden = !isHotSeat
            self.playersSection.alpha = isHotSeat ? 1 : 0
        }
    }

    // MARK: - Actions

    @objc private func backTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let nav = navigationController, nav.viewControllers.first !== self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    @objc private func rulesTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        present(JackarooRulesViewController(), animated: true)
    }

    @objc private func startTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if modePicker.selectedIndex == 0 {
            // Solo vs AI — you at seat 0, three AIs.
            let players = JackarooSeating.solo()
            pushGame(players: players)
        } else {
            // Hot-seat — collect names + seats in the lobby.
            let lobby = JackarooLobbyViewController(humanCount: playerPicker.value)
            navigationController?.pushViewController(lobby, animated: true)
        }
    }

    private func pushGame(players: [JKPlayer]) {
        let game = JackarooGameViewController(players: players,
                                             seed: UInt64.random(in: 1...UInt64.max))
        game.modalPresentationStyle = .fullScreen
        navigationController?.pushViewController(game, animated: true)
    }
}

// MARK: - Seating helper

enum JackarooSeating {
    /// Three AI personalities used to fill empty seats, in order.
    static let aiPersonalities: [JKPersonality] = [.tightAggressive, .balanced, .loosePassive]

    static func solo() -> [JKPlayer] {
        (0..<4).map { seat in
            if seat == 0 { return JKPlayer(seat: seat, name: "You", kind: .human) }
            let p = aiPersonalities[(seat - 1) % aiPersonalities.count]
            return JKPlayer(seat: seat, name: p.displayName, kind: .ai(personality: p))
        }
    }
}

// MARK: - Locked ruleset chip

private final class JKLockedChip: UIView {
    init(title: String) {
        super.init(frame: .zero)
        backgroundColor = MPTheme.glassWeak
        layer.cornerRadius = 14
        layer.borderWidth = 1
        layer.borderColor = MPTheme.border.cgColor

        let icon = UIImageView(image: UIImage(systemName: "lock.fill"))
        icon.tintColor = MPTheme.muted
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let name = UILabel()
        name.text = title
        name.font = MPFont.ui(15, weight: .bold)
        name.textColor = MPTheme.ink

        let tag = UILabel()
        tag.attributedText = NSAttributedString(string: "V1", attributes: [
            .kern: 1.0, .font: MPFont.ui(10, weight: .heavy), .foregroundColor: MPTheme.muted,
        ])

        let stack = UIStackView(arrangedSubviews: [name, UIView(), tag, icon])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            icon.widthAnchor.constraint(equalToConstant: 14),
            heightAnchor.constraint(equalToConstant: 52),
        ])
        isAccessibilityElement = true
        accessibilityLabel = "Ruleset: \(title). Locked in this version."
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Simple text segmented control (matches MPPlayerPicker styling)

final class JKSegment: UIControl {
    private let track = UIView()
    private var buttons: [UIButton] = []
    private(set) var selectedIndex: Int = 0
    var onChange: ((Int) -> Void)?

    init(items: [String]) {
        super.init(frame: .zero)
        track.layer.cornerRadius = 999
        track.translatesAutoresizingMaskIntoConstraints = false
        addSubview(track)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 4
        stack.distribution = .fillEqually
        stack.alignment = .center
        stack.isLayoutMarginsRelativeArrangement = true
        stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        track.addSubview(stack)

        for (i, title) in items.enumerated() {
            let b = UIButton(type: .system)
            b.tag = i
            b.setTitle(title, for: .normal)
            b.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            b.heightAnchor.constraint(equalToConstant: 44).isActive = true
            stack.addArrangedSubview(b)
            buttons.append(b)
        }

        NSLayoutConstraint.activate([
            track.topAnchor.constraint(equalTo: topAnchor),
            track.leadingAnchor.constraint(equalTo: leadingAnchor),
            track.trailingAnchor.constraint(equalTo: trailingAnchor),
            track.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 60),
            stack.topAnchor.constraint(equalTo: track.topAnchor),
            stack.leadingAnchor.constraint(equalTo: track.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: track.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: track.bottomAnchor),
        ])
        applyTheme()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
    }

    @objc private func tapped(_ sender: UIButton) {
        guard sender.tag != selectedIndex else { return }
        selectedIndex = sender.tag
        applyTheme()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onChange?(selectedIndex)
    }

    private func applyTheme() {
        track.backgroundColor = MPTheme.feltDepth
        for b in buttons {
            let selected = b.tag == selectedIndex
            if selected {
                b.backgroundColor = MPTheme.amber
                b.layer.cornerRadius = 22
                b.layer.shadowColor = MPTheme.amber.cgColor
                b.layer.shadowOpacity = 0.45
                b.layer.shadowOffset = CGSize(width: 0, height: 6)
                b.layer.shadowRadius = 12
                b.setTitleColor(UIColor(hex: 0x3B2A0E), for: .normal)
                b.titleLabel?.font = MPFont.ui(15, weight: .heavy)
            } else {
                b.backgroundColor = .clear
                b.layer.cornerRadius = 22
                b.layer.shadowOpacity = 0
                b.setTitleColor(MPTheme.muted, for: .normal)
                b.titleLabel?.font = MPFont.ui(14, weight: .bold)
            }
        }
    }
}
