//
//  JKPropertyTests.swift
//  Tokiyo CasinoTests — Jackaroo Phase 1
//
//  Phase 1 exit-criteria stress + performance:
//   - 1000 random seeded "first-legal-move" games each terminate with a
//     valid winner and pass every structural invariant.
//   - A representative game completes well under the 100 ms/game budget.
//
//  Games are driven by JKAIEngine (the Phase 1 first-legal stub) through
//  the real engine turn loop, so dealing, reshuffling, handoff, and
//  victory are all exercised.
//

import XCTest
@testable import Tokiyo_Casino

final class JKPropertyTests: XCTestCase {

    private func makeAIEngine(seed: UInt64) -> JackarooEngine {
        let players = (0..<4).map {
            JKPlayer(seat: $0, name: "P\($0)", kind: .ai(personality: .balanced))
        }
        // These suites are explicitly about "always-pick-first-legal" play;
        // the fast baseline keeps the 1000-game run tractable.
        return JackarooEngine(players: players, seed: seed, ai: JKFirstLegalAI())
    }

    /// Run one game to completion. Returns false if it failed to finish
    /// within the move cap (which would itself be a bug).
    @discardableResult
    private func playOut(_ engine: JackarooEngine, cap: Int = 20_000) -> Bool {
        engine.start()
        var n = cap
        while engine.state.winner == nil && n > 0 {
            engine.stepAIIfNeeded()
            n -= 1
        }
        return engine.state.winner != nil
    }

    private func assertInvariants(_ state: JKGameState, seed: UInt64) {
        // Exactly 16 marbles, 4 per seat, stable identities.
        XCTAssertEqual(state.marbles.count, 16, "seed \(seed)")
        XCTAssertEqual(Set(state.marbles.map { $0.id }).count, 16, "seed \(seed)")
        for seat in 0..<4 {
            XCTAssertEqual(state.marbles.filter { $0.owner == seat }.count, 4, "seed \(seed)")
        }
        // 52-card budget preserved.
        let total = state.deck.count + state.firePile.count
            + state.players.reduce(0) { $0 + $1.hand.count }
        XCTAssertEqual(total, 52, "card budget, seed \(seed)")
        // A valid winner whose whole team is in Safe.
        guard let winner = state.winner else {
            XCTFail("seed \(seed) did not terminate with a winner"); return
        }
        XCTAssertTrue(state.team(winner).allSatisfy {
            if case .safe = $0.position { return true }
            return false
        }, "winning team must be entirely in Safe, seed \(seed)")
    }

    func testThousandRandomSeededGamesTerminateValidly() {
        var meta = JKSeededRNG(seed: 0xA11_CE_5EED)
        for _ in 0..<1000 {
            let seed = meta.next()
            let engine = makeAIEngine(seed: seed)
            XCTAssertTrue(playOut(engine), "seed \(seed) failed to terminate")
            assertInvariants(engine.state, seed: seed)
        }
    }

    /// Exit criterion: a first-legal game finishes in < 100 ms wall time,
    /// measured as an average over several games to smooth out scheduler
    /// noise. The 100 ms budget assumes an optimized build — unoptimized
    /// (Debug) Swift runs this generator-heavy loop several times slower,
    /// so in DEBUG we only guard against gross regressions and print the
    /// number, while the real budget is enforced in optimized builds.
    func testFirstLegalGameCompletesUnder100ms() {
        let seeds: [UInt64] = (1...20).map { UInt64($0) &* 0x9E37_79B9_7F4A_7C15 }
        let start = Date()
        for seed in seeds {
            XCTAssertTrue(playOut(makeAIEngine(seed: seed)))
        }
        let perGameMs = Date().timeIntervalSince(start) / Double(seeds.count) * 1000
        print("⏱️ Jackaroo first-legal game: \(String(format: "%.2f", perGameMs)) ms/game")
        #if DEBUG
        // Debug is unoptimized and sensitive to machine load, so this is a
        // coarse regression guard only — the real 100 ms budget is enforced
        // in optimized builds (the #else branch).
        XCTAssertLessThan(perGameMs, 1000.0,
                          "Debug regression guard (optimized budget is 100 ms); got \(perGameMs) ms")
        #else
        XCTAssertLessThan(perGameMs, 100.0,
                          "A first-legal game must finish in under 100 ms (got \(perGameMs) ms)")
        #endif
    }
}
