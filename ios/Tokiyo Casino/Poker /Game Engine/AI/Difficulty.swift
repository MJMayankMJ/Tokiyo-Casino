//
//  Difficulty.swift
//  Poker — AI / Phase 2
//
//  Difficulty tiers + per-seat style selection and their persistence, per
//  POKER_AI_DESIGN.md §5. A `PokerAIConfig` (difficulty + style) is the single
//  user-facing knob; it resolves into a concrete `AIProfile` per AI seat that
//  the engine consumes. `Difficulty.apply(to:)` clamps the simulation budget
//  and mistake rate so a tier governs *strength* regardless of which stylistic
//  preset a seat draws.
//
//  The `exploitation` flag is stored here but consumed only in Phase 3
//  (OpponentModel / Exploit). It is intentionally inert today.
//

import Foundation

// MARK: - Difficulty tiers

enum Difficulty: String, Codable, CaseIterable {
    case easy, medium, hard, expert

    /// Monte Carlo budget for the tier (overrides whatever the base preset asks).
    var equitySamples: Int {
        switch self {
        case .easy:   return 200
        case .medium: return 1500
        case .hard:   return 3000
        case .expert: return 3000
        }
    }

    /// Random sub-optimal-action rate forced by the tier.
    var mistakeRate: Double {
        switch self {
        case .easy:   return 0.25
        case .medium: return 0.05
        case .hard:   return 0.0
        case .expert: return 0.0
        }
    }

    /// Whether Phase 3 opponent-modeling exploits are active for this tier.
    var exploitation: Exploitation {
        switch self {
        case .easy, .medium: return .off
        case .hard:          return .on
        case .expert:        return .aggressive
        }
    }

    /// Stylistic presets an "auto-mix" table draws from at this tier. Seats are
    /// assigned by cycling this list, so the order also sets the mix ratio.
    var autoMixStyles: [PokerAIStyle] {
        switch self {
        case .easy:   return [.callingStation, .nit]
        case .medium: return [.tag, .callingStation, .nit]
        case .hard:   return [.tag, .lag, .solverInspired]
        case .expert: return [.solverInspired]
        }
    }

    var displayName: String {
        switch self {
        case .easy:   return "Easy"
        case .medium: return "Medium"
        case .hard:   return "Hard"
        case .expert: return "Expert"
        }
    }

    /// Clamp a stylistic base profile to this tier's strength envelope. Style
    /// (aggression, looseness, etc.) is preserved; only the budget and mistake
    /// rate — the levers that actually set *how strong* the seat is — change.
    func apply(to base: AIProfile) -> AIProfile {
        var p = base
        p.equitySamples = equitySamples
        p.mistakeRate = mistakeRate
        return p
    }
}

enum Exploitation: String, Codable {
    case off, on, aggressive
}

// MARK: - Per-seat style

/// User-selectable seat style. `.autoMix` defers to the difficulty tier's
/// `autoMixStyles`; every other case pins all AI seats to one preset.
enum PokerAIStyle: String, Codable, CaseIterable {
    case autoMix
    case nit
    case tag
    case lag
    case callingStation
    case maniac
    case solverInspired

    /// Concrete preset, or nil for `.autoMix` (which is resolved per-tier).
    var profile: AIProfile? {
        switch self {
        case .autoMix:        return nil
        case .nit:            return .nit
        case .tag:            return .tag
        case .lag:            return .lag
        case .callingStation: return .callingStation
        case .maniac:         return .maniac
        case .solverInspired: return .solverInspired
        }
    }

    var displayName: String {
        switch self {
        case .autoMix:        return "Auto-mix"
        case .nit:            return "Nit"
        case .tag:            return "TAG"
        case .lag:            return "LAG"
        case .callingStation: return "Calling Station"
        case .maniac:         return "Maniac"
        case .solverInspired: return "Pro"
        }
    }
}

// MARK: - Config

/// The single persisted AI configuration. `style` is the optional advanced
/// override; most players only ever touch `difficulty`.
struct PokerAIConfig: Codable, Equatable {
    var difficulty: Difficulty
    var style: PokerAIStyle

    init(difficulty: Difficulty = .medium, style: PokerAIStyle = .autoMix) {
        self.difficulty = difficulty
        self.style = style
    }

    static let `default` = PokerAIConfig()

    /// Resolve concrete per-seat profiles for `aiSeatCount` AI seats.
    ///
    /// - An explicit `style` pins every seat to that preset (then tier-clamped).
    /// - `.autoMix` cycles the tier's `autoMixStyles` so the table feels varied
    ///   while still capped to the tier's strength.
    func resolvedProfiles(aiSeatCount: Int) -> [AIProfile] {
        guard aiSeatCount > 0 else { return [] }

        let bases: [AIProfile]
        if let pinned = style.profile {
            bases = [pinned]
        } else {
            // Expert's autoMixStyles is just [.solverInspired]; others vary.
            bases = difficulty.autoMixStyles.compactMap { $0.profile }
        }
        // Defensive fallback so we never divide by an empty list.
        let safeBases = bases.isEmpty ? [AIProfile.solverInspired] : bases

        return (0..<aiSeatCount).map { i in
            difficulty.apply(to: safeBases[i % safeBases.count])
        }
    }
}

// MARK: - Persistence

/// Reads/writes the one `PokerAIConfig` under a single `UserDefaults` key, per
/// POKER_AI_DESIGN.md §5.3. Tolerates a missing/corrupt blob by returning the
/// default config.
enum PokerAIConfigStore {
    static let key = "pokerAIConfig"

    static func load(defaults: UserDefaults = .standard) -> PokerAIConfig {
        guard let data = defaults.data(forKey: key),
              let config = try? JSONDecoder().decode(PokerAIConfig.self, from: data) else {
            return .default
        }
        return config
    }

    static func save(_ config: PokerAIConfig, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        defaults.set(data, forKey: key)
    }
}
