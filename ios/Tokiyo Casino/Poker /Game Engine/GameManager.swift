//
//  GameManager.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import Foundation

// MARK: - Game Phase
enum GamePhase {
    case waiting
    case preFlop
    case flop
    case turn
    case river
    case showdown
    
    var description: String {
        switch self {
        case .waiting: return "Waiting"
        case .preFlop: return "Pre-Flop"
        case .flop: return "Flop"
        case .turn: return "Turn"
        case .river: return "River"
        case .showdown: return "Showdown"
        }
    }
}

// MARK: - Pot Structure
struct Pot {
    var amount: Int = 0
    var eligiblePlayers: [Player] = []
    
    mutating func add(_ chips: Int) {
        amount += chips
    }
    
    mutating func reset() {
        amount = 0
        eligiblePlayers = []
    }
}

// MARK: - Game Manager Protocol
protocol GameManagerDelegate: AnyObject {
    func gameDidStart()
    func gamePhaseDidChange(_ phase: GamePhase)
    func playerDidAct(_ player: Player, action: PlayerAction)
    func playerDidWin(_ player: Player, amount: Int, handDescription: String)
    func gameDidEnd()
    func cardsDealt()
    func potDidUpdate(_ amount: Int)
    func currentPlayerChanged(_ player: Player)
}

// MARK: - Texas Hold'em Game Manager
class GameManager {
    
    // MARK: - Properties
    weak var delegate: GameManagerDelegate?
    
    private(set) var players: [Player] = []
    private var deck: Deck = Deck()
    private(set) var communityCards: [Card] = []
    private(set) var mainPot: Pot = Pot()
    private var sidePots: [Pot] = []
    private(set) var currentPhase: GamePhase = .waiting
    
    private(set) var dealerIndex: Int = 0
    private var currentPlayerIndex: Int = 0
    private var smallBlind: Int = 10
    private var bigBlind: Int = 20
    private(set) var currentBet: Int = 0
    private(set) var minRaise: Int = 20
    private var lastRaiseAmount: Int = 0
    
    // Game settings
    private let startingChips: Int
    private let playerCount: Int
    
    // MARK: - Computed Properties
    var activePlayers: [Player] {
        return players.filter { $0.isActive && !$0.isFolded }
    }
    
    var currentPlayer: Player? {
        guard currentPlayerIndex >= 0 && currentPlayerIndex < activePlayers.count else { return nil }
        return activePlayers[currentPlayerIndex]
    }
    
    var humanPlayer: Player? {
        return players.first { $0.isHuman }
    }
    
    var pot: Int {
        return mainPot.amount
    }
    
    // MARK: - Initialization
    init(playerCount: Int, startingChips: Int = 1000) {
        self.playerCount = playerCount
        self.startingChips = startingChips
        setupPlayers()
    }
    
