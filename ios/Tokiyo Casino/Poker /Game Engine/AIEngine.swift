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

        let chosen: Choice
        if gameState.communityCards.isEmpty {
            if callAmount > 0 && facesShove(player: player, gameState: gameState, callAmount: callAmount) {
                chosen = shoveDecision(
                    player: player, gameState: gameState, profile: profile,
                    callAmount: callAmount, canRaise: canRaise, rng: &rng
                )
            } else {
                chosen = preflopDecision(
                    player: player, gameState: gameState, profile: profile,
                    callAmount: callAmount, canRaise: canRaise, rng: &rng
                )
            }
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

    /// A branch's pick, plus whether the hand is strong enough that even a
    /// mistake shouldn't fold it — nobody misclicks aces into the muck.
    private struct Choice {
        let action: PlayerAction
        var strong = false
    }

    // MARK: - Preflop

    private static func preflopDecision(
        player: Player,
        gameState: GameState,
        profile: AIProfile,
        callAmount: Int,
        canRaise: Bool,
        rng: inout some RandomNumberGenerator
    ) -> Choice {
        guard player.holeCards.count == 2 else {
            return Choice(action: callAmount > 0 ? affordableCall(callAmount, player) : .check)
        }

        let hand = (player.holeCards[0], player.holeCards[1])
        let facingRaise = gameState.wasRaisedPreflop && callAmount > 0

        let range = PreflopRanges.recommendedAction(
            hand: hand,
            position: gameState.position,
            facingRaise: facingRaise,
            profile: profile,
            raiserRange: gameState.bettor?.raiseRange ?? PreflopRanges.typicalRaiseRange
        )
        let strong = PreflopRanges.isPremium(hand.0, hand.1)

        switch range.sample(using: &rng) {
        case .raiseIntent:
            return Choice(action: openOrReraise(gameState: gameState, player: player,
                                                profile: profile, canRaise: canRaise),
                          strong: strong)
        case .callIntent:
            return Choice(action: callAmount > 0 ? affordableCall(callAmount, player) : .check, strong: strong)
        case .foldIntent:
            return Choice(action: callAmount > 0 ? .fold : .check, strong: strong)
        }
    }

    /// Preflop raise sized off the pot, legalized.
    private static func openOrReraise(
        gameState: GameState,
        player: Player,
        profile: AIProfile,
        canRaise: Bool
    ) -> PlayerAction {
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
    }

    // MARK: - Preflop, facing a shove

    /// A preflop bet that puts stacks at risk: an all-in set the price, or
    /// calling would commit a third of our stack. The chart's facing-raise
    /// lines are built for a normal raise and ignore the price, which had the
    /// table folding ~85% of hands to every shove; these spots go to
    /// `shoveDecision` instead.
    static func facesShove(player: Player, gameState: GameState, callAmount: Int) -> Bool {
        if callAmount * 3 >= player.chips { return true }
        return gameState.activePlayers.contains {
            $0.id != player.id && $0.isAllIn && $0.currentBet >= gameState.currentBet
        }
    }

    /// Call when our equity against the bettor's range beats the pot odds by
    /// the profile's margin; re-raise to isolate as a big favourite. The range
    /// is the tracker's read on the bettor (`GameState.bettor`), so a seat
    /// that shoves every hand gets called wide once the table has seen it.
    private static func shoveDecision(
        player: Player,
        gameState: GameState,
        profile: AIProfile,
        callAmount: Int,
        canRaise: Bool,
        rng: inout some RandomNumberGenerator
    ) -> Choice {
        guard player.holeCards.count == 2 else {
            return Choice(action: affordableCall(callAmount, player))
        }

        let odds = potOdds(callAmount: callAmount, pot: gameState.pot, chips: player.chips)

        // Who we'd be up against: everyone already in for the full bet, or
        // all-in. The bettor holds its shoving range if it shoved, or its
        // raising range if the raise only prices us in because we're short;
        // anyone who just called holds something tighter; in an unraised pot
        // the blinds hold any two.
        let contestants = gameState.activePlayers.filter {
            $0.id != player.id && ($0.isAllIn || $0.currentBet >= gameState.currentBet)
        }
        let bettorRange: Double
        if let read = gameState.bettor {
            let shoved = contestants.first { $0.id == read.seat }?.hasShoved ?? true
            bettorRange = shoved ? read.shoveRange : read.raiseRange
        } else {
            bettorRange = defaultShoveRange
        }
        let ranges: [Double] = contestants.isEmpty ? [1.0] : contestants.map { seat in
            guard gameState.wasRaisedPreflop else { return 1.0 }
            guard let bettor = gameState.bettor?.seat, seat.id != bettor else { return bettorRange }
            return min(bettorRange, calledShoveRange)
        }
        let eq = EquityCalculator.equity(
            hole: player.holeCards,
            board: [],
            opponentRanges: ranges,
            iterations: profile.equitySamples,
            rng: &rng
        )

        // Anyone still to act could wake up with a hand behind us.
        let stillToAct = gameState.activePlayers.filter {
            $0.id != player.id && !$0.isAllIn && $0.currentBet < gameState.currentBet
        }.count
        let callLine = odds + shoveCallMargin(profile) + 0.01 * Double(stillToAct)
        guard eq >= callLine else { return Choice(action: .fold) }

        if canRaise && eq >= max(0.62, callLine + 0.15) {
            return Choice(action: openOrReraise(gameState: gameState, player: player,
                                                profile: profile, canRaise: canRaise),
                          strong: true)
        }
        return Choice(action: affordableCall(callAmount, player), strong: eq >= callLine + 0.08)
    }

    /// Range assumed behind a shove from a seat with no read yet — the same
    /// prior the tracker starts every seat at.
    private static let defaultShoveRange =
        OpponentModel(stats: OpponentStats(), prior: .populationBaseline).shoveRange

    /// Widest range credited to a player who called the shove rather than made it.
    private static let calledShoveRange = 0.2

    /// Equity cushion over the pot odds before calling off a stack: tight
    /// profiles want a clear edge, loose and sticky ones call a little light.
    private static func shoveCallMargin(_ profile: AIProfile) -> Double {
        0.02 - profile.callStation * 0.08 - (profile.looseness - 0.5) * 0.08
    }

    /// Equity needed to call: what we can actually put in against the part of
    /// the pot we can win. A bet bigger than our stack only costs our stack,
    /// and the excess goes back to the bettor.
    static func potOdds(callAmount: Int, pot: Int, chips: Int) -> Double {
        let effectiveCall = min(callAmount, chips)
        let winnablePot = pot - max(0, callAmount - chips)
        return Double(effectiveCall) / Double(max(1, winnablePot + effectiveCall))
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
    ) -> Choice {
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
        let strong = eq >= valueLine

        if callAmount > 0 {
            // Facing a bet: value-raise / call / bluff-raise / fold.
            let odds = potOdds(callAmount: callAmount, pot: pot, chips: player.chips)

            if strong && canRaise {
                if Double.random(in: 0..<1, using: &rng) < profile.trickiness * 0.4 {
                    return Choice(action: affordableCall(callAmount, player), strong: strong)   // slowplay
                }
                return Choice(action: raiseToFraction(pot: pot, gameState: gameState, player: player,
                                                      canRaise: canRaise, profile: profile),
                              strong: strong)
            }

            // callStation raises the fold line toward calling; looseness too.
            let foldLine = odds * (1.0 - profile.callStation) * (1.0 - profile.looseness * 0.2)
            if eq >= foldLine {
                return Choice(action: affordableCall(callAmount, player), strong: strong)
            }

            if canRaise && Double.random(in: 0..<1, using: &rng) < profile.bluffFrequency * 0.5 {
                return Choice(action: raiseToFraction(pot: pot, gameState: gameState, player: player,
                                                      canRaise: canRaise, profile: profile))
            }
            return Choice(action: .fold)
        } else {
            // Checked to us: value-bet / c-bet-bluff / trap-check.
            if strong {
                if Double.random(in: 0..<1, using: &rng) < profile.trickiness * 0.5 {
                    return Choice(action: .check, strong: strong)   // slowplay a strong hand
                }
                return Choice(action: raiseToFraction(pot: pot, gameState: gameState, player: player,
                                                      canRaise: canRaise, profile: profile),
                              strong: strong)
            }

            let cbetChance = profile.bluffFrequency * (0.6 + profile.aggression * 0.4)
            if canRaise && Double.random(in: 0..<1, using: &rng) < cbetChance {
                return Choice(action: raiseToFraction(pot: pot, gameState: gameState, player: player,
                                                      canRaise: canRaise, profile: profile))
            }
            return Choice(action: .check)
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
        to choice: Choice,
        player: Player,
        gameState: GameState,
        profile: AIProfile,
        callAmount: Int,
        canRaise: Bool,
        rng: inout some RandomNumberGenerator
    ) -> PlayerAction {
        guard profile.mistakeRate > 0,
              Double.random(in: 0..<1, using: &rng) < profile.mistakeRate else {
            return choice.action
        }

        var options: [PlayerAction] = []
        if callAmount > 0 {
            // A mistake can misjudge a hand, but never folds a strong one.
            if !choice.strong { options.append(.fold) }
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
        return options.randomElement(using: &rng) ?? choice.action
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

    /// Preflop position from a seat's place in the order after the button:
    /// 0 = small blind ... `seatsDealtIn - 1` = the button. For opening, what
    /// matters is how many players are still to act behind the seat. (This
    /// replaced a seat-id ratio that rated the button "early" and reshuffled
    /// every seat as players folded.)
    static func position(placeAfterButton place: Int, seatsDealtIn: Int) -> Position {
        guard seatsDealtIn > 2 else {
            // Heads-up: the button (small blind) against the big blind.
            return place == seatsDealtIn - 1 ? .late : .middle
        }
        // The blinds have money in, but play the hand out of position.
        if place < 2 { return .middle }
        // Behind this seat: the rest of the way round to the button, then both blinds.
        let behind = (seatsDealtIn - 1 - place) + 2
        if behind <= 3 { return .late }        // cutoff, button
        return behind == 4 ? .middle : .early
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
    /// The acting seat's preflop position (see `AIEngine.position`).
    var position: Position = .middle
    /// The table's read on whoever made the bet being faced; nil when nothing
    /// is bet into the actor or no read was built, and the engine then
    /// assumes a typical player.
    var bettor: BettorRead? = nil
}

extension Player {
    /// All-in, or at least a third of the stack already in this hand — a
    /// shove, as far as reading a range goes.
    var hasShoved: Bool { isAllIn || totalInvested * 3 >= chips + totalInvested }
}

/// What this session has shown about the seat that made the bet being faced,
/// from `HandHistoryTracker`. Ranges are shares of starting hands with the
/// prior blended in: 1.0 means any two cards.
struct BettorRead: Equatable {
    let seat: Int
    /// How wide this seat shoves preflop (`OpponentModel.shoveRange`).
    let shoveRange: Double
    /// How wide this seat raises preflop (its PFR).
    let raiseRange: Double
}
