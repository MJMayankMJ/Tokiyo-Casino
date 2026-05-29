//
//  GameManagerActions.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import Foundation

extension GameManager {
    
    // MARK: - Player Actions
    @discardableResult
    func executeAction(_ action: PlayerAction, for player: Player) -> PlayerAction {
        let resolvedAction = normalizedAction(action, for: player)
        player.lastAction = resolvedAction
        
        switch resolvedAction {
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
            let oldCurrentBet = currentBet
            let previousMinRaise = minRaise
            let totalBet = oldCurrentBet + amount
            let raiseAmount = max(0, totalBet - player.currentBet)
            let actualBet = player.bet(amount: raiseAmount)
            mainPot.add(actualBet)
            
            if player.currentBet > oldCurrentBet {
                let actualRaise = player.currentBet - oldCurrentBet
                currentBet = player.currentBet
                lastRaiseAmount = actualRaise
                
                if actualRaise >= previousMinRaise {
                    minRaise = actualRaise
                    currentBetAllowsRaises = true
                    
                    for p in activePlayers where p.id != player.id {
                        p.hasActed = false
                    }
                } else {
                    currentBetAllowsRaises = false
                }
            }
            
            delegate?.potDidUpdate(mainPot.amount)
            
        case .allIn:
            let allInAmount = player.chips
            let betAmount = player.bet(amount: allInAmount)
            mainPot.add(betAmount)

            // If this all-in exceeds the current bet, update it
            if player.currentBet > currentBet {
                let previousMinRaise = minRaise
                let raiseAmount = player.currentBet - currentBet  // capture delta BEFORE overwriting
                currentBet = player.currentBet
                lastRaiseAmount = raiseAmount

                if raiseAmount >= previousMinRaise {
                    // Full raise: update minimum and reopen action for other players
                    minRaise = raiseAmount
                    currentBetAllowsRaises = true

                    for p in activePlayers where p.id != player.id {
                        p.hasActed = false
                    }
                } else {
                    currentBetAllowsRaises = false
                }
                // Short all-in (raiseAmount < minRaise): others must call the new
                // amount, but minRaise stays unchanged and action is NOT reopened
                // for players who already acted at the prior raise level.
            }

            player.isAllIn = true
            delegate?.potDidUpdate(mainPot.amount)

        }

        // Track pre-flop aggression for the AI's opponent-range tightening.
        if currentPhase == .preFlop && currentBet > bigBlind {
            handWasRaisedPreflop = true
        }

        player.hasActed = true
        return resolvedAction
    }
    
    // MARK: - Valid Actions
    func getValidActions(for player: Player) -> [PlayerAction] {
        var actions: [PlayerAction] = []
        
        let callAmount = currentBet - player.currentBet
        
        if callAmount == 0 {
            // No bet to match
            actions.append(.check)
            if canPlayerRaise(player) && player.chips >= minRaise {
                actions.append(.raise(minRaise))
            }
        } else {
            // Need to match bet
            actions.append(.fold)
            if player.chips >= callAmount {
                actions.append(.call)
                if canPlayerRaise(player) && player.chips >= callAmount + minRaise {
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
    
    func normalizedAction(_ action: PlayerAction, for player: Player) -> PlayerAction {
        switch action {
        case .raise:
            if canPlayerRaise(player) {
                return action
            }
            
            return currentBet > player.currentBet ? .call : .check
        case .check:
            return currentBet > player.currentBet ? .fold : .check
        case .call:
            return currentBet > player.currentBet ? .call : .check
        default:
            return action
        }
    }
    
    func canPlayerRaise(_ player: Player) -> Bool {
        let liveOpponents = activePlayers.filter {
            $0.id != player.id && !$0.isAllIn && !$0.isFolded
        }
        
        return !liveOpponents.isEmpty && (currentBetAllowsRaises || !player.hasActed)
    }
    
    // MARK: - Action Processing
    func processPlayerAction(_ action: PlayerAction, for player: Player) {
        guard player.id == currentPlayer?.id else { return }
        
        let executedAction = executeAction(action, for: player)
        delegate?.playerDidAct(player, action: executedAction)
        
        // Determine delay based on action type
        let delay: TimeInterval
        switch executedAction {
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
                self?.moveToNextPlayer(after: player)
                self?.processNextTurn()
            }
        }
    }
}
