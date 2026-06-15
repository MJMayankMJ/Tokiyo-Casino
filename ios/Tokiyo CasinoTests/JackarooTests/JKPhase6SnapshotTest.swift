//
//  JKPhase6SnapshotTest.swift
//  Tokiyo CasinoTests — manual snapshot helper (Phase 6)
//
//  Not a regression test. Renders the game screen in three fixture
//  states (fresh deal, mid-game, near-win) to /tmp + as attachments so
//  the board, hand strip, and corners can be eyeballed in light + dark.
//

import XCTest
@testable import Tokiyo_Casino

private extension UIView {
    /// Depth-first list of every descendant view.
    var recursiveSubviews: [UIView] {
        subviews + subviews.flatMap { $0.recursiveSubviews }
    }
}

final class JKPhase6SnapshotTest: XCTestCase {

    private func render(_ vc: UIViewController, _ name: String,
                        style: UIUserInterfaceStyle = .dark,
                        size: CGSize = CGSize(width: 393, height: 852)) {
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.overrideUserInterfaceStyle = style
        let nav = UINavigationController(rootViewController: vc)
        nav.setNavigationBarHidden(true, animated: false)
        window.rootViewController = nav
        window.makeKeyAndVisible()
        for _ in 0..<2 { vc.view.setNeedsLayout(); vc.view.layoutIfNeeded() }

        let renderer = UIGraphicsImageRenderer(bounds: vc.view.bounds)
        let img = renderer.image { _ in vc.view.drawHierarchy(in: vc.view.bounds, afterScreenUpdates: true) }
        let url = URL(fileURLWithPath: "/tmp/jackaroo_p6/\(name).png")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        if let data = img.pngData() { try? data.write(to: url) }
        let att = XCTAttachment(image: img); att.lifetime = .keepAlways; att.name = name
        add(att)

        XCTAssertGreaterThan(vc.view.bounds.width, 0, "\(name): screen must lay out")
    }

    private func gameVC(_ state: JKGameState) -> JackarooGameViewController {
        let vc = JackarooGameViewController(restoring: state)
        vc.isAutomatedTestMode = true   // no timers, no summary, no audio
        return vc
    }

    func testRenderGameScreenStates() {
        render(gameVC(freshState()), "game_fresh_dark", style: .dark)
        render(gameVC(midGameState()), "game_mid_dark", style: .dark)
        render(gameVC(midGameState()), "game_mid_light", style: .light)
        render(gameVC(nearWinState()), "game_nearwin_dark", style: .dark)
    }

    /// iPad must lay out without the board overflowing — the bug was the
    /// square board sized to 0.92×width, which overran the height in
    /// landscape. Render both orientations and assert the board fits.
    func testGameScreenFitsOnIPad() {
        for (name, size) in [("ipad_portrait", CGSize(width: 1024, height: 1366)),
                             ("ipad_landscape", CGSize(width: 1366, height: 1024))] {
            let vc = gameVC(midGameState())
            let window = UIWindow(frame: CGRect(origin: .zero, size: size))
            window.rootViewController = UINavigationController(rootViewController: vc)
            window.makeKeyAndVisible()
            for _ in 0..<2 { vc.view.setNeedsLayout(); vc.view.layoutIfNeeded() }

            let board = vc.view.recursiveSubviews.first { $0 is JKBoardView }
            XCTAssertNotNil(board, "\(name): board exists")
            if let b = board {
                XCTAssertGreaterThan(b.bounds.width, 100, "\(name): board has a sane size")
                XCTAssertLessThanOrEqual(b.bounds.height, size.height,
                                         "\(name): board must not overflow the screen height")
                XCTAssertLessThanOrEqual(b.bounds.width.rounded(), 720,
                                         "\(name): board respects the iPad cap")
            }
            window.isHidden = true
            window.rootViewController = nil
        }
    }

    // MARK: - Fixtures

    private func dealt(_ state: inout JKGameState, cardsPerSeat: Int = 4) {
        var rng = state.rng
        state.deck = JKCard.freshDeck()
        state.deck.jkShuffle(using: &rng)
        state.rng = rng
        for s in 0..<4 {
            state.players[s].hand.removeAll()
            for _ in 0..<cardsPerSeat { if let c = state.deck.popLast() { state.players[s].hand.append(c) } }
        }
        state.phase = .playing
        state.currentSeat = 0
    }

    private func base(_ positions: [(MarbleID, JKPosition)] = []) -> JKGameState {
        let players = JackarooSeating.solo()   // seat 0 human, 1–3 AI
        var marbles: [JKMarble] = []
        for seat in 0..<4 {
            for slot in 0..<4 {
                marbles.append(JKMarble(id: seat * 4 + slot, owner: seat,
                                        position: .home(slot: slot)))
            }
        }
        var state = JKGameState(players: players, marbles: marbles, dealer: 0,
                                rules: .jawakerBasic, seed: 7)
        for (id, pos) in positions {
            if let i = state.marbles.firstIndex(where: { $0.id == id }) {
                state.marbles[i].position = pos
            }
        }
        dealt(&state)
        return state
    }

    private func freshState() -> JKGameState { base() }

    private func midGameState() -> JKGameState {
        base([(0, .track(10)), (4, .track(30)), (8, .track(55)), (12, .track(80)),
              (1, .track(18)), (5, .safe(lane: 0))])
    }

    private func nearWinState() -> JKGameState {
        // Team A (seats 0, 2) almost home.
        base([(0, .safe(lane: 0)), (1, .safe(lane: 1)), (2, .safe(lane: 2)), (3, .track(12)),
              (8, .safe(lane: 0)), (9, .safe(lane: 1)), (10, .safe(lane: 2)), (11, .track(60)),
              (4, .track(40)), (12, .track(85))])
    }
}
