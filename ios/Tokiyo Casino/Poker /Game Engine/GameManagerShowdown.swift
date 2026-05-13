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



    func determineWinnersWithDelay() {
        print("Determining winners with side pot logic")
        
        // 1. Get all players who haven't folded (including All-In players)
        let candidates = players.filter { $0.isActive && !$0.isFolded && $0.holeCards.count == 2 }
        
        // 2. Calculate hand strength for everyone
        var playerStrengths: [(Player, HandEvaluation)] = []
        for player in candidates {
            let allCards = player.holeCards + communityCards
            let evaluation = HandEvaluator.evaluateBestHand(from: allCards)
            playerStrengths.append((player, evaluation))
        }
        
        // 3. Sort by hand strength (Highest value first)
        playerStrengths.sort { $0.1.value > $1.1.value }
        
        // 4. Build a local contribution ledger so we don't destroy player.totalInvested
        var contributions: [Int: Int] = [:]  // [player.id : invested amount]
        for p in players {
            contributions[p.id] = p.totalInvested
        }
        
        // 5. Distribute the pot (Side Pot Algorithm)
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
            // 2. Determine the specific winner with the SMALLEST contribution among the ties.
            // 3. That amount is the "Cap".
            // 4. Collect 'Cap' from EVERY player (active or folded) into a temporary side pot.
            //    (Subtract this 'Cap' from the ledger so we don't count it twice).
            // 5. Split that side pot among the winners.
            // 6. Remove the "Smallest Stack Winner" from the list (they are fully paid).
            // 7. Repeat until pot is empty.
            
            // Find the lowest invested amount among the current winners
            let minInvestedAmongWinners = winners.map { contributions[$0.0.id] ?? 0 }.min() ?? 0
            
            // Calculate the side pot size from the local ledger
            var sidePot = 0
            for p in players { // iterate ALL players (even folded ones contributed)
                let invested = contributions[p.id] ?? 0
                let contribution = min(invested, minInvestedAmongWinners)
                sidePot += contribution
                contributions[p.id] = invested - contribution  // deduct from ledger, not player
            }
            
            remainingPot -= sidePot
            
            // Split sidePot among winners, awarding odd chip(s) to first winner(s)
            // clockwise from the dealer button (standard poker rule)
            let playerCount = players.count
            let firstOddChipSeat = (dealerIndex + 1) % playerCount
            let sortedWinners = winners.sorted { a, b in
                let indexA = players.firstIndex(where: { $0.id == a.0.id }) ?? a.0.id
                let indexB = players.firstIndex(where: { $0.id == b.0.id }) ?? b.0.id
                let seatA = (indexA - firstOddChipSeat + playerCount) % playerCount
                let seatB = (indexB - firstOddChipSeat + playerCount) % playerCount
                return seatA < seatB
            }
            let share = sidePot / sortedWinners.count
            let remainder = sidePot % sortedWinners.count
            for (i, (winner, evaluation)) in sortedWinners.enumerated() {
                let bonus = (i < remainder) ? 1 : 0
                let total = share + bonus
                winner.win(amount: total)
                
                // Alert for this specific payout
                if total > 0 {
                    // We use a small delay to stack alerts if multiple side pots
                    self.showWinnerAlert(player: winner, amount: total, handDescription: evaluation.description)
                }
            }
            
            // Remove fully paid winners from the contest
            // (Anyone whose ledger contribution is now 0 has been fully calculated)
            playerStrengths.removeAll { (contributions[$0.0.id] ?? 0) == 0 }
        }
        
        // Reconcile any unclaimed remainder (e.g., from rounding mismatches)
        if remainingPot > 0 {
            assertionFailure("Unclaimed chips remained after side-pot distribution: \(remainingPot)")
            print("WARNING: \(remainingPot) unclaimed chips in pot – awarding only to an eligible contributor")
            
            let originalEligibleFallback = candidates
                .filter { $0.totalInvested > 0 }
                .map { ($0, HandEvaluator.evaluateBestHand(from: $0.holeCards + communityCards)) }
                .sorted { $0.1.value > $1.1.value }
                .first?
                .0
            let fallback = playerStrengths.first(where: { contributions[$0.0.id, default: 0] > 0 || $0.0.totalInvested > 0 })?.0 ?? originalEligibleFallback
            
            if let fallback {
                fallback.win(amount: remainingPot)
                self.showWinnerAlert(player: fallback, amount: remainingPot, handDescription: "Unclaimed remainder")
            } else {
                print("ERROR: No eligible contributor found for unclaimed remainder")
            }
        }
        
        // Zero the pot so it doesn't linger until resetForNewHand()
        mainPot.reset()
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
