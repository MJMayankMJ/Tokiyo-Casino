//
//  DailySpinManager.swift
//  Tokiyo Casino
//
//  Handles the daily coin-spin reward without changing Core Data.
//

import Foundation

struct DailySpinResult: Equatable {
    let reward: Int64
    let remainingSpins: Int
}

enum DailySpinError: Error, Equatable {
    case noSpinsRemaining
}

struct DailySpinRewardTier: Equatable {
    let amount: Int64
    let weight: Int
}

struct DailySpinRecord: Codable, Equatable {
    var day: String
    var spinsUsed: Int
}

protocol DailySpinStorage {
    func loadRecord() -> DailySpinRecord?
    func saveRecord(_ record: DailySpinRecord)
}

final class KeychainDailySpinStorage: DailySpinStorage {
    private let key = "tokiyo.dailySpinRecord.v2"

    func loadRecord() -> DailySpinRecord? {
        guard let data = KeychainHelper.shared.retrieveData(for: key) else {
            return nil
        }
        return try? JSONDecoder().decode(DailySpinRecord.self, from: data)
    }

    func saveRecord(_ record: DailySpinRecord) {
        guard let data = try? JSONEncoder().encode(record) else {
            return
        }
        KeychainHelper.shared.storeData(data, for: key)
    }
}

final class DailySpinManager {
    static let shared = DailySpinManager(storage: KeychainDailySpinStorage())

    static let maxSpinsPerDay = 2

    static let rewardTiers: [DailySpinRewardTier] = [
        DailySpinRewardTier(amount: 250, weight: 35),
        DailySpinRewardTier(amount: 500, weight: 30),
        DailySpinRewardTier(amount: 750, weight: 20),
        DailySpinRewardTier(amount: 1_000, weight: 10),
        DailySpinRewardTier(amount: 1_500, weight: 4),
        DailySpinRewardTier(amount: 2_500, weight: 1),
    ]

    private static var totalRewardWeight: Int {
        rewardTiers.reduce(0) { $0 + $1.weight }
    }

    private let storage: DailySpinStorage
    private let calendar: Calendar
    private let dateProvider: () -> Date

    init(storage: DailySpinStorage,
         calendar: Calendar = .current,
         dateProvider: @escaping () -> Date = Date.init) {
        self.storage = storage
        self.calendar = calendar
        self.dateProvider = dateProvider
    }

    var remainingSpinsToday: Int {
        remainingSpins(on: dateProvider())
    }

    func remainingSpins(on date: Date) -> Int {
        let record = recordForDate(date)
        return max(0, Self.maxSpinsPerDay - record.spinsUsed)
    }

    func performSpin() throws -> DailySpinResult {
        var rng = SystemRandomNumberGenerator()
        return try performSpin(using: &rng)
    }

    func performSpin<R: RandomNumberGenerator>(using rng: inout R) throws -> DailySpinResult {
        let date = dateProvider()
        var record = recordForDate(date)

        guard record.spinsUsed < Self.maxSpinsPerDay else {
            throw DailySpinError.noSpinsRemaining
        }

        let reward = Self.rewardForRandomRoll(using: &rng)
        record.spinsUsed += 1
        storage.saveRecord(record)

        return DailySpinResult(
            reward: reward,
            remainingSpins: max(0, Self.maxSpinsPerDay - record.spinsUsed)
        )
    }

    static func rewardForRoll(_ roll: Int) -> Int64 {
        let clampedRoll = min(max(roll, 1), totalRewardWeight)
        var cumulative = 0

        for tier in rewardTiers {
            cumulative += tier.weight
            if clampedRoll <= cumulative {
                return tier.amount
            }
        }

        return rewardTiers.last?.amount ?? 0
    }

    private static func rewardForRandomRoll<R: RandomNumberGenerator>(using rng: inout R) -> Int64 {
        rewardForRoll(Int.random(in: 1...totalRewardWeight, using: &rng))
    }

    private func recordForDate(_ date: Date) -> DailySpinRecord {
        let today = dayString(for: date)

        guard var record = storage.loadRecord(), record.day == today else {
            return DailySpinRecord(day: today, spinsUsed: 0)
        }

        record.spinsUsed = max(0, min(record.spinsUsed, Self.maxSpinsPerDay))
        return record
    }

    private func dayString(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
