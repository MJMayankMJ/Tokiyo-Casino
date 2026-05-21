//
//  GameViewControllerSetup.swift
//  Poker
//
//  Restyled to match the Claude Design poker handoff. Uses a soft cream
//  page background, a top info pill, the redesigned felt and action panel.
//

import UIKit

extension GameViewController {

    // MARK: - Setup
    func setupUI() {
        view.backgroundColor = PokerTheme.pageBg

        // Top info bar (back chip + center pill + 3-dot chip)
        let topBar = TopInfoBar()
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)
        topInfoBar = topBar

        // Back chip keeps the legacy menu (New Game / Mute / Exit) since the
        // top-right chip is now a hand-details affordance.
        topBar.backButton.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
        topBar.rulesButton.tintColor = PokerTheme.ink
        topBar.rulesButton.addTarget(self, action: #selector(rulesTapped), for: .touchUpInside)
        topBar.menuButton.tintColor = PokerTheme.ink
        topBar.menuButton.addTarget(self, action: #selector(handDetailsTapped), for: .touchUpInside)
        // Disabled until the first completed hand provides data to show.
        refreshHandDetailsButton()

        // The legacy `menuButton` / `muteButton` ivars are kept off-screen so
        // any cross-references (e.g. audio toggle updates) continue to work.
        menuButton.isHidden = true
        view.addSubview(menuButton)
        muteButton.isHidden = true
        view.addSubview(muteButton)

        // Update menu (mute) icon when the audio code resets it later.
        muteButton.addTarget(self, action: #selector(syncMuteIcon), for: .valueChanged)

        // Table view
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        // Betting controls panel
        bettingControls.translatesAutoresizingMaskIntoConstraints = false
        bettingControls.isHidden = true
        bettingControls.onAction = { [weak self] action in
            self?.handlePlayerAction(action)
        }
        bettingControls.onHeightChanged = { [weak self] height in
            guard let self else { return }
            self.bettingControlsHeightConstraint?.constant = self.bettingControls.isHidden ? 0 : height
            UIView.animate(withDuration: 0.24, delay: 0, options: [.curveEaseInOut]) {
                self.view.layoutIfNeeded()
            }
        }
        view.addSubview(bettingControls)

        // New-hand button.
        newHandButton.setTitle("New Hand", for: .normal)
        newHandButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .heavy)
        newHandButton.setTitleColor(PokerTheme.primaryActionText, for: .normal)
        newHandButton.backgroundColor = PokerTheme.primaryAction
        newHandButton.layer.cornerRadius = 16
        newHandButton.layer.borderWidth = 0
        PokerTheme.applyShadowMd(newHandButton.layer)
        newHandButton.addTarget(self, action: #selector(newHandTapped), for: .touchUpInside)
        newHandButton.translatesAutoresizingMaskIntoConstraints = false
        newHandButton.isHidden = true
        view.addSubview(newHandButton)

        // Initial info text
        topBar.setInfo(
            blinds: "\(gameManager?.smallBlind ?? 10)/\(gameManager?.bigBlind ?? 20)",
            hand: nil,
            phase: nil
        )

        let controlsHeight = bettingControls.heightAnchor.constraint(equalToConstant: 0)
        controlsHeight.priority = .required
        bettingControlsHeightConstraint = controlsHeight

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 48),

            tableView.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bettingControls.topAnchor, constant: -8),

            // Betting controls — intrinsic height (~78 collapsed, ~220 with
            // raise panel expanded) so the felt naturally expands when the
            // slider isn't shown.
            bettingControls.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bettingControls.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bettingControls.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            controlsHeight,

            // Hidden legacy buttons positioned off-screen but in hierarchy
            menuButton.widthAnchor.constraint(equalToConstant: 1),
            menuButton.heightAnchor.constraint(equalToConstant: 1),
            menuButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -10),
            menuButton.topAnchor.constraint(equalTo: view.topAnchor, constant: -10),
            muteButton.widthAnchor.constraint(equalToConstant: 1),
            muteButton.heightAnchor.constraint(equalToConstant: 1),
            muteButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -10),
            muteButton.topAnchor.constraint(equalTo: view.topAnchor, constant: -10),

            newHandButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            newHandButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 60),
            newHandButton.widthAnchor.constraint(equalToConstant: 160),
            newHandButton.heightAnchor.constraint(equalToConstant: 52)
        ])
    }

    @objc func syncMuteIcon() {
        topInfoBar?.menuButton.tintColor = PokerTheme.ink
    }

    func setupGame() {
        gameManager = GameManager(playerCount: playerCount, startingChips: startingChips)
        gameManager.delegate = self

        topInfoBar?.setInfo(
            blinds: "\(gameManager.smallBlind)/\(gameManager.bigBlind)",
            hand: nil,
            phase: nil
        )

        // Start first hand after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startNewHand()
        }
    }

    func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showDelayedWinnerAlert(_:)),
            name: NSNotification.Name("ShowWinnerAlert"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(soundSettingChanged),
            name: NSNotification.Name("SoundSettingChanged"),
            object: nil
        )
    }
}
