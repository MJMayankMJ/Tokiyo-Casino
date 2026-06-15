//
//  JKEdgeCaseTests.swift
//  Tokiyo CasinoTests — Jackaroo Phase 1
//
//  The remaining JACKAROO_SPEC.md §7 edge cases that apply to the
//  default (Jawaker Basic) preset and weren't already covered:
//    ec 2  — cannot pass own marble
//    ec 4  — 4 backward across the Base cell (capture + own-block reverse)
//    ec 5  — Safe entry default mode: track-distance landing, advancing a
//            marble already in Safe, and the deepest-empty-cell guard
//    ec 6  — blockade in Safe (no jumping inside, independent of cannotPassOwn)
//    ec 13 — game ends immediately mid-hand
//
//  (ec 1 / ec 12 live in JKBurnTests, ec 9 in JKPartnerHandoffTests,
//   ec 11 in JKReplayTests; ec 3 / 7 / 8 are in the existing files.)
//

import XCTest
@testable import Tokiyo_Casino

final class JKEdgeCaseTests: XCTestCase {

    private let graph = JKBoardGraph()
    private func gen() -> JKLegalMoveGenerator { JKLegalMoveGenerator(graph: graph) }
    private func marble(_ id: MarbleID, in state: JKGameState) -> JKMarble {
        state.marbles.first { $0.id == id }!
    }

    // MARK: - ec 2 — cannot pass your own marble

    func testCannotPassOwnMarble_blocksForwardThroughOwn() {
        var state = JKFixture.makeState()
        // Own marbles on cells 10 and 12 (12 is two ahead, in the path).
        JKFixture.place(0, at: .track(10), in: &state)
        JKFixture.place(1, at: .track(12), in: &state)

        // Forward 3 on the rear marble would pass marble #1 on cell 12 → illegal.
        XCTAssertNil(gen().walkForward(marble: marble(0, in: state), steps: 3,
                                       seat: 0, state: state),
                     "cannotPassOwn must block a forward move that crosses an own marble")

        // A shorter forward that stops before the own marble is fine.
        XCTAssertEqual(gen().walkForward(marble: marble(0, in: state), steps: 1,
                                         seat: 0, state: state)?.destination,
                       .track(11))

        // The front marble itself is free to advance (nothing ahead of it).
        XCTAssertEqual(gen().walkForward(marble: marble(1, in: state), steps: 3,
                                         seat: 0, state: state)?.destination,
                       .track(15))
    }

    // MARK: - ec 4 — backward 4 across the Base cell

    func testBackwardFour_crossesOwnEmptyBaseCell() {
        var state = JKFixture.makeState()
        // Seat 0 base = 0. Marble two cells past base; backward 4 walks
        // 1 → 0(base) → 99 → 98, crossing the empty Base cell.
        JKFixture.place(0, at: .track(2), in: &state)
        let o = gen().walkBackward(marble: marble(0, in: state), steps: 4,
                                   seat: 0, state: state)
        XCTAssertEqual(o?.destination, .track(98),
                       "Backward 4 must be able to cross an empty own Base cell")
        XCTAssertNil(o?.capture)
    }

    func testBackwardFour_capturesOpponentOnLanding() {
        var state = JKFixture.makeState()
        JKFixture.place(0, at: .track(5), in: &state)        // seat 0
        JKFixture.place(4, at: .track(1), in: &state)        // seat 1 (opponent)
        let o = gen().walkBackward(marble: marble(0, in: state), steps: 4,
                                   seat: 0, state: state)
        XCTAssertEqual(o?.destination, .track(1))
        XCTAssertEqual(o?.capture, 4, "Backward landing on an opponent captures it")
    }

    func testBackwardFour_blockedByOwnMarbleInReverse() {
        var state = JKFixture.makeState()
        JKFixture.place(0, at: .track(5), in: &state)
        JKFixture.place(1, at: .track(3), in: &state)        // own marble on the reverse path
        XCTAssertNil(gen().walkBackward(marble: marble(0, in: state), steps: 4,
                                        seat: 0, state: state),
                     "Backward must respect own-marble blocking in reverse")
    }

    // MARK: - Lone opponents are passable (Jawaker: only Base + blockade
    // fronts "cannot be bypassed"; a lone piece is captured only on landing)

