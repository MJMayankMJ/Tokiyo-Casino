//
//  GameViewController.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import UIKit

class GameViewController: UIViewController {
    
    // MARK: - Properties
    private var gameManager: GameManager!
    private let tableView = PokerTableView()
    private let bettingControls = BettingControlsView()
    private let menuButton = UIButton(type: .system)
    private let newHandButton = UIButton(type: .system)
    private let muteButton = UIButton(type: .system)
    
    // Sound Manager for BGM
    private var bgmManager = SoundManager()
    
    // Game settings
    private let playerCount: Int
    private let startingChips: Int
    
    // 🟡 Cash-out state
    private let initialBuyIn: Int        // remember what the human brought to the table
    private var hasSettledCoins = false  // make sure we only settle once
    
    // Track winners for summary
    private var handWinners: [(player: Player, amount: Int, handDescription: String)] = []
    
    // MARK: - Initialization
    init(playerCount: Int = 6, startingChips: Int = 1000) {
        self.playerCount = playerCount
        self.startingChips = startingChips
        self.initialBuyIn = startingChips
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGame()
        setupNotifications()
        setupBGM()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        playBGM()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pauseBGM()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.setupPlayers(gameManager.players, dealerIndex: gameManager.dealerIndex)
    }
    
    deinit {
        // Defensive: if someone dismisses without tapping our menu hooks
        settleCoinsIfNeeded()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.05, green: 0.15, blue: 0.05, alpha: 1.0)
        
        // Table view
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        // Betting controls
        bettingControls.translatesAutoresizingMaskIntoConstraints = false
        bettingControls.isHidden = true
        bettingControls.onAction = { [weak self] action in
            self?.handlePlayerAction(action)
        }
        view.addSubview(bettingControls)
        
        // Menu button
        menuButton.setTitle("Menu", for: .normal)
        menuButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        menuButton.setTitleColor(.white, for: .normal)
        menuButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        menuButton.layer.cornerRadius = 10
        menuButton.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(menuButton)
        
        // Mute button
        muteButton.setImage(getMuteButtonImage(), for: .normal)
        muteButton.tintColor = .white
        muteButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        muteButton.layer.cornerRadius = 20
        muteButton.addTarget(self, action: #selector(muteTapped), for: .touchUpInside)
        muteButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(muteButton)
        
        // New hand button
        newHandButton.setTitle("New Hand", for: .normal)
        newHandButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        newHandButton.setTitleColor(.white, for: .normal)
        newHandButton.backgroundColor = UIColor.green.withAlphaComponent(0.8)
        newHandButton.layer.cornerRadius = 12
        newHandButton.layer.borderWidth = 2
        newHandButton.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        newHandButton.addTarget(self, action: #selector(newHandTapped), for: .touchUpInside)
        newHandButton.translatesAutoresizingMaskIntoConstraints = false
        newHandButton.isHidden = true
        view.addSubview(newHandButton)
        
        NSLayoutConstraint.activate([
            // Table view
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // Betting controls - more padding and height
            bettingControls.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            bettingControls.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            bettingControls.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 30),
            bettingControls.heightAnchor.constraint(equalToConstant: 200),
            
            // Menu button
            menuButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            menuButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            menuButton.widthAnchor.constraint(equalToConstant: 90),
            menuButton.heightAnchor.constraint(equalToConstant: 40),
            
            // Mute button
            muteButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            muteButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            muteButton.widthAnchor.constraint(equalToConstant: 40),
            muteButton.heightAnchor.constraint(equalToConstant: 40),
            
            // New hand button
            newHandButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            newHandButton.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 100),
            newHandButton.widthAnchor.constraint(equalToConstant: 140),
            newHandButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func setupGame() {
        gameManager = GameManager(playerCount: playerCount, startingChips: startingChips)
        gameManager.delegate = self
        
        // Start first hand after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startNewHand()
        }
    }
    
    private func setupNotifications() {
        // Listen for delayed winner alerts
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showDelayedWinnerAlert(_:)),
            name: NSNotification.Name("ShowWinnerAlert"),
            object: nil
        )
        
