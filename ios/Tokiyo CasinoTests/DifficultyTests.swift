//
//  DifficultyTests.swift
//  Tokiyo CasinoTests
//
//  Phase 2 — difficulty tiers, per-seat profile resolution, and config
//  persistence (POKER_AI_DESIGN.md §5). These pin the contract the UI relies
//  on: a tier governs *strength* (equity samples + mistake rate) while style
//  governs *flavour* (aggression/looseness/etc.), and the two compose into a
//  concrete per-seat AIProfile.
//

import XCTest
@testable import Tokiyo_Casino

final class DifficultyTests: XCTestCase {

    // MARK: apply(to:) clamps strength, preserves style

    func testApplyOverridesBudgetAndMistakeButKeepsStyle() {
        let tuned = Difficulty.medium.apply(to: .maniac)
        // Style levers untouched...
        XCTAssertEqual(tuned.aggression, AIProfile.maniac.aggression)
        XCTAssertEqual(tuned.looseness, AIProfile.maniac.looseness)
        XCTAssertEqual(tuned.bluffFrequency, AIProfile.maniac.bluffFrequency)
        // ...strength levers replaced by the tier.
        XCTAssertEqual(tuned.equitySamples, 1500)
        XCTAssertEqual(tuned.mistakeRate, 0.05, accuracy: 1e-9)
    }

    func testTierStrengthTable() {
        // (samples, mistakeRate) per POKER_AI_DESIGN.md §5.2.
        let expected: [Difficulty: (Int, Double)] = [
            .easy:   (200, 0.25),
            .medium: (1500, 0.05),
            .hard:   (3000, 0.0),
            .expert: (3000, 0.0),
        ]
        for (tier, (samples, mistake)) in expected {
            XCTAssertEqual(tier.equitySamples, samples, "\(tier) samples")
            XCTAssertEqual(tier.mistakeRate, mistake, accuracy: 1e-9, "\(tier) mistake")
        }
    }

    func testExploitationGating() {
        XCTAssertEqual(Difficulty.easy.exploitation, .off)
        XCTAssertEqual(Difficulty.medium.exploitation, .off)
        XCTAssertEqual(Difficulty.hard.exploitation, .on)
        XCTAssertEqual(Difficulty.expert.exploitation, .aggressive)
    }

    // MARK: resolved per-seat profiles

    func testAutoMixEasyCyclesAllowedStylesAtTierStrength() {
        let config = PokerAIConfig(difficulty: .easy, style: .autoMix)
        let profiles = config.resolvedProfiles(aiSeatCount: 4)
        XCTAssertEqual(profiles.count, 4)
        // Every seat clamped to easy strength.
        for p in profiles {
            XCTAssertEqual(p.equitySamples, 200)
            XCTAssertEqual(p.mistakeRate, 0.25, accuracy: 1e-9)
        }
        // Cycles [callingStation, nit] → looseness 0.70, 0.20, 0.70, 0.20.
        XCTAssertEqual(profiles[0].looseness, AIProfile.callingStation.looseness, accuracy: 1e-9)
        XCTAssertEqual(profiles[1].looseness, AIProfile.nit.looseness, accuracy: 1e-9)
        XCTAssertEqual(profiles[2].looseness, AIProfile.callingStation.looseness, accuracy: 1e-9)
        XCTAssertEqual(profiles[3].looseness, AIProfile.nit.looseness, accuracy: 1e-9)
    }

    func testAutoMixExpertIsAllSolverInspired() {
        let config = PokerAIConfig(difficulty: .expert, style: .autoMix)
        let profiles = config.resolvedProfiles(aiSeatCount: 5)
        XCTAssertEqual(profiles.count, 5)
        for p in profiles {
            XCTAssertEqual(p.aggression, AIProfile.solverInspired.aggression, accuracy: 1e-9)
            XCTAssertEqual(p.equitySamples, 3000)
            XCTAssertEqual(p.mistakeRate, 0.0, accuracy: 1e-9)
        }
    }

    func testPinnedStylePinsEverySeatThenClamps() {
        let config = PokerAIConfig(difficulty: .medium, style: .lag)
        let profiles = config.resolvedProfiles(aiSeatCount: 3)
        XCTAssertEqual(profiles.count, 3)
        for p in profiles {
            XCTAssertEqual(p.aggression, AIProfile.lag.aggression, accuracy: 1e-9)
            XCTAssertEqual(p.looseness, AIProfile.lag.looseness, accuracy: 1e-9)
            // medium tier overrides lag's own samples (1500) and mistake (0.05).
            XCTAssertEqual(p.equitySamples, 1500)
            XCTAssertEqual(p.mistakeRate, 0.05, accuracy: 1e-9)
        }
    }

    func testZeroSeatsResolvesEmpty() {
        XCTAssertTrue(PokerAIConfig.default.resolvedProfiles(aiSeatCount: 0).isEmpty)
        XCTAssertTrue(PokerAIConfig.default.resolvedProfiles(aiSeatCount: -3).isEmpty)
    }

    // MARK: persistence

    func testConfigStoreRoundTrips() {
        let defaults = UserDefaults(suiteName: "DifficultyTests.roundtrip")!
        defaults.removePersistentDomain(forName: "DifficultyTests.roundtrip")

        let config = PokerAIConfig(difficulty: .hard, style: .tag)
        PokerAIConfigStore.save(config, defaults: defaults)
        XCTAssertEqual(PokerAIConfigStore.load(defaults: defaults), config)
    }

    func testConfigStoreReturnsDefaultWhenMissing() {
        let defaults = UserDefaults(suiteName: "DifficultyTests.missing")!
        defaults.removePersistentDomain(forName: "DifficultyTests.missing")
        XCTAssertEqual(PokerAIConfigStore.load(defaults: defaults), .default)
    }
}