    func testForward_passesLoneOpponentButCapturesOnLanding() {
        var state = JKFixture.makeState()
        JKFixture.place(0, at: .track(10), in: &state)   // mover
        JKFixture.place(4, at: .track(12), in: &state)   // lone opponent on the path
        // Forward 4 passes over the opponent at 12 and lands on empty 14.
        let pass = gen().walkForward(marble: marble(0, in: state), steps: 4,
                                     seat: 0, state: state)
        XCTAssertEqual(pass?.destination, .track(14), "May pass a lone opponent")
        XCTAssertNil(pass?.capture, "Passing over does not capture")
        // Forward 2 lands exactly on the opponent → capture.
        let land = gen().walkForward(marble: marble(0, in: state), steps: 2,
                                     seat: 0, state: state)
        XCTAssertEqual(land?.destination, .track(12))
        XCTAssertEqual(land?.capture, 4, "Landing on a lone opponent captures it")
    }

    func testBackward_passesLoneOpponentButCapturesOnLanding() {
        var state = JKFixture.makeState()
        JKFixture.place(0, at: .track(10), in: &state)
        JKFixture.place(4, at: .track(8), in: &state)    // lone opponent on the reverse path
        let pass = gen().walkBackward(marble: marble(0, in: state), steps: 4,
                                      seat: 0, state: state)
        XCTAssertEqual(pass?.destination, .track(6), "May pass a lone opponent backward")
        XCTAssertNil(pass?.capture)
        let land = gen().walkBackward(marble: marble(0, in: state), steps: 2,
                                      seat: 0, state: state)
        XCTAssertEqual(land?.capture, 4, "Backward landing on a lone opponent captures it")
    }

    // MARK: - ec 5 — Safe entry (cardValueAtMostRemaining default)

    /// Cell 95 is exactly 3 cw-steps before seat 0's Safe gate (98).
    func testSafeEntry_landsOnLaneFromTrackDistancePlusInsideSteps() {
        var state = JKFixture.makeState()
        JKFixture.place(0, at: .track(95), in: &state)        // distance-to-gate = 3
        // value = 3(to gate) + (lane+1) inside.
        XCTAssertEqual(gen().walkForward(marble: marble(0, in: state), steps: 4,
                                         seat: 0, state: state)?.destination,
                       .safe(lane: 0))
        XCTAssertEqual(gen().walkForward(marble: marble(0, in: state), steps: 6,
                                         seat: 0, state: state)?.destination,
                       .safe(lane: 2))
    }

    func testSafeEntry_advancesMarbleAlreadyInsideSafe() {
        var state = JKFixture.makeState()
        JKFixture.place(0, at: .safe(lane: 0), in: &state)
        XCTAssertEqual(gen().walkForward(marble: marble(0, in: state), steps: 2,
                                         seat: 0, state: state)?.destination,
                       .safe(lane: 2))
        // Overshooting the 4-cell lane is illegal.
        XCTAssertNil(gen().walkForward(marble: marble(0, in: state), steps: 4,
                                       seat: 0, state: state),
                     "A marble in Safe cannot advance past lane 3")
    }

    func testSafeEntry_respectsDeepestEmptyCellGuard() {
        var state = JKFixture.makeState()
        JKFixture.place(1, at: .safe(lane: 3), in: &state)    // deepest cell taken
        JKFixture.place(0, at: .track(95), in: &state)        // distance-to-gate = 3

        // value 6 → would land on lane 2, the deepest empty cell → allowed.
        XCTAssertEqual(gen().walkForward(marble: marble(0, in: state), steps: 6,
                                         seat: 0, state: state)?.destination,
                       .safe(lane: 2))

        // value 7 → would need lane 3 (occupied) → no Safe entry; the
        // marble overshoots and continues around the track instead.
        let over = gen().walkForward(marble: marble(0, in: state), steps: 7,
                                     seat: 0, state: state)
        if case .safe = over?.destination {
            XCTFail("Must not enter Safe past the deepest empty cell")
        }
        XCTAssertEqual(over?.destination, .track(2))
    }

    // MARK: - ec 6 — blockade inside Safe (no jumping), independent of cannotPassOwn