    private func setupPlayers() {
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
    
    // MARK: - Game Control
    func startNewHand() {
        resetForNewHand()
        dealHoleCards()
        postBlinds()
        
        currentPhase = .preFlop
        delegate?.gamePhaseDidChange(currentPhase)
        delegate?.gameDidStart()
        
        // Set current player (after big blind)
        currentPlayerIndex = findNextActivePlayerIndex(after: 2)
        
        // Process AI turns if needed
        processNextTurn()
    }
    
    private func resetForNewHand() {
        deck.reset()
        communityCards = []
        mainPot.reset()
        sidePots = []
        currentBet = 0
        lastRaiseAmount = bigBlind
        minRaise = bigBlind
        
        for player in players {
            player.reset()
        }
        
        // Move dealer button
        dealerIndex = (dealerIndex + 1) % players.count
    }
    
    private func dealHoleCards() {
        print("Dealing hole cards to \(players.count) players")
        
        // Deal two cards to each active player
        for round in 0..<2 {
            for player in players where player.chips > 0 && !player.isFolded {
                if let card = deck.deal() {
                    player.holeCards.append(card)
                    print("Dealt \(card.description) to \(player.name)")
                } else {
                    print("Error: No more cards in deck!")
                }
            }
        }
        
        delegate?.cardsDealt()
    }
    
    private func postBlinds() {
        let sbIndex = (dealerIndex + 1) % players.count
        let bbIndex = (dealerIndex + 2) % players.count
        
        // Small blind
        let sbPlayer = players[sbIndex]
        let sbAmount = sbPlayer.bet(amount: smallBlind)
        mainPot.add(sbAmount)
        
        // Big blind
        let bbPlayer = players[bbIndex]
        let bbAmount = bbPlayer.bet(amount: bigBlind)
        mainPot.add(bbAmount)
        
        currentBet = bigBlind
        delegate?.potDidUpdate(mainPot.amount)
    }
    
    private func executeAction(_ action: PlayerAction, for player: Player) {
        player.lastAction = action
        
        switch action {
        case .fold:
            player.isFolded = true
            player.isActive = false
            
        case .check:
            break
            
        case .call:
            let callAmount = min(currentBet - player.currentBet, player.chips)
            let betAmount = player.bet(amount: callAmount)
            mainPot.add(betAmount)
            delegate?.potDidUpdate(mainPot.amount)
            
        case .raise(let amount):
            let totalBet = currentBet + amount
            let raiseAmount = totalBet - player.currentBet
            let actualBet = player.bet(amount: raiseAmount)
            mainPot.add(actualBet)
            
            currentBet = player.currentBet
            lastRaiseAmount = amount
            minRaise = amount
            
            for p in activePlayers where p.id != player.id {
                p.hasActed = false
            }
            
            delegate?.potDidUpdate(mainPot.amount)
            
        case .allIn:
            let allInAmount = player.chips
            let betAmount = player.bet(amount: allInAmount)
            mainPot.add(betAmount)
            
            if player.currentBet > currentBet {
                currentBet = player.currentBet
                lastRaiseAmount = currentBet - player.currentBet
                minRaise = lastRaiseAmount
                
                for p in activePlayers where p.id != player.id {
                    p.hasActed = false
                }
            }
            
            player.isAllIn = true
            delegate?.potDidUpdate(mainPot.amount)
        }
        
        player.hasActed = true
    }
    
    private func processNextTurn() {
        guard !activePlayers.isEmpty else {
            endBettingRound()
            return
        }
        
        guard let current = currentPlayer else {
            endBettingRound()
            return
        }
        
        if current.isAllIn || current.isFolded {
            let bettingPlayers = activePlayers.filter { !$0.isAllIn && !$0.isFolded }
            
            if bettingPlayers.isEmpty {
                endBettingRound()
            } else {
                currentPlayerIndex = findNextActivePlayerIndex(after: currentPlayerIndex)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.processNextTurn()
                }
            }
            return
        }
        
        delegate?.currentPlayerChanged(current)
        
        if current.isHuman {
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.processAITurn()
        }
    }
    
    private func processAITurn() {
        guard let current = currentPlayer,
              let personality = current.personality else { return }
        
        let gameState = GameState(
            pot: mainPot.amount,
            currentBet: currentBet,
            minRaise: minRaise,
            communityCards: communityCards,
            activePlayers: activePlayers,
            dealerIndex: dealerIndex
        )
        
        let decision = AIEngine.makeDecision(
            for: current,
            gameState: gameState,
            personality: personality
        )
        
        processPlayerAction(decision, for: current)
    }
    
    private func moveToNextPlayer() {
        currentPlayerIndex = findNextActivePlayerIndex(after: currentPlayerIndex)
    }
    
    private func findNextActivePlayerIndex(after index: Int) -> Int {
        let active = activePlayers
        guard !active.isEmpty else { return -1 }
        
        var nextIndex = (index + 1) % active.count
        var attempts = 0
        
        while attempts < active.count {
            let player = active[nextIndex]
            if !player.isAllIn && !player.isFolded {
                return nextIndex
            }
            nextIndex = (nextIndex + 1) % active.count
            attempts += 1
        }
        
        return -1
    }
    
    // MARK: - Betting Round Management
    private func shouldEndBettingRound() -> Bool {
        let activeBettingPlayers = activePlayers.filter { !$0.isAllIn }
        
        if activePlayers.count <= 1 {
            return true
        }
        
        if activeBettingPlayers.isEmpty {
            return true
        }
        
        for player in activeBettingPlayers {
            if !player.hasActed || (player.currentBet < currentBet && !player.isAllIn) {
                return false
            }
        }
        
        return true
    }
    
    func validateGameState() -> Bool {
        let playersWithChips = players.filter { $0.chips > 0 }
        if playersWithChips.count < 2 {
            print("Game over: Not enough players with chips")
            return false
        }
        
        if deck.remainingCards < 10 {
            print("Warning: Running low on cards (\(deck.remainingCards) remaining)")
        }
        
        return true
    }
    
