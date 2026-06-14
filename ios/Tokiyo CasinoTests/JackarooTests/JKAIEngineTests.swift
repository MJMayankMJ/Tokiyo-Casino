//
//  JKAIEngineTests.swift
//  Tokiyo CasinoTests — Jackaroo Phase 4
//
//  The heuristic AI: never burns when a real move exists, prefers a
//  worthwhile capture over plain progress, and its personalities bias
//  play in observable ways. Also a competence check (heuristic beats the
//  first-legal stub) and a no-illegal-move / termination check.
//

import XCTest
@testable import Tokiyo_Casino

final class JKAIEngineTests: XCTestCase {

    private let graph = JKBoardGraph()
    private func ai() -> JKAIEngine { JKAIEngine(graph: graph) }

    // MARK: - Never burns when an alternative exists

    func testNeverBurnsWhenAnAlternativeExists() {
        var state = JKFixture.makeState()
        JKFixture.place(0, at: .track(10), in: &state)
        JKFixture.setHand([JKFixture.twoHearts], for: 0, in: &state)

        let real = JKMove.forward(card: JKFixture.twoHearts, marble: 0, steps: 2)
        let burn = JKMove.burnHand(cards: [JKFixture.twoHearts])

        XCTAssertEqual(ai().chooseMove(for: 0, moves: [burn, real], state: state), real)
        XCTAssertEqual(ai().chooseMove(for: 0, moves: [real, burn], state: state), real)
        // When burning is the ONLY option, it is chosen.
        XCTAssertEqual(ai().chooseMove(for: 0, moves: [burn], state: state), burn)
    }

    // MARK: - Capture over progress

    func testPrefersDistantCaptureOverPlainProgress() {
        var state = JKFixture.makeState()
        state.players[0] = JKPlayer(seat: 0, name: "AI",
                                    kind: .ai(personality: .tightAggressive))
        // Own marble that can capture an opponent far from its home...
        JKFixture.place(0, at: .track(10), in: &state)
        JKFixture.place(4, at: .track(13), in: &state)      // seat 1 opponent
        // ...and another own marble that can only make plain progress.
        JKFixture.place(1, at: .track(40), in: &state)
        let three = JKCard(suit: .clubs, rank: .three)
        JKFixture.setHand([three, JKFixture.twoHearts], for: 0, in: &state)

        let capture = JKMove.forward(card: three, marble: 0, steps: 3)         // lands on marble 4
        let progress = JKMove.forward(card: JKFixture.twoHearts, marble: 1, steps: 2)

        XCTAssertEqual(ai().chooseMove(for: 0, moves: [progress, capture], state: state),
                       capture, "A far capture must beat plain progress")
    }

    // MARK: - Personality bias

    func testTightAggressiveCapturesMoreThanLoosePassive() {
        // The AI is deterministic and these seeds are fixed, so the result is
        // stable run-to-run; the game count is about seed diversity, not
        // flakiness. (The plan's "1000 games" is calibration colour — the
        // bias is already unambiguous at this sample.)
        var tightCaptures = 0
        var looseCaptures = 0
        for i in 0..<200 {
            // Team A (seats 0,2) tight-aggressive; Team B (seats 1,3) loose-passive.
            let players = (0..<4).map { seat in
                JKPlayer(seat: seat, name: "P\(seat)",
                         kind: .ai(personality: seat % 2 == 0 ? .tightAggressive : .loosePassive))
            }
            let engine = JackarooEngine(players: players, seed: UInt64(0xA1CE &+ i &* 7))
            engine.start()
            var n = 6000
            while engine.state.winner == nil && n > 0 { engine.stepAIIfNeeded(); n -= 1 }
            for e in engine.state.log {
                if case let .captured(_, by) = e {
                    if by % 2 == 0 { tightCaptures += 1 } else { looseCaptures += 1 }
                }
            }
        }
        XCTAssertGreaterThan(tightCaptures, looseCaptures,
                             "tight-aggressive (\(tightCaptures)) should capture more than loose-passive (\(looseCaptures))")
    }

    // MARK: - Competence vs the first-legal stub

    func testHeuristicBeatsFirstLegalAcrossManyGames() {
        let heuristic = JKAIEngine(graph: graph)
        let firstLegal = JKFirstLegalAI()
        var heuristicWins = 0
        let games = 40
        for i in 0..<games {
            // Team A (seats 0,2) heuristic; Team B (seats 1,3) first-legal.
            let players = (0..<4).map {
                JKPlayer(seat: $0, name: "P\($0)", kind: .ai(personality: .balanced))
            }
            let engine = JackarooEngine(players: players,
                                        seed: UInt64(0xBEEF &+ i &* 131),
                                        ai: firstLegal)
            engine.start()
            var n = 6000
            while engine.state.winner == nil && n > 0 {
                let seat = engine.state.currentSeat
                let moves = engine.legalMovesForCurrentSeat()
                let policy: JKAIPolicy = (seat % 2 == 0) ? heuristic : firstLegal
                guard let move = policy.chooseMove(for: seat, moves: moves, state: engine.state) else { break }
                engine.play(move)
                n -= 1
            }
            if engine.state.winner == .a { heuristicWins += 1 }
        }
        XCTAssertGreaterThan(heuristicWins, games / 2,
                             "Heuristic should beat first-legal more than half the time (won \(heuristicWins)/\(games))")
    }

    // MARK: - No illegal moves / termination

    func testHeuristicGamesTerminateCleanly() {
        for i in 0..<10 {
            let players = (0..<4).map {
                JKPlayer(seat: $0, name: "P\($0)", kind: .ai(personality: .balanced))
            }
            let engine = JackarooEngine(players: players, seed: UInt64(1 &+ i &* 9973))
            engine.start()
            var n = 6000
            while engine.state.winner == nil && n > 0 { engine.stepAIIfNeeded(); n -= 1 }
            XCTAssertNotNil(engine.state.winner, "heuristic game \(i) must terminate")
            XCTAssertEqual(engine.state.marbles.count, 16)
            let s = engine.state
            let total = s.deck.count + s.firePile.count + s.players.reduce(0) { $0 + $1.hand.count }
            XCTAssertEqual(total, 52)
        }
    }
}
