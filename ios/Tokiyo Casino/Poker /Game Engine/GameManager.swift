//
//  GameManager.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import Foundation

// MARK: - Texas Hold'em Game Manager
class GameManager {
    
    // MARK: - Properties
    weak var delegate: GameManagerDelegate?
    
    var players: [Player] = []
    var deck: Deck = Deck()
    var communityCards: [Card] = []
    var mainPot: Pot = Pot()
    var currentPhase: GamePhase = .waiting
    
    private(set) var dealerIndex: Int = 0
    var currentPlayerIndex: Int = 0
    var smallBlind: Int = 10
    var bigBlind: Int = 20
    var currentBet: Int = 0
    var minRaise: Int = 20
    var lastRaiseAmount: Int = 0
    var currentBetAllowsRaises: Bool = true
    var bigBlindPlayerSeatIndex: Int?
    /// True once any player has raised above the big blind during pre-flop this
    /// hand. Consumed by the AI's equity calculation to tighten the assumed
    /// opponent range in raised pots (see AIEngine / EquityCalculator).
    var handWasRaisedPreflop: Bool = false

    /// Phase 2 — difficulty/style configuration for the AI seats. Set by the
    /// setup flow (solo) or host service (multiplayer); `applyAIConfigToAISeats`
    /// turns it into a concrete per-seat `AIProfile`. Defaults to medium/auto-mix
    /// so a manager created without explicit config still behaves reasonably.
    var aiConfig: PokerAIConfig = .default

    // Game settings
    let startingChips: Int
    let playerCount: Int
    private(set) var expectedTotalChips: Int
    
    // MARK: - Computed Properties
    var activePlayers: [Player] {
        // FIX: Removed '&& $0.chips > 0'.
        // All-In players have 0 chips but are still active in the hand.
        return players.filter { $0.isActive && !$0.isFolded }
    }
    
    var currentPlayer: Player? {
        guard currentPlayerIndex >= 0 && currentPlayerIndex < activePlayers.count else { return nil }
        return activePlayers[currentPlayerIndex]
    }
    
    var humanPlayer: Player? {
        return players.first { $0.isHuman }
    }
    
    // MARK: - Initialization
    init(playerCount: Int, startingChips: Int = 1000) {
        self.playerCount = playerCount
        self.startingChips = startingChips
        self.expectedTotalChips = playerCount * startingChips
        setupPlayers()
    }

    /// Multiplayer-friendly initializer. Skips the default solo roster so
    /// the host service can install a custom seat layout (mix of human
    /// peers, the host themselves, and AI fill) before the first hand.
    init(seats: [Player], smallBlind: Int, bigBlind: Int, startingChips: Int) {
        self.playerCount = seats.count
        self.startingChips = startingChips
        self.players = seats
        self.smallBlind = smallBlind
        self.bigBlind = bigBlind
        self.minRaise = bigBlind
        self.lastRaiseAmount = bigBlind
        self.expectedTotalChips = seats.reduce(0) { $0 + $1.chips }
    }

    func setupPlayers() {
        players = []

        // Add human player
        players.append(Player(id: 0, name: "You", type: .human, chips: startingChips))

        // Add AI players with varied personalities
        let personalities = AIPersonality.allCases
        for i in 1..<playerCount {
            let personality = personalities[i % personalities.count]
            let aiPlayer = Player(
                id: i,
                name: "\(personality.avatar) \(personality.name)",
                type: .ai(personality: personality),
                chips: startingChips
            )
            players.append(aiPlayer)
        }
    }

    func adjustExpectedChipTotal(by delta: Int) {
        expectedTotalChips += delta
    }

    /// Phase 2 — resolve `aiConfig` into a concrete `AIProfile` for every AI
    /// seat. Personalities still drive the visible name/avatar; behaviour now
    /// comes from the installed profile. Call after the roster exists and any
    /// time `aiConfig` changes. Safe to call repeatedly.
    func applyAIConfigToAISeats() {
        let aiSeats = players.filter { !$0.isHuman }
        let profiles = aiConfig.resolvedProfiles(aiSeatCount: aiSeats.count)
        for (seat, profile) in zip(aiSeats, profiles) {
            seat.aiProfile = profile
        }
    }
    
    // MARK: - Game Control
    func startNewHand() {
        // Chip conservation check (debug only)
        #if DEBUG
        let totalChips = players.reduce(0) { $0 + $1.chips } + mainPot.amount
        let expected = expectedTotalChips
        assert(totalChips == expected,
               "CHIP LEAK: total=\(totalChips) expected=\(expected)")
        #endif
        
        resetForNewHand()
        guard activePlayers.count >= 2 else {
            currentPhase = .waiting
            delegate?.gamePhaseDidChange(currentPhase)
            return
        }
        
        dealHoleCards()
        postBlinds()
        
        currentPhase = .preFlop
        delegate?.gamePhaseDidChange(currentPhase)
        delegate?.gameDidStart()
        
        // Set current player (left of the actual big blind)
        if let bigBlindPlayerSeatIndex {
            currentPlayerIndex = findNextActivePlayerIndex(afterSeatIndex: bigBlindPlayerSeatIndex)
        } else {
            currentPlayerIndex = findFirstActivePlayerAfterDealer()
        }
        
        // Process AI turns if needed
        processNextTurn()
    }
    
    func resetForNewHand() {
        deck.reset()
        communityCards = []
        mainPot.reset()
        currentBet = 0
        lastRaiseAmount = bigBlind
        minRaise = bigBlind
        currentBetAllowsRaises = true
        bigBlindPlayerSeatIndex = nil
        handWasRaisedPreflop = false

        for player in players {
            player.reset()
        }
        
        // Move dealer button
        dealerIndex = findNextInHandSeat(afterSeatIndex: dealerIndex) ?? ((dealerIndex + 1) % players.count)
    }
}
