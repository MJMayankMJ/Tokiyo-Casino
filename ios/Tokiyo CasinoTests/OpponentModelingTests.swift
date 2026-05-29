//
//  OpponentModelingTests.swift
//  Tokiyo CasinoTests
//
//  Phase 3 — opponent modeling (POKER_AI_DESIGN.md §6). Three layers under test:
//  the `HandHistoryTracker`'s event folding (VPIP/PFR/AF/fold-to-cbet/
//  fold-to-3bet/WTSD opportunity counting), the `OpponentModel` sample-size
//  blending, and the pure `Exploit` adjustment. These pin the contract the
//  Hard/Expert AI relies on to adapt to a human's tendencies.
//

import XCTest
@testable import Tokiyo_Casino

final class OpponentModelingTests: XCTestCase {

    // MARK: - HandHistoryTracker: preflop VPIP / PFR

    func testOpenRaiseCountsVpipAndPfr_callerOnlyVpip_folderNeither() {
        let t = HandHistoryTracker()
        t.handStarted(button: 0, seats: [0, 1, 2])

        // seat0 opens (raise over the BB of 20): voluntary + raise.
        t.recordAction(seat: 0, action: .raise(40), callAmount: 20, raisedBet: true)
        // seat1 calls the open: voluntary, not a raise.
        t.recordAction(seat: 1, action: .call, callAmount: 40, raisedBet: false)
        // seat2 folds: neither.
        t.recordAction(seat: 2, action: .fold, callAmount: 40, raisedBet: false)

        XCTAssertEqual(t.rawStats(for: 0).handsDealt, 1)
        XCTAssertEqual(t.rawStats(for: 0).vpipCount, 1)
        XCTAssertEqual(t.rawStats(for: 0).pfrCount, 1)

        XCTAssertEqual(t.rawStats(for: 1).vpipCount, 1)
        XCTAssertEqual(t.rawStats(for: 1).pfrCount, 0)

        XCTAssertEqual(t.rawStats(for: 2).vpipCount, 0)
        XCTAssertEqual(t.rawStats(for: 2).pfrCount, 0)
    }

    func testBigBlindCheckingOptionIsNotVoluntary() {
        let t = HandHistoryTracker()
        t.handStarted(button: 0, seats: [0, 1])
        // BB checks its option (no bet to call): not voluntary, not a raise.
        t.recordAction(seat: 1, action: .check, callAmount: 0, raisedBet: false)
        XCTAssertEqual(t.rawStats(for: 1).vpipCount, 0)
        XCTAssertEqual(t.rawStats(for: 1).pfrCount, 0)
    }

    // MARK: - HandHistoryTracker: fold to 3-bet

    func testFoldTo3BetCountsOpportunityAndFold() {
        let t = HandHistoryTracker()
        t.handStarted(button: 0, seats: [0, 1, 2])

        t.recordAction(seat: 0, action: .raise(40), callAmount: 20, raisedBet: true)   // open (raises=1)
        t.recordAction(seat: 1, action: .raise(80), callAmount: 40, raisedBet: true)   // 3-bet (raises=2)
        t.recordAction(seat: 2, action: .fold, callAmount: 80, raisedBet: false)       // faces 3-bet, folds
        t.recordAction(seat: 0, action: .fold, callAmount: 60, raisedBet: false)       // faces 3-bet, folds

        XCTAssertEqual(t.rawStats(for: 2).faced3bet, 1)
        XCTAssertEqual(t.rawStats(for: 2).foldedTo3bet, 1)
        XCTAssertEqual(t.rawStats(for: 0).faced3bet, 1)
        XCTAssertEqual(t.rawStats(for: 0).foldedTo3bet, 1)
        // The 3-bettor never faced a 3-bet.
        XCTAssertEqual(t.rawStats(for: 1).faced3bet, 0)
    }

    // MARK: - HandHistoryTracker: fold to c-bet

