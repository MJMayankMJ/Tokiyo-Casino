//
//  TDPDebugScenarioTests.swift
//  Tokiyo CasinoTests — Teen Do Paanch
//
//  The debug shortcuts build states by hand; prove each is a legal table
//  that lands on exactly the debt it promises.
//

#if DEBUG
import XCTest
@testable import Tokiyo_Casino

final class TDPDebugScenarioTests: XCTestCase {

    private func settled(_ scenario: TDPDebugScenario) -> TDPEngine {
        let engine = TDPEngine(state: scenario.makeState(playerName: "You"))
        engine.flushAutomatic()                       // deals the last two
        return engine
    }

    func testEveryScenarioIsALegalTableAtSettleUp() {
        for scenario in TDPDebugScenario.allCases {
            let engine = settled(scenario)
            XCTAssertEqual(engine.state.phase, .settle, "\(scenario)")
            XCTAssertEqual(engine.state.players.map(\.hand.count), [10, 10, 10], "\(scenario)")
            XCTAssertEqual(Set(engine.state.players.flatMap(\.hand).map(\.tdpID)).count, 30, "\(scenario)")
            for round in engine.state.roundHistory {
                XCTAssertEqual(round.delta.values.reduce(0, +), 0, "\(scenario) round \(round.round)")
                XCTAssertEqual(round.tricks.values.reduce(0, +), 10, "\(scenario) round \(round.round)")
            }
        }
    }

    func testScenarioDebtsAndLocks() {
        let owe = settled(.youOwe).state
        XCTAssertEqual(owe.debts, [TDPDebt(from: 0, to: 1, amount: 2)])
        XCTAssertFalse(TDPEngine.isGiveTricksLocked(owe, debtor: 0, creditor: 1))

        let locked = settled(.youOweLocked).state
        XCTAssertEqual(locked.debts, [TDPDebt(from: 0, to: 1, amount: 2)])
        XCTAssertTrue(TDPEngine.isGiveTricksLocked(locked, debtor: 0, creditor: 1))

        let two = settled(.youOweTwo).state
        XCTAssertEqual(Set(two.debts.map(\.to)), [1, 2])
        XCTAssertTrue(two.debts.allSatisfy { $0.from == 0 })

        let owed = settled(.youAreOwed).state
        XCTAssertEqual(owed.debts, [TDPDebt(from: 1, to: 0, amount: 2)])
    }

    func testGivingCardsOpensTheArrangingWindowBetweenTheTwoPeople() {
        let engine = settled(.youOwe)
        XCTAssertNil(engine.apply(.settle(seat: 0, choices: [1: .giveCards])))
        XCTAssertEqual(engine.state.khichaiCurrent?.arranging, true)
    }
}
#endif
