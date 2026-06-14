//
//  JKReplayTests.swift
//  Tokiyo CasinoTests — Jackaroo Phase 1
//
//  Determinism + replay (JACKAROO_SPEC.md §1, §7 ec 11):
//   - Two engines started from the same seed produce byte-for-byte
//     identical end states and logs (deeper than the smoke test, which
//     only compares log length + winner).
//   - The Fire Pile is reshuffled back into the deck when the draw stack
//     empties mid-game, and the reshuffle is recorded in the log without
//     derailing the game.
//

import XCTest
@testable import Tokiyo_Casino

final class JKReplayTests: XCTestCase {

    private func makeAIEngine(seed: UInt64) -> JackarooEngine {
        let players = (0..<4).map {
            JKPlayer(seat: $0, name: "P\($0)", kind: .ai(personality: .balanced))
        }
        return JackarooEngine(players: players, seed: seed)
    }

    private func runToEnd(_ engine: JackarooEngine, cap: Int = 10_000) {
        var n = cap
        while engine.state.winner == nil && n > 0 {
            engine.stepAIIfNeeded()
            n -= 1
        }
    }

    func testReplay_producesIdenticalEndStateAndLog() {
        let a = makeAIEngine(seed: 0xC0FFEE)
        let b = makeAIEngine(seed: 0xC0FFEE)
        a.start(); b.start()
        runToEnd(a); runToEnd(b)

        XCTAssertNotNil(a.state.winner)
        XCTAssertEqual(a.state.winner, b.state.winner)
        XCTAssertEqual(a.state.log, b.state.log, "Same seed must replay an identical log")
        XCTAssertEqual(a.state.marbles, b.state.marbles, "Final marble layout must match")
        XCTAssertEqual(a.state.firePile, b.state.firePile)
        XCTAssertEqual(a.state.deck, b.state.deck)
        XCTAssertEqual(a.state.handsDealt, b.state.handsDealt)
    }

    func testReplay_diverges_forDifferentSeeds() {
        let a = makeAIEngine(seed: 1); a.start(); runToEnd(a)
        let b = makeAIEngine(seed: 2); b.start(); runToEnd(b)
        // Overwhelmingly likely to differ; guards against a constant-seed bug.
        XCTAssertNotEqual(a.state.log, b.state.log)
    }

    // MARK: - ec 11 — reshuffle mid-hand

    func testReshuffle_happensAndIsLoggedDuringAFullGame() {
        let engine = makeAIEngine(seed: 0xC0FFEE)
        engine.start()
        runToEnd(engine)

        XCTAssertNotNil(engine.state.winner, "Game must complete")
        XCTAssertTrue(engine.state.log.contains { if case .reshuffled = $0 { return true }; return false },
                      "A full game exhausts the 52-card deck and must reshuffle the Fire Pile")
        // The reshuffle preserved the card budget.
        let s = engine.state
        let total = s.deck.count + s.firePile.count
            + s.players.reduce(0) { $0 + $1.hand.count }
        XCTAssertEqual(total, 52)
    }
}
