import XCTest
@testable import Tokiyo_Casino

/// Exercises the storyboard entry point and navigation, and exports actual UIKit
/// renders for the phone/tablet, theme, and accessibility layout review.
@MainActor
final class HomePresentationTests: XCTestCase {
    private var savedDefaults: [String: Any] = [:]
    private let keys = ["tokiyo.profile.onboarded.v1", "didGrantInitialChips.v1", "tokiyo.profile.name"]
    private var host: UIWindow?

    override func setUp() {
        super.setUp()
        for key in keys { savedDefaults[key] = UserDefaults.standard.object(forKey: key) }
        UserDefaults.standard.set(true, forKey: keys[0])
        UserDefaults.standard.set(true, forKey: keys[1])
        UserDefaults.standard.set("Mayank", forKey: keys[2])
    }

    override func tearDown() {
        host?.isHidden = true
        host?.rootViewController = nil
        host = nil
        for key in keys {
            if let value = savedDefaults[key] { UserDefaults.standard.set(value, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        savedDefaults.removeAll()
        super.tearDown()
    }

    func testHomeNavigationAndReturn() throws {
        let nav = try mountHome(size: CGSize(width: 402, height: 874), style: .dark)
        let home = try XCTUnwrap(nav.topViewController as? HomeViewController)
        let buttons = descendants(home.view).compactMap { $0 as? HomeGameButton }
        XCTAssertEqual(buttons.count, 2)
        XCTAssertTrue(nav.isNavigationBarHidden)
        let tdp = try XCTUnwrap(buttons.first { $0.accessibilityIdentifier == "home.532" })
        tdp.sendActions(for: .touchUpInside)
        XCTAssertTrue(nav.topViewController === home, "Preview must play before routing")
        buttons.first { $0 !== tdp }?.sendActions(for: .touchUpInside)
        waitFor { nav.topViewController is TDPEntryViewController }
        settle()
        XCTAssertTrue(nav.topViewController is TDPEntryViewController)
        XCTAssertFalse(nav.isNavigationBarHidden, "5-3-2 must retain its system back button")
        nav.popViewController(animated: false)
        settle()
        XCTAssertTrue(nav.topViewController === home, "Stack after return: \(nav.viewControllers)")
        XCTAssertTrue(nav.isNavigationBarHidden)
        let poker = try XCTUnwrap(buttons.first { $0.accessibilityIdentifier == "home.poker" })
        poker.sendActions(for: .touchUpInside)
        waitFor { nav.topViewController is MenuViewController }
        settle()
        XCTAssertTrue(nav.topViewController is MenuViewController)
        nav.popViewController(animated: false)
        settle()
        let profile = try XCTUnwrap(descendants(home.view).first { $0.accessibilityIdentifier == "home.profile" } as? UIControl)
        profile.sendActions(for: .touchUpInside)
        settle()
        XCTAssertNotNil(home.presentedViewController)
        home.dismiss(animated: false)
    }

    func testPreviewCardsTimingAndCancellation() throws {
        let nav = try mountHome(size: CGSize(width: 402, height: 874), style: .dark)
        let home = try XCTUnwrap(nav.topViewController as? HomeViewController)
        let previews = descendants(home.view).compactMap { $0 as? HomeCardPreview }
        for preview in previews {
            let cutCards = descendants(preview).compactMap { $0 as? TDPCardButton }
            let pokerCards = descendants(preview).compactMap { $0 as? CardView }
            if preview.kind == .firstCut {
                XCTAssertEqual(cutCards.filter { !$0.isHidden }.count, 2)
            } else {
                XCTAssertEqual(pokerCards.count, 5)
                XCTAssertEqual(pokerCards.filter(\.isFaceUp).count, 4)
                let board = Array(pokerCards.prefix(3))
                let hole = Array(pokerCards.suffix(2))
                XCTAssertFalse(board[2].isFaceUp)
                XCTAssertTrue(hole.allSatisfy(\.isFaceUp))
                XCTAssertLessThan(board.map { $0.center.y }.max()!, hole.map { $0.center.y }.min()!)
            }
            var completions = 0
            let began = CACurrentMediaTime()
            preview.play { completions += 1 }
            RunLoop.main.run(until: Date().addingTimeInterval(preview.kind == .firstCut ? 0.58 : 0.86))
            saveSnapshot(home.view, preview.kind == .firstCut ? "home-cut-active" : "home-royal-active")
            waitFor(timeout: 0.65) { completions == 1 }
            XCTAssertLessThan(CACurrentMediaTime() - began, 1.6, "Keep the launch beat quick")
            XCTAssertEqual(completions, 1)
            preview.reset()
            preview.play { completions += 1 }
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            preview.reset()
            RunLoop.main.run(until: Date().addingTimeInterval(1.4))
            XCTAssertEqual(completions, 1, "Cancelled effects must not route later")
            XCTAssertFalse(preview.isPlaying)
            if preview.kind == .firstCut {
                XCTAssertEqual(cutCards.filter { !$0.isHidden }.count, 2)
            } else {
                XCTAssertEqual(pokerCards.filter(\.isFaceUp).count, 4)
            }
        }
    }

    func testBackgroundCancelsPendingNavigation() throws {
        let nav = try mountHome(size: CGSize(width: 402, height: 874), style: .dark)
        let home = try XCTUnwrap(nav.topViewController as? HomeViewController)
        let button = try XCTUnwrap(descendants(home.view).compactMap { $0 as? HomeGameButton }.first)
        button.sendActions(for: .touchUpInside)
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(1.5))
        XCTAssertTrue(nav.topViewController === home)
        XCTAssertFalse(descendants(home.view).compactMap { $0 as? HomeCardPreview }.contains { $0.isPlaying })
        button.sendActions(for: .touchUpInside)
        waitFor { nav.topViewController is MenuViewController }
    }

    func testCatalogWrapsAdditionalGamesIntoRows() throws {
        for size in [CGSize(width: 402, height: 874), CGSize(width: 834, height: 1194)] {
            let home = HomeViewController()
            // Fixture-only duplicates: production still exposes just the installed games.
            home.catalog = (0..<5).map { HomeGameItem.catalog[$0 % 2] }
            let nav = UINavigationController(rootViewController: home)
            mount(nav, size: size, style: .dark)
            let buttons = descendants(home.view).compactMap { $0 as? HomeGameButton }
            XCTAssertEqual(buttons.count, 5)
            let frames = buttons.map { $0.convert($0.bounds, to: home.view) }
            for (index, frame) in frames.enumerated() {
                XCTAssertGreaterThanOrEqual(frame.minX, 0)
                XCTAssertLessThanOrEqual(frame.maxX, size.width + 1)
                for other in frames.dropFirst(index + 1) { XCTAssertFalse(frame.intersects(other)) }
            }
            XCTAssertGreaterThan(frames.last!.minY, frames.first!.minY)
            saveSnapshot(home.view, size.width > 700 ? "home-five-game-grid" : "home-five-game-list")
        }
    }

    func testHomeAndSplashLayoutReview() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let mode = style == .dark ? "dark" : "light"
            for (name, size) in [("phone", CGSize(width: 402, height: 874)),
                                 ("compact", CGSize(width: 320, height: 568)),
                                 ("tablet", CGSize(width: 834, height: 1194))] {
                let nav = try mountHome(size: size, style: style)
                let home = try XCTUnwrap(nav.topViewController as? HomeViewController)
                let buttons = descendants(home.view).compactMap { $0 as? HomeGameButton }
                for button in buttons {
                    XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
                    XCTAssertFalse(button.hasAmbiguousLayout, "Ambiguous \(name) \(mode) \(button.accessibilityIdentifier ?? "")")
                    let frame = button.convert(button.bounds, to: home.view)
                    XCTAssertGreaterThanOrEqual(frame.minX, 0)
                    XCTAssertLessThanOrEqual(frame.maxX, size.width + 1)
                }
                saveSnapshot(nav.view, "home-\(name)-\(mode)")
                host?.isHidden = true
            }
            let splash = try XCTUnwrap(UIStoryboard(name: "LaunchScreen", bundle: .main).instantiateInitialViewController())
            mount(splash, size: CGSize(width: 402, height: 874), style: style)
            saveSnapshot(splash.view, "splash-\(mode)")
            host?.isHidden = true
        }
        let nav = try mountHome(size: CGSize(width: 320, height: 568), style: .dark)
        nav.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        settle()
        nav.view.layoutIfNeeded()
        let home = try XCTUnwrap(nav.topViewController as? HomeViewController)
        for label in descendants(home.view).compactMap({ $0 as? UILabel }) where !label.isHidden {
            let rect = label.convert(label.bounds, to: home.view)
            XCTAssertGreaterThanOrEqual(rect.minX, -1)
            XCTAssertLessThanOrEqual(rect.maxX, 321)
        }
        saveSnapshot(nav.view, "home-accessibility")
    }

