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
        dprint("Dealing hole cards to \(players.count) players") // Debug
        
        // Deal two cards to each active player. `isAway` seats are
        // multiplayer humans who have left/disconnected; they're held
        // vacant and skipped at the deal so we don't burn cards on
        // them.
        for _ in 0..<2 {
            for player in players where player.chips > 0 && !player.isFolded && !player.isAway {
                if let card = deck.deal() {
                    player.holeCards.append(card)
                    dprint("Dealt \(card.description) to \(player.name)") // Debug
                } else {
                    dprint("Error: No more cards in deck!") // Debug
                }
            }
        }
        
        delegate?.cardsDealt()
    }
    
    func postBlinds() {
        let blindIndexes: (smallBlind: Int, bigBlind: Int)?
        
        if activePlayers.count == 2 {
            let dealerCanPostBlind = players.indices.contains(dealerIndex)
                && players[dealerIndex].isActive
                && !players[dealerIndex].isFolded
            let sbIndex = dealerCanPostBlind ? dealerIndex : findNextInHandSeat(afterSeatIndex: dealerIndex)
            
            if let sbIndex,
               let bbIndex = findNextInHandSeat(afterSeatIndex: sbIndex) {
                blindIndexes = (smallBlind: sbIndex, bigBlind: bbIndex)
            } else {
                blindIndexes = nil
            }
        } else if let sbIndex = findNextInHandSeat(afterSeatIndex: dealerIndex),
                  let bbIndex = findNextInHandSeat(afterSeatIndex: sbIndex) {
            blindIndexes = (smallBlind: sbIndex, bigBlind: bbIndex)
        } else {
            blindIndexes = nil
        }
        
        guard let blindIndexes else {
            bigBlindPlayerSeatIndex = nil
            currentBet = 0
            delegate?.potDidUpdate(mainPot.amount)
            return
        }
        
        bigBlindPlayerSeatIndex = blindIndexes.bigBlind
        
        // Small blind
        let sbPlayer = players[blindIndexes.smallBlind]
        let sbAmount = sbPlayer.bet(amount: smallBlind)
        mainPot.add(sbAmount)
        
        // Big blind
        let bbPlayer = players[blindIndexes.bigBlind]
        let bbAmount = bbPlayer.bet(amount: bigBlind)
        mainPot.add(bbAmount)
        
        currentBet = bigBlind
        currentBetAllowsRaises = true
        delegate?.potDidUpdate(mainPot.amount)
    }
    
    func dealRemainingCommunityCards() {
        dprint("Dealing remaining community cards. Current count: \(communityCards.count)")
        
        // Deal remaining streets following Texas Hold'em burn/deal rules:
        // Flop:  burn 1, deal 3
        // Turn:  burn 1, deal 1
        // River: burn 1, deal 1
        
        if communityCards.count < 3 {
            // Flop not yet dealt
            _ = deck.deal() // Burn
            let flopCards = deck.dealMultiple(3 - communityCards.count)
            communityCards.append(contentsOf: flopCards)
            dprint("Flop: \(flopCards.map { $0.description }.joined(separator: ", "))")
        }
        
        if communityCards.count < 4 {
            // Turn not yet dealt
            _ = deck.deal() // Burn
            if let turnCard = deck.deal() {
                communityCards.append(turnCard)
                dprint("Turn: \(turnCard.description)")
            }
        }
        
        if communityCards.count < 5 {
            // River not yet dealt
            _ = deck.deal() // Burn
            if let riverCard = deck.deal() {
                communityCards.append(riverCard)
                dprint("River: \(riverCard.description)")
            }
        }
        
        // Notify delegate that cards were dealt
        delegate?.cardsDealt()
    }
    
    // Enhanced flop dealing
    func dealFlop() {
        dprint("Dealing flop")
        
        // Burn one card
        _ = deck.deal()
        
        // Deal 3 community cards
        let flopCards = deck.dealMultiple(3)
        communityCards.append(contentsOf: flopCards)
        
        dprint("Flop: \(flopCards.map { $0.description }.joined(separator: ", "))")
        
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
        dprint("Dealing turn")
        
        // Burn one card
        _ = deck.deal()
        
        // Deal turn card
        if let turnCard = deck.deal() {
            communityCards.append(turnCard)
            dprint("Turn: \(turnCard.description)")
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
        dprint("Dealing river")
        
        // Burn one card
        _ = deck.deal()
        
        // Deal river card
        if let riverCard = deck.deal() {
            communityCards.append(riverCard)
            dprint("River: \(riverCard.description)")
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
