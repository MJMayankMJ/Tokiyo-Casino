//
//  JKAnimationSmokeTests.swift
//  Tokiyo CasinoTests — Jackaroo Phase 2/4
//
//  The marble-animation path is intentionally skipped in automated-test
//  mode (for deterministic, runloop-free stepping). This drives a *live*
//  view controller — real AI pacing timers and real step-by-step
//  animations — by spinning the run loop, to prove that pipeline advances
//  the game and reconciles without crashing.
//

import XCTest
@testable import Tokiyo_Casino

final class JKAnimationSmokeTests: XCTestCase {

    func testLiveAIPlayWithAnimationsAdvancesTheGame() {
        let players = (0..<4).map {
            JKPlayer(seat: $0, name: "AI\($0)", kind: .ai(personality: .balanced))
        }
        // NOT automated-test mode — real timers + real animations run.
        let vc = JackarooGameViewController(players: players, seed: 0xA417)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = vc
        window.makeKeyAndVisible()
        vc.view.setNeedsLayout(); vc.view.layoutIfNeeded()
        vc.view.setNeedsLayout(); vc.view.layoutIfNeeded()

        let initialLog = vc.engine.state.log.count

        // Let several paced + animated AI turns play out.
        let deadline = Date().addingTimeInterval(6.0)
        while Date() < deadline && vc.engine.state.winner == nil {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        XCTAssertGreaterThan(vc.engine.state.log.count, initialLog,
                             "Live AI pacing + animation should advance the game")
        // State invariants still hold through the animated path.
        let s = vc.engine.state
        XCTAssertEqual(s.marbles.count, 16)
        let total = s.deck.count + s.firePile.count + s.players.reduce(0) { $0 + $1.hand.count }
        XCTAssertEqual(total, 52)

        // Backgrounding mid-game must not crash or corrupt state.
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        let after = vc.engine.state
        XCTAssertEqual(after.marbles.count, 16)

        window.isHidden = true
        window.rootViewController = nil
    }
}
