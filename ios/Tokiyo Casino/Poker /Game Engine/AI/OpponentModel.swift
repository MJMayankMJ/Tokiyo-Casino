//
//  OpponentModel.swift
//  Poker — AI / Phase 3
//
//  Per-session statistical model of a single seat, derived from the counts the
//  `HandHistoryTracker` accumulates while folding over the `ActionLog`
//  (POKER_AI_DESIGN.md §6.2). Stats are the industry-standard set —
//  VPIP / PFR / AF / fold-to-cbet / fold-to-3bet / WTSD — each computed from an
//  explicit opportunity count (e.g. fold-to-cbet = foldedToCbet / facedCbet).
//
//  Sample-size aware: every stat is blended with a prior derived from a notional
//  baseline `AIProfile` until ~30 opportunities of data, then the observed rate
//  is increasingly trusted. This stops the exploit layer from over-reacting to a
//  two-hand sample.
//

import Foundation

// MARK: - Raw counts

/// Pure tally of one seat's observed behaviour this session. Accumulated by
/// `HandHistoryTracker`; never blended — that happens in `OpponentModel`.
struct OpponentStats: Equatable {
    // Preflop opportunities (denominator = handsDealt).
    var handsDealt = 0
    var vpipCount = 0          // hands where money went in voluntarily preflop
    var pfrCount = 0           // hands raised preflop

    // Postflop aggression factor: (bets + raises) / calls.
    var postflopBets = 0       // postflop bets + raises
    var postflopCalls = 0      // postflop calls

    // Fold to flop continuation bet.
    var facedCbet = 0
    var foldedToCbet = 0

    // Fold to a preflop 3-bet.
    var faced3bet = 0
    var foldedTo3bet = 0

    // Went to showdown (denominator = hands that saw the flop).
    var sawFlop = 0
    var wentToShowdown = 0
}

// MARK: - Blended model

/// A blended, sample-size-aware view of one seat. `prior` is the notional
/// baseline used while data is thin; as opportunities accumulate the observed
/// rate dominates (full trust by ~30 opportunities for that stat).
struct OpponentModel {
    let stats: OpponentStats
    let prior: AIProfile

    /// Opportunities below which a stat is trusted at full weight.
    static let fullTrustThreshold = 30.0

    /// Sample size used by the exploit layer's adaptation ramp.
    var handsObserved: Int { stats.handsDealt }

    // MARK: Blended stats (all 0...1 except `af`)

    var vpip: Double { blend(num: stats.vpipCount, den: stats.handsDealt, prior: priorVPIP) }
    var pfr: Double { blend(num: stats.pfrCount, den: stats.handsDealt, prior: priorPFR) }
    var foldToCbet: Double { blend(num: stats.foldedToCbet, den: stats.facedCbet, prior: priorFoldToCbet) }
    var foldTo3bet: Double { blend(num: stats.foldedTo3bet, den: stats.faced3bet, prior: priorFoldTo3bet) }
    var wtsd: Double { blend(num: stats.wentToShowdown, den: stats.sawFlop, prior: priorWTSD) }

    /// Aggression factor (bets+raises)/calls, capped so a 0-call sample doesn't
    /// blow up to infinity. Blended by total postflop actions seen.
    var af: Double {
        let samples = stats.postflopBets + stats.postflopCalls
        let rawValue: Double?
        if stats.postflopCalls > 0 {
            rawValue = min(Self.afCap, Double(stats.postflopBets) / Double(stats.postflopCalls))
        } else if stats.postflopBets > 0 {
            rawValue = Self.afCap     // all aggression, no calls → treat as maximally aggressive
        } else {
            rawValue = nil
        }
        return blendValue(raw: rawValue, prior: priorAF, samples: samples)
    }

    private static let afCap = 10.0

    // MARK: Priors derived from the notional baseline profile

    private var priorVPIP: Double { clamp01(0.15 + prior.looseness * 0.45) }
    private var priorPFR: Double { clamp01(priorVPIP * (0.35 + prior.aggression * 0.45)) }
    private var priorAF: Double { 0.5 + prior.aggression * 3.0 }
    private var priorFoldToCbet: Double { clamp01(0.30 + (1.0 - prior.callStation) * 0.40) }
    private var priorFoldTo3bet: Double { clamp01(0.40 + (1.0 - prior.looseness) * 0.40) }
    private var priorWTSD: Double { clamp01(0.18 + prior.callStation * 0.32) }

    // MARK: Blend helpers

    /// Blend an observed ratio (num/den) with a prior, weighting the observation
    /// by `min(1, den / fullTrustThreshold)`.
    private func blend(num: Int, den: Int, prior: Double) -> Double {
        guard den > 0 else { return prior }
        let raw = Double(num) / Double(den)
        let w = min(1.0, Double(den) / Self.fullTrustThreshold)
        return raw * w + prior * (1.0 - w)
    }

    /// Blend an already-computed value with a prior given a sample count.
    private func blendValue(raw: Double?, prior: Double, samples: Int) -> Double {
        guard let raw, samples > 0 else { return prior }
        let w = min(1.0, Double(samples) / Self.fullTrustThreshold)
        return raw * w + prior * (1.0 - w)
    }
}

private func clamp01(_ x: Double) -> Double { min(1.0, max(0.0, x)) }