    private func mountHome(size: CGSize, style: UIUserInterfaceStyle) throws -> UINavigationController {
        let nav = try XCTUnwrap(UIStoryboard(name: "Main", bundle: .main).instantiateInitialViewController() as? UINavigationController)
        mount(nav, size: size, style: style)
        return nav
    }

    private func mount(_ controller: UIViewController, size: CGSize, style: UIUserInterfaceStyle) {
        host?.isHidden = true
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        controller.overrideUserInterfaceStyle = style
        window.overrideUserInterfaceStyle = style
        window.rootViewController = controller
        window.makeKeyAndVisible()
        host = window
        controller.view.frame = window.bounds
        settle()
        controller.view.layoutIfNeeded()
        XCTAssertEqual(controller.traitCollection.userInterfaceStyle, style)
    }

    private func waitFor(timeout: TimeInterval = 1.6, _ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
        XCTAssertTrue(condition(), "Timed out waiting for the preview to finish")
    }

    private func settle() { RunLoop.main.run(until: Date().addingTimeInterval(0.8)) }
    private func descendants(_ view: UIView) -> [UIView] { view.subviews.flatMap { [$0] + descendants($0) } }

    private func saveSnapshot(_ view: UIView, _ name: String) {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let destination = URL(fileURLWithPath: "/tmp/tokiyo-home-review/\(name).png")
        try? FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? image.pngData()?.write(to: destination)
    }
}
