//
//  HomeViewController.swift
//  Spin Royale
//
//  Created by Mayank Jangid on 5/25/25.
//

import Foundation

/// Possible bet errors
enum BetError: Error {
    case empty
    case belowMinimum
    case insufficientFunds

    var message: String {
        switch self {
        case .empty:
            return "Please enter a bet amount!"
        case .belowMinimum:
            return "Minimum bet is 250 coins!"
        case .insufficientFunds:
            return "You don't have enough coins!"
        }
    }
}

/// Result of validating a bet
struct BetValidationResult {
    let isValid: Bool       // true if 250 ≤ bet ≤ totalCoins
    let clampedAmount: Int  // final amount after clamping
    let error: BetError?    // nil if valid
}

class SlotViewModel {
    // MARK: - Properties

    var onUpdate: (() -> Void)?

    var dataArray: [[Int]] = [[], [], [], []]

    private(set) var currentBetAmount: Int = 250

    var totalCoins: Int64 {
        return CoinsManager.shared.userStats?.totalCoins ?? 0
    }

    // MARK: - Init

    init() {
        loadData()
        observeCoinsChange()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Observe Coin Updates

    private func observeCoinsChange() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(coinsDidChange),
            name: CoinsManager.coinsDidChangeNotification,
            object: nil
        )
    }

    @objc private func coinsDidChange() {
        // If bet is now more than available coins, clamp it
        if Int64(currentBetAmount) > totalCoins {
            currentBetAmount = max(250, Int(totalCoins))
            onUpdate?()
        }
    }

    // MARK: - Data Loading

    func loadData() {
        for col in 0..<4 {
            dataArray[col] = []
            for _ in 0..<100 {
                dataArray[col].append(Int.random(in: 0..<(K.imageArray.count)))
            }
        }
    }

    // MARK: - Bet Adjustment

    func increaseBet() {
        let next = currentBetAmount + 250
        if Int64(next) <= totalCoins {
            currentBetAmount = next
        } else {
            currentBetAmount = Int(totalCoins)
        }
        onUpdate?()
    }

    func decreaseBet() {
        currentBetAmount = max(250, currentBetAmount - 250)
        onUpdate?()
    }

    // MARK: - Validate Manual Input

    func validateBetInput(_ text: String?) -> BetValidationResult {
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !t.isEmpty else {
            return BetValidationResult(isValid: false,
                                       clampedAmount: currentBetAmount,
                                       error: .empty)
        }

        guard let value = Int(t) else {
            currentBetAmount = 250
            return BetValidationResult(isValid: false,
                                       clampedAmount: 250,
                                       error: .belowMinimum)
        }

        if value < 250 {
            currentBetAmount = 250
            return BetValidationResult(isValid: false,
                                       clampedAmount: 250,
                                       error: .belowMinimum)
        }

        if Int64(value) > totalCoins {
            let clamped = Int(totalCoins)
            currentBetAmount = clamped
            return BetValidationResult(isValid: false,
                                       clampedAmount: clamped,
                                       error: .insufficientFunds)
        }

        currentBetAmount = value
        return BetValidationResult(isValid: true,
                                   clampedAmount: value,
                                   error: nil)
    }

    // MARK: - Spin Logic

    func spinSlots() -> [Int] {
        var picks: [Int] = []
        for _ in 0..<4 {
            picks.append(Int.random(in: 3...97))
        }
        return picks
    }

    // MARK: - Win/Lose Calculation

    /**
     Deducts the bet, checks symbols, awards any reward, and calls completion.
     - selectedRows: indices for each of the 4 columns
     */
    func checkWinOrLose(selectedRows: [Int],
                        completion: @escaping (String, Int, Bool, Bool) -> Void) {
        // 1) Deduct bet
        CoinsManager.shared.deductCoins(amount: Int64(currentBetAmount)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                // 2) Get 4 symbols
                let s0 = K.imageArray[self.dataArray[0][selectedRows[0]]]
                let s1 = K.imageArray[self.dataArray[1][selectedRows[1]]]
                let s2 = K.imageArray[self.dataArray[2][selectedRows[2]]]
                let s3 = K.imageArray[self.dataArray[3][selectedRows[3]]]
                let symbols = [s0, s1, s2, s3]

                // 3) Count matches
                let counts = Dictionary(grouping: symbols, by: { $0 }).mapValues { $0.count }
                let maxCount = counts.values.max() ?? 0

                var reward = 0
                var msg = ""
                var playWin = false

                if maxCount == 4 {
                    reward = self.currentBetAmount * 4
                    msg = "JACKPOT! 4× WIN!"
                    playWin = true
                } else if maxCount == 3 {
                    reward = Int(Double(self.currentBetAmount) * 1.5)
                    msg = "BIG WIN! 1.5×"
                    playWin = true
                } else if maxCount == 2 {
                    reward = self.currentBetAmount
                    msg = "WIN! Bet returned"
                } else {
                    reward = 0
                    msg = K.lose
                }

                // 4) Award reward
                if reward > 0 {
                    CoinsManager.shared.addCoins(amount: Int64(reward)) { addResult in
                        switch addResult {
                        case .success:
                            completion(msg, reward, playWin, true)
                        case .failure:
                            completion("Error awarding reward", 0, false, false)
                        }
                    }
                } else {
                    completion(msg, reward, playWin, true)
                }

            case .failure:
                completion("Error processing bet", 0, false, false)
            }
        }
    }

    // MARK: - Daily Bonus

    func checkDailyReward() {
        guard let stats = CoinsManager.shared.userStats else { return }
        let today = Date()
        let claimed = KeychainHelper.shared.isDayClaimed(today, for: "claimedCoinsDates")
        stats.collectedCoinsToday = claimed
        CoreDataManager.shared.saveContext()
        onUpdate?()
    }

    func collectDailyBonus(completion: @escaping (Bool) -> Void) {
        guard let stats = CoinsManager.shared.userStats, !stats.collectedCoinsToday else {
            completion(false)
            return
        }

        CoinsManager.shared.addCoins(amount: 1000) { result in
            switch result {
            case .success:
                stats.collectedCoinsToday = true
                CoreDataManager.shared.saveContext()
                KeychainHelper.shared.addClaimedDay(Date(), for: "claimedCoinsDates")
                completion(true)
            case .failure:
                completion(false)
            }
        }
    }
}