    func testSafeLaneIsAlwaysBlocked_regardlessOfCannotPassOwn() {
        for cannotPassOwn in [true, false] {
            var state = JKFixture.makeState(
                rules: JKRulesPreset(cannotPassOwn: cannotPassOwn))
            JKFixture.place(0, at: .safe(lane: 0), in: &state)
            JKFixture.place(1, at: .safe(lane: 2), in: &state)   // blocker deeper in lane

            XCTAssertNil(gen().walkForward(marble: marble(0, in: state), steps: 2,
                                           seat: 0, state: state),
                         "No jumping inside Safe (cannotPassOwn=\(cannotPassOwn))")
            // Advancing into the empty lane just before the blocker is fine.
            XCTAssertEqual(gen().walkForward(marble: marble(0, in: state), steps: 1,
                                             seat: 0, state: state)?.destination,
                           .safe(lane: 1))
        }
    }

    // MARK: - ec 7 — Jack swap excludes Home / own-Base / Safe marbles

    func testJackSwap_excludesOwnBaseHomeAndSafeMarbles() {
        var state = JKFixture.makeState()
        // Seat 0: one marble protected on its own Base, one free on the track,
        // one in Safe. Seat 1: an opponent protected on ITS own Base, plus a
        // free opponent on the track.
        JKFixture.place(0, at: .track(graph.baseCell[0]!), in: &state)   // own, on own Base
        JKFixture.place(1, at: .track(10), in: &state)                    // own, free
        JKFixture.place(2, at: .safe(lane: 0), in: &state)               // own, in Safe
        JKFixture.place(4, at: .track(graph.baseCell[1]!), in: &state)   // opp, on its own Base
        JKFixture.place(5, at: .track(30), in: &state)                    // opp, free
        JKFixture.setHand([JKFixture.jackSpades], for: 0, in: &state)

        let swaps = gen().moves(in: state, for: 0).compactMap { (m: JKMove) -> (MarbleID, MarbleID)? in
            if case let .swap(_, own, other) = m { return (own, other) }
            return nil
        }
        XCTAssertFalse(swaps.isEmpty, "The two on-track marbles should be swappable")
        // The only legal swap is free-own (1) with free-opponent (5).
        for (own, other) in swaps {
            XCTAssertEqual(own, 1, "Own swap source must be the free track marble, not Home/Base/Safe")
            XCTAssertEqual(other, 5, "Opponent target must be the free track marble, not its own Base")
        }
    }

    // MARK: - ec 13 — game ends immediately mid-hand

    func testGameEndsImmediately_whenEighthTeamMarbleEntersSafe() {
        var state = JKFixture.makeState()
        // Team A = seats 0 + 2. Seat 0 fully home → in Safe.
        JKFixture.place(0, at: .safe(lane: 0), in: &state)
        JKFixture.place(1, at: .safe(lane: 1), in: &state)
        JKFixture.place(2, at: .safe(lane: 2), in: &state)
        JKFixture.place(3, at: .safe(lane: 3), in: &state)
        // Seat 2 has 3 marbles in Safe (deepest-first) and one about to enter.
        JKFixture.place(8, at: .safe(lane: 3), in: &state)
        JKFixture.place(9, at: .safe(lane: 2), in: &state)
        JKFixture.place(10, at: .safe(lane: 1), in: &state)
        JKFixture.place(11, at: .track(45), in: &state)        // distance 3 to gate 48

        let fourClubs = JKCard(suit: .clubs, rank: .four)
        let spare = JKCard(suit: .diamonds, rank: .two)
        JKFixture.setHand([fourClubs, spare], for: 2, in: &state)

        var resolver = JKMoveResolver(graph: graph)
        resolver.apply(.forward(card: fourClubs, marble: 11, steps: 4),
                       by: 2, to: &state)

        XCTAssertEqual(state.winner, .a, "Eighth team marble in Safe wins for Team A")
        XCTAssertEqual(state.phase, .finished)
        XCTAssertTrue(state.log.contains { if case .gameOver(.a) = $0 { return true }; return false })
        // The deal was NOT finished — the player still holds the spare card.
        XCTAssertEqual(state.players[2].hand, [spare],
                       "Game ends mid-hand; remaining cards are not played or redealt")
    }
}
