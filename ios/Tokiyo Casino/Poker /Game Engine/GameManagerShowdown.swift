//
//  GameManagerShowdown.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//

import Foundation

// MARK: - Enhanced Showdown with Delayed Winner Alert
extension GameManager {
    
    // Enhanced showdown with proper card reveal timing
    func showdown() {
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

    func revealAllPlayerCards() {
        print("Revealing all player cards")
        delegate?.gameDidEnd() // This will trigger card reveals in the UI
    }

    func determineWinners() {
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

    func determineWinnersWithDelay() {
        print("Determining winners with side pot logic")
        
        // 1. Get all players who haven't folded (including All-In players)
        let candidates = players.filter { !$0.isFolded }
        
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
            
            // ROBUST ALGORITHM:
            // 1. Pick the winner(s) with best hand.
            // 2. Determine the specific winner with the SMALLEST totalInvested among the ties.
            // 3. That amount is the "Cap".
            // 4. Collect 'Cap' from EVERY player (active or folded) into a temporary side pot.
            //    (Subtract this 'Cap' from everyone's totalInvested tracker so we don't count it twice).
            // 5. Split that side pot among the winners.
            // 6. Remove the "Smallest Stack Winner" from the list (they are fully paid).
            // 7. Repeat until pot is empty.
            
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
    
    func showWinnerAlert(player: Player, amount: Int, handDescription: String) {
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
}
