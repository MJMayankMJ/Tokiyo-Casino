# Poker AI Upgrade — Design Doc

Status: Proposed
Owner: Mayank
Scope: On-device upgrade to the Texas Hold'em AI used in single-player and as host-side bots in multiplayer
Out of scope: Backend / cloud ML, neural-network policies, training pipelines

---

## 1. Motivation

The current AI in [AIEngine.swift](Tokiyo%20Casino/Poker%20/Game%20Engine/AIEngine.swift) is pure heuristic: an ad-hoc hand-strength formula plus pot odds plus position, branched across four hardcoded personalities (`tightAggressive`, `loosePassive`, `balanced`, `bluffer`). There is no equity calculation, no preflop range logic, and no opponent modeling. Result:

- AI plays roughly the same regardless of board texture
- "Personalities" feel like reskins of the same logic, not distinct opponents
- No way for the player to choose difficulty
- Decisions are weak enough that a moderately experienced player will beat the table every session

Goal: a meaningfully stronger and more *varied* AI, configurable as Easy / Medium / Hard / Expert with selectable opponent styles, while staying fully on-device with no external dependencies on a server or large ML runtime.

---

## 2. Approach summary

Three layers, each independently shippable:

1. **Equity engine** — replace the hand-strength heuristic with Monte Carlo win-probability and use real preflop range charts.
2. **Parametric profiles + difficulty UI** — turn the four hardcoded personalities into a `AIProfile` struct with knobs, and expose difficulty/style to the player.
3. **Opponent modeling** — track the human's stats during a session and let Hard/Expert bots adapt their strategy to exploit observed tendencies.

No ML model is shipped. The strength gain comes from correct poker math plus adaptive exploitation, which is what experienced human players actually do.

**Naming honesty:** this design produces *strong heuristic poker AI*, not Game-Theory-Optimal (GTO) play. True GTO requires solving the full imperfect-information betting tree (range vs. range across all streets), which is explicitly out of scope (see §10). No profile, tier, or component in this doc should be labelled "GTO". The strongest preset is named `.solverInspired` to make this distinction explicit.

---

## 3. Architecture

New modules slot into `Poker /Game Engine/AI/`. The existing `AIEngine.swift` becomes a thin orchestrator that composes them. [HandEvaluator.swift](Tokiyo%20Casino/Poker%20/Game%20Engine/HandEvaluator.swift) is unchanged — the equity calculator calls into it inside the rollout loop.

```
Poker /Game Engine/
  AI/
    EquityCalculator.swift      # Phase 1 — Monte Carlo equity
    PreflopRanges.swift         # Phase 1 — chart lookup
    PreflopRanges.json          # Phase 1 — bundled data asset
    AIProfile.swift             # Phase 2 — parametric profile + presets
    Difficulty.swift            # Phase 2 — Easy/Medium/Hard/Expert tiers
    HandHistoryTracker.swift    # Phase 3 — emits hand/street/showdown events -> ActionLog
    OpponentModel.swift         # Phase 3 — per-session stat tracker (consumes ActionLog)
    Exploit.swift               # Phase 3 — adjustments derived from stats
  AIEngine.swift                # Refactored: thin orchestrator, off-main-thread decision
```

The decision pipeline must run **off the main thread**. Today `processAITurn` calls `AIEngine.makeDecision` synchronously on the main queue ([GameManagerTurns.swift:59-78](Tokiyo%20Casino/Poker%20/Game%20Engine/GameManagerTurns.swift:59)); a multi-thousand-iteration rollout there will freeze the UI. The refactor introduces an async decision entry point that runs the rollout on a background queue and hops back to main to apply the action, with cancellation if the seat is replaced mid-think (the existing `scheduledPlayerId` guard pattern).

