//
//  GameManagerCards.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import Foundation

extension GameManager {
    
    // MARK: - Card Dealing
    func dealHoleCards() {
        print("Dealing hole cards to \(players.count) players") // Debug
        
        // Deal two cards to each active player
        for _ in 0..<2 {
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
    
    func postBlinds() {
        guard let sbIndex = findNextInHandSeat(afterSeatIndex: dealerIndex),
              let bbIndex = findNextInHandSeat(afterSeatIndex: sbIndex) else {
            bigBlindPlayerSeatIndex = nil
            currentBet = 0
            delegate?.potDidUpdate(mainPot.amount)
            return
        }
        
        bigBlindPlayerSeatIndex = bbIndex
        
        // Small blind
        let sbPlayer = players[sbIndex]
        let sbAmount = sbPlayer.bet(amount: smallBlind)
        mainPot.add(sbAmount)
        
        // Big blind
        let bbPlayer = players[bbIndex]
        let bbAmount = bbPlayer.bet(amount: bigBlind)
        mainPot.add(bbAmount)
        
        currentBet = max(sbPlayer.currentBet, bbPlayer.currentBet)
        currentBetAllowsRaises = true
        delegate?.potDidUpdate(mainPot.amount)
    }
    
    func dealRemainingCommunityCards() {
        print("Dealing remaining community cards. Current count: \(communityCards.count)")
        
        // Deal remaining streets following Texas Hold'em burn/deal rules:
        // Flop:  burn 1, deal 3
        // Turn:  burn 1, deal 1
        // River: burn 1, deal 1
        
        if communityCards.count < 3 {
            // Flop not yet dealt
            _ = deck.deal() // Burn
            let flopCards = deck.dealMultiple(3 - communityCards.count)
            communityCards.append(contentsOf: flopCards)
            print("Flop: \(flopCards.map { $0.description }.joined(separator: ", "))")
        }
        
        if communityCards.count < 4 {
            // Turn not yet dealt
            _ = deck.deal() // Burn
            if let turnCard = deck.deal() {
                communityCards.append(turnCard)
                print("Turn: \(turnCard.description)")
            }
        }
        
        if communityCards.count < 5 {
            // River not yet dealt
            _ = deck.deal() // Burn
            if let riverCard = deck.deal() {
                communityCards.append(riverCard)
                print("River: \(riverCard.description)")
            }
        }
        
        // Notify delegate that cards were dealt
        delegate?.cardsDealt()
    }
    
    // Enhanced flop dealing
    func dealFlop() {
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
    
    func dealTurn() {
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
    
    func dealRiver() {
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
}
