//
//  JKGameViewControllerSmokeTests.swift
//  Tokiyo CasinoTests — Jackaroo Phase 2
//
//  Lightweight smoke coverage for the game screen: instantiate the
//  VC, run a layout pass, and confirm the engine boots and the board
//  positions every marble without crashing. Real interaction testing
//  belongs in XCUITest (Phase 6).
//

import XCTest
@testable import Tokiyo_Casino

final class JKGameViewControllerSmokeTests: XCTestCase {

    func testGameViewControllerBootsCleanly() {
        let vc = JackarooGameViewController(seed: 0xBADBED)
        // Force the view to load + lay out inside a sized window so
        // `viewDidLayoutSubviews` runs and the engine starts.
        let host = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        host.rootViewController = vc
        host.makeKeyAndVisible()
        // Pump layout twice — first pass sets bounds, second pass
        // triggers the engine.start() path inside viewDidLayoutSubviews.
        vc.view.setNeedsLayout()
        vc.view.layoutIfNeeded()
        vc.view.setNeedsLayout()
        vc.view.layoutIfNeeded()
        XCTAssertNotNil(vc.view, "VC should have loaded a view")
    }

    func testGameViewControllerWithMultipleSeedsAllBoot() {
        for seed: UInt64 in [1, 0xCAFE, 0x1234_5678, 0xFFFF_FFFF_FFFF_FFFF] {
            let vc = JackarooGameViewController(seed: seed)
            let host = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
            host.rootViewController = vc
            host.makeKeyAndVisible()
            vc.view.setNeedsLayout()
            vc.view.layoutIfNeeded()
            vc.view.setNeedsLayout()
            vc.view.layoutIfNeeded()
            XCTAssertNotNil(vc.view, "Seed \(seed) should boot the VC cleanly")
        }
    }
}
