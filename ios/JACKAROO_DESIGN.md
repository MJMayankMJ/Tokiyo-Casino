# Jackaroo — Visual & UX Design Spec

Last updated: 2026-05-21
Owns: visual language, screens, board layout, motion. Pairs with `JACKAROO_SPEC.md` (rules) and `JACKAROO_TECH_SPEC.md` (engine).

---

## 1. Visual direction

Jackaroo must read as the **same product** as Poker. Reuse the existing design tokens; do not introduce a new palette.

### Tokens

There are **two existing theme namespaces** in the project and they overlap rather than nest. Reuse both:

- **`MPTheme`** (`Poker /Multiplayer/UI/MultiplayerDesign.swift`) — page chrome, glass surfaces, lobby/menu typography. Defines `amber`, `coral`, `coralDeep`, `forest`, `forestDeep`, `felt`, `feltDepth`, `feltEdge`, `glass`, `glassMedium`, `glassWeak`, `primaryAction`, plus the radial gradient backdrop.
- **`PokerTheme`** (`Poker /UI/Components/PokerDesign.swift`) — atoms like `CardView`, `SuitView`, `ChipView`, `BetPillView`, `PotPillView`, `TopInfoBar` all reference `PokerTheme` internally (`PokerTheme.cardBack`, `PokerTheme.amber`, `PokerTheme.suitRed`, `PokerTheme.warn`, etc.). Reusing those atoms automatically pulls in PokerTheme. The two palettes are intentionally aligned — same gold, same coral, same forest — so this is fine, but the spec should call it out so implementers don't assume MPTheme is the only theme.

Tokens we'll use:
- Light = parchment cream, dark = tuxedo navy-black (both themes).
- Gold = `MPTheme.amber` / `amberDeep` / `primaryAction` (= `PokerTheme.amber`).
- Green = `MPTheme.forest` / `forestDeep`.
- Coral = `MPTheme.coral` / `coralDeep`.
- Warn red = `PokerTheme.warn` (only defined on PokerTheme).
- Felt = `MPTheme.felt` / `feltDepth` / `feltEdge`.
- Glass chrome = `MPTheme.glass` / `glassMedium` / `glassWeak`.

Typography: `MPFont.display` (serif New York) for screen titles + big numbers; `MPFont.ui` (SF) for buttons, captions, labels. **Never** introduce a new font face.
Shadows: reuse `PokerTheme.applyShadowSm/Md/Lg`.

### Player color assignment

Each seat gets its **own distinct marble color** so a player can tell their marbles apart from their partner's at a glance — essential for partner handoff (you start moving your partner's marbles), for capture (the right Home pocket lights up), and because each player's Base + Safe lane is owned individually, not jointly.

