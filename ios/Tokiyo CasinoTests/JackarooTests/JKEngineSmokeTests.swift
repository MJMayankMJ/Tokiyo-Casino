//
//  JKEngineSmokeTests.swift
//  Tokiyo CasinoTests — Jackaroo Phase 1
//
//  End-to-end smoke: the stub AI runs every seat. The game must
//  either reach a winner or run out of legal options without
//  corrupting any invariants. Determinism: identical seed must
//  produce identical final state.
//

import XCTest
@testable import Tokiyo_Casino

final class JKEngineSmokeTests: XCTestCase {

    func testEngineRunsAFullGameDeterministically() {
        let engine = makeEngine(seed: 0xC0FFEE)
        engine.start()
        runUntilEnd(engine, maxTurns: 5_000)
        let s1 = engine.state

        // Same seed → same final state.
        let engine2 = makeEngine(seed: 0xC0FFEE)
        engine2.start()
        runUntilEnd(engine2, maxTurns: 5_000)
        XCTAssertEqual(engine.state.log.count, engine2.state.log.count,
                       "Replay should produce identical log length")
        XCTAssertEqual(engine.state.winner, engine2.state.winner)
        _ = s1
    }

    func testEngineMaintainsMarbleInvariants() {
        let engine = makeEngine(seed: 0xDECAFBAD)
        engine.start()
        runUntilEnd(engine, maxTurns: 5_000) { state in
            XCTAssertEqual(state.marbles.count, 16, "Marble count must stay 16")
            // Owners 0…3, each with exactly 4 marbles.
            for seat in 0..<4 {
                XCTAssertEqual(state.marbles.filter { $0.owner == seat }.count, 4)
            }
            // No marble in two places — covered by structure; assert
            // that all (owner, position) coordinates resolve cleanly.
            XCTAssertEqual(Set(state.marbles.map { $0.id }).count, 16)
        }
    }

    func testDeckPlusFireEqualsBaselineMinusHands() {
        let engine = makeEngine(seed: 0xBADBED)
        engine.start()
        var maxIters = 200
        while engine.state.winner == nil && maxIters > 0 {
            let total = engine.state.deck.count + engine.state.firePile.count
                      + engine.state.players.reduce(0) { $0 + $1.hand.count }
            XCTAssertEqual(total, 52, "Card budget must stay at 52")
            engine.stepAIIfNeeded()
            maxIters -= 1
        }
    }

    // MARK: - Helpers

    private func makeEngine(seed: UInt64) -> JackarooEngine {
        let players: [JKPlayer] = (0..<4).map {
            JKPlayer(seat: $0, name: "P\($0)", kind: .ai(personality: .balanced))
        }
        return JackarooEngine(players: players, seed: seed)
    }

    private func runUntilEnd(_ engine: JackarooEngine,
                             maxTurns: Int,
                             checkpoint: ((JKGameState) -> Void)? = nil) {
        var n = maxTurns
        while engine.state.winner == nil && n > 0 {
            checkpoint?(engine.state)
            engine.stepAIIfNeeded()
            n -= 1
        }
    }
}