    func testFoldToCbetOnlyCountsAgainstPreflopAggressorsFlopBet() {
        let t = HandHistoryTracker()
        t.handStarted(button: 0, seats: [0, 1])

        // Preflop: seat0 opens, seat1 calls. seat0 is the preflop aggressor.
        t.recordAction(seat: 0, action: .raise(40), callAmount: 20, raisedBet: true)
        t.recordAction(seat: 1, action: .call, callAmount: 40, raisedBet: false)

        t.streetBegan(.flop)
        // seat1 checks, seat0 c-bets, seat1 folds to the c-bet.
        t.recordAction(seat: 1, action: .check, callAmount: 0, raisedBet: false)
        t.recordAction(seat: 0, action: .raise(50), callAmount: 0, raisedBet: true)   // c-bet
        t.recordAction(seat: 1, action: .fold, callAmount: 50, raisedBet: false)

        XCTAssertEqual(t.rawStats(for: 1).facedCbet, 1)
        XCTAssertEqual(t.rawStats(for: 1).foldedToCbet, 1)
        // The c-bettor never faced a c-bet.
        XCTAssertEqual(t.rawStats(for: 0).facedCbet, 0)
        // Both saw the flop.
        XCTAssertEqual(t.rawStats(for: 0).sawFlop, 1)
        XCTAssertEqual(t.rawStats(for: 1).sawFlop, 1)
    }

    func testDonkBetIsNotACbet() {
        let t = HandHistoryTracker()
        t.handStarted(button: 0, seats: [0, 1])
        // seat0 opens (aggressor), seat1 calls.
        t.recordAction(seat: 0, action: .raise(40), callAmount: 20, raisedBet: true)
        t.recordAction(seat: 1, action: .call, callAmount: 40, raisedBet: false)

        t.streetBegan(.flop)
        // seat1 (NOT the preflop aggressor) leads out — a donk bet, not a c-bet.
        t.recordAction(seat: 1, action: .raise(50), callAmount: 0, raisedBet: true)
        t.recordAction(seat: 0, action: .fold, callAmount: 50, raisedBet: false)

        // seat0 folded to a donk bet, which must NOT count as fold-to-cbet.
        XCTAssertEqual(t.rawStats(for: 0).facedCbet, 0)
        XCTAssertEqual(t.rawStats(for: 0).foldedToCbet, 0)
    }

    // MARK: - HandHistoryTracker: postflop aggression factor counts

    func testPostflopBetsAndCallsAccumulate() {
        let t = HandHistoryTracker()
        t.handStarted(button: 0, seats: [0, 1])
        t.recordAction(seat: 0, action: .raise(40), callAmount: 20, raisedBet: true)
        t.recordAction(seat: 1, action: .call, callAmount: 40, raisedBet: false)

        t.streetBegan(.flop)
        t.recordAction(seat: 0, action: .raise(50), callAmount: 0, raisedBet: true)   // bet
        t.recordAction(seat: 1, action: .call, callAmount: 50, raisedBet: false)      // call

        t.streetBegan(.turn)
        t.recordAction(seat: 0, action: .raise(80), callAmount: 0, raisedBet: true)   // bet
        t.recordAction(seat: 1, action: .raise(160), callAmount: 80, raisedBet: true) // raise

        XCTAssertEqual(t.rawStats(for: 0).postflopBets, 2)
        XCTAssertEqual(t.rawStats(for: 0).postflopCalls, 0)
        XCTAssertEqual(t.rawStats(for: 1).postflopBets, 1)
        XCTAssertEqual(t.rawStats(for: 1).postflopCalls, 1)
    }

    func testAllInThatOnlyCallsIsACallNotAggression() {
        let t = HandHistoryTracker()
        t.handStarted(button: 0, seats: [0, 1])
        t.recordAction(seat: 0, action: .raise(40), callAmount: 20, raisedBet: true)
        t.recordAction(seat: 1, action: .call, callAmount: 40, raisedBet: false)
        t.streetBegan(.flop)
        t.recordAction(seat: 0, action: .raise(50), callAmount: 0, raisedBet: true)
        // seat1 jams all-in but it does not exceed the bet (raisedBet == false).
        t.recordAction(seat: 1, action: .allIn, callAmount: 50, raisedBet: false)

        XCTAssertEqual(t.rawStats(for: 1).postflopBets, 0)
        XCTAssertEqual(t.rawStats(for: 1).postflopCalls, 1)
    }

    // MARK: - HandHistoryTracker: WTSD

