//
//  PreflopRanges.swift
//  Poker — AI / Phase 1
//
//  Hand-authored preflop strategy. Per POKER_AI_DESIGN.md §4.2 we author our
//  own simplified ranges rather than bundling commercial charts (which are not
//  license-clean to redistribute). For the MVP these are encoded directly in
//  Swift as a principled scoring function + position thresholds rather than a
//  169-cell JSON grid; a JSON asset can replace `handScore`/thresholds later
//  without changing the call sites.
//
//  `handScore` is also reused by EquityCalculator's coarse opponent-range
//  rejection filter (§4.1 intermediate improvement).
//

import Foundation

/// A sampled-action distribution for a starting hand in a given spot.
/// The three weights sum to 1.0.
struct ActionRange: Equatable {
    var raise: Double
    var call: Double
    var fold: Double

    /// Pick one of .raiseIntent / .callIntent / .foldIntent using `rng`.
    func sample(using rng: inout some RandomNumberGenerator) -> PreflopIntent {
        let roll = Double.random(in: 0..<1, using: &rng)
        if roll < raise { return .raiseIntent }
        if roll < raise + call { return .callIntent }
        return .foldIntent
    }
}

enum PreflopIntent {
    case raiseIntent
    case callIntent
    case foldIntent
}

enum PreflopRanges {

    /// Heuristic starting-hand strength in 0...1 (pairs, suitedness, gaps, high
    /// cards). Deliberately simple and self-authored.
    static func handScore(_ c1: Card, _ c2: Card) -> Double {
        // Pocket pair
        if c1.rank == c2.rank {
            let pairValue = Double(c1.rank.rawValue)
            return min(0.50 + (pairValue / 14.0) * 0.45, 0.99)
        }

        let suited = c1.suit == c2.suit
        let hi = max(c1.rank.rawValue, c2.rank.rawValue)
        let lo = min(c1.rank.rawValue, c2.rank.rawValue)
        let gap = hi - lo

        var score = (Double(hi + lo) / 28.0) * 0.42
        score += suited ? 0.10 : 0.0
        switch gap {
        case 1: score += 0.08   // connected
        case 2: score += 0.04   // one-gap
        case 3: score += 0.02   // two-gap
        default: break
        }
        if hi == Rank.ace.rawValue { score += 0.10 }

        return min(score, 0.95)
    }

    /// Recommended action distribution for an opening / facing-raise decision.
    /// `profile.looseness` widens (lowers thresholds) or tightens the range;
    /// `profile.aggression` shifts marginal hands from call toward raise.
    static func recommendedAction(
        hand: (Card, Card),
        position: Position,
        facingRaise: Bool,
        profile: AIProfile
    ) -> ActionRange {

        let score = handScore(hand.0, hand.1)

        var raiseLine: Double
        var callLine: Double
        switch position {
        case .early:  raiseLine = 0.60; callLine = 0.52
        case .middle: raiseLine = 0.54; callLine = 0.46
        case .late:   raiseLine = 0.46; callLine = 0.38
        }

        // Facing a raise tightens both lines (need a better hand to continue).
        if facingRaise {
            raiseLine += 0.15
            callLine  += 0.10
        }

        // Looseness lowers thresholds (loose players play more hands).
        let loosen = (profile.looseness - 0.5) * 0.20
        raiseLine -= loosen
        callLine  -= loosen

        if score >= raiseLine {
            return ActionRange(raise: 0.82, call: 0.13, fold: 0.05)
        } else if score >= callLine {
            // Marginal: aggressive profiles convert more of these into raises.
            let raise = 0.15 + profile.aggression * 0.25
            let call  = max(0.0, 0.70 - raise * 0.30)
            let fold  = max(0.0, 1.0 - raise - call)
            return ActionRange(raise: raise, call: call, fold: fold)
        } else {
            // Weak: mostly fold, occasional loose limp.
            let call = 0.05 * profile.looseness
            return ActionRange(raise: 0.0, call: call, fold: 1.0 - call)
        }
    }
}
