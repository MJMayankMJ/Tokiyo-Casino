//
//  SlotViewModel.swift
//  Tokiyo Casino
//

import Foundation

class SlotViewModel {

    var onUpdate: (() -> Void)?

    var dataArray: [[Int]] = [[], [], [], []]

    private let dailySpinManager: DailySpinManager

    var totalCoins: Int64 {
        return CoinsManager.shared.userStats?.totalCoins ?? 0
    }

    var remainingDailySpins: Int {
        return dailySpinManager.remainingSpinsToday
    }

    var canSpinForCoins: Bool {
        return remainingDailySpins > 0
    }

    init(dailySpinManager: DailySpinManager = .shared) {
        self.dailySpinManager = dailySpinManager
        loadData()
        observeCoinsChange()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func observeCoinsChange() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(coinsDidChange),
            name: CoinsManager.coinsDidChangeNotification,
            object: nil
        )
    }

    @objc private func coinsDidChange() {
        onUpdate?()
    }

    func loadData() {
        for col in 0..<4 {
            dataArray[col] = []
            for _ in 0..<100 {
                dataArray[col].append(Int.random(in: 0..<(K.imageArray.count)))
            }
        }
    }

    func spinSlots() -> [Int] {
        var picks: [Int] = []
        for _ in 0..<4 {
            picks.append(Int.random(in: 3...97))
        }
        return picks
    }

    func performDailyRewardSpin(completion: @escaping (Result<DailySpinResult, Error>) -> Void) {
        do {
            let spinResult = try dailySpinManager.performSpin()
            CoinsManager.shared.addCoins(amount: spinResult.reward) { addResult in
                DispatchQueue.main.async {
                    switch addResult {
                    case .success:
                        completion(.success(spinResult))
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
}
