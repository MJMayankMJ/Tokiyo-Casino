//
//  MenuViewController.swift
//  Poker
//
//  Screen E — "Texas Hold'em" solo-game setup. Mirrors the Claude Design
//  handoff bundle (poker/project/Multiplayer.html — screen E).
//
//  Navigation: this VC is pushed onto the host nav stack (see
//  HomeViewController.openPokerGame). The system nav bar is hidden here so
//  the custom poker back pill does not reserve an empty title row.
//

import UIKit

class MenuViewController: UIViewController {

    // MARK: Subviews
    private let backdrop = MPPageBackgroundView()
    private let backButton = MPBackPill()
    private let gearButton = MPGearPill()
    private let scrollView = UIScrollView()
    private let titleBlock = MPTitleView(
        eyebrow: "Solo Game",
        title: "Texas Hold'em",
        subtitle: nil
    )
    private let miniDeck = MPMiniDeck()

    private let playersEyebrow = mpSectionEyebrow("Number of players")
    private let playerPicker = MPPlayerPicker(value: 5)

    private let difficultyEyebrow = mpSectionEyebrow("AI difficulty")
    private let difficultyPicker = MPDifficultyPicker(value: PokerAIConfigStore.load().difficulty)
    /// Persisted AI config (difficulty + style). Loaded on appear, saved on change.
    private var aiConfig = PokerAIConfigStore.load()

    private let chipsHeaderRow = UIView()
    private let chipsEyebrow = mpSectionEyebrow("Starting chips")
    private let coinsPill = MPCoinsPill()
    private let chipsValueLabel = UILabel()
    private let chipsSlider: MPChipsSlider

    private let startButton = MPPrimaryButton(title: "Start Game")
    private let friendsButton: PlayWithFriendsButton

    /// Discrete buy-in tiers — slider snaps to exactly these four values.
    private static let buyInSteps: [Int] = [500, 1_000, 2_000, 4_000]

    // MARK: Coins
    private var availableCoins: Int64 {
        return CoinsManager.shared.userStats?.totalCoins ?? 0
    }
    private var minBuyIn: Int { Self.buyInSteps.first ?? 500 }

