//
//  JKBoardSnapshotTest.swift
//  Tokiyo CasinoTests — manual snapshot helper
//
//  Not part of the regression suite. Run this test manually to render
//  the game screen into an image attached to the test result; useful
//  for verifying layout changes without needing to drive the simulator
//  UI manually.
//

import XCTest
@testable import Tokiyo_Casino

final class JKBoardSnapshotTest: XCTestCase {

    func testRenderBoardSnapshot() {
        let vc = JackarooGameViewController(seed: 0xC0FFEE_BEEF)
        let host = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        host.rootViewController = vc
        host.makeKeyAndVisible()

        // Pump layout a couple of times so viewDidLayoutSubviews boots the engine.
        vc.view.setNeedsLayout()
        vc.view.layoutIfNeeded()
        vc.view.setNeedsLayout()
        vc.view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(bounds: vc.view.bounds)
        let img = renderer.image { ctx in
            vc.view.drawHierarchy(in: vc.view.bounds, afterScreenUpdates: true)
        }

        // Persist to a known location so the agent can read it.
        let url = URL(fileURLWithPath: "/tmp/jackaroo_shots/snapshot_board.png")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        if let data = img.pngData() {
            try? data.write(to: url)
        }

        let attachment = XCTAttachment(image: img)
        attachment.lifetime = .keepAlways
        attachment.name = "board_snapshot.png"
        add(attachment)
    }
}
