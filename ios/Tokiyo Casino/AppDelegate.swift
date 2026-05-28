//
//  AppDelegate.swift
//  Tokiyo Casino
//
//  Created by Mayank Jangid on 5/29/25.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if DEBUG
        // Verify the multiplayer wire-format hasn't drifted from the
        // golden fixtures. The fixtures are also the cross-platform
        // contract for Android.
        ProtocolGoldenFixtures.selfTest()
        #endif
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}
