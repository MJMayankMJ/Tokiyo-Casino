import UIKit

/// A quiet game shelf, using the same adaptive palette as the 5-3-2 table.
final class HomeViewController: UIViewController {
    private let viewModel = HomeViewModel()
    private let coinsLabel = HomeDesign.label("0", size: 14, weight: .semibold, style: .subheadline)
    private let games = UIStackView()
    private let header = UIStackView()
    private let headerSpacer = UIView()
    private var gameButtons: [HomeGameButton] = []
    private var isOpeningGame = false
    private var launchGeneration = 0
    private var gridColumns = 0
    var catalog = HomeGameItem.catalog
    private static let initialChipGrantKey = "didGrantInitialChips.v1"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = TDPTheme.page
        buildHome()
        grantInitialChipsIfNeeded()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (home: HomeViewController, _: UITraitCollection) in
            home.view.setNeedsLayout()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(cancelGameLaunch),
            name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshCoins),
            name: CoinsManager.coinsDidChangeNotification, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        cancelGameLaunch()
        refreshCoins()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !PlayerProfile.hasOnboarded, presentedViewController == nil else { return }
        let onboarding = OnboardingViewController()
        onboarding.modalPresentationStyle = .fullScreen
        present(onboarding, animated: false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancelGameLaunch()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let accessible = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        header.axis = accessible ? .vertical : .horizontal
        header.alignment = accessible ? .leading : .center
        headerSpacer.isHidden = accessible
        let wide = !accessible && view.safeAreaLayoutGuide.layoutFrame.width >= HomeDesign.wideBreakpoint
        updateGameGrid(columns: wide ? 2 : 1)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    private func buildHome() {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = false
        scroll.showsVerticalScrollIndicator = false
        view.addSubview(scroll)

        let content = UIStackView()
        content.axis = .vertical
        content.spacing = HomeDesign.sectionGap
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)
        let preferredWidth = content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor,
                                                             constant: -HomeDesign.pageInset * 2)
        preferredWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -16),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: HomeDesign.pageInset),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -HomeDesign.pageInset),
            content.centerXAnchor.constraint(equalTo: scroll.frameLayoutGuide.centerXAnchor),
            content.widthAnchor.constraint(lessThanOrEqualToConstant: HomeDesign.maxWidth),
            preferredWidth
        ])

        content.addArrangedSubview(makeHeader())
        // Equal flexible space above and below keeps the games centred between the
        // header and the disclaimer; both collapse once the library outgrows the screen.
        let above = Self.flexibleSpace()
        let below = Self.flexibleSpace()
        content.addArrangedSubview(above)

        games.axis = .vertical
        games.spacing = HomeDesign.cardGap
        gameButtons = catalog.map { item in
            let button = HomeGameButton(game: item)
            button.addTarget(self, action: #selector(openGame(_:)), for: .touchUpInside)
            return button
        }
        updateGameGrid(columns: 1)
        content.addArrangedSubview(games)
        content.addArrangedSubview(below)
        content.setCustomSpacing(0, after: above)
        content.setCustomSpacing(0, after: games)
        below.heightAnchor.constraint(equalTo: above.heightAnchor).isActive = true
        let disclaimer = HomeDesign.label("For entertainment only.\nVirtual chips have no real-world value.", size: 11,
                                           style: .caption2, color: TDPTheme.inkSoft)
        disclaimer.textAlignment = .center
        content.addArrangedSubview(disclaimer)
        content.heightAnchor.constraint(greaterThanOrEqualTo: scroll.frameLayoutGuide.heightAnchor,
                                        constant: -(12 + 16)).isActive = true
    }

    private static func flexibleSpace() -> UIView {
        let space = UIView()
        space.setContentHuggingPriority(UILayoutPriority(1), for: .vertical)
        space.setContentCompressionResistancePriority(UILayoutPriority(1), for: .vertical)
        return space
    }

    private func updateGameGrid(columns: Int) {
        guard columns != gridColumns else { return }
        cancelGameLaunch()
        gridColumns = columns
        gameButtons.forEach { $0.removeFromSuperview(); $0.isWideLayout = columns == 2 }
        for row in games.arrangedSubviews {
            games.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        for index in stride(from: 0, to: gameButtons.count, by: columns) {
            if columns == 1 {
                games.addArrangedSubview(gameButtons[index])
            } else {
                let row = UIStackView()
                row.axis = .horizontal
                row.distribution = .fillEqually
                row.spacing = HomeDesign.cardGap
                row.addArrangedSubview(gameButtons[index])
                row.addArrangedSubview(index + 1 < gameButtons.count ? gameButtons[index + 1] : UIView())
                games.addArrangedSubview(row)
            }
        }
    }

    private func makeHeader() -> UIView {
        header.alignment = .center
        header.spacing = 12
        // The app icon's hand and wordmark; a fixed-size lockup, not body copy.
        let brand = TokiyoLogoView()
        brand.setContentCompressionResistancePriority(.required, for: .horizontal)
        brand.setContentHuggingPriority(.required, for: .horizontal)
        header.addArrangedSubview(brand)
        headerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        header.addArrangedSubview(headerSpacer)

        let balance = UIStackView()
        balance.alignment = .center
        balance.spacing = 6
        balance.isLayoutMarginsRelativeArrangement = true
        balance.layoutMargins = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        balance.backgroundColor = TDPTheme.raised
        balance.layer.cornerRadius = 18
        let chip = UIImageView(image: UIImage(systemName: "circle.hexagongrid.fill"))
        chip.tintColor = TDPTheme.primary
        chip.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([chip.widthAnchor.constraint(equalToConstant: 16), chip.heightAnchor.constraint(equalToConstant: 16)])
        coinsLabel.numberOfLines = 1
        coinsLabel.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .monospacedDigitSystemFont(ofSize: 14, weight: .semibold))
        coinsLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        balance.addArrangedSubview(chip)
        balance.addArrangedSubview(coinsLabel)
        header.addArrangedSubview(balance)
        let avatar = ProfileAvatarView(diameter: 44)
        avatar.followsProfile = true
        avatar.accessibilityTraits = .button
        avatar.accessibilityHint = "Opens your profile"
        avatar.accessibilityIdentifier = "home.profile"
        avatar.addTarget(self, action: #selector(openProfile), for: .touchUpInside)
        header.addArrangedSubview(avatar)
        return header
    }

    private func grantInitialChipsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.initialChipGrantKey) else { return }
        CoinsManager.shared.addCoins(amount: 1000) { _ in
            UserDefaults.standard.set(true, forKey: Self.initialChipGrantKey)
        }
    }

    @objc private func refreshCoins() {
        viewModel.fetchUserStats()
        let amount = viewModel.totalCoins
        coinsLabel.text = amount.formatted(.number.notation(.compactName))
        coinsLabel.accessibilityLabel = "\(amount.formatted()) virtual chips"
    }

    @objc private func openProfile() {
        cancelGameLaunch()
        present(ProfileViewController.sheet(), animated: true)
    }

    @objc private func cancelGameLaunch() {
        launchGeneration += 1
        isOpeningGame = false
        gameButtons.forEach { $0.resetPreview() }
    }

    @objc private func openGame(_ button: HomeGameButton) {
        guard !isOpeningGame, presentedViewController == nil else { return }
        isOpeningGame = true
        let token = launchGeneration
        button.playPreview { [weak self] in
            guard let self, self.launchGeneration == token, self.isOpeningGame,
                  self.view.window != nil, self.presentedViewController == nil else { return }
            let controller = button.game.makeViewController()
            if let navigationController = self.navigationController {
                // 5-3-2 uses the system back button; Poker hides it in its own lifecycle.
                navigationController.setNavigationBarHidden(false, animated: true)
                navigationController.pushViewController(controller, animated: true)
            } else {
                controller.modalPresentationStyle = .fullScreen
                self.present(controller, animated: true)
            }
        }
    }
}