        // Listen for sound setting changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(soundSettingChanged),
            name: NSNotification.Name("SoundSettingChanged"),
            object: nil
        )
    }
    
    // MARK: - BGM Setup
    private func setupBGM() {
        bgmManager.setupPlayer(soundName: "casino_bgm", soundType: .mp3)
        bgmManager.volume(0.3)
    }
    
    private func playBGM() {
        // Loop indefinitely (-1 means infinite loop)
        bgmManager.play(-1)
    }
    
    private func pauseBGM() {
        bgmManager.pause()
    }
    
    private func getMuteButtonImage() -> UIImage? {
        let imageName = SoundManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        return UIImage(systemName: imageName)
    }
    
    @objc private func soundSettingChanged() {
        // Update mute button icon
        muteButton.setImage(getMuteButtonImage(), for: .normal)
        
        // Handle BGM based on mute state
        if SoundManager.isMuted {
            pauseBGM()
        } else {
            playBGM()
        }
    }
    
    @objc private func showDelayedWinnerAlert(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let player = userInfo["player"] as? Player,
              let amount = userInfo["amount"] as? Int,
              let handDescription = userInfo["handDescription"] as? String else {
            return
        }
        
        // Store winner info for the summary
        handWinners.append((player: player, amount: amount, handDescription: handDescription))
        
        // Show the summary after a small delay to ensure all winners are collected
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showGameSummary()
        }
    }
    
    // MARK: - Haptics
    private func addHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }

    private func addSuccessFeedback() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }

    private func addErrorFeedback() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    // MARK: - Game Actions
    private func startNewHand() {
        newHandButton.isHidden = true
        bettingControls.isHidden = true
        handWinners = [] // Reset winners for new hand
        
        // Reset human player position
        tableView.adjustHumanPlayerPosition(shiftUp: false)
        
        // Clear table with animation
        tableView.clearTable()
        
        // Add preparation haptic
        addHapticFeedback(.medium)
        
        // Start new hand after table is cleared
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.gameManager.startNewHand()
        }
    }
    
    private func handlePlayerAction(_ action: PlayerAction) {
        guard let currentPlayer = gameManager.currentPlayer,
              currentPlayer.isHuman else { return }
        
        // Hide controls immediately to prevent double-clicking or UI glitches
        bettingControls.isHidden = true
        gameManager.processPlayerAction(action, for: currentPlayer)
    }
    
    private func showBettingControls() {
        guard let humanPlayer = gameManager.humanPlayer,
              humanPlayer.id == gameManager.currentPlayer?.id else { return }
        
        let validActions = gameManager.getValidActions(for: humanPlayer)
        let callAmount = gameManager.currentBet - humanPlayer.currentBet
        let minRaise = gameManager.minRaise
        let maxRaise = humanPlayer.chips
        
        // Shift human player view up to make space for betting controls
        tableView.adjustHumanPlayerPosition(shiftUp: true)
        
        // Small delay to let player view animate first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.bettingControls.updateForActions(
                validActions,
                callAmount: callAmount,
                minRaise: minRaise,
                maxRaise: maxRaise
            )
            self.bettingControls.isHidden = false
        }
    }
    
    private func hideBettingControls() {
        bettingControls.isHidden = true
        
        // Reset human player position with animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.tableView.adjustHumanPlayerPosition(shiftUp: false)
        }
    }
    
    // MARK: - Game Summary
    private func showGameSummary() {
        guard !handWinners.isEmpty else { return }
        
        // Create player summaries
        var summaries: [PlayerSummary] = []
        
        for player in gameManager.players {
            let category: PlayerSummary.PlayerCategory
            var handDescription: String?
            
            // Determine category
            if let winnerInfo = handWinners.first(where: { $0.player.id == player.id }) {
                category = .winner
                handDescription = winnerInfo.handDescription
            } else if player.isFolded {
                category = .folded
            } else {
                category = .lost
                // Evaluate hand for lost players
                let allCards = player.holeCards + gameManager.communityCards
                let evaluation = HandEvaluator.evaluateBestHand(from: allCards)
                handDescription = evaluation.description
            }
            
            summaries.append(PlayerSummary(
                player: player,
                handDescription: handDescription,
                category: category
            ))
        }
        
        // Create and present summary view controller
        let summaryVC = GameSummaryViewController(
            playerSummaries: summaries,
            totalPot: handWinners.reduce(0) { $0 + $1.amount }, // Total pot from all winners
            communityCards: gameManager.communityCards
        )
        
        summaryVC.modalPresentationStyle = .fullScreen
        
        summaryVC.onNewGame = { [weak self] in
            self?.startNewHand()
        }
        
        // ⬇️ When leaving to Menu from the summary, settle net chips → coins
        summaryVC.onMenu = { [weak self] in
            self?.settleCoinsIfNeeded()
            self?.dismiss(animated: true)
        }
        
        present(summaryVC, animated: true)
    }
    
    // MARK: - Coins settlement (Poker $ ↔︎ Tokyo Coins 1:1)
    private func settleCoinsIfNeeded() {
        guard !hasSettledCoins,
              let human = gameManager?.humanPlayer else { return }
        
        let delta = human.chips - initialBuyIn    // net won/lost in dollars == coins
        hasSettledCoins = true
        
        if delta > 0 {
            CoinsManager.shared.addCoins(amount: Int64(delta)) { _ in }
        } else if delta < 0 {
            CoinsManager.shared.deductCoins(amount: Int64(-delta)) { _ in }
        }
    }
    
    // MARK: - Actions
    @objc private func menuTapped() {
        addHapticFeedback(.light)
        
        let alert = UIAlertController(title: "Menu", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "New Game", style: .default) { [weak self] _ in
            self?.addHapticFeedback(.medium)
            self?.setupGame()
        })
        
        alert.addAction(UIAlertAction(title: "Exit to Menu", style: .default) { [weak self] _ in
            // 💰 Settle coins when exiting the Poker screen
            self?.settleCoinsIfNeeded()
            self?.addHapticFeedback(.medium)
            self?.dismiss(animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            self.addHapticFeedback(.light)
        })
        
        present(alert, animated: true)
    }

    @objc private func newHandTapped() {
        addHapticFeedback(.medium)
        startNewHand()
    }
    
    @objc private func muteTapped() {
        addHapticFeedback(.light)
        SoundManager.setMuted(!SoundManager.isMuted)
    }
}

