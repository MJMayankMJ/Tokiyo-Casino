# Jackaroo — Implementation Plan

Last updated: 2026-05-21
Companion to `JACKAROO_SPEC.md`, `JACKAROO_DESIGN.md`, `JACKAROO_TECH_SPEC.md`. Each phase has a goal, scope, deliverables, and exit criteria. Phases are sequential; do not start phase N+1 until N's exit criteria are met.

The work lives on a `feat/jackaroo-offline` branch off `main`. Commit at the end of each phase with a tag-friendly message (`Jackaroo: Phase 1 — engine + rules`).

---

## Phase 1 — Engine + rules

**Goal**: a headless, fully tested Jackaroo engine with no UI. Every rule documented in `JACKAROO_SPEC.md` is correctly enforced; default preset is Jawaker Basic.

### Scope
- Create `Jackaroo/` folder under `Tokiyo Casino/`.
- Add `Game Engine/`, `Models/` subfolders per `JACKAROO_TECH_SPEC.md` §1.
- Define `JKCard` as its own `Codable` struct (Poker's `Card` is not `Codable`), with a bridge to the Poker `Card`/`Suit`/`Rank` for the reused `CardView` / `SuitView` atoms.
- Implement:
  - `JKBoardGraph` (72-cell default, configurable).
  - `JKMarble`, `JKPosition`, `JKPlayer`, `JKGameState`, `JKRulesPreset`, `JKMove`, `JKGameLog`, `JKSeededRNG`.
  - `JKLegalMoveGenerator` for the **default preset only** (Jawaker Basic). Variant-only behaviors (King-13, 5-any, etc.) are stubbed and gated off.
  - `JKMoveResolver` covering all default-preset card effects + capture + swap + safe entry + blockade + safe-internal movement.
  - `JackarooEngine` with turn loop, deterministic shuffle (seeded), reshuffle on deck empty.
- Set up `Tokiyo CasinoTests/JackarooTests/` and write the Phase 1 test suite (`JKBoardGraphTests`, `JKMoveResolverTests`, `JKLegalMoveGeneratorTests`, `BurnTests`, `PartnerHandoffTests`, basic `ReplayTests`).

### Deliverables
- Code compiles in Xcode. Local test target passes 100% (no CI configured in this repo — confirm whether to add CI before Phase 6).
- `JKLegalMoveGenerator` + `JKMoveResolver` + `JKBoardGraph` at 100% line coverage.
- A small CLI-style test fixture: given a seed, the engine plays a 4-AI game to completion deterministically.

### Exit criteria
- The §7 edge cases from `JACKAROO_SPEC.md` **that apply to the default preset** have named, passing tests. Specifically: ec 1, 2, 3 (twoOwn branch only), 4, 5 (`cardValueAtMostRemaining` default mode — must cover all of `stepsToGate + stepsInsideSafe`, marbles already inside Safe, and the deepest-empty-cell guard), 6, 7, 8, 9, 11, 12, 13. The variant-only sub-cases — ec 5's `exactOnly` / `overflowAroundTrack` modes and ec 10 (King-13) — are deferred to Phase 5 alongside the toggles they exercise.
- Property test: 1000 random seeded games of "always-pick-first-legal" terminate with valid `winner` and pass all invariants.
- Game played by `currentSeat = round-robin first-legal-move` finishes in < 100 ms wall time per game.

### Out of scope this phase
- Any UI. Any AI (uses "first legal move" stub). Any variant presets.

---

## Phase 2 — Board + game UI

**Goal**: pixel-perfect game screen that visualizes engine state. Single human + 3 stub AIs (the Phase 1 "first legal" picker), no hot-seat, no privacy curtain, no real AI.

### Scope
- `Jackaroo/UI/Components/`:
  - `JKMarbleView`.
  - `JKBoardView` — renders cells/zones from `JKBoardGraph` + `JKBoardLayout`.
  - `JKHandStripView`.
  - `JKTurnPillView`.
- `Jackaroo/UI/View/JKBoardLayout.swift` — polar/Cartesian layout helper.
- `Jackaroo/UI/ViewControllers/JackarooGameViewController.swift`:
  - Wire up `JackarooEngine` delegate → animations.
  - Tap a card → highlight legal targets → tap target → resolve.
  - Animate marble movement step-by-step.
  - Animate capture / swap / safe entry / deal.
- Reuse `MPTheme`, `MPFont`, `MPPageBackgroundView`, `MPBackPill`, `MPGearPill`, `CardView`, `SuitView`, `AvatarView` directly.
- Add a temporary developer entry point: `JackarooGameViewController` is launched from a debug button in `HomeViewController` (gated `#if DEBUG`).

### Deliverables
- A playable solo game (you + 3 stub AIs) end to end on device.
- Light + dark theme both look correct.
- Animations feel like Poker — same timing, easings, haptics.

### Exit criteria
- Reviewer can play a complete game start to finish without crashing.
- No memory leaks across one full game (verify with Instruments).
- All animations interruptible by app backgrounding without breaking engine state.

### Out of scope this phase
- Hot-seat. Real AI. Rules screen. Game summary screen. Variant presets. Permanent menu entry.

---

## Phase 3 — Hot-seat flow

**Goal**: solo + 2/3/4-human-on-one-device experiences shipped behind the production menu entry. Privacy curtain works.

### Scope
- `JackarooMenuViewController` (mirrors `MenuViewController` in Poker):
  - Mode picker: Solo vs AI / Hot-Seat (2–4).
  - Ruleset preset chip (locked to Jawaker Basic in this phase — variants are Phase 5).
  - Primary CTA: Start.
- `JackarooLobbyViewController`:
  - Up to 4 player name fields, seat picker, AI fill toggle.
  - Validate at least 1 human + 1 AI or 2 humans before enabling Start.
- `JKHandoffOverlay`:
  - Full-screen curtain between human turns, "Pass to <name>".
  - "Show my hand" reveal + auto-hide.
- `JackarooGameSummaryViewController`:
  - Win/lose modal showing team marbles, MVP marble (most progress), play-again CTA.
- `JackarooRulesViewController`:
  - Card-by-card rule listing built from the `JACKAROO_SPEC.md` default ruleset.
- Permanent **Jackaroo tile** added to `HomeViewController` (programmatic, like Poker's). Tile pushes `JackarooMenuViewController` on the nav stack.
- Replace the debug entry point from Phase 2.

### Deliverables
- The whole Solo + Hot-Seat flow ships behind the home tile.
- Curtain prevents the next player from seeing the previous player's hand.
- Game summary appears at end of game.

### Exit criteria
- Manual QA: every hot-seat seat count (2/3/4 humans with AI fill) runs to a winner cleanly.
- Curtain auto-hides on inactivity (8 s default).
- VoiceOver reads turn ownership and selected card correctly.

### Out of scope this phase
- Real AI (still stub). Variant presets. Sound / SFX work. Settings screen.

---

## Phase 4 — AI players

**Goal**: replace the stub picker with a heuristic AI that plays competently.

### Scope
- `Jackaroo/Game Engine/JKAIEngine.swift` implementing the scorer from `JACKAROO_TECH_SPEC.md` §6.
- Jackaroo-local `JKPersonality` enum with 4 flavors: `tightAggressive`, `loosePassive`, `balanced`, `bluffer` — names mirror Poker's `AIPersonality` for UX consistency, but the enum is independent so modules stay decoupled.
- 600–1200 ms latency per AI turn for pacing.
- AI-only games (no human) supported for QA.
- Tests in `JKAIEngineTests`:
  - Capture beats progress when capture target is far from Home.
  - Burn is never chosen if any other move exists.
  - Personality biases are observable across 1000 simulated games (tight-aggressive captures more often than loose-passive, etc.).

### Deliverables
- The default mode is solo vs 3 mixed-personality AIs.
- AI labels in lobby show personality icon + name (own Jackaroo strings + emoji; do not reuse Poker `AIPersonality`).

### Exit criteria
- AI never illegal-moves (engine asserts on illegal AI moves).
- Solo human wins ~50% over 50 games against mixed AI (rough calibration).
- 4-AI game completes within 90 s wall time including animations.

### Out of scope this phase
- Search-based AI. Difficulty selector. Hidden-hand modeling.

---

## Phase 5 — Variants & settings

**Goal**: expose Jawaker Complex and Community presets, plus per-session settings.

### Scope
- `JKLegalMoveGenerator` + `JKMoveResolver` updates for:
  - `kingMode = .fieldOrThirteenCapture`.
  - `fiveMode = .anyMarbleOnTrack`.
  - `sevenMode = .multiOwn`.
  - `jackMode = .redElevenBlackSwap`.
  - `queenMode = .blackTwelveRedDiscard`.
  - `dealCycle = .fourThenFive` and `.fourFourFive`.
  - `seatOrder = .dealerRightCCW`.
  - `safeEntryMode` variants.
  - `cannotPassOwn = false` path.
  - `burnOnNoMove = false` path.
- `JKRulesPreset.jawakerComplex` + `JKRulesPreset.community` factories.
- Preset picker in `JackarooMenuViewController` (chip with 3 segments).
- `JackarooSettingsSheet` — per-session **preset picker**, not a freeform toggle editor. Reads `JKRulesPreset.jawakerBasic | jawakerComplex | community` only; advanced/custom toggle editing is post-V1 (consistent with `JACKAROO_SPEC.md` §4 — locked-in presets only in V1).
- Per-preset rules screen content (`JackarooRulesViewController` reads from the active preset).
- Tests expanded: `JKRulesPresetTests` for each toggle's effect, plus regression suite that re-runs Phase 1's tests against each preset. Add explicit tests for `JACKAROO_SPEC.md` §7 ec 5 (`safeEntryMode=exactOnly`) and ec 10 (King-13 capture) here, since those edge cases depend on the variant toggles introduced in this phase.

### Deliverables
- 3 selectable presets fully playable.
- Settings sheet works for both human-controlled and AI-controlled toggles.

### Exit criteria
- Each preset has a smoke test that plays one full AI vs AI game to completion.
- Switching presets between hands does not corrupt state (presets are locked at game start).
- No regressions on Phase 1 tests.

### Out of scope this phase
- User-saved custom presets. Cross-game persistence of preset preference.

---

## Phase 6 — Polish, animation, testing

**Goal**: ship-quality. Sound, motion, accessibility, autosave, performance pass.

### Scope
- Sound integration via `SoundManager` (reuse existing assets per `JACKAROO_DESIGN.md` §6).
- Haptics for select, move, capture, win.
- Marble move-speed setting (1× / 1.5× / 2×) on the gear menu.
- Confetti / celebration emitter on win.
- VoiceOver passes (label every interactive element, announce turn changes).
- Dynamic Type support on the menu, lobby, rules screens.
- Autosave hook (`Documents/jackaroo_autosave.json`); "Resume game" pill on menu when present.
- Crash recovery test: kill app mid-game, verify recovery offers resume.
- Performance pass with Instruments:
  - Time profiler over a 4-AI game.
  - Memory snapshot before/after game.
  - No view-controller leaks.
- Snapshot tests for the game screen in 3 fixture states.
- Manual QA matrix completed (iPhone SE, iPhone 15 Pro Max, light, dark, VoiceOver on).
- Update the project's README to mention Jackaroo.

### Deliverables
- Production-ready Jackaroo, behind a feature flag if one exists (the codebase doesn't appear to use feature flags — confirm).
- All 3 spec docs reviewed and locked.

### Exit criteria
- Bug bash with at least one external player produces no blockers.
- App Store screenshots include a Jackaroo board (if part of marketing).
- All Phase 1–5 tests still green.

### Out of scope (post-V1)
- Online multiplayer (peer-to-peer via MPC, mirroring Poker's offline-friends architecture).
- Achievements / coin economy.
- iPad-specific layout.
- Game Center integration.

---

## Cross-cutting concerns

### Branching
- `feat/jackaroo-offline` off `main`. Phase tags: `jackaroo-phase-1` … `jackaroo-phase-6`. PR per phase.

### Naming
- All Jackaroo types use the `JK*` prefix (`JKMarbleView`, `JKBoardView`, `JKPlayer`, `JKCard`, `JKGameState`, `JKBoardGraph`, `JKMove`, `JKMoveResolver`, `JKLegalMoveGenerator`, `JKAIEngine`, `JKRulesPreset`, etc.). The Tokiyo Casino app is a **single Swift module**, and the existing Poker engine already defines top-level `AIEngine`, `GameState`, and `Position`. Reusing those names would compile-conflict.
- Screen-level view controllers and the engine coordinator keep their `Jackaroo` prefix (`JackarooMenuViewController`, `JackarooEngine`, etc.) because they're already unambiguous.

### Reuse vs. fork
- **Reuse (as-is)**: Poker `Suit` / `Rank` enums and `Card` for view atoms; `MPTheme`, `MPFont`, `PokerTheme`, `MPPageBackgroundView`, menu chrome, `CardView`, `SuitView`, `AvatarView`, `ChipView`, `PotPillView`, `SoundManager`.
- **Mirror but don't share**: AI personalities (define `JKPersonality` locally; UX wording can match).
- **Do not fork**: never copy theme values into a new theme file. Add new shades to `MPTheme` (e.g., `coralLight`, `forestLight` for seat 2/3) if needed.

### CI
This repo has no CI configured (no `.github/workflows`, no Fastlane, no `.yml`). Plan assumes local Xcode test runs only. If CI lands before Phase 6, swap "local test target passes" for "CI green."

### Things I still need confirmed before Phase 1 starts
1. Board cell count (defaulted to 72; not a verified canonical fact — confirm).
2. `safeEntryMode` default (defaulted to `cardValueAtMostRemaining`; confirm).
3. `burnOnNoMove` default (defaulted to **on**) and `burnScope` default (defaulted to **whole hand**); confirm both.
4. `JKPersonality` is Jackaroo-local. Confirm — alternative is to share Poker's `AIPersonality`.
5. Whether autosave ships in Phase 6 or post-V1.
6. Coins economy in V1 (defaulted to **none**).
7. Difficulty selector (defaulted to single difficulty).
8. Hot-seat partner assignment UX (defaulted to seat-tap, partners are seat 0+2 vs 1+3).
9. Red queen discard target: engine RNG selects victim's lost card. Confirm — alternative is victim-chooses (adds an out-of-turn UI step).
10. Seat 2/3 marble color treatment: hue-shifted same-team family vs entirely different hues with a team ring badge (default plan: family-with-ring).

A 10-minute decision pass on these unblocks Phase 1.