    func testWentToShowdownCountsOnlyNonFoldedSeats() {
        let t = HandHistoryTracker()
        t.handStarted(button: 0, seats: [0, 1])
        t.recordAction(seat: 0, action: .raise(40), callAmount: 20, raisedBet: true)
        t.recordAction(seat: 1, action: .call, callAmount: 40, raisedBet: false)

        t.streetBegan(.flop)
        t.recordAction(seat: 0, action: .raise(50), callAmount: 0, raisedBet: true)
        t.recordAction(seat: 1, action: .fold, callAmount: 50, raisedBet: false)
        // seat1 folded the flop, so the hand actually ends without showdown — but
        // assert the showdown accounting in isolation: only non-folded seats count.
        t.handEnded(wentToShowdown: true)

        XCTAssertEqual(t.rawStats(for: 0).sawFlop, 1)
        XCTAssertEqual(t.rawStats(for: 0).wentToShowdown, 1)
        XCTAssertEqual(t.rawStats(for: 1).sawFlop, 1)        // saw the flop before folding
        XCTAssertEqual(t.rawStats(for: 1).wentToShowdown, 0) // folded → no showdown credit
    }

    func testFoldEndedHandGrantsNoShowdown() {
        let t = HandHistoryTracker()
        t.handStarted(button: 0, seats: [0, 1])
        t.recordAction(seat: 0, action: .raise(40), callAmount: 20, raisedBet: true)
        t.recordAction(seat: 1, action: .fold, callAmount: 40, raisedBet: false)
        t.handEnded(wentToShowdown: false)

        XCTAssertEqual(t.rawStats(for: 0).wentToShowdown, 0)
        XCTAssertEqual(t.rawStats(for: 0).sawFlop, 0)   // never reached the flop
        XCTAssertEqual(t.rawStats(for: 1).wentToShowdown, 0)
    }

    // MARK: - OpponentModel: sample-size blending

    func testEmptyModelReturnsPriorsFromBaseline() {
        let model = OpponentModel(stats: OpponentStats(), prior: .populationBaseline)
        // Baseline: looseness 0.5, aggression 0.4, callStation 0.5.
        XCTAssertEqual(model.vpip, 0.375, accuracy: 1e-9)        // 0.15 + 0.5*0.45
        XCTAssertEqual(model.af, 1.7, accuracy: 1e-9)            // 0.5 + 0.4*3
        XCTAssertEqual(model.foldToCbet, 0.5, accuracy: 1e-9)    // 0.30 + 0.5*0.40
        XCTAssertEqual(model.foldTo3bet, 0.6, accuracy: 1e-9)    // 0.40 + 0.5*0.40
        XCTAssertEqual(model.wtsd, 0.34, accuracy: 1e-9)         // 0.18 + 0.5*0.32
    }

    func testLargeSampleIsFullyTrusted() {
        var s = OpponentStats()
        s.handsDealt = 60
        s.vpipCount = 60        // observed VPIP = 1.0, weight = 1.0
        let model = OpponentModel(stats: s, prior: .populationBaseline)
        XCTAssertEqual(model.vpip, 1.0, accuracy: 1e-9)
    }

    func testSmallSampleIsBlendedTowardPrior() {
        var s = OpponentStats()
        s.handsDealt = 15       // weight = 15/30 = 0.5
        s.vpipCount = 15        // raw = 1.0
        let model = OpponentModel(stats: s, prior: .populationBaseline)
        // 1.0*0.5 + 0.375*0.5 = 0.6875
        XCTAssertEqual(model.vpip, 0.6875, accuracy: 1e-9)
    }

    // MARK: - Exploit

    private func bigSample(vpip: Double, foldToCbet: Double, af: Double) -> OpponentModel {
        // Build stats with >= 30 opportunities everywhere so the adaptation ramp
        // is at full strength and observed rates dominate the prior.
        var s = OpponentStats()
        s.handsDealt = 40
        s.vpipCount = Int((vpip * 40).rounded())
        s.facedCbet = 40
        s.foldedToCbet = Int((foldToCbet * 40).rounded())
        // af = bets/calls; pick calls = 10, bets = af*10.
        s.postflopCalls = 10
        s.postflopBets = Int((af * 10).rounded())
        return OpponentModel(stats: s, prior: .populationBaseline)
    }