    func printGameState() {
        print("=== Game State ===")
        print("Phase: \(currentPhase)")
        print("Pot: $\(mainPot.amount)")
        print("Current bet: $\(currentBet)")
        print("Community cards: \(communityCards.map { $0.description }.joined(separator: ", "))")
        print("Active players: \(activePlayers.count)")
        for player in players {
            let status = player.isFolded ? "FOLDED" : player.isAllIn ? "ALL-IN" : "ACTIVE"
            print("  \(player.name): $\(player.chips) (\(status)) - Bet: $\(player.currentBet)")
        }
        print("================")
    }
    
    private func determineWinners() {
        print("Starting showdown")
        
        var playerHands: [(Player, HandEvaluation)] = []
        
        for player in activePlayers {
            let allCards = player.holeCards + communityCards
            let evaluation = HandEvaluator.evaluateBestHand(from: allCards)
            playerHands.append((player, evaluation))
            
            print("\(player.name): \(player.holeCards.map { $0.description }.joined(separator: ", ")) -> \(evaluation.description)")
        }
        
        playerHands.sort { $0.1.value > $1.1.value }
        
        guard !playerHands.isEmpty else { return }
        
        let winningValue = playerHands[0].1.value
        let winners = playerHands.filter { $0.1.value == winningValue }
        
        print("Winners: \(winners.map { $0.0.name }.joined(separator: ", "))")
        
        let potShare = mainPot.amount / winners.count
        
        for (player, evaluation) in winners {
            player.win(amount: potShare)
            delegate?.playerDidWin(player, amount: potShare, handDescription: evaluation.description)
        }
    }
    
    // MARK: - Valid Actions
    func getValidActions(for player: Player) -> [PlayerAction] {
        var actions: [PlayerAction] = []
        
        let callAmount = currentBet - player.currentBet
        
        if callAmount == 0 {
            actions.append(.check)
            if player.chips >= minRaise {
                actions.append(.raise(minRaise))
            }
        } else {
            actions.append(.fold)
            if player.chips >= callAmount {
                actions.append(.call)
                if player.chips > callAmount + minRaise {
                    actions.append(.raise(minRaise))
                }
            }
        }
        
        if player.chips > 0 {
            actions.append(.allIn)
        }
        
        return actions
    }
}

// MARK: - Enhanced Showdown
extension GameManager {
    
    private func showdown() {
        currentPhase = .showdown
        delegate?.gamePhaseDidChange(currentPhase)
        
        // Deal final cards if needed
        dealRemainingCommunityCards()
        
        // Reveal all non-folded players' cards
        DispatchQueue.main.async {
            self.delegate?.gameDidEnd()
        }
        
        // Wait before calculating winners (4 seconds to show cards)
        let revealDelay: TimeInterval = 4.0
        DispatchQueue.main.asyncAfter(deadline: .now() + revealDelay) {
            self.determineWinnersWithDelay()
        }
    }
    
    private func dealRemainingCommunityCards() {
        print("Dealing remaining community cards. Current count: \(communityCards.count)")
        
        while communityCards.count < 5 {
            if communityCards.count > 0 {
                _ = deck.deal()
            }
            
            if let card = deck.deal() {
                communityCards.append(card)
                print("Dealt community card: \(card.description)")
            } else {
                print("No more cards in deck!")
                break
            }
        }
        
        delegate?.cardsDealt()
    }
    
    private func revealAllPlayerCards() {
        print("Revealing all player cards")
        delegate?.gameDidEnd()
    }
    
    private func determineWinnersWithDelay() {
        print("Determining winners with side pot logic")
        
        var candidates = players.filter { !$0.isFolded }
        
        var playerStrengths: [(Player, HandEvaluation)] = []
        for player in candidates {
            let allCards = player.holeCards + communityCards
            let evaluation = HandEvaluator.evaluateBestHand(from: allCards)
            playerStrengths.append((player, evaluation))
        }
        
        playerStrengths.sort { $0.1.value > $1.1.value }
        
        var remainingPot = mainPot.amount
        
        while remainingPot > 0 && !playerStrengths.isEmpty {
            let bestValue = playerStrengths[0].1.value
            let winners = playerStrengths.filter { $0.1.value == bestValue }
            
            if winners.isEmpty { break }
            
            let minInvestedAmongWinners = winners.map { $0.0.totalInvested }.min() ?? 0
            
            var sidePot = 0
            for p in players {
                let contribution = min(p.totalInvested, minInvestedAmongWinners)
                sidePot += contribution
                p.totalInvested -= contribution
            }
            
            remainingPot -= sidePot
            
            let share = sidePot / winners.count
            for (winner, evaluation) in winners {
                winner.win(amount: share)
                
                // Just notify delegate, no alerts
                if share > 0 {
                    delegate?.playerDidWin(winner, amount: share, handDescription: evaluation.description)
                }
            }
            
            playerStrengths.removeAll { $0.0.totalInvested == 0 }
        }
    }
    
