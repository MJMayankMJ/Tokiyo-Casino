import XCTest
@testable import Tokiyo_Casino

final class DailySpinManagerTests: XCTestCase {

    func testStartsWithTwoSpins() {
        let manager = makeManager(day: 28)
        XCTAssertEqual(manager.remainingSpinsToday, 2)
    }

    func testFirstAndSecondSpinsAwardCoinsAndDecrementRemainingCount() throws {
        let manager = makeManager(day: 28)
        var rng = FixedRandomNumberGenerator(values: [0, 99])
        let validRewards = Set(DailySpinManager.rewardTiers.map(\.amount))

        let first = try manager.performSpin(using: &rng)
        XCTAssertTrue(validRewards.contains(first.reward))
        XCTAssertEqual(first.remainingSpins, 1)

        let second = try manager.performSpin(using: &rng)
        XCTAssertTrue(validRewards.contains(second.reward))
        XCTAssertEqual(second.remainingSpins, 0)
        XCTAssertEqual(manager.remainingSpinsToday, 0)
    }

    func testThirdSameDaySpinIsBlocked() throws {
        let manager = makeManager(day: 28)
        var rng = FixedRandomNumberGenerator(values: [0, 1, 2])

        _ = try manager.performSpin(using: &rng)
        _ = try manager.performSpin(using: &rng)

        XCTAssertThrowsError(try manager.performSpin(using: &rng)) { error in
            XCTAssertEqual(error as? DailySpinError, .noSpinsRemaining)
        }
    }

    func testSpinsResetOnNextLocalDay() throws {
        let storage = InMemoryDailySpinStorage()
        let firstDay = fixedDate(day: 28)
        let secondDay = fixedDate(day: 29)
        var currentDate = firstDay
        let manager = DailySpinManager(
            storage: storage,
            calendar: testCalendar,
            dateProvider: { currentDate }
        )
        var rng = FixedRandomNumberGenerator(values: [0, 1, 2, 3])

        _ = try manager.performSpin(using: &rng)
        _ = try manager.performSpin(using: &rng)
        XCTAssertEqual(manager.remainingSpinsToday, 0)

        currentDate = secondDay
        XCTAssertEqual(manager.remainingSpinsToday, 2)
    }

    func testRewardSelectionOnlyReturnsConfiguredTiers() {
        let validRewards = Set(DailySpinManager.rewardTiers.map(\.amount))

        for roll in 1...100 {
            XCTAssertTrue(validRewards.contains(DailySpinManager.rewardForRoll(roll)))
        }
    }

    private func makeManager(day: Int) -> DailySpinManager {
        DailySpinManager(
            storage: InMemoryDailySpinStorage(),
            calendar: testCalendar,
            dateProvider: { self.fixedDate(day: day) }
        )
    }

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return calendar
    }

    private func fixedDate(day: Int) -> Date {
        DateComponents(
            calendar: testCalendar,
            timeZone: testCalendar.timeZone,
            year: 2026,
            month: 5,
            day: day,
            hour: 10,
            minute: 0
        ).date!
    }
}

private final class InMemoryDailySpinStorage: DailySpinStorage {
    private var record: DailySpinRecord?

    func loadRecord() -> DailySpinRecord? {
        record
    }

    func saveRecord(_ record: DailySpinRecord) {
        self.record = record
    }
}

private struct FixedRandomNumberGenerator: RandomNumberGenerator {
    private var values: [UInt64]
    private var index = 0

    init(values: [UInt64]) {
        self.values = values
    }

    mutating func next() -> UInt64 {
        defer { index += 1 }
        return values[index % values.count]
    }
}
