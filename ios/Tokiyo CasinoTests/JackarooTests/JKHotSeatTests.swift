//
//  JKHotSeatTests.swift
//  Tokiyo CasinoTests — Jackaroo Phase 3
//
//  Exit criterion: every hot-seat seat count (2/3/4 humans with AI fill)
//  runs to a winner cleanly through the real view-controller pipeline.
//  Driven headless via the VC's automated-test seam (which suppresses the
//  pass-the-device curtain and timers so the game can be stepped
//  synchronously).
//

import XCTest
@testable import Tokiyo_Casino

final class JKHotSeatTests: XCTestCase {

    /// Build a table with `humanCount` humans at the first seats and AI
    /// filling the rest — the same seating the lobby produces.
    private func makePlayers(humanCount: Int) -> [JKPlayer] {
        let ai: [JKPersonality] = [.tightAggressive, .balanced, .loosePassive]
        return (0..<4).map { seat in
            if seat < humanCount {
                return JKPlayer(seat: seat, name: "Human\(seat + 1)", kind: .human)
            }
            let p = ai[(seat - humanCount) % ai.count]
            return JKPlayer(seat: seat, name: p.displayName, kind: .ai(personality: p))
        }
    }

    private func runHotSeatGame(humanCount: Int, seed: UInt64) {
        let vc = JackarooGameViewController(players: makePlayers(humanCount: humanCount), seed: seed)
        vc.isAutomatedTestMode = true
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = vc
        window.makeKeyAndVisible()
        vc.view.setNeedsLayout(); vc.view.layoutIfNeeded()
        vc.view.setNeedsLayout(); vc.view.layoutIfNeeded()

        var moves = 0
        while vc.engine.state.winner == nil && moves < 5_000 {
            guard vc.playFirstLegalMoveForCurrentSeat() else { break }
            moves += 1
        }

        XCTAssertNotNil(vc.engine.state.winner,
                        "\(humanCount)-human hot-seat (seed \(seed)) must reach a winner")
        // Card budget intact through the whole hot-seat game.
        let s = vc.engine.state
        let total = s.deck.count + s.firePile.count + s.players.reduce(0) { $0 + $1.hand.count }
        XCTAssertEqual(total, 52)

        window.isHidden = true
        window.rootViewController = nil
    }

    func testTwoHumanHotSeatRunsToWinner()   { runHotSeatGame(humanCount: 2, seed: 0xA1) }
    func testThreeHumanHotSeatRunsToWinner() { runHotSeatGame(humanCount: 3, seed: 0xB2) }
    func testFourHumanHotSeatRunsToWinner()  { runHotSeatGame(humanCount: 4, seed: 0xC3) }
}