    func testExploitOffIsIdentity() {
        let station = bigSample(vpip: 0.9, foldToCbet: 0.0, af: 0.2)
        let out = Exploit.adjusted(profile: .solverInspired, vs: station, intensity: .off)
        XCTAssertEqual(out, .solverInspired)
    }

    func testExploitNoSignalIsIdentity() {
        // Empty stats → all priors → no archetype threshold is crossed, and the
        // adaptation ramp is 0 (handsObserved == 0), so the profile is unchanged.
        let neutral = OpponentModel(stats: OpponentStats(), prior: .populationBaseline)
        let out = Exploit.adjusted(profile: .solverInspired, vs: neutral, intensity: .on)
        XCTAssertEqual(out, .solverInspired)
    }

    func testExploitCallingStationCutsBluffsAndBetsBigger() {
        let station = bigSample(vpip: 0.9, foldToCbet: 0.0, af: 0.2)
        let out = Exploit.adjusted(profile: .solverInspired, vs: station, intensity: .on)
        XCTAssertLessThan(out.bluffFrequency, AIProfile.solverInspired.bluffFrequency)
        XCTAssertGreaterThan(out.aggression, AIProfile.solverInspired.aggression)
        XCTAssertLessThan(out.trickiness, AIProfile.solverInspired.trickiness)
    }

    func testExploitNitBluffsMore() {
        let nit = bigSample(vpip: 0.05, foldToCbet: 1.0, af: 0.5)
        let out = Exploit.adjusted(profile: .solverInspired, vs: nit, intensity: .on)
        XCTAssertGreaterThan(out.bluffFrequency, AIProfile.solverInspired.bluffFrequency)
        XCTAssertGreaterThan(out.aggression, AIProfile.solverInspired.aggression)
    }

    func testExploitManiacTightensAndTraps() {
        // High AF, but not a calling station (vpip mid, foldToCbet high).
        let maniac = bigSample(vpip: 0.5, foldToCbet: 0.7, af: 8.0)
        let out = Exploit.adjusted(profile: .solverInspired, vs: maniac, intensity: .on)
        XCTAssertLessThan(out.looseness, AIProfile.solverInspired.looseness)
        XCTAssertGreaterThan(out.trickiness, AIProfile.solverInspired.trickiness)
        XCTAssertLessThan(out.bluffFrequency, AIProfile.solverInspired.bluffFrequency)
    }

    func testExploitIsInertBelowMinSampleThenAdapts() {
        // A model that clearly reads as a maniac (capped AF) ...
        var s = OpponentStats()
        s.postflopBets = 30
        s.postflopCalls = 0
        s.handsDealt = Exploit.minHandsToAdapt - 1   // just under the floor
        let thin = OpponentModel(stats: s, prior: .populationBaseline)
        XCTAssertEqual(thin.af, 10.0, accuracy: 1e-9)
        // ... is still ignored because the sample is too thin: identity.
        XCTAssertEqual(Exploit.adjusted(profile: .solverInspired, vs: thin, intensity: .on), .solverInspired)

        // At the floor the same read starts tilting (maniac → tighter calling).
        s.handsDealt = Exploit.minHandsToAdapt
        let atFloor = OpponentModel(stats: s, prior: .populationBaseline)
        let out = Exploit.adjusted(profile: .solverInspired, vs: atFloor, intensity: .on)
        XCTAssertLessThan(out.looseness, AIProfile.solverInspired.looseness)
    }

    func testExploitClampsAndAggressiveTiltsHarder() {
        let station = bigSample(vpip: 0.9, foldToCbet: 0.0, af: 0.2)
        let aggressive = Exploit.adjusted(profile: .solverInspired, vs: station, intensity: .aggressive)
        let normal = Exploit.adjusted(profile: .solverInspired, vs: station, intensity: .on)
        // Aggressive intensity cuts bluffs at least as hard, and never escapes [0,1].
        XCTAssertLessThanOrEqual(aggressive.bluffFrequency, normal.bluffFrequency)
        XCTAssertGreaterThanOrEqual(aggressive.bluffFrequency, 0.0)
        XCTAssertLessThanOrEqual(aggressive.aggression, 1.0)
    }
}
