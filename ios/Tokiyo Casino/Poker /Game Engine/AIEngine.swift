//
//  AIEngine.swift
//  Poker
//
//  Created by Mayank Jangid on 8/17/25.
//  Phase 1 refactor: thin orchestrator over EquityCalculator + PreflopRanges +
//  AIProfile. The old per-personality strategy functions and the ad-hoc
//  hand-strength heuristic are gone; all variation now flows through AIProfile
//  knobs (see POKER_AI_DESIGN.md §4.3).
//

import Foundation

// MARK: - AI Decision Engine
enum AIEngine {

    // MARK: - Entry points

    /// Back-compatible entry: resolves the personality to its AIProfile preset.
    /// Runs the full decision (including the Monte Carlo rollout) synchronously,
    /// so callers MUST invoke this off the main thread (see §3 and
    /// `GameManager.processAITurn`).
    static func makeDecision(
        for player: Player,
        gameState: GameState,
        personality: AIPersonality
    ) -> PlayerAction {
        makeDecision(for: player, gameState: gameState, profile: personality.profile)
    }

    static func makeDecision(
        for player: Player,
        gameState: GameState,
        profile: AIProfile
    ) -> PlayerAction {
        var rng = SystemRandomNumberGenerator()
        return decide(for: player, gameState: gameState, profile: profile, rng: &rng)
    }

    /// Pure, seedable decision core (used by tests for determinism).
    static func decide(
        for player: Player,
        gameState: GameState,
        profile: AIProfile,
        rng: inout some RandomNumberGenerator
    ) -> PlayerAction {
        let callAmount = max(0, gameState.currentBet - player.currentBet)
        let liveOpponents = gameState.activePlayers.filter {
            $0.id != player.id && !$0.isAllIn && !$0.isFolded
        }
        let canRaise = !liveOpponents.isEmpty
        let opponents = max(1, gameState.activePlayers.count - 1)

        let chosen: PlayerAction
        if gameState.communityCards.isEmpty {
            chosen = preflopDecision(
                player: player, gameState: gameState, profile: profile,
                callAmount: callAmount, canRaise: canRaise, rng: &rng
            )
        } else {
            chosen = postflopDecision(
                player: player, gameState: gameState, profile: profile,
                callAmount: callAmount, canRaise: canRaise, opponents: opponents, rng: &rng
            )
        }

        // Overlay #1: random sub-optimal action (mistakeRate). legalize is the
        // final step inside each branch, so the overlay only swaps among legal
        // actions it builds itself.
        return applyMistakeOverlay(
            to: chosen, player: player, gameState: gameState, profile: profile,
            callAmount: callAmount, canRaise: canRaise, rng: &rng
        )
    }

    // MARK: - Preflop

    private static func preflopDecision(
        player: Player,
        gameState: GameState,
        profile: AIProfile,
        callAmount: Int,
        canRaise: Bool,
        rng: inout some RandomNumberGenerator
    ) -> PlayerAction {
        guard player.holeCards.count == 2 else {
            return callAmount > 0 ? affordableCall(callAmount, player) : .check
        }

        let position = calculatePosition(
            player: player,
            dealerIndex: gameState.dealerIndex,
            playerCount: gameState.activePlayers.count
        )
        let facingRaise = gameState.wasRaisedPreflop && callAmount > 0

        let range = PreflopRanges.recommendedAction(
            hand: (player.holeCards[0], player.holeCards[1]),
            position: position,
            facingRaise: facingRaise,
            profile: profile
        )

        switch range.sample(using: &rng) {
        case .raiseIntent:
            let frac = 0.6 + profile.aggression * 0.5
            let delta = max(gameState.minRaise, Int(Double(gameState.pot) * frac))
            return legalize(
                targetTotal: gameState.currentBet + delta,
                currentBet: gameState.currentBet,
                playerCurrentBet: player.currentBet,
                playerChips: player.chips,
                minRaise: gameState.minRaise,
                canRaise: canRaise
            )
        case .callIntent:
            return callAmount > 0 ? affordableCall(callAmount, player) : .check
        case .foldIntent:
            return callAmount > 0 ? .fold : .check
        }
    }

    // MARK: - Postflop

    private static func postflopDecision(
        player: Player,
        gameState: GameState,
        profile: AIProfile,
        callAmount: Int,
        canRaise: Bool,
        opponents: Int,
        rng: inout some RandomNumberGenerator
    ) -> PlayerAction {
        let pot = gameState.pot

        // Coarse opponent-range tightening in raised pots (§4.1 intermediate).
        let topFraction = gameState.wasRaisedPreflop ? 0.5 : 0.85
        let eq = EquityCalculator.equity(
            hole: player.holeCards,
            board: gameState.communityCards,
            opponents: opponents,
            iterations: profile.equitySamples,
            opponentTopFraction: topFraction,
            rng: &rng
        )

        let valueLine = valueThreshold(profile)

        if callAmount > 0 {
            // Facing a bet: value-raise / call / bluff-raise / fold.
            let odds = Double(callAmount) / Double(pot + callAmount)

            if eq >= valueLine && canRaise {
                if Double.random(in: 0..<1, using: &rng) < profile.trickiness * 0.4 {
                    return affordableCall(callAmount, player)   // slowplay
                }
                return raiseToFraction(pot: pot, gameState: gameState, player: player,
                                       canRaise: canRaise, profile: profile)
            }

            // callStation raises the fold line toward calling; looseness too.
            let foldLine = odds * (1.0 - profile.callStation) * (1.0 - profile.looseness * 0.2)
            if eq >= foldLine {
                return affordableCall(callAmount, player)
            }

            if canRaise && Double.random(in: 0..<1, using: &rng) < profile.bluffFrequency * 0.5 {
                return raiseToFraction(pot: pot, gameState: gameState, player: player,
                                       canRaise: canRaise, profile: profile)
            }
            return .fold
        } else {
            // Checked to us: value-bet / c-bet-bluff / trap-check.
            if eq >= valueLine {
                if Double.random(in: 0..<1, using: &rng) < profile.trickiness * 0.5 {
                    return .check   // slowplay a strong hand
                }
                return raiseToFraction(pot: pot, gameState: gameState, player: player,
                                       canRaise: canRaise, profile: profile)
            }

            let cbetChance = profile.bluffFrequency * (0.6 + profile.aggression * 0.4)
            if canRaise && Double.random(in: 0..<1, using: &rng) < cbetChance {
                return raiseToFraction(pot: pot, gameState: gameState, player: player,
                                       canRaise: canRaise, profile: profile)
            }
            return .check
        }
    }

