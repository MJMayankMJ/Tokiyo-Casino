//
//  HomeViewController.swift
//  Tokiyo Casino
//
//  Created by Mayank Jangid on 5/28/25.
//

import UIKit

class HomeViewController: UIViewController, UIAdaptivePresentationControllerDelegate {

    // MARK: - Outlets
    @IBOutlet weak var labelTotalCoins: UILabel!
    @IBOutlet weak var treasureChestImage: UIImageView!

    private enum HomeGame: Int {
        case poker = 1
        case jackaroo = 2
    }

    private var viewModel = HomeViewModel()
    private var gameCards: [UIView] = []
    // Daily-spin prompt path is quarantined — see REBRAND_PRD.md §3.1 / Phase A.
    // private var hasShownDailySpinPrompt = false

    // First-launch chip grant key. Idempotent — one-time 1000-chip bonus on fresh install.
    private static let initialChipGrantKey = "didGrantInitialChips.v1"
    private static let initialChipGrantAmount: Int64 = 1000

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        grantInitialChipsIfNeeded()

        setupGameCards()
        setupTapGestures()
        setupInitialAnimations()
        setupDisclaimerLabel()

        // Outlet was originally the daily-spin treasure chest. Repurposed as the
        // static chip indicator next to labelTotalCoins. The image was swapped
        // in Main.storyboard from `coinBox` to the system "circle.hexagonpath.fill" SF Symbol.
        treasureChestImage?.isHidden = false
        treasureChestImage?.isUserInteractionEnabled = false

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(coinsDidChange),
            name: CoinsManager.coinsDidChangeNotification,
            object: nil
        )
    }

    private func grantInitialChipsIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.initialChipGrantKey) else { return }
        CoinsManager.shared.addCoins(amount: Self.initialChipGrantAmount) { _ in
            defaults.set(true, forKey: Self.initialChipGrantKey)
        }
    }

    private weak var disclaimerPill: UIView?
    private weak var disclaimerInfoButton: UIButton?
    private static let disclaimerSeenKey = "homeDisclaimerSeen.v1"

    private func setupDisclaimerLabel() {
        // Expanded pill
        let pill = UIView()
        pill.backgroundColor = UIColor(red: 0.10, green: 0.08, blue: 0.06, alpha: 0.85)
        pill.layer.cornerRadius = 10
        pill.layer.borderWidth = 1
        pill.layer.borderColor = UIColor(red: 1, green: 0.706, blue: 0.204, alpha: 0.55).cgColor
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.isUserInteractionEnabled = true
        view.addSubview(pill)

        let disclaimer = UILabel()
        disclaimer.text = "For entertainment only. Virtual chips have no real-world value."
        disclaimer.font = .systemFont(ofSize: 11, weight: .semibold)
        disclaimer.textColor = UIColor(red: 1, green: 0.95, blue: 0.85, alpha: 1)
        disclaimer.textAlignment = .center
        disclaimer.numberOfLines = 0
        disclaimer.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(disclaimer)

        let pillTap = UITapGestureRecognizer(target: self, action: #selector(collapseDisclaimer))
        pill.addGestureRecognizer(pillTap)

        // Collapsed info button (SF Symbol)
        var cfg = UIButton.Configuration.plain()
        cfg.image = UIImage(systemName: "info.circle.fill",
                            withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .regular))
        cfg.baseForegroundColor = UIColor(red: 0.18, green: 0.14, blue: 0.10, alpha: 0.70)
        cfg.contentInsets = .zero

        let infoButton = UIButton(configuration: cfg)
        infoButton.translatesAutoresizingMaskIntoConstraints = false
        infoButton.backgroundColor = .clear
        infoButton.accessibilityLabel = "Show disclaimer"
        infoButton.alpha = 0
        infoButton.addTarget(self, action: #selector(expandDisclaimer), for: .touchUpInside)
        view.addSubview(infoButton)

        NSLayoutConstraint.activate([
            pill.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            pill.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            pill.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),

            disclaimer.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 12),
            disclaimer.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -12),
            disclaimer.topAnchor.constraint(equalTo: pill.topAnchor, constant: 8),
            disclaimer.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -8),

            infoButton.widthAnchor.constraint(equalToConstant: 32),
            infoButton.heightAnchor.constraint(equalToConstant: 32),
            infoButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            infoButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -6)
        ])

        self.disclaimerPill = pill
        self.disclaimerInfoButton = infoButton

        // Decide initial state
        let alreadySeen = UserDefaults.standard.bool(forKey: Self.disclaimerSeenKey)
        if alreadySeen {
            // Start collapsed
            pill.alpha = 0
            pill.isHidden = true
            infoButton.alpha = 1
        } else {
            // Show full pill, auto-collapse after 4s
            UserDefaults.standard.set(true, forKey: Self.disclaimerSeenKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak self] in
                self?.collapseDisclaimer()
            }
        }
    }

    @objc private func collapseDisclaimer() {
        guard let pill = disclaimerPill, let button = disclaimerInfoButton, !pill.isHidden else { return }
        UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseInOut], animations: {
            pill.alpha = 0
            pill.transform = CGAffineTransform(scaleX: 0.6, y: 0.6).translatedBy(x: pill.bounds.width / 2 - 40, y: 0)
            button.alpha = 1
        }, completion: { _ in
            pill.isHidden = true
            pill.transform = .identity
        })
    }

    @objc private func expandDisclaimer() {
        guard let pill = disclaimerPill, let button = disclaimerInfoButton else { return }
        pill.isHidden = false
        pill.alpha = 0
        pill.transform = CGAffineTransform(scaleX: 0.6, y: 0.6).translatedBy(x: pill.bounds.width / 2 - 40, y: 0)
        UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseInOut], animations: {
            pill.alpha = 1
            pill.transform = .identity
            button.alpha = 0
        })
        // Auto-collapse again after a few seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.collapseDisclaimer()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.fetchUserStats()
        updateUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Daily-spin prompt path quarantined.
        // if !hasShownDailySpinPrompt && viewModel.canSpinForCoins {
        //     showDailySpinPrompt()
        //     hasShownDailySpinPrompt = true
        // }

        startIdleAnimations()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopIdleAnimations()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup
    private func setupGameCards() {
        guard let stackView = findGameCardsStackView() else {
            #if DEBUG
            print("Warning: Could not find game cards stack view")
            #endif
            return
        }

        removeExistingStoryboardCards(from: stackView)

        let pokerCard = makeGameCard(
            game: .poker,
            title: "POKER",
            imageName: "game1icon",
            badgeText: nil
        )

        #if DEBUG
        let jackarooBadge: String? = nil
        #else
        let jackarooBadge: String? = "COMING SOON"
        #endif

        let jackarooCard = makeGameCard(
            game: .jackaroo,
            title: "JACKAROO",
            imageName: "game2icon",
            badgeText: jackarooBadge
        )

        [pokerCard, jackarooCard].forEach {
            stackView.addArrangedSubview($0)
            gameCards.append($0)
        }
    }

    private func removeExistingStoryboardCards(from stackView: UIStackView) {
        let cardViews = stackView.arrangedSubviews.filter { view in
            view.subviews.contains { $0 is CustomShapeView }
        }

        cardViews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    private func makeGameCard(game: HomeGame,
                              title: String,
                              imageName: String,
                              badgeText: String?) -> UIView {
        let container = UIView()
        container.tag = game.rawValue
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isUserInteractionEnabled = true
        container.isAccessibilityElement = true
        container.accessibilityLabel = badgeText == nil ? title : "\(title), \(badgeText!)"
        container.accessibilityTraits = .button

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapGameCard(_:)))
        container.addGestureRecognizer(tap)

        let backgroundShape = CustomShapeView()
        backgroundShape.translatesAutoresizingMaskIntoConstraints = false
        backgroundShape.slant = 30
        backgroundShape.cornerRadius = 20
        backgroundShape.fillColor = UIColor(red: 0.31, green: 0.26, blue: 0.19, alpha: 1.0)
        container.addSubview(backgroundShape)

        let contentStack = UIStackView()
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(contentStack)

        let artworkView = UIImageView(image: UIImage(named: imageName))
        artworkView.contentMode = .scaleAspectFit
        artworkView.translatesAutoresizingMaskIntoConstraints = false
        artworkView.widthAnchor.constraint(equalToConstant: 100).isActive = true
        artworkView.heightAnchor.constraint(equalToConstant: 100).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .boldSystemFont(ofSize: 17)
        titleLabel.textColor = UIColor(red: 1, green: 0.706, blue: 0.204, alpha: 1)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 4
        textStack.addArrangedSubview(titleLabel)

        if let badgeText {
            let badgeLabel = UILabel()
            badgeLabel.text = badgeText
            badgeLabel.font = .boldSystemFont(ofSize: 10)
            badgeLabel.textColor = UIColor(red: 0.16, green: 0.11, blue: 0.06, alpha: 1)
            badgeLabel.backgroundColor = UIColor(red: 1, green: 0.706, blue: 0.204, alpha: 1)
            badgeLabel.layer.cornerRadius = 7
            badgeLabel.layer.masksToBounds = true
            badgeLabel.textAlignment = .center
            badgeLabel.translatesAutoresizingMaskIntoConstraints = false
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 88).isActive = true
            badgeLabel.heightAnchor.constraint(equalToConstant: 18).isActive = true
            textStack.addArrangedSubview(badgeLabel)
        }

        let buttonView = UIImageView(image: UIImage(named: "blueButton"))
        buttonView.contentMode = .scaleAspectFit
        buttonView.translatesAutoresizingMaskIntoConstraints = false
        buttonView.widthAnchor.constraint(equalToConstant: 52).isActive = true
        buttonView.heightAnchor.constraint(equalToConstant: 50).isActive = true

        contentStack.addArrangedSubview(artworkView)
        contentStack.addArrangedSubview(textStack)
        contentStack.addArrangedSubview(buttonView)

        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 295),
            container.heightAnchor.constraint(equalToConstant: 116),

            backgroundShape.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            backgroundShape.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -15),
            backgroundShape.topAnchor.constraint(equalTo: container.topAnchor, constant: 30),
            backgroundShape.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            contentStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: container.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    private func findGameCardsStackView() -> UIStackView? {
        func findStackView(in view: UIView) -> UIStackView? {
            if let stackView = view as? UIStackView,
               stackView.axis == .vertical,
               stackView.arrangedSubviews.contains(where: { arrangedView in
                   arrangedView.subviews.contains { $0 is CustomShapeView }
               }) {
                return stackView
            }

            for subview in view.subviews {
                if let found = findStackView(in: subview) {
                    return found
                }
            }
            return nil
        }

        return findStackView(in: view)
    }

    private func setupTapGestures() {
        // Treasure chest tap retired with the daily-spin module.
        // treasureChestImage.isUserInteractionEnabled = true
        // treasureChestImage.accessibilityLabel = "Daily spins"
        // treasureChestImage.accessibilityTraits = .button
        //
        // let chestTap = UITapGestureRecognizer(target: self, action: #selector(didTapTreasureChest))
        // treasureChestImage.addGestureRecognizer(chestTap)
    }

    private func setupInitialAnimations() {
        gameCards.forEach { card in
            card.transform = CGAffineTransform(translationX: 0, y: 50).scaledBy(x: 0.8, y: 0.8)
            card.alpha = 0
        }

        for (index, card) in gameCards.enumerated() {
            UIView.animate(
                withDuration: 0.8,
                delay: 0.2 + (Double(index) * 0.2),
                usingSpringWithDamping: 0.7,
                initialSpringVelocity: 0.5
            ) {
                card.transform = .identity
                card.alpha = 1
            }
        }
    }

    // MARK: - UI Update
    private func updateUI() {
        let newCoinText = "\(viewModel.totalCoins)"
        if labelTotalCoins.text != newCoinText {
            animateCoinUpdate(to: newCoinText)
        }
        // Treasure-chest visuals removed — chest is hidden in viewDidLoad.
    }

    @objc private func coinsDidChange() {
        viewModel.fetchUserStats()
        updateUI()
    }

    // MARK: - Actions
    @objc private func didTapGameCard(_ sender: UITapGestureRecognizer) {
        guard let card = sender.view else { return }

        animateGameCardTap(card) {
            switch HomeGame(rawValue: card.tag) {
            case .poker:
                self.openPokerGame()
            case .jackaroo:
                self.openJackarooGame()
            case .none:
                break
            }
        }
    }

    private func openPokerGame() {
        let pokerVC = MenuViewController()
        pokerVC.modalPresentationStyle = .fullScreen

        if let navigationController = navigationController {
            navigationController.pushViewController(pokerVC, animated: true)
        } else {
            present(pokerVC, animated: true)
        }
    }

    private func openJackarooGame() {
        #if DEBUG
        let jackarooVC = JackarooGameViewController()
        #else
        let jackarooVC = ComingSoonViewController(
            title: "Jackaroo",
            subtitle: "This table is being polished for release."
        )
        #endif

        jackarooVC.modalPresentationStyle = .fullScreen
        if let navigationController = navigationController {
            navigationController.pushViewController(jackarooVC, animated: true)
        } else {
            present(jackarooVC, animated: true)
        }
    }

    // Daily-spin entry points retired.
    // private func openDailySpinGame() {
    //     performSegue(withIdentifier: K.toSlotVC, sender: nil)
    // }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
    }

    // @objc private func didTapTreasureChest() {
    //     animateTreasureChestTap {
    //         if self.viewModel.canSpinForCoins {
    //             self.showDailySpinPrompt()
    //         } else {
    //             self.showNoSpinsAlert()
    //         }
    //     }
    // }

    // MARK: - Animations
    private func animateGameCardTap(_ view: UIView, completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.1, animations: {
            view.transform = CGAffineTransform(scaleX: 0.95, y: 0.95).rotated(by: -0.02)
        }) { _ in
            UIView.animate(withDuration: 0.15, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8) {
                view.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            } completion: { _ in
                UIView.animate(withDuration: 0.1) {
                    view.transform = .identity
                } completion: { _ in
                    completion()
                }
            }
        }
    }

    // Treasure-chest tap animation retired with the daily-spin module.
    // private func animateTreasureChestTap(completion: @escaping () -> Void) {
    //     let shakeAnimation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
    //     shakeAnimation.values = [0, -0.1, 0.1, -0.05, 0.05, 0]
    //     shakeAnimation.duration = 0.3
    //     shakeAnimation.repeatCount = 1
    //
    //     UIView.animate(withDuration: 0.1, animations: {
    //         self.treasureChestImage.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
    //     }) { _ in
    //         self.treasureChestImage.layer.add(shakeAnimation, forKey: "shake")
    //         UIView.animate(withDuration: 0.2) {
    //             self.treasureChestImage.transform = .identity
    //         } completion: { _ in
    //             completion()
    //         }
    //     }
    // }

    private func animateCoinUpdate(to newText: String) {
        UIView.animate(withDuration: 0.15, animations: {
            self.labelTotalCoins.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            self.labelTotalCoins.alpha = 0.7
        }) { _ in
            self.labelTotalCoins.text = newText
            self.labelTotalCoins.font = UIFont(name: "Pocket Monk", size: 30)
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
                self.labelTotalCoins.transform = .identity
                self.labelTotalCoins.alpha = 1.0
            }
        }
    }

    // MARK: - Idle Animations
    private func startIdleAnimations() {
        for (index, card) in gameCards.enumerated() {
            animateFloating(card, delay: Double(index))
        }
    }

    private func stopIdleAnimations() {
        gameCards.forEach { $0.layer.removeAllAnimations() }
    }

    private func animateFloating(_ view: UIView, delay: TimeInterval) {
        UIView.animate(withDuration: 2.0, delay: delay, options: [.repeat, .autoreverse, .allowUserInteraction]) {
            view.transform = CGAffineTransform(translationX: 0, y: -8)
        }
    }

    // MARK: - Visual Effects (Daily-spin glow retired)
    // private func addGlowEffect(to view: UIView) {
    //     view.layer.shadowColor = UIColor.systemYellow.cgColor
    //     view.layer.shadowRadius = 10
    //     view.layer.shadowOpacity = 0.6
    //     view.layer.shadowOffset = .zero
    // }
    //
    // private func removeGlowEffect(from view: UIView) {
    //     view.layer.shadowOpacity = 0
    // }

    // MARK: - Daily Spins (retired)
    // private func showDailySpinPrompt() {
    //     guard viewModel.canSpinForCoins else {
    //         showNoSpinsAlert()
    //         return
    //     }
    //
    //     let remaining = viewModel.remainingDailySpins
    //     let noun = remaining == 1 ? "spin" : "spins"
    //     let alert = UIAlertController(
    //         title: "Daily Spins",
    //         message: "Spin to collect free virtual coins.\n\(remaining) \(noun) available today.\n\nCoins have no cash value.",
    //         preferredStyle: .alert
    //     )
    //
    //     let spinAction = UIAlertAction(title: "Go Spin", style: .default) { _ in
    //         self.openDailySpinGame()
    //     }
    //     alert.addAction(spinAction)
    //     alert.addAction(UIAlertAction(title: "Later", style: .cancel))
    //     alert.preferredAction = spinAction
    //
    //     present(alert, animated: true)
    // }
    //
    // private func showNoSpinsAlert() {
    //     let alert = UIAlertController(
    //         title: "Daily Spins",
    //         message: "No spins left today. Come back tomorrow.",
    //         preferredStyle: .alert
    //     )
    //     alert.addAction(UIAlertAction(title: "OK", style: .default))
    //     present(alert, animated: true)
    // }
}
