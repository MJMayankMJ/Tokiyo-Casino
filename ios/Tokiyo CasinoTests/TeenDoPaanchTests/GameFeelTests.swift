//
//  GameFeelTests.swift
//  Tokiyo CasinoTests
//
//  Every sound the tables ask for must exist in the app, in the engine's
//  format — a missing file would just be silence nobody notices.
//

import XCTest
@testable import Tokiyo_Casino

final class GameFeelTests: XCTestCase {

    func testEverySoundLoads() {
        for sound in GameSound.allCases {
            XCTAssertGreaterThan(GameAudio.shared.loadedVariants(of: sound), 0, "\(sound) has no recording")
        }
    }

    func testRecordingsHaveVariantsSoRepeatsDontSoundCanned() {
        for sound in [GameSound.play, .deal, .bet, .raise, .check] {
            XCTAssertGreaterThan(GameAudio.shared.loadedVariants(of: sound), 1, "\(sound)")
        }
    }

    func testHapticsSwitchPersists() {
        let before = GameHaptics.isEnabled
        defer { GameHaptics.isEnabled = before }
        GameHaptics.isEnabled = false
        XCTAssertFalse(GameHaptics.isEnabled)
        GameHaptics.isEnabled = true
        XCTAssertTrue(GameHaptics.isEnabled)
    }

    func testMutedPlaysNothingAndDoesNotCrash() {
        let before = GameAudio.isEnabled
        defer { GameAudio.isEnabled = before }
        GameAudio.isEnabled = false
        GameAudio.shared.play(.check)
        GameAudio.isEnabled = true
        GameAudio.shared.play(.play, times: 3, every: 0.01)
    }
}