    init() {
        self.chipsSlider = MPChipsSlider(
            value: 1_000,
            steps: Self.buyInSteps
        )
        self.friendsButton = PlayWithFriendsButton()
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        MPNavigationChrome.hideSystemBackBar(for: self, animated: animated)
        refreshCoinsAndClampSlider()
        // Re-sync in case the config changed elsewhere (e.g. settings sheet).
        aiConfig = PokerAIConfigStore.load()
        difficultyPicker.setValue(aiConfig.difficulty, animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        MPNavigationChrome.restoreSystemBackBarIfLeaving(self, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        refreshChipsValueLabel()
    }

    private func setupUI() {
        view.backgroundColor = MPTheme.pageBg

        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(backdrop, at: 0)

        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        gearButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gearButton)
        gearButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        // Build a vertical stack inside a scroll view. Short landscape/small
        // devices can scroll instead of clipping labels against the edges.
        let centerStack = UIStackView()
        centerStack.axis = .vertical
        centerStack.alignment = .fill
        centerStack.spacing = 12
        centerStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(centerStack)

        // Title + mini-deck cluster
        let titleCluster = UIStackView()
        titleCluster.axis = .vertical
        titleCluster.alignment = .center
        titleCluster.spacing = 64
        titleCluster.addArrangedSubview(titleBlock)
        titleCluster.addArrangedSubview(miniDeck)
        centerStack.addArrangedSubview(titleCluster)
        centerStack.setCustomSpacing(2, after: titleCluster)

        // Players section
        let playersSection = UIStackView()
        playersSection.axis = .vertical
        playersSection.alignment = .fill
        playersSection.spacing = 8
        let playersHeader = UIView()
        playersEyebrow.translatesAutoresizingMaskIntoConstraints = false
        playersHeader.addSubview(playersEyebrow)
        NSLayoutConstraint.activate([
            playersEyebrow.leadingAnchor.constraint(equalTo: playersHeader.leadingAnchor, constant: 4),
            playersEyebrow.topAnchor.constraint(equalTo: playersHeader.topAnchor),
            playersEyebrow.bottomAnchor.constraint(equalTo: playersHeader.bottomAnchor),
        ])
        playersSection.addArrangedSubview(playersHeader)
        playersSection.addArrangedSubview(playerPicker)
        centerStack.addArrangedSubview(playersSection)

        // Difficulty section
        let difficultySection = UIStackView()
        difficultySection.axis = .vertical
        difficultySection.alignment = .fill
        difficultySection.spacing = 8
        let difficultyHeader = UIView()
        difficultyEyebrow.translatesAutoresizingMaskIntoConstraints = false
        difficultyHeader.addSubview(difficultyEyebrow)
        NSLayoutConstraint.activate([
            difficultyEyebrow.leadingAnchor.constraint(equalTo: difficultyHeader.leadingAnchor, constant: 4),
            difficultyEyebrow.topAnchor.constraint(equalTo: difficultyHeader.topAnchor),
            difficultyEyebrow.bottomAnchor.constraint(equalTo: difficultyHeader.bottomAnchor),
        ])
        difficultyPicker.addTarget(self, action: #selector(difficultyChanged), for: .valueChanged)
        difficultySection.addArrangedSubview(difficultyHeader)
        difficultySection.addArrangedSubview(difficultyPicker)
        centerStack.addArrangedSubview(difficultySection)

        // Chips section
        let chipsSection = UIStackView()
        chipsSection.axis = .vertical
        chipsSection.alignment = .fill
        chipsSection.spacing = 0

        coinsPill.translatesAutoresizingMaskIntoConstraints = false
        chipsEyebrow.translatesAutoresizingMaskIntoConstraints = false
        chipsHeaderRow.addSubview(chipsEyebrow)
        chipsHeaderRow.addSubview(coinsPill)
        NSLayoutConstraint.activate([
            chipsEyebrow.leadingAnchor.constraint(equalTo: chipsHeaderRow.leadingAnchor, constant: 4),
            chipsEyebrow.centerYAnchor.constraint(equalTo: chipsHeaderRow.centerYAnchor),
            coinsPill.trailingAnchor.constraint(equalTo: chipsHeaderRow.trailingAnchor, constant: -4),
            coinsPill.centerYAnchor.constraint(equalTo: chipsHeaderRow.centerYAnchor),
            chipsHeaderRow.heightAnchor.constraint(equalToConstant: 32),
        ])

        chipsValueLabel.textAlignment = .center
        chipsValueLabel.translatesAutoresizingMaskIntoConstraints = false
        chipsValueLabel.numberOfLines = 1
        chipsValueLabel.adjustsFontSizeToFitWidth = true
        chipsValueLabel.minimumScaleFactor = 0.72
        chipsValueLabel.setContentHuggingPriority(.required, for: .vertical)

        chipsSection.addArrangedSubview(chipsHeaderRow)
        chipsSection.addArrangedSubview(chipsValueLabel)
        chipsSection.setCustomSpacing(0, after: chipsValueLabel)
        chipsSection.addArrangedSubview(chipsSlider)
        centerStack.addArrangedSubview(chipsSection)
        centerStack.setCustomSpacing(10, after: chipsSection)

        let ctaStack = UIStackView(arrangedSubviews: [startButton, friendsButton])
        ctaStack.axis = .vertical
        ctaStack.alignment = .fill
        ctaStack.spacing = 8
        ctaStack.translatesAutoresizingMaskIntoConstraints = false
        centerStack.addArrangedSubview(ctaStack)

        // Wire actions
        playerPicker.onChange = { [weak self] _ in self?.refreshCoinsAndClampSlider() }
        chipsSlider.onChange = { [weak self] _ in self?.refreshChipsValueLabel() }
        startButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
        friendsButton.addTarget(self, action: #selector(playWithFriendsTapped), for: .touchUpInside)

        let preferredStackWidth = centerStack.widthAnchor.constraint(
            equalTo: scrollView.frameLayoutGuide.widthAnchor,
            constant: -40
        )
        preferredStackWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            gearButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            gearButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            centerStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 2),
            centerStack.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            preferredStackWidth,
            centerStack.widthAnchor.constraint(lessThanOrEqualToConstant: 640),
            centerStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),

            titleBlock.widthAnchor.constraint(equalTo: titleCluster.widthAnchor),
            chipsValueLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            miniDeck.widthAnchor.constraint(equalToConstant: 200),
            miniDeck.heightAnchor.constraint(equalToConstant: 104),
        ])
    }

    // MARK: Difficulty

    @objc private func difficultyChanged() {
        UISelectionFeedbackGenerator().selectionChanged()
        aiConfig.difficulty = difficultyPicker.value
        PokerAIConfigStore.save(aiConfig)
    }

    // MARK: Coins

    private func refreshCoinsAndClampSlider() {
        coinsPill.setAmount(Int(availableCoins))

        // Disable any buy-in tier above the player's coin balance.
        let canPlay = Int64(minBuyIn) <= availableCoins
        startButton.isEnabled = canPlay
        if !canPlay {
            chipsSlider.setValue(minBuyIn, animated: false)
        } else if Int64(chipsSlider.value) > availableCoins {
            // Snap down to the highest affordable tier.
            let affordable = Self.buyInSteps.filter { Int64($0) <= availableCoins }.last ?? minBuyIn
            chipsSlider.setValue(affordable, animated: false)
        }
        refreshChipsValueLabel()
    }

    private func refreshChipsValueLabel() {
        let f = NumberFormatter(); f.numberStyle = .decimal
        let amount = chipsSlider.value
        let fontSize: CGFloat = traitCollection.verticalSizeClass == .compact || view.bounds.height < 520 ? 40 : 48
        let attr = NSMutableAttributedString()
        attr.append(NSAttributedString(string: f.string(from: NSNumber(value: amount)) ?? "\(amount)",
                                       attributes: [
            .font: MPFont.display(fontSize, weight: .medium),
            .foregroundColor: MPTheme.ink,
            .kern: -1.0,
        ]))
        chipsValueLabel.attributedText = attr
    }

    // MARK: Actions

    @objc private func backTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        leaveScreen()
    }

    @objc private func playTapped() {
        let playerCount = playerPicker.value
        let startingChips = chipsSlider.value

        if Int64(startingChips) > availableCoins {
            let f = NumberFormatter(); f.numberStyle = .decimal
            let coinStr = f.string(from: NSNumber(value: availableCoins)) ?? "\(availableCoins)"
            let alert = UIAlertController(
                title: "Not enough chips",
                message: "You have \(coinStr) chips. Lower the starting amount.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let gameVC = GameViewController(playerCount: playerCount, startingChips: startingChips, aiConfig: aiConfig)
        gameVC.modalPresentationStyle = .fullScreen
        present(gameVC, animated: true)
    }

    @objc private func playWithFriendsTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let lobby = MultiplayerEntryViewController()
        if let nav = navigationController {
            nav.pushViewController(lobby, animated: true)
        } else {
            lobby.modalPresentationStyle = .fullScreen
            present(lobby, animated: true)
        }
    }

    @objc private func settingsTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let alert = UIAlertController(title: "Settings", message: "Coming soon!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func leaveScreen() {
        if let nav = navigationController, nav.viewControllers.first !== self {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

// MARK: - "Play with Friends" secondary CTA with chip flourish

/// Variant of MPSecondaryButton that prepends a two-chip flourish (coral
/// + amber) on the leading edge — matches the JSX PlayWithFriendsCTA.
final class PlayWithFriendsButton: UIControl {
    private let bg = UIView()
    private let chipCoral = MPChipView(size: 18, color: MPTheme.coral)
    private let chipAmber = MPChipView(size: 18, color: MPTheme.amber)
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        bg.isUserInteractionEnabled = false
        bg.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bg)
        bg.layer.cornerRadius = 16
        bg.layer.borderWidth = 1.5

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false

        let chipWrap = UIView()
        chipWrap.translatesAutoresizingMaskIntoConstraints = false
        chipCoral.translatesAutoresizingMaskIntoConstraints = false
        chipAmber.translatesAutoresizingMaskIntoConstraints = false
        chipWrap.addSubview(chipCoral)
        chipWrap.addSubview(chipAmber)
        NSLayoutConstraint.activate([
            chipCoral.leadingAnchor.constraint(equalTo: chipWrap.leadingAnchor),
            chipCoral.topAnchor.constraint(equalTo: chipWrap.topAnchor),
            chipCoral.bottomAnchor.constraint(equalTo: chipWrap.bottomAnchor),
            chipCoral.widthAnchor.constraint(equalToConstant: 18),
            chipAmber.leadingAnchor.constraint(equalTo: chipCoral.trailingAnchor, constant: -8),
            chipAmber.centerYAnchor.constraint(equalTo: chipWrap.centerYAnchor),
            chipAmber.widthAnchor.constraint(equalToConstant: 18),
            chipAmber.heightAnchor.constraint(equalToConstant: 18),
            chipWrap.widthAnchor.constraint(equalToConstant: 18 + 18 - 8),
            chipWrap.heightAnchor.constraint(equalToConstant: 18),
        ])

        label.text = "Play with Friends"
        label.font = MPFont.ui(15, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(chipWrap)
        stack.addArrangedSubview(label)

        addSubview(stack)
        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: topAnchor),
            bg.leadingAnchor.constraint(equalTo: leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: trailingAnchor),
            bg.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),

            heightAnchor.constraint(equalToConstant: 54),
        ])

        applyTheme()
        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyTheme()
    }

    private func applyTheme() {
        bg.backgroundColor = MPTheme.glassMedium
        bg.layer.borderColor = MPTheme.borderStrong.cgColor
        label.textColor = MPTheme.ink
        bg.layer.shadowColor = UIColor.black.cgColor
        bg.layer.shadowOpacity = 0.15
        bg.layer.shadowOffset = CGSize(width: 0, height: 1)
        bg.layer.shadowRadius = 2
    }

    @objc private func touchDown() {
        UIView.animate(withDuration: 0.08) { self.transform = .init(scaleX: 0.97, y: 0.97); self.alpha = 0.92 }
    }
    @objc private func touchUp() {
        UIView.animate(withDuration: 0.12) { self.transform = .identity; self.alpha = 1 }
    }
}
