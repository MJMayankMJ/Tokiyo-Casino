//
//  JackarooMenuViewController.swift
//  Tokiyo Casino — Jackaroo (Phase 3)
//
//  Setup screen for Jackaroo. Pick Solo vs AI or Hot-Seat (2–4 humans
//  on one device) and the ruleset (Basic / Complex / Community, the
//  three locked-in V1 presets). Mirrors Poker's MenuViewController.
//

import UIKit

final class JackarooMenuViewController: UIViewController {

    private let backdrop = MPPageBackgroundView()
    private let backButton = MPBackPill()
    private let scrollView = UIScrollView()
    private let titleBlock = MPTitleView(eyebrow: "Board Game", title: "Jackaroo",
                                         subtitle: "Solo vs AI, or pass-and-play")

    private let balancePill = MPCoinsPill()

    private let modeEyebrow = mpSectionEyebrow("Mode")
    private let modePicker = JKSegment(items: ["Solo vs AI", "Hot-Seat"])

    private let playersEyebrow = mpSectionEyebrow("Human players")
    private let playerPicker = MPPlayerPicker(value: 2, options: [2, 3, 4])
    private let playersSection = UIStackView()

    private let stakeEyebrow = mpSectionEyebrow("Stake")
    private let stakePicker = JKSegment(items: JKGamePreferences.stakeTiers.map(JackarooMenuViewController.stakeLabel))
    private let stakeCaption = JackarooMenuViewController.makeCaption()
    private let stakeSection = UIStackView()

    /// Selected solo wager.
    private var selectedStake: Int { JKGamePreferences.stakeTiers[stakePicker.selectedIndex] }
    private var coinBalance: Int64 { CoinsManager.shared.userStats?.totalCoins ?? 0 }

    private let rulesetEyebrow = mpSectionEyebrow("Ruleset")
    private let presetPicker = JKSegment(items: JKRulesPreset.selectableOptions.map { $0.name })
    private let presetCaption = JackarooMenuViewController.makeCaption()

    /// The ruleset the player has selected (locked at game start).
    private var selectedPreset: JKRulesPreset {
        JKRulesPreset.selectableOptions[presetPicker.selectedIndex].preset
    }

    private let resumeButton = MPPrimaryButton(title: "Resume game")
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
        refreshResume()
        balancePill.setAmount(Int(coinBalance))
    }

    /// Show the Resume pill only when a mid-game autosave exists.
    private func refreshResume() {
        resumeButton.isHidden = !JKAutosave.hasResumableGame
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
        presetPicker.onChange = { [weak self] _ in self?.updatePresetCaption() }
        updatePresetCaption()

        playersSection.axis = .vertical
        playersSection.alignment = .fill
        playersSection.spacing = 8
        playersSection.addArrangedSubview(wrapEyebrow(playersEyebrow))
        playersSection.addArrangedSubview(playerPicker)

        stakeSection.axis = .vertical
        stakeSection.alignment = .fill
        stakeSection.spacing = 8
        stakeSection.addArrangedSubview(wrapEyebrow(stakeEyebrow))
        stakeSection.addArrangedSubview(stakePicker)
        stakeSection.addArrangedSubview(stakeCaption)
        stakeSection.setCustomSpacing(6, after: stakePicker)
        stakePicker.onChange = { [weak self] _ in self?.updateStakeCaption() }
        updateStakeCaption()

        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)
        rulesButton.addTarget(self, action: #selector(rulesTapped), for: .touchUpInside)

        resumeButton.addTarget(self, action: #selector(resumeTapped), for: .touchUpInside)
        resumeButton.isHidden = true
        resumeButton.accessibilityHint = "Continues the game you left in progress."

        center.addArrangedSubview(titleBlock)
        center.setCustomSpacing(16, after: titleBlock)
        center.addArrangedSubview(centered(balancePill))
        center.setCustomSpacing(22, after: center.arrangedSubviews.last!)
        center.addArrangedSubview(resumeButton)
        center.setCustomSpacing(20, after: resumeButton)
        center.addArrangedSubview(makeSection(modeEyebrow, modePicker))
        center.addArrangedSubview(playersSection)
        center.addArrangedSubview(stakeSection)
        let rulesetSection = makeSection(rulesetEyebrow, presetPicker)
        rulesetSection.addArrangedSubview(presetCaption)
        rulesetSection.setCustomSpacing(6, after: presetPicker)
        center.addArrangedSubview(rulesetSection)
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

    private static func makeCaption() -> UILabel {
        let l = UILabel()
        l.font = MPFont.ui(12, weight: .medium)
        l.textColor = MPTheme.muted
        l.numberOfLines = 0
        return l
    }

    private func updatePresetCaption() {
        let option = JKRulesPreset.selectableOptions[presetPicker.selectedIndex]
        presetCaption.text = option.caption
    }

    /// Compact coin label, e.g. 1000 → "1K", 25000 → "25K".
    private static func stakeLabel(_ value: Int) -> String {
        value % 1000 == 0 ? "\(value / 1000)K" : "\(value)"
    }

    private func updateStakeCaption() {
        let f = NumberFormatter(); f.numberStyle = .decimal
        let s = f.string(from: NSNumber(value: selectedStake)) ?? "\(selectedStake)"
        stakeCaption.text = "Win to take \(s) coins from the other team; lose and you forfeit it."
    }

    /// Wrap an intrinsic-size view so it stays centered in a fill stack.
    private func centered(_ inner: UIView) -> UIView {
        let row = UIView()
        inner.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.centerXAnchor.constraint(equalTo: row.centerXAnchor),
            inner.topAnchor.constraint(equalTo: row.topAnchor),
            inner.bottomAnchor.constraint(equalTo: row.bottomAnchor),
        ])
        return row
    }

    private func updateModeVisibility() {
        let isHotSeat = modePicker.selectedIndex == 1
        UIView.animate(withDuration: 0.2) {
            self.playersSection.isHidden = !isHotSeat
            self.playersSection.alpha = isHotSeat ? 1 : 0
            // Wagers apply to solo vs AI only — hot-seat is local play.
            self.stakeSection.isHidden = isHotSeat
            self.stakeSection.alpha = isHotSeat ? 0 : 1
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
        present(JackarooRulesViewController(preset: selectedPreset), animated: true)
    }

    @objc private func resumeTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard let state = JKAutosave.load() else {
            refreshResume()   // stale (finished/corrupt) — hide the pill
            return
        }
        let game = JackarooGameViewController(restoring: state)
        game.modalPresentationStyle = .fullScreen
        navigationController?.pushViewController(game, animated: true)
    }

    @objc private func startTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if modePicker.selectedIndex == 0 {
            // Solo vs AI — you at seat 0, three AIs. Must be able to cover
            // the wager.
            guard coinBalance >= Int64(selectedStake) else {
                presentInsufficientCoins()
                return
            }
            pushGame(players: JackarooSeating.solo(), stake: selectedStake)
        } else {
            // Hot-seat — collect names + seats in the lobby. No wager.
            let lobby = JackarooLobbyViewController(humanCount: playerPicker.value,
                                                    rules: selectedPreset)
            navigationController?.pushViewController(lobby, animated: true)
        }
    }

    private func presentInsufficientCoins() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        let alert = UIAlertController(
            title: "Not enough coins",
            message: "You need \(selectedStake) coins for this stake. Pick a lower stake or earn more coins.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func pushGame(players: [JKPlayer], stake: Int) {
        let game = JackarooGameViewController(players: players,
                                             seed: UInt64.random(in: 1...UInt64.max),
                                             rules: selectedPreset,
                                             stake: stake)
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
