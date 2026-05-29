//
//  GameManagerTurns.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import Foundation

extension GameManager {
    
    // MARK: - Turn Management
    func processNextTurn() {
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
                moveToNextPlayer(after: current)
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
        
        // AI makes decision after a delay for better UX. Capture the seat id
        // so a mid-delay seat replacement cannot act for the wrong player.
        let scheduledPlayerId = current.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard self?.currentPlayer?.id == scheduledPlayerId else { return }
            self?.processAITurn()
        }
    }

    func processAITurn() {
        guard let current = currentPlayer, !current.isHuman else { return }

        // Phase 2: behaviour is driven by the resolved AIProfile (difficulty +
        // style), not the personality directly. Personality remains only the
        // visible label/avatar.
        var profile = current.resolvedProfile

        // Phase 3: on Hard/Expert, tilt the profile to exploit the human's
        // observed tendencies. Easy/Medium (`.off`) skip this entirely so newer
        // players aren't punished for predictable play. We exploit the active
        // human opponent we have the most data on.
        let exploitation = aiConfig.difficulty.exploitation
        if exploitation != .off,
           let target = activePlayers
               .filter({ $0.isHuman && $0.id != current.id })
               .map({ handHistory.model(for: $0.id) })
               .max(by: { $0.handsObserved < $1.handsObserved }) {
            profile = Exploit.adjusted(profile: profile, vs: target, intensity: exploitation)
        }

        let gameState = GameState(
            pot: mainPot.amount,
            currentBet: currentBet,
            minRaise: minRaise,
            communityCards: communityCards,
            activePlayers: activePlayers,
            dealerIndex: dealerIndex,
            wasRaisedPreflop: handWasRaisedPreflop
        )

        // The decision includes a multi-thousand-iteration Monte Carlo rollout,
        // which must NOT run on the main thread (it would freeze the UI). Run it
        // on a background queue, then hop back to main to apply the action.
        // Capture the acting seat id so a mid-think seat replacement cannot act
        // for the wrong player (same guard pattern as processNextTurn).
        let scheduledPlayerId = current.id
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let decision = AIEngine.makeDecision(
                for: current,
                gameState: gameState,
                profile: profile
            )
            DispatchQueue.main.async {
                guard let self else { return }
                guard self.currentPlayer?.id == scheduledPlayerId else { return }
                self.processPlayerAction(decision, for: current)
            }
        }
    }
    
    func moveToNextPlayer() {
        moveToNextPlayer(after: currentPlayer)
    }
    
    func moveToNextPlayer(after player: Player?) {
        guard let player,
              let seatIndex = players.firstIndex(where: { $0.id == player.id }) else {
            currentPlayerIndex = findFirstActivePlayerAfterDealer()
            return
        }
        currentPlayerIndex = findNextActivePlayerIndex(afterSeatIndex: seatIndex)
    }
    
    func findFirstActivePlayerAfterDealer() -> Int {
        return findNextActivePlayerIndex(afterSeatIndex: dealerIndex)
    }
    
    func findNextActivePlayerIndex(afterSeatIndex seatIndex: Int) -> Int {
        guard !players.isEmpty else { return -1 }
        
        var searchIndex = (seatIndex + 1) % players.count
        var attempts = 0
        
        while attempts < players.count {
            let player = players[searchIndex]
            if player.isActive,
               !player.isFolded,
               !player.isAllIn,
               let activeIndex = activePlayers.firstIndex(where: { $0.id == player.id }) {
                return activeIndex
            }
            searchIndex = (searchIndex + 1) % players.count
            attempts += 1
        }
        
        return -1
    }
    
    func findNextInHandSeat(afterSeatIndex seatIndex: Int) -> Int? {
        guard !players.isEmpty else { return nil }
        
        var searchIndex = (seatIndex + 1) % players.count
        var attempts = 0
        
        while attempts < players.count {
            let player = players[searchIndex]
            if player.isActive && !player.isFolded {
                return searchIndex
            }
            searchIndex = (searchIndex + 1) % players.count
            attempts += 1
        }
        
        return nil
    }
}