// MARK: - GameManagerDelegate
extension GameViewController: GameManagerDelegate {
    func gameDidStart() {
        addHapticFeedback(.light)
        tableView.updatePlayers(gameManager.players, dealerIndex: gameManager.dealerIndex)
    }
    
    func gamePhaseDidChange(_ phase: GamePhase) {
        addHapticFeedback(.light)
        tableView.updatePhase(phase)
        
        // Special effects for showdown
        if phase == .showdown {
            addHapticFeedback(.heavy)
        }
    }
    
    func playerDidAct(_ player: Player, action: PlayerAction) {
        // Different haptics for different actions
        switch action {
        case .fold:
            addHapticFeedback(.medium)
        case .check:
            addHapticFeedback(.light)
        case .call:
            addHapticFeedback(.light)
        case .raise:
            addHapticFeedback(.heavy)
        case .allIn:
            addHapticFeedback(.heavy)
            // Add a second haptic for all-in emphasis
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.addHapticFeedback(.heavy)
            }
        }
        
        tableView.showPlayerAction(player, action: action)
        tableView.updatePlayers(gameManager.players, dealerIndex: gameManager.dealerIndex)
    }
    
    func playerDidWin(_ player: Player, amount: Int, handDescription: String) {
        // Animation only; summary/alerts triggered later
        addSuccessFeedback()
        tableView.showWinner(player)
    }
    
    func gameDidEnd() {
        addHapticFeedback(.medium)
        
        // Hide betting controls immediately and reset position
        hideBettingControls()
        
        // Reveal all cards (human + AI)
        tableView.revealAllCards()
        
        // Little staggered haptics for flare
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.addHapticFeedback(.light) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.addHapticFeedback(.light) }
    }
    
    func cardsDealt() {
        addHapticFeedback(.light)
        tableView.showCommunityCards(gameManager.communityCards)
        tableView.updatePlayers(gameManager.players, dealerIndex: gameManager.dealerIndex)
    }
    
    func potDidUpdate(_ amount: Int) {
        addHapticFeedback(.light)
        tableView.updatePot(amount)
    }
    
    func currentPlayerChanged(_ player: Player) {
        addHapticFeedback(.light)
        tableView.highlightCurrentPlayer(player)

        if player.isHuman {
            if player.isAllIn {
                bettingControls.isHidden = true
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.showBettingControls()
            }
        }
    }
}

