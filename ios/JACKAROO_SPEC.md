# Jackaroo — Product & Rules Spec

Last updated: 2026-05-21
Source of truth for rules: `deep-research-report-5.md`. This spec narrows that audit into a single, implementation-ready preset for V1 offline play, and lists every variant the engine must expose as a toggle.

---

## 1. Product goal

Ship a fully **offline** Jackaroo board game inside Tokiyo Casino that:

- Lives next to the existing Poker app and feels like the same product (same dark casino mood, gold/coral/forest palette, parchment-vs-tuxedo themes, MP design tokens).
- Plays solo (1 human + 3 AI) or in **hot-seat** with 2–4 humans on one device.
- Uses a verifiable, canonical baseline ruleset (Jawaker Basic) with disputed mechanics behind toggles, per the deep-research audit.
- Has no network, no accounts, no IAP. Coins balance from `CoinsManager` is optional flavor only — V1 ships chip-free.
- Is deterministic and replayable from a single seed for debugging.

Out of scope for V1: online multiplayer, MPC peer play, Game Center, cross-device persistence, achievements, leaderboards.

---

## 2. Core gameplay loop

```
Deal → TurnStart → SelectCard → GenerateLegalMoves
  ↳ legal move exists → ResolveMove → EffectsAndCapture → PartnerHandoffCheck → EndTurn
  ↳ no legal move    → BurnCard → EndTurn
EndTurn → VictoryCheck
  ↳ team has 8 in Safe → Game over
  ↳ hand exhausted     → Re-deal
  ↳ otherwise          → Next player's TurnStart
```

- 4 seats arranged around a square board. Partners sit opposite (seat 0 ↔ seat 2, seat 1 ↔ seat 3).
- Each player has 4 marbles in their **Home** zone.
- The team wins by getting **all 8 partner marbles** into their **Safe** zones.

---

## 3. Default ruleset (Jawaker Basic preset)

This is the V1 shipping default — the **project default ruleset based on Jawaker Basic**. The card-effect table and the setup/dealer/direction rules track Jawaker Basic directly. The collision and movement rules (blockade, cannot-pass-own, burn-on-no-move, burn scope, Safe lane internal mechanics) are consolidated from Jawaker Complex + CatsAtCards + community sources where Jawaker Basic English is silent or translation-ambiguous. See §4 for the per-toggle source labels.

### Setup
- **4 players, 2 teams**, partners opposite.
- **4 marbles per player**, all in Home at start.
- **52-card deck** (no jokers in default).
- **Dealer** chosen randomly for hand 1; rotates clockwise each subsequent hand.
- **Deal 4 cards** to each player.
- **First turn**: player to dealer's **left**.
- **Turn direction**: clockwise.
- **Fire Pile** (discard) is reshuffled into the Card Pile when the draw stack empties.

### Card effects (default)

| Card | Effect |
|------|--------|
| Ace | Field one own marble Home → Base, **or** move one own marble forward 1 or 11. |
| 2, 3, 5, 6, 8, 9, 10 | Move one marble forward by face value. |
| 4 | Move one marble **backward 4**. |
| 7 | Split 7 total steps across **two of your own** marbles. |
| Jack | Swap one of your marbles with an opponent's marble. Neither may be in Home, Base, or Safe. |
| Queen | Move one marble forward 12. |
| King | Field one own marble Home → Base. |

### Movement & collision
- Landing on another marble sends that marble Home.
- A marble on its **own Base** is protected — cannot be captured, swapped, or bypassed.
- **Blockade**: two consecutive marbles of the same player form a temporary base — the front marble is protected and cannot be bypassed, captured, or swapped (Jawaker Basic + Complex, explicit).
- **Cannot pass your own marble** anywhere on the track (default-on consolidation per the audit; toggle exposed because Jawaker Basic English is translation-ambiguous).
- **Safe zone**: ordered 4-cell lane per player. Entry requires the played card's full value to be consumable, with the final step landing inside Safe. No jumping inside Safe.
- **Burn on no legal move**: if a player has no legal move with any card in hand, the hand is discarded face-up to the Fire Pile and play passes. (The research report only states that "burn/discard on no legal move" is community-sourced; it does **not** verify whether the player loses one card or the whole hand. Default for V1 is **whole hand**, exposed via `burnScope` toggle (`wholeHand` vs `singleCard`). Confirm.)

### Partner handoff
When a player gets **all 4** of their own marbles into Safe, they keep taking turns but now move **their partner's** marbles using the same rules. The legal-move generator must switch ownership at the same moment that the 4th own marble enters Safe, mid-hand.

### Victory
First team to have **all 8 team marbles** in their Safe zones wins. Game ends immediately — no end-of-hand wrap-up.

---

## 4. Variant toggles

