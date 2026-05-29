//
//  AIProfile.swift
//  Poker — AI / Phase 1
//
//  Parametric description of an AI opponent's style. Every field maps to a
//  concrete lever in the decision policy (see POKER_AI_DESIGN.md §4.3 table) —
//  no field is cosmetic. Difficulty tiers and the settings UI that compose
//  these are Phase 2; Phase 1 only needs the struct, the presets, and the
//  AIPersonality -> preset mapping so the existing four seats already feel
//  distinct on the new engine.
//

import Foundation

struct AIProfile: Codable, Equatable {
    /// 0..1 — bet/raise sizing and frequency; also lowers the value-bet threshold.
    var aggression: Double
    /// 0..1 — preflop range width and postflop calling width.
    var looseness: Double
    /// 0..1 — chance to bluff/c-bet when equity is below value but the spot is credible.
    var bluffFrequency: Double
    /// 0..1 — reluctance to fold to bets (raises the fold line toward calling).
    var callStation: Double
    /// 0..1 — slowplay / check-raise rate with strong hands.
    var trickiness: Double
    /// 0..1 — chance per decision to pick a random legal sub-optimal action.
    var mistakeRate: Double
    /// Monte Carlo iteration budget. Lower = noisier equity = weaker decisions.
    var equitySamples: Int

    // MARK: - Presets (starting points, tuned in play-testing)

    static let nit            = AIProfile(aggression: 0.30, looseness: 0.20, bluffFrequency: 0.05, callStation: 0.10, trickiness: 0.10, mistakeRate: 0.05, equitySamples: 2000)
    static let tag            = AIProfile(aggression: 0.60, looseness: 0.35, bluffFrequency: 0.15, callStation: 0.20, trickiness: 0.30, mistakeRate: 0.05, equitySamples: 2000)
    static let lag            = AIProfile(aggression: 0.80, looseness: 0.60, bluffFrequency: 0.30, callStation: 0.20, trickiness: 0.50, mistakeRate: 0.10, equitySamples: 1500)
    static let callingStation = AIProfile(aggression: 0.30, looseness: 0.70, bluffFrequency: 0.05, callStation: 0.80, trickiness: 0.10, mistakeRate: 0.20, equitySamples: 800)
    static let maniac         = AIProfile(aggression: 0.95, looseness: 0.85, bluffFrequency: 0.60, callStation: 0.30, trickiness: 0.50, mistakeRate: 0.25, equitySamples: 800)
    /// Strongest preset. Named to avoid implying true GTO (see §2).
    static let solverInspired = AIProfile(aggression: 0.65, looseness: 0.50, bluffFrequency: 0.25, callStation: 0.30, trickiness: 0.35, mistakeRate: 0.00, equitySamples: 3000)

    /// Default used by the Phase 1 MVP before the difficulty UI exists.
    static let `default` = solverInspired
}

// MARK: - AIPersonality bridge
//
// The existing AIPersonality enum (Player.swift) stays as the labelled,
// user-visible seat identity; each case now resolves to an AIProfile preset so
// the new engine drives all four. This keeps GameManager / multiplayer seat
// assignment compiling unchanged while behaviour comes from the profile.

extension AIPersonality {
    var profile: AIProfile {
        switch self {
        case .tightAggressive: return .tag
        case .loosePassive:    return .callingStation
        case .balanced:        return .solverInspired
        case .bluffer:         return .maniac
        }
    }
}