    // MARK: - Sizing & thresholds

    /// Minimum equity to bet/raise for value. Aggressive profiles bet thinner.
    private static func valueThreshold(_ profile: AIProfile) -> Double {
        return 0.66 - profile.aggression * 0.16   // ~0.50 ... 0.66
    }

    /// Build a pot-fraction-sized bet/raise and legalize it. Works for both a
    /// fresh bet (currentBet == playerCurrentBet) and a raise over a bet.
    private static func raiseToFraction(
        pot: Int,
        gameState: GameState,
        player: Player,
        canRaise: Bool,
        profile: AIProfile
    ) -> PlayerAction {
        let frac = 0.4 + profile.aggression * 0.6          // 0.4x ... 1.0x pot
        let size = max(1, Int(Double(pot) * frac))
        return legalize(
            targetTotal: gameState.currentBet + size,
            currentBet: gameState.currentBet,
            playerCurrentBet: player.currentBet,
            playerChips: player.chips,
            minRaise: gameState.minRaise,
            canRaise: canRaise
        )
    }

    private static func affordableCall(_ callAmount: Int, _ player: Player) -> PlayerAction {
        return player.chips <= callAmount ? .allIn : .call
    }

    // MARK: - Mistake overlay

    private static func applyMistakeOverlay(
        to action: PlayerAction,
        player: Player,
        gameState: GameState,
        profile: AIProfile,
        callAmount: Int,
        canRaise: Bool,
        rng: inout some RandomNumberGenerator
    ) -> PlayerAction {
        guard profile.mistakeRate > 0,
              Double.random(in: 0..<1, using: &rng) < profile.mistakeRate else {
            return action
        }

        var options: [PlayerAction] = []
        if callAmount > 0 {
            options.append(.fold)
            options.append(affordableCall(callAmount, player))
        } else {
            options.append(.check)
        }
        if canRaise && player.chips > callAmount {
            options.append(legalize(
                targetTotal: gameState.currentBet + gameState.minRaise,
                currentBet: gameState.currentBet,
                playerCurrentBet: player.currentBet,
                playerChips: player.chips,
                minRaise: gameState.minRaise,
                canRaise: canRaise
            ))
        }
        return options.randomElement(using: &rng) ?? action
    }

    // MARK: - Raise legalization (pure; covered by RaiseLegalizationTests)

    /// Convert a desired *total table bet* into a legal `PlayerAction`.
    ///
    /// `PlayerAction.raise(Int)` is a delta over the current bet, not a total
    /// (see GameManagerActions.swift:33). This clamps the delta to
    /// `[minRaise, chips]`, downgrades an unaffordable raise to `.allIn`, and
    /// downgrades a non-raise (target at/below current bet, or no legal raise
    /// available) to `.call`/`.check`/`.allIn`.
    static func legalize(
        targetTotal: Int,
        currentBet: Int,
        playerCurrentBet: Int,
        playerChips: Int,
        minRaise: Int,
        canRaise: Bool
    ) -> PlayerAction {
        let callAmount = max(0, currentBet - playerCurrentBet)

        func nonRaise() -> PlayerAction {
            if callAmount <= 0 { return .check }
            return playerChips <= callAmount ? .allIn : .call
        }

        guard canRaise else { return nonRaise() }

        let rawDelta = targetTotal - currentBet
        if rawDelta <= 0 { return nonRaise() }            // (d) not actually a raise

        let delta = max(rawDelta, minRaise)               // (a) bump up to min raise
        let chipsToCommit = callAmount + delta            // == target - playerCurrentBet
        if chipsToCommit >= playerChips { return .allIn }  // (b)/(c) can't afford full raise

        return .raise(delta)
    }

    // MARK: - Position

    static func calculatePosition(player: Player, dealerIndex: Int, playerCount: Int) -> Position {
        guard playerCount > 0 else { return .middle }
        let playerPosition = (player.id - dealerIndex + playerCount) % playerCount
        let positionRatio = Double(playerPosition) / Double(playerCount)
        if positionRatio < 0.33 { return .early }
        else if positionRatio < 0.67 { return .middle }
        else { return .late }
    }
}

// MARK: - Supporting Types

enum Position {
    case early
    case middle
    case late

    var bonus: Double {
        switch self {
        case .early:  return 0.0
        case .middle: return 0.05
        case .late:   return 0.1
        }
    }
}

struct GameState {
    let pot: Int
    let currentBet: Int
    let minRaise: Int
    let communityCards: [Card]
    let activePlayers: [Player]
    let dealerIndex: Int
    /// True once any player has raised above the big blind preflop this hand.
    /// Drives the coarse opponent-range tightening in EquityCalculator.
    let wasRaisedPreflop: Bool
}
