//
//  FlipGameViewModel.swift
//  Tokiyo Casino
//
//  Created by Mayank Jangid on 6/9/25.
//

import Foundation
import UIKit

enum FlipChoice: Int {
    case heads = 0
    case tails = 1
}

struct BetValidation {
    let amount: Int64
    let errorMessage: String?
}

class FlipGameViewModel {
    // MARK: - Properties
    var currentBet: Int64 = 100
    let minBet: Int64 = 100
    private var maxBet: Int64 {
        return CoinsManager.shared.userStats?.totalCoins ?? 0
    }
    var totalCoins: Int64 {
        return CoinsManager.shared.userStats?.totalCoins ?? 0
    }

    // MARK: - Bet Management
    func validate(betString: String?) -> BetValidation {
        guard let text = betString,
              let value = Int64(text),
              value >= minBet,
              value <= maxBet else {
            let msg: String
            if let v = Int64(betString ?? ""), v > maxBet {
                msg = "Your bet cannot exceed your total coins (\(maxBet))."
            } else {
                msg = "Enter an amount between \(minBet) and \(maxBet)."
            }
            return BetValidation(amount: minBet, errorMessage: msg)
        }
        return BetValidation(amount: value, errorMessage: nil)
    }

    func updateBet(by delta: Int64) {
        let newBet = currentBet + delta
        currentBet = min(max(newBet, minBet), maxBet)
    }

    // MARK: - Game Logic
    func performFlip(choice: FlipChoice, completion: @escaping (_ result: FlipChoice,_ won: Bool, _ reward: Int64) -> Void) {
        // Simulate flip: random 0 or 1
        let resultRaw = Int.random(in: 0...1)
        let result: FlipChoice = (resultRaw == 0) ? .heads : .tails
        let won = (choice == result)
        let reward: Int64 = won ? currentBet * 2 : 0

        // Update coins
        if won {
            CoinsManager.shared.addCoins(amount: reward - currentBet) { _ in }
        } else {
            CoinsManager.shared.deductCoins(amount: currentBet) { _ in }
        }

        completion(result,won, reward)
    }
}
