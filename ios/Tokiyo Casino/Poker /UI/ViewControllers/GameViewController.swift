//
//  GameViewController.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import UIKit

class GameViewController: UIViewController {
    
    // MARK: - Properties
    var gameManager: GameManager!
    let tableView = PokerTableView()
    let bettingControls = BettingControlsView()
    let menuButton = UIButton(type: .system)
    let newHandButton = UIButton(type: .system)
    let muteButton = UIButton(type: .system)
    var topInfoBar: TopInfoBar?
    var bettingControlsHeightConstraint: NSLayoutConstraint?
    
    // Sound Manager for BGM
    var bgmManager = SoundManager()

    // Round-result sounds — kept alive on `self` so AVAudioPlayer outlives
    // the local scope that started playback.
    var winSoundManager = SoundManager()
    var loseSoundManager = SoundManager()
    
    // Game settings
    let playerCount: Int
    let startingChips: Int
    /// Phase 2 — difficulty/style for AI seats, chosen on the setup screen.
    let aiConfig: PokerAIConfig
    
    // 🟡 Cash-out state
    let initialBuyIn: Int        // remember what the human brought to the table
    var hasSettledCoins = false  // make sure we only settle once
    
    // Track winners for summary
    var handWinners: [(player: Player, amount: Int, handDescription: String)] = []

    // Pending coalesced round-result presentation (cancelled if another
    // winner notification arrives within the dedupe window).
    var pendingResultWork: DispatchWorkItem?

    // Whether the session is presenting the round-end banner moment.
    var isShowingRoundResult: Bool = false

    // Most recent completed hand's full breakdown — surfaced by the
    // top-right info button.
    var lastHandSummary: GameViewController.LastHandSummary?

    // Gates the top-right details button until at least one hand has finished.
    var hasCompletedFirstHand: Bool = false

    struct LastHandSummary {
        let playerSummaries: [PlayerSummary]
        let totalPot: Int
        let communityCards: [Card]
    }
    
    // MARK: - Initialization
    init(playerCount: Int = 6, startingChips: Int = 1000,
         aiConfig: PokerAIConfig = PokerAIConfigStore.load()) {
        self.playerCount = playerCount
        self.startingChips = startingChips
        self.initialBuyIn = startingChips
        self.aiConfig = aiConfig
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
        // Make sure seats are present after the first layout pass — once.
        if let gm = gameManager, tableView.playerViews.isEmpty {
            tableView.setupPlayers(gm.players, dealerIndex: gm.dealerIndex)
        }
    }
    
    deinit {
        // Defensive: if someone dismisses without tapping our menu hooks
        settleCoinsIfNeeded()
        NotificationCenter.default.removeObserver(self)
    }
}
