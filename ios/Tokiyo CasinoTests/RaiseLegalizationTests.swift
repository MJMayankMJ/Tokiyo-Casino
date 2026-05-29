//
//  RaiseLegalizationTests.swift
//  Tokiyo CasinoTests
//
//  Phase 1 — pure-function coverage for AIEngine.legalize, per
//  POKER_AI_DESIGN.md §4.3. `PlayerAction.raise(Int)` is a DELTA over the
//  current table bet, not a total, so these tests pin down the conversion from
//  a desired total table bet into a legal action: min-raise bumping, all-in
//  downgrades for unaffordable raises, and non-raise downgrades to call/check.
//
//  PlayerAction is not Equatable, so every assertion pattern-matches.
//

import XCTest
@testable import Tokiyo_Casino

final class RaiseLegalizationTests: XCTestCase {

    // MARK: helpers (PlayerAction is not Equatable)

    private func assertRaise(_ action: PlayerAction, _ expectedDelta: Int,
                             _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        guard case let .raise(delta) = action else {
            return XCTFail("\(message): expected .raise(\(expectedDelta)), got \(action.description)", file: file, line: line)
        }
        XCTAssertEqual(delta, expectedDelta, message, file: file, line: line)
    }

    private func assertAllIn(_ action: PlayerAction, _ message: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        guard case .allIn = action else {
            return XCTFail("\(message): expected .allIn, got \(action.description)", file: file, line: line)
        }
    }

    private func assertCall(_ action: PlayerAction, _ message: String,
                            file: StaticString = #filePath, line: UInt = #line) {
        guard case .call = action else {
            return XCTFail("\(message): expected .call, got \(action.description)", file: file, line: line)
        }
    }

    private func assertCheck(_ action: PlayerAction, _ message: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        guard case .check = action else {
            return XCTFail("\(message): expected .check, got \(action.description)", file: file, line: line)
        }
    }

    // MARK: (a) target below min-raise → bumped to exactly minRaise

    func testTargetBelowMinRaiseBumpsToMinRaise() {
        // currentBet 100, want total 120 (delta 20) but minRaise is 50 →
        // delta must be bumped to exactly 50.
        let action = FastAIEngineLegalize(targetTotal: 120, currentBet: 100,
                                          playerCurrentBet: 0, playerChips: 1000,
                                          minRaise: 50, canRaise: true)
        assertRaise(action, 50, "sub-minRaise delta should bump to exactly minRaise")
    }

    func testNormalRaisePassesThroughDelta() {
        // currentBet 100, want total 300 → legal delta 200 (≥ minRaise, affordable).
        let action = FastAIEngineLegalize(targetTotal: 300, currentBet: 100,
                                          playerCurrentBet: 0, playerChips: 1000,
                                          minRaise: 50, canRaise: true)
        assertRaise(action, 200, "affordable above-min raise should pass through unchanged")
    }

    // MARK: (b) target ≥ stack → downgraded to .allIn

    func testTargetAtOrAboveStackIsAllIn() {
        // Committing call+delta == chips → all-in (can't leave a non-raise stub).
        let action = FastAIEngineLegalize(targetTotal: 1000, currentBet: 100,
                                          playerCurrentBet: 0, playerChips: 1000,
                                          minRaise: 50, canRaise: true)
        assertAllIn(action, "raise that commits the whole stack should be .allIn")
    }

    func testTargetBeyondStackIsAllIn() {
        let action = FastAIEngineLegalize(targetTotal: 5000, currentBet: 100,
                                          playerCurrentBet: 0, playerChips: 1000,
                                          minRaise: 50, canRaise: true)
        assertAllIn(action, "raise beyond the stack should be .allIn")
    }

    // MARK: (c) short all-in below minRaise → .allIn

    func testShortAllInBelowMinRaiseIsAllIn() {
        // Player has only 40 chips, minRaise 50, facing a bet of 100 over a 0
        // current bet. Even bumping to minRaise the chips can't cover it → all-in.
        let action = FastAIEngineLegalize(targetTotal: 130, currentBet: 100,
                                          playerCurrentBet: 0, playerChips: 40,
                                          minRaise: 50, canRaise: true)
        assertAllIn(action, "raise the player can't fund should downgrade to .allIn")
    }

    // MARK: (d) zero / negative delta → non-raise downgrade

    func testTargetAtCurrentBetDowngradesToCall() {
        // target == currentBet → rawDelta 0 → non-raise. Facing a bet so → call.
        let action = FastAIEngineLegalize(targetTotal: 100, currentBet: 100,
                                          playerCurrentBet: 0, playerChips: 1000,
                                          minRaise: 50, canRaise: true)
        assertCall(action, "target at current bet should downgrade to .call")
    }

    func testTargetBelowCurrentBetDowngradesToCall() {
        let action = FastAIEngineLegalize(targetTotal: 80, currentBet: 100,
                                          playerCurrentBet: 0, playerChips: 1000,
                                          minRaise: 50, canRaise: true)
        assertCall(action, "target below current bet should downgrade to .call")
    }

    func testNonRaiseWithNothingToCallChecks() {
        // No outstanding bet (currentBet == playerCurrentBet) and a non-raise → check.
        let action = FastAIEngineLegalize(targetTotal: 0, currentBet: 100,
                                          playerCurrentBet: 100, playerChips: 1000,
                                          minRaise: 50, canRaise: true)
        assertCheck(action, "non-raise with nothing to call should be .check")
    }

    // MARK: (e) cannot raise (no live opponent) → call/check only

    func testCannotRaiseFacingBetCalls() {
        let action = FastAIEngineLegalize(targetTotal: 300, currentBet: 100,
                                          playerCurrentBet: 0, playerChips: 1000,
                                          minRaise: 50, canRaise: false)
        assertCall(action, "canRaise=false facing a bet should be .call")
    }

    func testCannotRaiseNothingToCallChecks() {
        let action = FastAIEngineLegalize(targetTotal: 300, currentBet: 100,
                                          playerCurrentBet: 100, playerChips: 1000,
                                          minRaise: 50, canRaise: false)
        assertCheck(action, "canRaise=false with nothing to call should be .check")
    }

    func testCannotRaiseShortStackFacingBetIsAllIn() {
        // canRaise=false, facing a bet larger than the stack → all-in call.
        let action = FastAIEngineLegalize(targetTotal: 300, currentBet: 100,
                                          playerCurrentBet: 0, playerChips: 60,
                                          minRaise: 50, canRaise: false)
        assertAllIn(action, "canRaise=false short stack facing a bet should be .allIn")
    }

    // MARK: shim — keeps call sites readable

    private func FastAIEngineLegalize(targetTotal: Int, currentBet: Int,
                                      playerCurrentBet: Int, playerChips: Int,
                                      minRaise: Int, canRaise: Bool) -> PlayerAction {
        AIEngine.legalize(targetTotal: targetTotal, currentBet: currentBet,
                          playerCurrentBet: playerCurrentBet, playerChips: playerChips,
                          minRaise: minRaise, canRaise: canRaise)
    }
}
