//
//  JKPhase3SnapshotTest.swift
//  Tokiyo CasinoTests — manual snapshot helper (Phase 3)
//
//  Not a regression test. Renders the new Phase 3 screens to /tmp so the
//  menu, lobby, curtain, and summary can be eyeballed without driving the
//  simulator UI by hand.
//

import XCTest
@testable import Tokiyo_Casino

final class JKPhase3SnapshotTest: XCTestCase {

    private func render(_ vc: UIViewController, _ name: String,
                        style: UIUserInterfaceStyle = .dark) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.overrideUserInterfaceStyle = style
        let nav = UINavigationController(rootViewController: vc)
        nav.setNavigationBarHidden(true, animated: false)
        window.rootViewController = nav
        window.makeKeyAndVisible()
        vc.view.setNeedsLayout(); vc.view.layoutIfNeeded()
        vc.view.setNeedsLayout(); vc.view.layoutIfNeeded()
        write(view: vc.view, name: name)
    }

    private func render(view: UIView, _ name: String,
                        style: UIUserInterfaceStyle = .dark) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.overrideUserInterfaceStyle = style
        view.frame = window.bounds
        window.addSubview(view)
        window.makeKeyAndVisible()
        view.setNeedsLayout(); view.layoutIfNeeded()
        write(view: view, name: name)
    }

    private func write(view: UIView, name: String) {
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        let img = renderer.image { _ in view.drawHierarchy(in: view.bounds, afterScreenUpdates: true) }
        let url = URL(fileURLWithPath: "/tmp/jackaroo_p3/\(name).png")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        if let data = img.pngData() { try? data.write(to: url) }
        let att = XCTAttachment(image: img); att.lifetime = .keepAlways; att.name = name
        add(att)
    }

    func testRenderPhase3Screens() {
        render(JackarooMenuViewController(), "menu_dark", style: .dark)
        render(JackarooMenuViewController(), "menu_light", style: .light)
        render(JackarooLobbyViewController(humanCount: 3), "lobby_dark", style: .dark)
        render(JackarooRulesViewController(), "rules_light", style: .light)

        let summary = JackarooGameSummaryViewController(
            state: sampleWonState(), winner: .a, humanSeats: [0])
        render(summary, "summary_dark", style: .dark)

        let curtain = JKHandoffOverlay()
        curtain.configure(name: "Mayank", seat: 1)
        render(view: curtain, "curtain_dark", style: .dark)
    }

    /// A finished state with Team A entirely in Safe, for the summary.
    private func sampleWonState() -> JKGameState {
        let players = [
            JKPlayer(seat: 0, name: "You", kind: .human),
            JKPlayer(seat: 1, name: "Shark", kind: .ai(personality: .tightAggressive)),
            JKPlayer(seat: 2, name: "Pro", kind: .ai(personality: .balanced)),
            JKPlayer(seat: 3, name: "Fish", kind: .ai(personality: .loosePassive)),
        ]
        var marbles: [JKMarble] = []
        for seat in 0..<4 {
            for slot in 0..<4 {
                let inSafe = (seat % 2 == 0)   // Team A all home
                marbles.append(JKMarble(id: seat * 4 + slot, owner: seat,
                                        position: inSafe ? .safe(lane: slot) : .home(slot: slot)))
            }
        }
        var state = JKGameState(players: players, marbles: marbles, dealer: 0,
                                rules: .jawakerBasic, seed: 1)
        state.winner = .a
        return state
    }
}
