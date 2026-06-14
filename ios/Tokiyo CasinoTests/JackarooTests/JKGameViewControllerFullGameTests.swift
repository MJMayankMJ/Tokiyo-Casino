//
//  JKGameViewControllerFullGameTests.swift
//  Tokiyo CasinoTests — Jackaroo Phase 2
//
//  Exit-criteria coverage for the Phase 2 game screen:
//   1. A complete game can be played start → finish through the real
//      view-controller pipeline (deal → move → capture → reshuffle →
//      handoff → victory) without crashing.
//   2. The view controller deallocates after a full game — no retain
//      cycle between the VC, the engine, the board, and the hand strip.
//
//  These run headless by driving the VC's `playFirstLegalMoveForCurrentSeat`
//  test seam with `isAutomatedTestMode = true`, so there are no timers
//  or alerts to stall a unit test.
//

import XCTest
@testable import Tokiyo_Casino

final class JKGameViewControllerFullGameTests: XCTestCase {

    /// Stand up an all-AI table so every seat can be driven from the test
    /// without needing simulated taps, hosted in a real sized window so
    /// the layout/engine-start path runs exactly as it does on device.
    private func makeHostedVC(seed: UInt64) -> (JackarooGameViewController, UIWindow) {
        let players = (0..<4).map {
            JKPlayer(seat: $0, name: "AI\($0)", kind: .ai(personality: .balanced))
        }
        let vc = JackarooGameViewController(players: players, seed: seed)
        vc.isAutomatedTestMode = true
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = vc
        window.makeKeyAndVisible()
        // Two passes: first sizes the board, second runs the engine-start
        // branch inside viewDidLayoutSubviews.
        vc.view.setNeedsLayout(); vc.view.layoutIfNeeded()
        vc.view.setNeedsLayout(); vc.view.layoutIfNeeded()
        return (vc, window)
    }

    /// Drive every seat via the human-style play path until someone wins.
    /// Returns the number of moves played.
    @discardableResult
    private func runToCompletion(_ vc: JackarooGameViewController,
                                 maxMoves: Int = 5_000) -> Int {
        var moves = 0
        while vc.engine.state.winner == nil && moves < maxMoves {
            guard vc.playFirstLegalMoveForCurrentSeat() else { break }
            moves += 1
        }
        return moves
    }

    func testFullGamePlaysToAWinnerThroughTheVC() {
        let (vc, window) = makeHostedVC(seed: 0xC0FFEE)
        defer { window.isHidden = true; window.rootViewController = nil }

        runToCompletion(vc)

        let state = vc.engine.state
        XCTAssertNotNil(state.winner,
                        "A full game driven through the VC must reach a winner")

        // The winning team must actually have all 8 marbles in Safe.
        if let winner = state.winner {
            let teamMarbles = state.team(winner)
            XCTAssertEqual(teamMarbles.count, 8)
            XCTAssertTrue(teamMarbles.allSatisfy {
                if case .safe = $0.position { return true }
                return false
            }, "Winner must have every team marble in Safe")
        }
        // Card budget stayed intact across the whole game.
        let total = state.deck.count + state.firePile.count
            + state.players.reduce(0) { $0 + $1.hand.count }
        XCTAssertEqual(total, 52, "Card budget must stay at 52 through a full game")
    }

    func testFullGameRunsCleanlyAcrossMultipleSeeds() {
        for seed: UInt64 in [1, 0xCAFE, 0x1234_5678, 0xFFFF_FFFF_FFFF_FFFF] {
            let (vc, window) = makeHostedVC(seed: seed)
            runToCompletion(vc)
            XCTAssertNotNil(vc.engine.state.winner,
                            "Seed \(seed) should play to completion through the VC")
            window.isHidden = true
            window.rootViewController = nil
        }
    }

    func testViewControllerDeallocatesAfterFullGame() {
        weak var weakVC: JackarooGameViewController?
        autoreleasepool {
            let (vc, window) = makeHostedVC(seed: 0xBADF00D)
            runToCompletion(vc)
            XCTAssertNotNil(vc.engine.state.winner)
            weakVC = vc
            // Tear the VC off the window so nothing external retains it.
            window.isHidden = true
            window.rootViewController = nil
        }
        // UIKit releases a controller's view hierarchy on a later run-loop
        // tick, so a synchronous check races the dealloc. Pump the run loop
        // briefly: a genuine retain cycle survives this; deferred dealloc
        // does not.
        let deadline = Date().addingTimeInterval(2.0)
        while weakVC != nil && Date() < deadline {
            autoreleasepool {
                RunLoop.current.run(until: Date().addingTimeInterval(0.02))
            }
        }
        XCTAssertNil(weakVC,
                     "JackarooGameViewController leaked after a full game — check for a retain cycle")
    }
}