    private func endBettingRound() {
        print("Ending betting round. Phase: \(currentPhase)")
        
        // Check if only one player remains (everyone else folded)
        let nonFoldedPlayers = players.filter { !$0.isFolded && $0.chips >= 0 }
        if nonFoldedPlayers.count == 1 {
            print("Only one player remaining, ending hand early")
            
            if let winner = nonFoldedPlayers.first {
                winner.win(amount: mainPot.amount)
                
                // Reveal cards
                DispatchQueue.main.async {
                    self.delegate?.gameDidEnd()
                }
                
                // Wait 4 seconds then notify about winner (GameViewController will handle summary)
                let revealDelay: TimeInterval = 4.0
                DispatchQueue.main.asyncAfter(deadline: .now() + revealDelay) {
                    self.delegate?.playerDidWin(winner, amount: self.mainPot.amount, handDescription: "All others folded")
                }
            }
            return
        }
        
        // Check if all remaining players are all-in
        let activeBettingPlayers = activePlayers.filter { !$0.isAllIn && !$0.isFolded }
        if activeBettingPlayers.isEmpty {
            print("All remaining players are all-in – going to showdown")
            showdown()
            return
        }
        
        // Normal path: reset for next round
        for player in players {
            player.hasActed = false
            player.currentBet = 0
        }
        currentBet = 0
        minRaise = bigBlind
        currentPlayerIndex = 0
        
        // Move to next phase
        switch currentPhase {
        case .preFlop:
            dealFlop()
        case .flop:
            dealTurn()
        case .turn:
            dealRiver()
        case .river:
            showdown()
        default:
            break
        }
    }
    
    private func dealFlop() {
        print("Dealing flop")
        
        _ = deck.deal()
        
        let flopCards = deck.dealMultiple(3)
        communityCards.append(contentsOf: flopCards)
        
        print("Flop: \(flopCards.map { $0.description }.joined(separator: ", "))")
        
        currentPhase = .flop
        delegate?.gamePhaseDidChange(currentPhase)
        delegate?.cardsDealt()
        
        resetBettingRound()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.processNextTurn()
        }
    }
    
    private func dealTurn() {
        print("Dealing turn")
        
        _ = deck.deal()
        
        if let turnCard = deck.deal() {
            communityCards.append(turnCard)
            print("Turn: \(turnCard.description)")
        }
        
        currentPhase = .turn
        delegate?.gamePhaseDidChange(currentPhase)
        delegate?.cardsDealt()
        
        resetBettingRound()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.processNextTurn()
        }
    }
    
    private func dealRiver() {
        print("Dealing river")
        
        _ = deck.deal()
        
        if let riverCard = deck.deal() {
            communityCards.append(riverCard)
            print("River: \(riverCard.description)")
        }
        
        currentPhase = .river
        delegate?.gamePhaseDidChange(currentPhase)
        delegate?.cardsDealt()
        
        resetBettingRound()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.processNextTurn()
        }
    }
    
    private func resetBettingRound() {
        for player in players {
            player.hasActed = false
            player.currentBet = 0
        }
        currentBet = 0
        minRaise = bigBlind
        
        currentPlayerIndex = findFirstActivePlayerAfterDealer()
    }
    
    private func findFirstActivePlayerAfterDealer() -> Int {
        let activePlayerIds = activePlayers.map { $0.id }
        
        var searchIndex = (dealerIndex + 1) % players.count
        var attempts = 0
        
        while attempts < players.count {
            let player = players[searchIndex]
            if let activeIndex = activePlayerIds.firstIndex(of: player.id),
               !player.isAllIn && !player.isFolded {
                return activeIndex
            }
            searchIndex = (searchIndex + 1) % players.count
            attempts += 1
        }
        
        return 0
    }
    
    func processPlayerAction(_ action: PlayerAction, for player: Player) {
        guard player.id == currentPlayer?.id else { return }
        
        executeAction(action, for: player)
        delegate?.playerDidAct(player, action: action)
        
        let delay: TimeInterval
        switch action {
        case .fold:
            delay = 0.8
        case .check:
            delay = 0.5
        case .call:
            delay = 0.7
        case .raise:
            delay = 1.0
        case .allIn:
            delay = 1.2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            if self?.shouldEndBettingRound() == true {
                self?.endBettingRound()
            } else {
                self?.moveToNextPlayer()
                self?.processNextTurn()
            }
        }
    }
}
