//
//  GameManagerActions.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import Foundation

extension GameManager {
    
    // MARK: - Player Actions
    func executeAction(_ action: PlayerAction, for player: Player) {
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
    
    // MARK: - Action Processing
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
