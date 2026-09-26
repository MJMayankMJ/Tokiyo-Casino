//
//  TDPArrangeTimerTests.swift
//  Tokiyo CasinoTests — Teen Do Paanch
//
//  The arranging window's clock lives in the host, not the engine. These
//  drive a real host through play until two people meet in a pull, then
//  check the clock: it counts down on every screen, closes on its own, and
//  is NOT restarted when the debtor moves a card (`pump()` cancels pending
//  work on every pass, which is exactly how a naive timer would reset).
//

import XCTest
@testable import Tokiyo_Casino

private final class ViewSpy: TDPHostServiceDelegate {
    var views: [TDPSeat: TDPClientView] = [:]
    func host(_ service: TDPHostService, didUpdateLocalView view: TDPClientView, seat: TDPSeat) {
        views[seat] = view
    }
}

final class TDPArrangeTimerTests: XCTestCase {

    private func spin(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    /// Plays a two-person pass-and-play table (seat 2 is a bot) until the
    /// arranging window opens between the two people.
    private func hostAtArrangingWindow(window: TimeInterval) -> (TDPHostService, ViewSpy)? {
        for seed in UInt32(1)...60 {
            let host = TDPHostService(mode: .passAndPlay(humanSeats: 2), hostName: "Aa", targetRounds: 30, seed: seed)
            host.aiThinkTime = 0
            host.dealPace = 0
            host.trickHold = 0
            host.arrangeWindow = window
            let spy = ViewSpy()
            host.delegate = spy
            host.startGame()

            for _ in 0..<4_000 {
                spin(0.001)
                let state = host.engine.state
                if state.phase == .khichai, state.khichaiCurrent?.arranging == true { return (host, spy) }
                if state.phase == .sessionEnd { break }
                if state.phase == .roundEnd { host.engine.apply(.beginNextRound); host.pump(); continue }
                // The two people are played by the AI's choices here.
                for seat in 0..<2 {
                    if let action = TDPAIEngine.nextAction(state: state, seat: seat) {
                        XCTAssertNil(host.engine.apply(action))
                        host.pump()
                        break
                    }
                }
            }
        }
        return nil
    }

    func testTheWindowCountsDownAndClosesOnItsOwn() throws {
        let (host, spy) = try XCTUnwrap(hostAtArrangingWindow(window: 2), "Two people never met in a pull")
        let debtor = host.engine.state.khichaiCurrent!.debtorSeat
        let creditor = host.engine.state.khichaiCurrent!.creditorSeat

        XCTAssertEqual(spy.views[debtor]?.prompt, .arrangeCards)
        XCTAssertEqual(spy.views[creditor]?.khichai?.isArranging, true)
        let first = try XCTUnwrap(spy.views[creditor]?.khichai?.arrangeSecondsLeft)
        XCTAssertEqual(first, 2)

        spin(1.1)
        let later = try XCTUnwrap(spy.views[creditor]?.khichai?.arrangeSecondsLeft, "Ticks keep republishing")
        XCTAssertLessThan(later, first, "The clock should have moved on every screen")

        spin(1.2)
        XCTAssertEqual(host.engine.state.khichaiCurrent?.arranging, false, "The window closes at zero")
        XCTAssertEqual(spy.views[creditor]?.prompt, .khichaiDraw, "…and the puller is up")
    }

    func testMovingACardDoesNotRestartTheClock() throws {
        let (host, _) = try XCTUnwrap(hostAtArrangingWindow(window: 1), "Two people never met in a pull")
        let started = Date()
        let debtor = host.engine.state.khichaiCurrent!.debtorSeat

        // Rearrange twice mid-window, the way a player dragging cards would.
        for _ in 0..<2 {
            spin(0.35)
            let ids = host.engine.state.player(at: debtor)!.hand.map(\.tdpID).shuffled()
            XCTAssertNil(host.submit(TDPIntent(kind: .arrange, order: ids, done: false), from: debtor))
        }
        XCTAssertEqual(host.engine.state.khichaiCurrent?.arranging, true, "Not done yet")

        while host.engine.state.khichaiCurrent?.arranging == true && Date().timeIntervalSince(started) < 3 {
            spin(0.02)
        }
        let closedAfter = Date().timeIntervalSince(started)
        XCTAssertEqual(host.engine.state.khichaiCurrent?.arranging, false)
        XCTAssertLessThan(closedAfter, 1.4, "Moves must not extend the 1s window (closed after \(closedAfter)s)")
    }

    func testDoneEndsTheWindowEarly() throws {
        let (host, _) = try XCTUnwrap(hostAtArrangingWindow(window: 10), "Two people never met in a pull")
        let debtor = host.engine.state.khichaiCurrent!.debtorSeat
        let ids = host.engine.state.player(at: debtor)!.hand.map(\.tdpID)
        XCTAssertNil(host.submit(TDPIntent(kind: .arrange, order: ids, done: true), from: debtor))
        XCTAssertEqual(host.engine.state.khichaiCurrent?.arranging, false)
    }
}