The engine must expose a `RulesPreset` value with the toggles below. Defaults are the **project default preset based on Jawaker Basic**. Lines marked "consolidated" are not directly verified by Jawaker Basic; they come from the research-report consolidation across Jawaker Complex / CatsAtCards / community sources and need confirmation. Presets simply pick a set of values; they are not a separate code path.

| Toggle | Values | Default | Notes |
|--------|--------|---------|-------|
| `dealCycle` | `four`, `fourThenFive`, `fourFourFive` | `four` | `four` = Jawaker. `fourThenFive` = CatsAtCards. `fourFourFive` = Bader / community. |
| `seatOrder` | `dealerLeftCW`, `dealerRightCCW` | `dealerLeftCW` | CCW is CatsAtCards. |
| `kingMode` | `fieldOnly`, `fieldOrThirteenCapture` | `fieldOnly` | `fieldOrThirteenCapture` = Jawaker Complex / community. |
| `fiveMode` | `selfOnly`, `anyMarbleOnTrack` | `selfOnly` | Complex/community allow +5 on any track marble (still respects blockades). |
| `sevenMode` | `twoOwn`, `multiOwn` | `twoOwn` | CatsAtCards allows >2 marble splits. |
| `jackMode` | `swapOpponentOnly`, `redElevenBlackSwap` | `swapOpponentOnly` | CatsAtCards uses red/black powers. |
| `queenMode` | `twelveForward`, `blackTwelveRedDiscard` | `twelveForward` | CatsAtCards red queen forces an opponent discard. |
| `cannotPassOwn` | `true`, `false` | `true` | Consolidated. Jawaker Basic English is translation-ambiguous; Jawaker Complex + CatsAtCards explicit. |
| `burnOnNoMove` | `true`, `false` | `true` | Consolidated. Not in Jawaker Basic English; comparative/community-sourced. |
| `burnScope` | `wholeHand`, `singleCard` | `wholeHand` | Consolidated. Report doesn't specify scope of burn. |
| `safeEntryMode` | `cardValueAtMostRemaining`, `exactOnly`, `overflowAroundTrack` | `cardValueAtMostRemaining` | Card value is consumed across `stepsToGate + stepsInsideSafe`. `cardValueAtMostRemaining` = the marble must end on or before the deepest empty Safe cell; `exactOnly` = must end exactly on the deepest empty Safe cell; `overflowAroundTrack` = unused steps continue around the main track instead of entering Safe. No jumping inside Safe in any mode. |
| `partnerHandoff` | `true`, `false` | `true` | Audit-supported. |
| `aceSplit` | `oneOrEleven`, `oneOnly`, `elevenOnly` | `oneOrEleven` | Jawaker Basic. |

Presets shipped in V1:
- **Jawaker Basic** (default, all defaults above).
- **Jawaker Complex** (`kingMode=fieldOrThirteenCapture`, `fiveMode=anyMarbleOnTrack`).
- **Community/CatsAtCards** (Complex + `dealCycle=fourThenFive`, `seatOrder=dealerRightCCW`, `jackMode=redElevenBlackSwap`, `queenMode=blackTwelveRedDiscard`, `sevenMode=multiOwn`).

Custom preset (user-edited toggles) is **not** in V1 — locked-in presets only. Custom is a phase-5 nice-to-have.

---

## 5. Offline / hot-seat behavior

### Modes
1. **Solo vs AI**: 1 human at seat 0. AI fills seats 1–3. Default mode from the menu.
2. **Hot-seat (2–4 humans on one device)**: humans assigned to specific seats, AI fills the rest. Always 4 seats total.

### Privacy ("pass the device")
- Between turns, render a **handoff curtain**: "Pass to <next player name>".
- Hand reveals only after the seated player taps **Show my hand**. After move resolution, the curtain returns.
- Hand-card area is auto-hidden 8 seconds after the last interaction if no card has been played, to protect against a shoulder-surfer.
- AI turns have no curtain.

### Seat names & avatars
- Hot-seat lobby asks for up to 4 player names. Empty seats stay AI with personality-flavored names.
- Avatars: same `AvatarView` style as Poker (hue-seeded gradient + initials).

### No coins
- V1 does not deduct coins, settle winnings, or update `UserStats`. Each session is sandboxed.

---

## 6. AI requirements