- Seat 0 (Team A): `MPTheme.coral` body, `MPTheme.coralDeep` outline.
- Seat 1 (Team B): `MPTheme.forest` body, `MPTheme.forestDeep` outline.
- Seat 2 (Team A, partner of seat 0): coral hue shifted — same `MPTheme.coral` body desaturated and brightened ~12% (define as `MPTheme.coralLight` if missing — add to MPTheme rather than forking); outline matches seat 0's deep coral so the team is visibly the same family.
- Seat 3 (Team B, partner of seat 1): forest hue shifted brighter ~12% (`MPTheme.forestLight`); outline = `MPTheme.forestDeep`.
- Each marble carries a small team **ring badge** at its base (a 2 pt ring in the team's deep color) so the team affiliation is unambiguous even when seat colors are close.
- Highlights / "your turn" ring = `MPTheme.amber` regardless of seat.

Open: confirm whether `coralLight` / `forestLight` should be new MPTheme tokens, or if seat 2/3 should use entirely different hues (e.g., amber + a desaturated sky/teal) to maximize legibility. Default plan: hue-shifted family colors with the ring badge for team grouping.

### Surface stack on the game screen
1. `MPPageBackgroundView` (radial gradient + grain). Same backdrop as Poker.
2. Felt disk for the **board** — circular `felt` fill with `feltEdge` ring (depth + 1px brass border in dark).
3. Track cells + zones drawn on top.
4. Floating glass pills (turn info, deck count, hand) layered above the board.

---

## 2. Screen list

| Screen | Purpose | Reused chrome |
|--------|---------|---------------|
| **Home tile entry** | Add a "Jackaroo" tile to `HomeViewController` (programmatic, like the Poker tile). | `imageTokio<Game>` pattern. |
| **JackarooMenuViewController** | Mode select + ruleset preset + start. Mirrors Poker's `MenuViewController`. | `MPPageBackgroundView`, `MPBackPill`, `MPGearPill`, `MPTitleView`, `MPPrimaryButton`, `MPSecondaryButton`. |
| **JackarooLobbyViewController** | Hot-seat setup: enter up to 4 player names, AI fill toggle for empty seats, preset chip, Start. | `MPPlayerPicker`-style seat list, `MPPrimaryButton`. |
| **JackarooRulesViewController** | Card-by-card rules sheet. Same layout as `PokerRulesViewController`. | Sheet presentation, glass cards. |
| **JackarooGameViewController** | The board, hand, turn HUD. New layout; reuses tokens + atoms. | `TopInfoBar`-style top pill, `AvatarView`, card atoms. |
| **JackarooHandoffOverlay** | Full-screen curtain shown between humans in hot-seat. | Same dim + serif title style as Poker's round banner. |
| **JackarooGameSummaryViewController** | Post-game team win modal. | Mirror `GameSummaryViewController` exactly. |
| **JackarooSettingsSheet** *(stretch)* | Per-session toggles for advanced presets. | Sheet, list rows. |

Navigation: Jackaroo lives under the Home tile, exactly like Poker — push `JackarooMenuViewController` onto a nav controller, then push lobby → game.

---

## 3. Board layout

### Geometry
- Square, then circumscribe a circle inside.
- 4 corners + 4 sides. Each side carries part of the **shared track**, each corner carries one player's **Home**, **Base**, and **Safe** lane.
- Total track cells: 18 cells per quadrant × 4 = **72 cells** — **chosen project default**, not a verified canonical fact. The research report does not establish one universal Jackaroo board topology. `JKBoardGraph` is built to be configurable so we can change this without touching layout code; lock the number with the visual mock.
- Each player has:
  - 4 Home pockets (off-track, side of their corner).
  - 1 Base cell (their starting cell on the track).
  - 4 Safe cells (lane jutting toward the center).

### Drawing
- Board surface = `felt` disk with `feltEdge` ring. Center medallion = the **Card Pile + Fire Pile**, side-by-side.
- Track cells = small `glass`-filled rounded squares, ~22×22 pt, ring color `feltEdge`. Cell hovered/legal-target = ring color = team accent.
- **Base cell** for each player is colored by their team accent at 18% opacity, with a thicker brass border.
- **Safe cells** = brass-ringed (`amber`) with team-tinted interior. Inner ring grows from 0 → 4 filled as marbles enter.
- **Home pockets** = darker felt depressions (`feltDepth`) with the team color marbles resting inside.

### Marbles
- 26 pt circles with 2-color radial gradient (light center → team accent edge) for a glossy peg look. Same gradient engine as `AvatarView`.
- Outline 1.5 pt `*Deep` color of the team.
- Owner-of-current-turn marble glows with a 6 pt `amber` halo. Tap target = 44 pt invisible hit area.

### Center
- Two stacked card decks side by side: **Card Pile** (face-down, brass back like Poker `cardBack`) and **Fire Pile** (face-up, last discarded card visible). Both share Poker's `CardView` atom.
- Above center: a small **turn pill** = `glass` pill with avatar + name + "→ play a card". Mirrors `PotPillView` style.

### Coordinate system on screen
- Render board at `min(safeWidth, safeHeight) - 48` pt square.
- All cells are positioned using polar coords derived from `JKBoardGraph`. Layout is purely view-side; the engine knows nothing about pixels.

---

## 4. Card / hand UI

### Hand strip
- Bottom-anchored horizontal strip showing the **active human seat's** hand (1–5 cards).
- Reuse Poker's `CardView` atom directly — `Card.swift` already defines `Suit`/`Rank` and the suit pictograms in `PokerDesign.SuitView`.
- Resting card: 56 × 80 pt. Selected card: lifts 12 pt + grows 1.06× + shadow `Md`.
- Non-selected cards fade to 0.92 alpha when one is selected.

### Card selection flow
1. Tap a card → it lifts. Legal targets light up (board ring = `amber`).
2. Tap a legal target → move resolves with animation.
3. Tap selected card again → deselects.
4. If the card has no legal targets, it shakes (3 pt amplitude, 0.3 s) and shows a brief inline toast: "No legal move with this card."

### Confirmation step (toggleable in settings, stretch)
For high-stakes cards (Ace, 7, Jack): require a second-tap confirmation. Default off in V1 to keep the flow snappy.

### Burn affordance
When **no card in the hand has a legal move** (the hand may be 4 or 5 cards depending on `dealCycle`), the hand strip pulses red once and shows a single CTA pill — "Burn hand" if `burnScope=wholeHand`, "Burn card" per offending card if `burnScope=singleCard`. Tapping it sends the cards face-up to the Fire Pile.

---

## 5. Turn states

| State | Visual cue |
|-------|------------|
| Waiting (others' turn) | Hand strip is empty or curtain shown. Turn pill shows the active seat. |
| My turn — pick a card | Hand strip glowing, turn pill brass-glow, card pile pulses subtly. |
| Card selected — pick a target | Board shows ring highlights on legal cells. Active card hovers. |
| Resolving move | Hand strip disabled, marble animates along path. |
| Burn | Hand pulses red, burn pill appears. |
| AI thinking | AI avatar pulses brass; small "thinking" pip animates next to it; UI stays interactive only for non-game elements. |
| Partner handoff active | Player avatar gets a brass crown chip + tooltip "Moving partner marbles". |
| Game over | All marbles freeze, winning Safe lanes pulse, summary modal slides up. |

---

## 6. Animations & interactions

Use UIKit (`UIView.animate`, `CASpringAnimation`, `UIViewPropertyAnimator`) — no SwiftUI, matching the rest of the project.

### Motion
- **Marble move**: animate along the path **step-by-step**, 120 ms per cell, ease-in-out, with a tiny bounce at the destination (spring damping 0.7). Path is taken from the engine's legal-move resolver.
- **Capture**: captured marble jumps out of its cell (scale 1.0 → 1.15) then arcs back to its Home pocket over 350 ms.
- **Swap (Jack)**: both marbles swap positions along a cross-fade arc, 400 ms.
- **Card enter Fire Pile**: card slides from hand to Fire Pile, rotating slightly, 280 ms.
- **Deal**: cards fan from center to each seat with 60 ms stagger.
- **Safe entry**: brass halo flashes around the Safe cell.
- **Game win**: confetti-like brass spark layer (CAEmitterLayer) on the winning Safe lanes for 1.5 s, then the summary modal.

### Haptics
- Card select: `UIImpactFeedbackGenerator(style: .light)`.
- Move resolves: `.medium`.
- Capture / swap: `.heavy`.
- Win: `UINotificationFeedbackGenerator(.success)`.

### Sound
- Reuse: `button_tap.mp3` for selects, `coin_flip_sound.mp3` for marble moves, `success_press.mp3` for capture, `grand_win.mp3` for game win. No new audio assets in V1.

---

## 7. Empty / error / privacy states

### Hot-seat privacy curtain
- Full-screen `MPPageBackgroundView` overlay with center serif title: "Pass to **<name>**".
- Subtitle: "When you're ready, tap to reveal your hand."
- Primary button: "Show my hand" — fades the overlay in 300 ms.
- After move resolution, curtain auto-returns within 600 ms.
- Auto-hide guard: if 8 s elapse with no card played, fade hand to 0 alpha + dim board; tap anywhere to restore.

### Empty / loading
- Cold start of the game screen: skeleton board (cells outlined, no marbles) + center label "Dealing…" for the duration of the deal animation.
- Lobby with 0 humans: Start button disabled, helper text "Add at least one player".

### Errors
- Invalid action (should never happen with proper legal-move generation, but defensive): show inline toast "That move isn't legal" anchored to the card; 1.5 s timeout.
- AI failure (engine bug): show a recoverable banner "AI couldn't move — burning hand" and pass the turn after a `burn`. Log to debug log.
- Crash recovery: V1 does not auto-resume a crashed game. If the app relaunches mid-game, return to the Jackaroo menu. (See tech spec for an optional autosave hook.)

---

## 8. Components to add (new) vs. reuse

### Reuse (no changes)
- `MPTheme`, `MPFont`, `MPPageBackgroundView`.
- `MPBackPill`, `MPGearPill`, `MPTitleView`, `MPPrimaryButton`, `MPSecondaryButton`, `MPCoinsPill` (re-purposed as info pill).
- `AvatarView`, `ChipView`, `BetPillView`, `PotPillView` (the last as a model for the turn pill).
- `CardView`, `SuitView` (from `PokerDesign.swift` — internally reference `PokerTheme`; reused as-is).
- `Card.swift` `Suit`/`Rank` model.

### Reuse with light extensions
- `PokerTheme` — referenced through the reused atoms (`CardView`, `ChipView`, `PotPillView`, etc.). Do not duplicate values into a new theme file.
- `MPTheme` — if we need brighter coral/forest shades for seat 2 + 3, add them as `coralLight` / `forestLight` directly to MPTheme (single-line additions) rather than forking.

### New (Jackaroo-only, kept in `Jackaroo/UI/Components/`)
- `JKMarbleView` — gradient circle peg.
- `JKBoardView` — draws cells + zones from a `JKBoardGraph` + layout function.
- `JKHandStripView` — the bottom card hand.
- `JKTurnPillView` — avatar + name + status, sized like `PotPillView`.
- `JKHandoffOverlay` — privacy curtain.
- `JKCelebrationLayer` — emitter-based win flourish.

Everything else (buttons, theme, page background, card atoms) is reused.

---

## 9. Open design decisions

1. **Board size**: 72 cells assumed. Confirm — Jackaroo World boards vary 60–80. Engine is configurable; the visual mock should be locked to one number.
2. **Marble peg style**: matte plastic peg vs. shiny glass orb. I default to glossy (matches the casino feel). Confirm.
3. **Light vs. dark default**: follow system (no override). Confirm.
4. **Curtain copy tone**: "Pass to Mayank" (casual) vs. "Mayank's turn" (formal). I default to casual.
5. **Should hot-seat lobby allow seat re-ordering** (drag to assign seats)? Default plan: pick seat by tapping into a slot.
6. **Should the Fire Pile show the last 3 cards stacked** like Poker community cards, or just one? Default: 3-card peek stack.
