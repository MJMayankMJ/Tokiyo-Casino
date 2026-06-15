//
//  JKAutosaveTests.swift
//  Tokiyo CasinoTests — Jackaroo Phase 6
//
//  Crash-recovery autosave: a mid-game `JKGameState` survives a JSON
//  round-trip byte-for-byte (deterministic RNG included), a finished
//  game is never offered as resumable, and resuming reproduces the
//  exact same game to completion.
//

import XCTest
@testable import Tokiyo_Casino

final class JKAutosaveTests: XCTestCase {

    override func setUp() { super.setUp(); JKAutosave.clear() }
    override func tearDown() { JKAutosave.clear(); super.tearDown() }

    /// Drive an all-AI game `turns` steps in and return the live state.
    private func midGameState(seed: UInt64,
                              rules: JKRulesPreset = .jawakerBasic,
                              turns: Int) -> JKGameState {
        let players = (0..<4).map {
            JKPlayer(seat: $0, name: "P\($0)", kind: .ai(personality: .balanced))
        }
        let engine = JackarooEngine(players: players, rules: rules, seed: seed)
        engine.start()
        var n = turns
        while engine.state.winner == nil && n > 0 { engine.stepAIIfNeeded(); n -= 1 }
        return engine.state
    }

    func testAutosaveRoundTripsStateExactly() {
        let state = midGameState(seed: 0xA5A5, turns: 30)
        XCTAssertNil(state.winner, "fixture should be mid-game")
        JKAutosave.save(state)

        guard let r = JKAutosave.load() else { return XCTFail("autosave did not load") }
        XCTAssertEqual(r.currentSeat, state.currentSeat)
        XCTAssertEqual(r.dealer, state.dealer)
        XCTAssertEqual(r.handsDealt, state.handsDealt)
        XCTAssertEqual(r.rng.state, state.rng.state, "deterministic RNG must survive")
        XCTAssertEqual(r.log.count, state.log.count)
        XCTAssertEqual(r.deck, state.deck)
        XCTAssertEqual(r.firePile, state.firePile)
        XCTAssertEqual(r.handoffEngaged, state.handoffEngaged)
        for (a, b) in zip(r.marbles, state.marbles) {
            XCTAssertEqual(a.id, b.id)
            XCTAssertEqual(a.owner, b.owner)
            XCTAssertEqual(a.position, b.position)
        }
        for s in 0..<4 { XCTAssertEqual(r.players[s].hand, state.players[s].hand) }
    }

    func testFinishedGameIsNotResumable() {
        var state = midGameState(seed: 1, turns: 10)
        state.winner = .a
        JKAutosave.save(state)
        XCTAssertNil(JKAutosave.load(), "a finished game must not be offered as resumable")
        XCTAssertFalse(JKAutosave.hasResumableGame)
    }

    func testResumeReproducesTheExactGame() {
        let state = midGameState(seed: 0xBEEF, turns: 24)
        XCTAssertNil(state.winner, "fixture should be mid-game")

        func playOut(_ s: JKGameState) -> (winner: JKTeam?, log: Int) {
            let e = JackarooEngine(restoring: s)
            var n = 8000
            while e.state.winner == nil && n > 0 { e.stepAIIfNeeded(); n -= 1 }
            return (e.state.winner, e.state.log.count)
        }

        let direct = playOut(state)
        JKAutosave.save(state)
        guard let restored = JKAutosave.load() else { return XCTFail("no save") }
        let viaDisk = playOut(restored)

        XCTAssertNotNil(direct.winner)
        XCTAssertEqual(direct.winner, viaDisk.winner,
                       "resuming from disk must reach the same winner")
        XCTAssertEqual(direct.log, viaDisk.log,
                       "resuming from disk must reproduce the same game length")
    }
}