- AI plays the same legal-move generator as humans — no shortcuts, no peeking.
- AI follows the **same architectural pattern** as Poker's `AIEngine.swift` (heuristic scorer + personality flavors), but lives in a separate Jackaroo-side type (`JKAIEngine`) with its own evaluation features.
- Treat the game as **imperfect information** (opponents' hands hidden). Do not Monte-Carlo over hidden cards in V1.
- V1 AI = single difficulty, heuristic-based. Difficulty selector (`Easy/Normal/Hard`) is a Phase 4 stretch.
- Heuristic evaluation features:
  1. Sum of progress-to-Safe for own + partner marbles.
  2. Capture: returning an opponent marble Home (weighted by how far it had moved).
  3. Threat: avoid landing 1–6 cells ahead of an enemy marble that could capture.
  4. Blockade bonus: forming a 2-marble blockade in a chokepoint.
  5. Hand flexibility: prefer to spend a low-utility card now over a Jack/King/Ace.
  6. Partner support: prioritize partner marbles once `partnerHandoff` engages.
  7. Burn avoidance: prefer any legal move over discarding the hand.
- After `partnerHandoff` engages, evaluation switches ownership of legal targets without changing personality.
- AI move latency: 600–1200 ms (random jitter) per move so the UI breathes.

---

## 7. Edge cases (must be handled by V1 engine)

These are the cases that broke prior community implementations. Each must have a dedicated unit test.

1. **No legal move at all** with all cards in hand → apply `burnScope` (default: discard the whole hand to Fire Pile), advance turn. Hand is not redealt mid-deal.
2. **Cannot pass own marble** turns a "have card, no target" position into a burn. Especially common with 4/7.
3. **7 split** in `sevenMode=twoOwn` (default) requires **two distinct ownable marbles** to participate. Generator enumerates partitions `(a, 7−a)` with `1 ≤ a ≤ 6`. Degenerate single-marble usage (`(7, 0)`) is **not** legal in `twoOwn`. In `sevenMode=multiOwn`, enumerate any 1-to-4-marble partitions summing to 7 (single-marble allocation legal in this mode only).
4. **4 backward** across the Base cell — front-of-Base ownership and blockade rules still apply, just in reverse direction.
5. **Safe entry**: a card of value `v` is consumed as `v = stepsToGate + stepsInsideSafe`, where `stepsToGate ≥ 0` is the track distance from the marble's current cell to the owner's Safe gate. The marble lands on Safe lane index `stepsInsideSafe − 1` (or stays on the track if `stepsInsideSafe == 0` and the destination is legal). In `cardValueAtMostRemaining` (default) the marble must land on or before the deepest empty Safe cell; in `exactOnly` it must land exactly on the deepest empty cell; in `overflowAroundTrack` the leftover steps continue around the main track instead. No jumping inside Safe in any mode. Marbles already in Safe at lane index `i` follow the same rule with `stepsToGate = 0` and `i + v ≤ 3`.
6. **Blockade in Safe**: marbles inside Safe are always blocked (no jumping inside Safe), independent of `cannotPassOwn`.
7. **Jack swap legality**: both targets must be on the **track** (not Home, Base, Safe). A Jack with no legal swap is unplayable; the player may still play another card.
8. **Ace 1-or-11**: the engine generates two distinct moves for one Ace card. If only one (or neither) is legal, only legal options appear.
9. **Partner handoff mid-turn**: if a 7-split's first marble entering Safe completes the player's 4-marble set, the **remaining steps** still resolve on the same player's marbles — handoff only applies to **future turns**.
10. **King capture (Complex)**: 13-step King captures every marble it passes (subject to blockade). The engine must walk the path step-by-step.
11. **Reshuffle mid-hand**: when the draw stack empties, fold Fire Pile back without changing dealer or turn order. Track the reshuffle in the log.
12. **Burn-on-no-move when one card is theoretically playable elsewhere but no others** — burn applies only when **no card** in the hand has any legal move.
13. **Game ends mid-hand**: if a move puts the 8th team marble in Safe, end the game immediately. Do not finish the deal.

---

## 8. Open decisions (need confirmation)

Flagging items the audit explicitly marks ambiguous or that I had to choose for V1:

1. **`safeEntryMode` default**: picked `cardValueAtMostRemaining` because Jawaker's wording leans toward "value must permit entry". Confirm — or switch to `exactOnly` if you prefer the stricter house rule.
2. **`burnOnNoMove` default + `burnScope`**: defaulting to **on** + **whole hand**. Jawaker Basic doesn't state burn at all; community sources confirm burn but don't agree on scope. Pair of decisions — confirm both, or default `burnScope=singleCard` for the milder interpretation.
3. **Hot-seat seat assignment**: I assume humans pick seat numbers in the lobby. Confirm whether you want partner choice exposed too (e.g., "Mayank & Pawan vs. AI & AI").
4. **No coin economy in V1**: confirm. Adding it later requires defining a buy-in / payout model that doesn't exist in board games.
5. **Difficulty selector**: ship single difficulty in V1, or expose Easy/Normal/Hard from day one? Default plan: single difficulty.
6. **Sound design**: reuse Poker SFX (`button_tap.mp3`, `coin_flip_sound.mp3`) or commission Jackaroo-specific marble/peg sounds? Default plan: reuse Poker SFX for now.
7. **Rules screen content**: Poker has `PokerRulesViewController.swift`. Mirror that for Jackaroo, but who writes the user-facing rules copy? I can lift the rule text from this spec.
