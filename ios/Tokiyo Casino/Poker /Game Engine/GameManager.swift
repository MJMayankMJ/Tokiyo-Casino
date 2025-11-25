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
            print("Dealing hole cards to \(players.count) players") // Debug
            
            // Deal two cards to each active player
            for round in 0..<2 {
                for player in players where player.chips > 0 && !player.isFolded {
                    if let card = deck.deal() {
                        player.holeCards.append(card)
                        print("Dealt \(card.description) to \(player.name)") // Debug
                    } else {
                        print("Error: No more cards in deck!") // Debug
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
    
    // MARK: - Player Actions
//    func processPlayerAction(_ action: PlayerAction, for player: Player) {
//        guard player.id == currentPlayer?.id else { return }
//        
//        executeAction(action, for: player)
//        delegate?.playerDidAct(player, action: action)
//        
//        // Small delay for better UX
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
//            if self?.shouldEndBettingRound() == true {
//                self?.endBettingRound()
//            } else {
//                self?.moveToNextPlayer()
//                self?.processNextTurn()
//            }
//        }
//    }
    
    private func executeAction(_ action: PlayerAction, for player: Player) {
        player.lastAction = action
        
        switch action {
        case .fold:
            player.isFolded = true
            player.isActive = false
            
        case .check:
            // No chips to add
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
            
            // Reset other players' hasActed flag
            for p in activePlayers where p.id != player.id {
                p.hasActed = false
            }
            
            delegate?.potDidUpdate(mainPot.amount)
            
        case .allIn:
            let allInAmount = player.chips
            let betAmount = player.bet(amount: allInAmount)
            mainPot.add(betAmount)

            // If this all-in exceeds the current bet, update it
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
    
    // MARK: - Turn Management
//    private func processNextTurn() {
//        guard let current = currentPlayer else {
//            endBettingRound()
//            return
//        }
//        
//        // Notify delegate of current player
//        delegate?.currentPlayerChanged(current)
//        
//        if current.isHuman {
//            // Wait for human input
//            return
//        }
//        
//        // AI makes decision after a delay for better UX
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
//            self?.processAITurn()
//        }
//    }
    private func processNextTurn() {
        // If somehow no active players, just end the round defensively
        guard !activePlayers.isEmpty else {
            endBettingRound()
            return
        }
        
        guard let current = currentPlayer else {
            endBettingRound()
            return
        }
        
        // If current player cannot act (all-in or folded), skip them
        if current.isAllIn || current.isFolded {
            let bettingPlayers = activePlayers.filter { !$0.isAllIn && !$0.isFolded }
            
            // Nobody left who can bet → end betting round
            if bettingPlayers.isEmpty {
                endBettingRound()
            } else {
                // Move to the next player who can actually act
                currentPlayerIndex = findNextActivePlayerIndex(after: currentPlayerIndex)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.processNextTurn()
                }
            }
            return
        }
        
        // Normal path: current player can act
        delegate?.currentPlayerChanged(current)
        
        if current.isHuman {
            // Wait for human input (bettingControls are shown by currentPlayerChanged)
            return
        }
        
        // AI makes decision after a delay for better UX
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
            // FIX: Explicitly skip players who are All-In
            // They are still "active" for winning, but inactive for betting turns
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
        
        // All but one folded
        if activePlayers.count <= 1 {
            return true
        }
        
        // Everyone is all-in
        if activeBettingPlayers.isEmpty {
            return true
        }
        
        // All active players have acted and bets are equal
        for player in activeBettingPlayers {
            if !player.hasActed || (player.currentBet < currentBet && !player.isAllIn) {
                return false
            }
        }
        
        return true
    }
    

    func validateGameState() -> Bool {
            // Check if game can continue
            let playersWithChips = players.filter { $0.chips > 0 }
            if playersWithChips.count < 2 {
                print("Game over: Not enough players with chips")
                return false
            }
            
            // Check deck has enough cards
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
         print("Starting showdown") // Debug
         
         var playerHands: [(Player, HandEvaluation)] = []
         
         // Evaluate each active player's hand
         for player in activePlayers {
             let allCards = player.holeCards + communityCards
             let evaluation = HandEvaluator.evaluateBestHand(from: allCards)
             playerHands.append((player, evaluation))
             
             print("\(player.name): \(player.holeCards.map { $0.description }.joined(separator: ", ")) -> \(evaluation.description)")
         }
         
         // Sort by hand value (highest first)
         playerHands.sort { $0.1.value > $1.1.value }
         
         guard !playerHands.isEmpty else { return }
         
         // Find all winners (handle ties)
         let winningValue = playerHands[0].1.value
         let winners = playerHands.filter { $0.1.value == winningValue }
         
         print("Winners: \(winners.map { $0.0.name }.joined(separator: ", "))")
         
         // Split pot among winners
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
            // No bet to match
            actions.append(.check)
            if player.chips >= minRaise {
                actions.append(.raise(minRaise))
            }
        } else {
            // Need to match bet
            actions.append(.fold)
            if player.chips >= callAmount {
                actions.append(.call)
                if player.chips > callAmount + minRaise {
                    actions.append(.raise(minRaise))
                }
            }
        }
        
        // All-in is always available if player has chips
        if player.chips > 0 {
            actions.append(.allIn)
        }
        
        return actions
    }
}


// Add these enhanced methods to your GameManager class

// MARK: - Enhanced Showdown with Delayed Winner Alert
extension GameManager {
    
    // Enhanced showdown with proper card reveal timing

    private func showdown() {
        currentPhase = .showdown
        delegate?.gamePhaseDidChange(currentPhase)
        
        // 1. Deal final cards if needed
        dealRemainingCommunityCards()
        
        // 2. Reveal all non-folded players' cards (human + AI)
        DispatchQueue.main.async {
            self.delegate?.gameDidEnd()   // triggers tableView.revealAllCards()
        }
        
        // 3. Wait LONGER before showing any alerts (4 seconds)
        let revealDelay: TimeInterval = 4.0
        DispatchQueue.main.asyncAfter(deadline: .now() + revealDelay) {
            // 4. Now calculate winners and send alerts
            self.determineWinnersWithDelay()
        }
    }


    
    private func dealRemainingCommunityCards() {
        print("Dealing remaining community cards. Current count: \(communityCards.count)")
        
        while communityCards.count < 5 {
            // Burn card before dealing (except for the first remaining card)
            if communityCards.count > 0 {
                _ = deck.deal() // Burn card
            }
            
            if let card = deck.deal() {
                communityCards.append(card)
                print("Dealt community card: \(card.description)")
            } else {
                print("No more cards in deck!")
                break
            }
        }
        
        // Notify delegate that cards were dealt
        delegate?.cardsDealt()
    }
    
    private func revealAllPlayerCards() {
        print("Revealing all player cards")
        delegate?.gameDidEnd() // This will trigger card reveals in the UI
    }

    private func determineWinnersWithDelay() {
        print("Determining winners with side pot logic")
        
        // 1. Get all players who haven't folded (including All-In players)
        var candidates = players.filter { !$0.isFolded }
        
        // 2. Calculate hand strength for everyone
        var playerStrengths: [(Player, HandEvaluation)] = []
        for player in candidates {
            let allCards = player.holeCards + communityCards
            let evaluation = HandEvaluator.evaluateBestHand(from: allCards)
            playerStrengths.append((player, evaluation))
        }
        
        // 3. Sort by hand strength (Highest value first)
        playerStrengths.sort { $0.1.value > $1.1.value }
        
        // 4. Distribute the pot (Side Pot Algorithm)
        var remainingPot = mainPot.amount
        
        // While there is money in the pot
        while remainingPot > 0 && !playerStrengths.isEmpty {
            
            // Get the best hand value currently remaining
            let bestValue = playerStrengths[0].1.value
            
            // Find all players tied for this best hand
            let winners = playerStrengths.filter { $0.1.value == bestValue }
            
            if winners.isEmpty { break } // Should not happen
            
            // Calculate how much these winners can take from the pot
            var potForThisRank = 0
            
            // For each winner, they can win chips from every other player (including folded ones)
            // UP TO the amount they themselves invested.
            for (winner, _) in winners {
                // Find the minimum investment this winner is eligible for from the "pool"
                // We take chips from the global pot based on this winner's contribution cap
                
                // Simplified Side Pot Logic:
                // 1. Determine the "Call Amount" for this tier of winners (min of their totalInvested)
                // 2. Take that amount from every player's "available contribution"
                // 3. Pay it to the winners
                
                // To do this simply without complex caching:
                // We will just calculate their "Fair Share" and subtract it.
                
                // (Note: This is a simplified "All-in EV" distribution for UX clarity)
                // Real side pots are calculated during betting, but this method works for Showdown-only calculation.
                
                // ...Actually, let's use the Robust Subtraction Method:
            }
            
            // ROBUST ALGORITHM:
            // 1. Pick the winner(s) with best hand.
            // 2. Determine the specific winner with the SMALLEST totalInvested among the ties.
            // 3. That amount is the "Cap".
            // 4. Collect 'Cap' from EVERY player (active or folded) into a temporary side pot.
            //    (Subtract this 'Cap' from everyone's totalInvested tracker so we don't count it twice).
            // 5. Split that side pot among the winners.
            // 6. Remove the "Smallest Stack Winner" from the list (they are fully paid).
            // 7. Repeat until pot is empty.
            
            // Let's implement this loop:
            
            // Find the lowest invested amount among the current winners
            let minInvestedAmongWinners = winners.map { $0.0.totalInvested }.min() ?? 0
            
            // Calculate the side pot size
            var sidePot = 0
            for p in players { // iterate ALL players (even folded ones contributed)
                let contribution = min(p.totalInvested, minInvestedAmongWinners)
                sidePot += contribution
                p.totalInvested -= contribution // Deduct used portion
            }
            
            remainingPot -= sidePot
            
            // Split sidePot among winners
            let share = sidePot / winners.count
            for (winner, evaluation) in winners {
                winner.win(amount: share)
                
                // Alert for this specific payout
                if share > 0 {
                    // We use a small delay to stack alerts if multiple side pots
                    self.showWinnerAlert(player: winner, amount: share, handDescription: evaluation.description)
                }
            }
            
            // Remove fully paid winners from the contest
            // (Anyone whose totalInvested is now 0 has been fully calculated)
            playerStrengths.removeAll { $0.0.totalInvested == 0 }
        }
    }
    
    private func showWinnerAlert(player: Player, amount: Int, handDescription: String) {
        // This method will be called by the GameViewController
        // We'll update the delegate method to handle this properly
        NotificationCenter.default.post(
            name: NSNotification.Name("ShowWinnerAlert"),
            object: nil,
            userInfo: [
                "player": player,
                "amount": amount,
                "handDescription": handDescription
            ]
        )
    }
    
    // Enhanced betting round end check
    private func endBettingRound() {
        print("Ending betting round. Phase: \(currentPhase)")
        
        // Check if only one player remains (early end)
//        let nonFoldedPlayers = players.filter { !$0.isFolded && $0.chips >= 0 }
//        if nonFoldedPlayers.count == 1 {
//            print("Only one player remaining, ending hand early")
//            if let winner = nonFoldedPlayers.first {
//                winner.win(amount: mainPot.amount)
//                
//                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                    self.showWinnerAlert(
//                        player: winner,
//                        amount: self.mainPot.amount,
//                        handDescription: "All others folded"
//                    )
//                }
//            }
//            return
//        }
        
        // Check if only one player remains (early end)
        let nonFoldedPlayers = players.filter { !$0.isFolded && $0.chips >= 0 }
        if nonFoldedPlayers.count == 1 {
            print("Only one player remaining, ending hand early")
            
            if let winner = nonFoldedPlayers.first {
                winner.win(amount: mainPot.amount)
                
                // 1) Reveal cards (only this non-folded player will show)
                DispatchQueue.main.async {
                    self.delegate?.gameDidEnd()   // → revealAllCards() → only winner gets shown
                }
                
                // 2) Wait same 4 seconds before showing alert
                let revealDelay: TimeInterval = 4.0
                DispatchQueue.main.asyncAfter(deadline: .now() + revealDelay) {
                    self.showWinnerAlert(
                        player: winner,
                        amount: self.mainPot.amount,
                        handDescription: "All others folded"
                    )
                }
            }
            return
        }

        
        // If everyone who is still in the hand is already all-in,
        // there is no more betting to do on later streets.
        let activeBettingPlayers = activePlayers.filter { !$0.isAllIn && !$0.isFolded }
        if activeBettingPlayers.isEmpty {
            print("All remaining players are all-in – skipping further betting rounds and going to showdown.")
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

//    private func endBettingRound() {
//        print("Ending betting round. Phase: \(currentPhase)")
//        
//        // Reset for next round
//        for player in players {
//            player.hasActed = false
//            player.currentBet = 0
//        }
//        currentBet = 0
//        minRaise = bigBlind
//        currentPlayerIndex = 0
//        
//        // Check if only one player remains (early end)
//        let nonFoldedPlayers = players.filter { !$0.isFolded && $0.chips >= 0 }
//        if nonFoldedPlayers.count == 1 {
//            print("Only one player remaining, ending hand early")
//            // Award pot to remaining player immediately
//            if let winner = nonFoldedPlayers.first {
//                winner.win(amount: mainPot.amount)
//                
//                // Show winner after short delay
//                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                    self.showWinnerAlert(player: winner, amount: self.mainPot.amount, handDescription: "All others folded")
//                }
//            }
//            return
//        }
//        
//        // Move to next phase
//        switch currentPhase {
//        case .preFlop:
//            dealFlop()
//        case .flop:
//            dealTurn()
//        case .turn:
//            dealRiver()
//        case .river:
//            showdown()
//        default:
//            break
//        }
//    }
    
    // Enhanced flop dealing
    private func dealFlop() {
        print("Dealing flop")
        
        // Burn one card
        _ = deck.deal()
        
        // Deal 3 community cards
        let flopCards = deck.dealMultiple(3)
        communityCards.append(contentsOf: flopCards)
        
        print("Flop: \(flopCards.map { $0.description }.joined(separator: ", "))")
        
        currentPhase = .flop
        delegate?.gamePhaseDidChange(currentPhase)
        delegate?.cardsDealt()
        
        // Reset betting for new round
        resetBettingRound()
        
        // Start new betting round
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.processNextTurn()
        }
    }
    
    private func dealTurn() {
        print("Dealing turn")
        
        // Burn one card
        _ = deck.deal()
        
        // Deal turn card
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
        
        // Burn one card
        _ = deck.deal()
        
        // Deal river card
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
    
    // Helper method to reset betting round
    private func resetBettingRound() {
        for player in players {
            player.hasActed = false
            player.currentBet = 0
        }
        currentBet = 0
        minRaise = bigBlind
        
        // Find first active player after dealer for new betting round
        currentPlayerIndex = findFirstActivePlayerAfterDealer()
    }
    
    private func findFirstActivePlayerAfterDealer() -> Int {
        let activePlayerIds = activePlayers.map { $0.id }
        
        // Start from small blind position (dealer + 1)
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
        
        return 0 // Fallback
    }
    
    // Enhanced action processing with better timing
    func processPlayerAction(_ action: PlayerAction, for player: Player) {
        guard player.id == currentPlayer?.id else { return }
        
        executeAction(action, for: player)
        delegate?.playerDidAct(player, action: action)
        
        // Determine delay based on action type
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
