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
    
    // Game settings
    private let playerCount: Int
    private let startingChips: Int
    
    // Track winners for summary
    private var handWinners: [(player: Player, amount: Int, handDescription: String)] = []
    
    // MARK: - Initialization
    init(playerCount: Int = 6, startingChips: Int = 1000) {
        self.playerCount = playerCount
        self.startingChips = startingChips
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
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.setupPlayers(gameManager.players, dealerIndex: gameManager.dealerIndex)
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
        
        // After all winner notifications are received, show the summary
        // (This assumes the game sends all notifications before we need to show the summary)
        // For a more robust solution, you might want to add a separate notification for "AllWinnersProcessed"
        
        // For now, we'll show the summary after a small delay to ensure all winners are collected
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showGameSummary()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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
        
        summaryVC.onMenu = { [weak self] in
            self?.dismiss(animated: true)
        }
        
        present(summaryVC, animated: true)
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
        print("Player did win called for: \(player.name)")
        
        // This now only handles the animation, not the alert
        addSuccessFeedback()
        tableView.showWinner(player)
        
        // The alert/summary is handled by notification system
    }
    
    func gameDidEnd() {
        print("GameViewController: gameDidEnd called")
        
        addHapticFeedback(.medium)
        
        // Hide betting controls immediately and reset position
        hideBettingControls()
        
        // Print all players and their card states
        for player in gameManager.players {
            print("GameViewController: Player \(player.name) - Cards: \(player.holeCards.map { $0.description }.joined(separator: ", ")), Folded: \(player.isFolded)")
        }
        
        // Reveal all cards
        print("GameViewController: Calling tableView.revealAllCards()")
        tableView.revealAllCards()
        
        // Add staggered haptic feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.addHapticFeedback(.light)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.addHapticFeedback(.light)
        }
    }
    
    func cardsDealt() {
        addHapticFeedback(.light)
        tableView.showCommunityCards(gameManager.communityCards)
        tableView.updatePlayers(gameManager.players, dealerIndex: gameManager.dealerIndex)
        
        // Special haptic for community cards
        if !gameManager.communityCards.isEmpty {
            let cardCount = gameManager.communityCards.count
            if cardCount == 3 { // Flop
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self.addHapticFeedback(.medium)
                }
            } else if cardCount == 4 || cardCount == 5 { // Turn or River
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.addHapticFeedback(.light)
                }
            }
        }
    }
    
    func potDidUpdate(_ amount: Int) {
        addHapticFeedback(.light)
        tableView.updatePot(amount)
    }
    
    func currentPlayerChanged(_ player: Player) {
        addHapticFeedback(.light)
        tableView.highlightCurrentPlayer(player)

        // If current player is human
        if player.isHuman {
            // Hide betting controls if player is all-in
            if player.isAllIn {
                bettingControls.isHidden = true
                print("Human player is all-in — auto-check enforced.")
                return
            }

            // Otherwise show betting controls
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.showBettingControls()
            }
        }
    }
}