Existing `AIPersonality` enum in [Player.swift](Tokiyo%20Casino/Poker%20/Models/Player.swift) is kept as a labelled alias mapping each case to an `AIProfile` preset, so the seat-assignment code at [GameManager.swift:82](Tokiyo%20Casino/Poker%20/Game%20Engine/GameManager.swift:82) and the multiplayer host at [PokerHostService.swift:239](Tokiyo%20Casino/Poker%20/Multiplayer/Services/PokerHostService.swift:239) continue to compile while migrating.

---

## 4. Phase 1 — Equity engine + preflop ranges

### 4.1 `EquityCalculator.swift`

API:

```swift
enum EquityCalculator {
    static func equity(
        hole: [Card],
        board: [Card],
        opponents: Int,
        iterations: Int
    ) -> Double  // 0.0 ... 1.0
}
```

Algorithm:

1. Build the remaining deck (52 minus hole + board).
2. For each iteration: shuffle remaining deck, deal `opponents * 2` opponent hole cards, deal missing board cards (5 - board.count).
3. Evaluate the hero's 7 cards and each opponent's 7 cards via `HandEvaluator.evaluateBestHand`.
4. Tally wins (count tie as `1 / numTied`).
5. Return `wins / iterations`.

Performance budget: a single AI decision must complete in under 100 ms of *wall-clock perceived* time. Because the rollout runs on a background queue (see §3) the hard constraint is actually "finish before the UX delay elapses and don't block main"; 100 ms is the target so the existing ~1.5 s think-delay fully hides it. Initial target: ~2,000 iterations per decision in pure Swift.

Threading: `equity(...)` is a pure synchronous function (easy to test/benchmark), but `AIEngine` only ever calls it from a background queue, and the call is cancellable — if the acting seat changes mid-computation the result is discarded.

Mitigations if the pure-Swift evaluator is too slow:

- Cache pre-flop equities (169 canonical starting hands x small opponent counts) in a static table built once at app launch.
- Bridge [OMPEval](https://github.com/zekyll/OMPEval) (C++/MIT) via an Objective-C++ shim — ~100x speedup, costs one `.mm` file and a dependency. Decision is gated on benchmark results, not committed up-front.

**Limitation — random vs. range-weighted opponents.** v1 samples opponent hole cards uniformly from the remaining deck, which over-estimates equity against opponents who only continue with strong ranges. This is an acceptable simplification for v1 and already far better than the current hand-rank heuristic. A later improvement weights the sampled opponent hands by a plausible range (derived from their preflop action and the `OpponentModel` from Phase 3) instead of treating every two-card combo as equally likely. Tracked as a future enhancement, not v1 scope.

### 4.2 `PreflopRanges.swift` + `PreflopRanges.json`

- Bundled JSON of position-based opening ranges (UTG / MP / CO / BTN / SB / BB). **Preferred source: hand-author a simplified set ourselves** (or generate our own with an open solver offline) so the bundled data is unambiguously ours to ship. "Free to view" charts from commercial sites (Upswing, GTO Wizard) are *not* automatically license-clean for redistribution inside a shipped app — treat them as reference only, not as bundleable assets.
- Encoding: each cell of the 13x13 starting-hand grid (e.g. `AKs`, `T9o`, `77`) maps to an action distribution `{ fold: x, call: y, raise: z }`.
- API:

```swift
enum PreflopRanges {
    static func recommendedAction(
        hand: (Card, Card),
        position: Position,
        facingRaise: Bool,
        profile: AIProfile
    ) -> ActionRange
}
```

- `profile.looseness` shifts the range: positive values expand it (e.g. add 22+, A2s+, KTo+), negative tightens.

### 4.3 `AIEngine` refactor

`AIEngine.makeDecision` becomes:

```
if gameState.communityCards.isEmpty:
    consult PreflopRanges -> raw action distribution
    sample action using profile (looseness, aggression)
else:
    eq = EquityCalculator.equity(...)
    odds = pot odds vs current bet
    if eq < odds * foldThreshold: fold
    elif eq > raiseThreshold(profile): raise sized by profile.aggression
    else: call / check
apply profile.mistakeRate (random sub-optimal swap) and profile.bluffFrequency overlays
```

The four existing strategy functions in `AIEngine.swift` are deleted. All variation now flows through `AIProfile` knobs.

**Raise legalization — must be exact.** `PlayerAction.raise(Int)` means "raise **by** this many chips over the current bet," *not* "raise to this total." Confirmed in [GameManagerActions.swift:33-37](Tokiyo%20Casino/Poker%20/Game%20Engine/GameManagerActions.swift:33): `totalBet = oldCurrentBet + amount`. So the engine computes a target *total* bet from pot fraction × `profile.aggression`, then emits `raise(target - currentBet)`. A dedicated `legalize(action:)` step clamps that delta to `[minRaise, player.chips]`, downgrades an unaffordable raise to `.allIn`, and downgrades a raise-to-equal-current to `.call`/`.check`. The engine must never emit an illegal raise amount; getting this wrong silently mis-sizes every bet.

---

## 5. Phase 2 — Parametric profiles + difficulty UI

### 5.1 `AIProfile.swift`

```swift
struct AIProfile: Codable, Equatable {
    var aggression: Double       // 0..1 — bet/raise sizing & freq
    var looseness: Double        // 0..1 — preflop range width
    var bluffFrequency: Double   // 0..1 — bluff when checked to in position
    var callStation: Double      // 0..1 — reluctance to fold to bets
    var trickiness: Double       // 0..1 — slowplay / check-raise rate
    var mistakeRate: Double      // 0..1 — random sub-optimal action
    var equitySamples: Int       // simulation budget; lower = weaker
}
```

Presets:

| Preset            | aggression | looseness | bluff | callStation | trickiness | mistake | samples |
|-------------------|------------|-----------|-------|-------------|------------|---------|---------|
| `.nit`            | 0.3        | 0.2       | 0.05  | 0.1         | 0.1        | 0.05    | 2000    |
| `.tag`            | 0.6        | 0.35      | 0.15  | 0.2         | 0.3        | 0.05    | 2000    |
| `.lag`            | 0.8        | 0.6       | 0.3   | 0.2         | 0.5        | 0.1     | 1500    |
| `.callingStation` | 0.3        | 0.7       | 0.05  | 0.8         | 0.1        | 0.2     | 800     |
| `.maniac`         | 0.95       | 0.85      | 0.6   | 0.3         | 0.5        | 0.25    | 800     |
| `.solverInspired` | 0.65       | 0.5       | 0.25  | 0.3         | 0.35       | 0.0     | 3000    |

(Numbers are starting points to be tuned against play-testing. `.solverInspired` is the strongest preset — named to avoid implying true GTO; see §2.)

The existing `AIPersonality` enum maps:

- `.tightAggressive -> .tag`
- `.loosePassive -> .callingStation`
- `.balanced -> .solverInspired`
- `.bluffer -> .maniac`

### 5.2 `Difficulty.swift`

```swift
enum Difficulty: String, Codable, CaseIterable {
    case easy, medium, hard, expert

    func apply(to base: AIProfile) -> AIProfile { ... }
}
```

Tier behaviour:

| Difficulty | Equity samples | Mistake rate | Profiles used                  | Exploitation |
|------------|----------------|--------------|--------------------------------|--------------|
| Easy       | 200            | 0.25         | only `.callingStation`, `.nit` | off          |
| Medium     | 1500           | 0.05         | mix of mid presets             | off          |
| Hard       | 3000           | 0.0          | mix incl. `.tag`, `.lag`       | on           |
| Expert     | 3000           | 0.0          | all seats use `.solverInspired`| on (aggressive) |

### 5.3 UI surface

- New pre-game settings sheet, or extension of the existing menu in [MenuViewController.swift](Tokiyo%20Casino/Poker%20/UI/ViewControllers/MenuViewController.swift):
  - Segmented control: Difficulty (Easy / Medium / Hard / Expert)
  - Optional advanced expander: per-seat style picker (TAG / LAG / Nit / Calling Station / Maniac / Auto-mix)
- Persist selection via `UserDefaults` under a single `pokerAIConfig` key.
- Setup flow in [GameViewControllerSetup.swift](Tokiyo%20Casino/Poker%20/UI/ViewControllers/GameViewControllerSetup.swift) reads the selection and passes resolved `AIProfile`s into `GameManager` instead of letting it randomly pick personalities.
- Multiplayer host ([PokerHostService.swift](Tokiyo%20Casino/Poker%20/Multiplayer/Services/PokerHostService.swift)) reads the same selection so host-driven bots match the local config.

---

## 6. Phase 3 — Opponent modeling

### 6.1 `HandHistoryTracker.swift` + `ActionLog`

The poker stats below cannot be computed from "the human acted" alone. VPIP/PFR need to know it's preflop and whether the action was voluntary (a big blind that checks its option did not voluntarily put money in). Fold-to-cbet needs to know who the preflop aggressor was and that this is the flop. Fold-to-3bet needs the preflop raise sequence. WTSD needs a showdown event. So we add a small dedicated event layer rather than a single action hook.

`HandHistoryTracker` observes the game lifecycle and emits structured events into an in-memory `ActionLog`:

- `handStarted(handId, button, blinds, seats)`
- `streetStarted(handId, street, board)` — driven by phase changes in `GameManager` ([GamePhase](Tokiyo%20Casino/Poker%20/Game%20Engine/GameTypes.swift:11))
- `playerActed(handId, seat, street, action, amountToCall, isVoluntary, isFacingRaise)`
- `aggressorChanged(handId, street, seat)` — tracks the last bettor/raiser per street
- `showdownReached(handId, seats)` and `handEnded(handId, winners)`

These hang off the existing delegate callbacks (`gamePhaseDidChange`, `playerDidAct`, `playerDidWin` in [GameTypes.swift:45](Tokiyo%20Casino/Poker%20/Game%20Engine/GameTypes.swift:45)) plus `processPlayerAction`, so no game-rules code is rewritten — the tracker is a passive observer.

### 6.2 `OpponentModel.swift`

Maintained per human seat for the lifetime of the session, computed by folding over the `ActionLog`.

Tracked stats (industry-standard), each derived from explicit opportunity counts (e.g. fold-to-cbet = `timesFoldedToCbet / timesFacedCbet`):

- `vpip` — voluntary $ in pot %
- `pfr` — preflop raise %
- `af` — aggression factor: `(bets + raises) / calls` postflop
- `foldToCbet`
- `foldTo3bet`
- `wtsd` — went to showdown %

Sample-size aware: each stat is blended with the player's notional `AIProfile` defaults until ~30 hands of data, then increasingly trusted.

### 6.2 `Exploit.swift`

Pure functions:

```swift
enum Exploit {
    static func adjusted(profile: AIProfile, vs opponent: OpponentModel) -> AIProfile
}
```

Heuristics:

- **Calling station** (high VPIP, low fold-to-cbet): reduce bluff frequency, increase value bet sizing, widen value range.
- **Nit** (low VPIP, high fold-to-cbet): increase bluff frequency, c-bet more often regardless of board.
- **Maniac** (high AF): tighten calling range, slow-play strong hands more (raise `trickiness`).

Only applied on **Hard** and **Expert**. Easy and Medium stay non-exploitative so newer players are not punished for predictable play.

---

## 7. Effort estimate

| Phase | Scope                                                                   | Estimate          |
|-------|-------------------------------------------------------------------------|-------------------|
| 0     | Benchmark harness: current evaluator + one postflop equity scenario     | 1–2 dev days      |
| 1     | Equity calc, hand-authored ranges, AIEngine refactor, off-main threading| 6–9 dev days      |
| 2     | Profiles, difficulty UI, persistence, multiplayer plumb                 | 3–5 dev days      |
| 3     | HandHistoryTracker/ActionLog, opponent model, exploit layer             | 4–6 dev days      |
|       | **Total**                                                               | **~3.5 weeks solo** |

---

## 8. Risks and open decisions

1. **Evaluator performance + threading.** Pure-Swift may not hit the iteration budget fast enough, and the decision currently runs synchronously on the main queue ([GameManagerTurns.swift:59](Tokiyo%20Casino/Poker%20/Game%20Engine/GameManagerTurns.swift:59)). Phase 0 benchmark + the off-main async refactor (§3) both gate Phase 1. OMPEval bridging only if the benchmark demands it.
2. **Preflop chart licensing.** "Free to view" is not "free to redistribute in a shipped app." Hand-author our own simplified ranges (or generate with an open solver offline). Treat commercial-site charts as reference only.
3. **Raise legalization.** `.raise(Int)` is a *delta over current bet*, not a total ([GameManagerActions.swift:33](Tokiyo%20Casino/Poker%20/Game%20Engine/GameManagerActions.swift:33)). The engine must convert target-total → delta and clamp to `[minRaise, chips]`, downgrading to `.allIn`/`.call`/`.check` as needed. Cover with unit tests.
4. **Multiplayer protocol compatibility.** The network protocol in [ProtocolConstants.swift](Tokiyo%20Casino/Poker%20/Multiplayer/Protocol/ProtocolConstants.swift) carries a seat `kind`. Syncing profile choices would need a protocol version bump. Cleaner: keep `AIProfile` host-local — host runs all decisions, clients see only the seat label. Recommended path.
5. **AIPersonality migration.** Keep the existing enum as a thin alias to presets (chosen path). Avoids touching persisted state and multiplayer payloads.
6. **Equity realism.** v1 uses random-opponent equity (over-optimistic vs. tight ranges). Range-weighted sampling is the planned follow-up once `OpponentModel` exists (see §4.1).
7. **Bet sizing distribution.** A naive "% of pot scaled by aggression" can feel mechanical. We may want a small set of discrete sizes (0.33x / 0.5x / 0.75x / pot / overbet) sampled by profile. Defer until play-testing.

---

## 9. Phased delivery plan

**Phase 0 — benchmark first (1–2 days):** build a benchmark harness around the current `HandEvaluator` and run one representative postflop equity scenario at varying iteration counts. Outcome locks in the `equitySamples` tiers and decides whether we need OMPEval bridging *before* any product code is written.

**Phase 1 MVP — engine, no UI:** `EquityCalculator` + hand-authored preflop ranges + `AIEngine` refactor running off the main thread with cancellation. All seats use the new engine; old personality strategy functions deleted. No new UI yet — validate strength by play-testing with a default profile. Player should notice opponents play meaningfully better.

**Phase 2 — profiles + difficulty UI:** `AIProfile`/`Difficulty`, the settings UI, persistence, and multiplayer host plumbing. `.solverInspired` preset (not "GTO"). Player can dial difficulty and style up or down.

**Phase 3 — adaptation, last:** only after the base AI feels solid. `HandHistoryTracker`/`ActionLog`, `OpponentModel`, `Exploit` layer. Hard/Expert opponents start adapting after ~30 hands; verify exploits trigger by play-testing against scripted calling-station and nit profiles.

---

## 10. Out of scope (intentionally)

- Neural-network policies (DeepCFR, NFSP, etc.) — punted to a future "Pro tier" if we ever want a backend.
- Cloud / REST inference — stays fully on-device.
- Multi-street planning (range-vs-range with full betting tree) — true GTO requires this; out of scope for v1.
- Hand history persistence beyond the current session — opponent model resets per session.
