# Jackaroo — Technical Spec

Last updated: 2026-05-21
Pairs with `JACKAROO_SPEC.md` (rules) + `JACKAROO_DESIGN.md` (UI). Defines the data, engine, and code organization. Conventions follow the existing Poker module (`Poker /Game Engine`, `Poker /Models`, `Poker /UI`).

---

## 1. Code layout

Mirror the Poker module under a new top-level folder so it's discoverable and so future multiplayer work can slot in next to it.

```
Tokiyo Casino/
  Jackaroo/
    Game Engine/
      JackarooEngine.swift          // top-level coordinator (analog of GameManager)
      JackarooEngineActions.swift   // play card, burn, advance turn
      JackarooEngineDeal.swift      // shuffle + deal + reshuffle
      JackarooEngineDebug.swift     // logs, replay
      JackarooTypes.swift           // enums (JKPhase, JKTeam, JKDirection)
      JKLegalMoveGenerator.swift    // pure function — (state, hand) -> [JKMove]
      JKMoveResolver.swift          // apply a JKMove to state (mutating)
      JKBoardGraph.swift            // node graph + topology helpers
      JKAIEngine.swift              // heuristic move picker (renamed to avoid Poker's AIEngine)
    Models/
      JKCard.swift                  // Codable card type for Jackaroo (see §2)
      JKMarble.swift                // marble id, team, position
      JKPlayer.swift                // seat, name, hand, owner-of-marbles
      JKRulesPreset.swift           // toggle bag + named presets
      JKGameState.swift             // root snapshot (Codable, renamed to avoid Poker's GameState)
      JKMove.swift                  // every legal move shape
      JKGameLog.swift               // append-only event log
    UI/
      Components/
        JKMarbleView.swift
        JKBoardView.swift
        JKHandStripView.swift
        JKTurnPillView.swift
        JKHandoffOverlay.swift
        JKCelebrationLayer.swift
      View/
        JKBoardLayout.swift         // pixel layout from BoardGraph
      ViewControllers/
        JackarooMenuViewController.swift
        JackarooLobbyViewController.swift
        JackarooGameViewController.swift
        JackarooRulesViewController.swift
        JackarooGameSummaryViewController.swift
    Resources/
      Assets.xcassets               // (only if we add Jackaroo-specific art)
```

Notes:
- The Poker module defines `Suit`, `Rank`, and `Card` but **none of them are `Codable`** (`Card: Equatable, Hashable`; `Suit: String, CaseIterable`; `Rank: Int, CaseIterable, Comparable`). Since Jackaroo needs `Codable` for replay / autosave, we define a dedicated `JKCard` struct in `JKCard.swift` that mirrors the same suit/rank pair and declares `Codable, Hashable, Equatable`. It interoperates with the Poker `Card` via init/extension boundary helpers so the visual `CardView` atom (which takes a `Card`) keeps working. Do **not** typealias.
- All `JK*` engine types must be top-level in the Jackaroo files to avoid colliding with the existing Poker types (`AIEngine`, `GameState`, `Position`) that live in the same app target.
- All engine files stay framework-free (no `UIKit` imports) so they're unit-testable and headless.

---

## 2. Data models

### Identifiers
- `SeatID = Int` (0–3). Seat 0 + 2 = Team A, seat 1 + 3 = Team B.
- `MarbleID = Int` (0–15). Marbles 0–3 belong to seat 0, 4–7 to seat 1, etc. The owner is `id / 4`.
- `CellID = Int` — index into the `JKBoardGraph` adjacency table.

### `JKCard`
```swift
struct JKCard: Codable, Hashable, Equatable {
    let suit: JKSuit
    let rank: JKRank
}

enum JKSuit: String, Codable, CaseIterable { case hearts, diamonds, clubs, spades }
enum JKRank: Int, Codable, CaseIterable, Comparable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack = 11, queen, king, ace
    static func < (l: Self, r: Self) -> Bool { l.rawValue < r.rawValue }
}

// Bridge to the Poker `Card`/`Suit`/`Rank` so existing CardView/SuitView atoms keep working.
extension JKSuit {
    var asPokerSuit: Suit {
        switch self {
        case .hearts:   return .hearts
        case .diamonds: return .diamonds
        case .clubs:    return .clubs
        case .spades:   return .spades
        }
    }
}

extension JKRank {
    var asPokerRank: Rank { Rank(rawValue: self.rawValue)! }   // 2…14 line up 1:1
}

extension JKCard {
    var asPokerCard: Card { Card(suit: suit.asPokerSuit, rank: rank.asPokerRank) }
}
```

We don't typealias Poker's `Card` because it isn't `Codable` (see §1 notes) and we need replay/autosave.

### `JKMarble`
```swift
struct JKMarble: Codable, Hashable {
    let id: MarbleID
    let owner: SeatID
    var position: JKPosition
}

/// A marble is always either in its owner's home pocket, on a specific
/// board cell, or in its owner's safe lane. There is no separate `.base`
/// case — a marble "on Base" is simply on the track cell whose
/// `JKCellKind` is `.base(owner:)`. That way an opponent occupying your
/// Base cell is representable (`position == .track(theirBaseCell)`).
enum JKPosition: Codable, Hashable {
    case home(slot: Int)        // 0...3, off-track
    case track(CellID)          // any cell on the loop (including Base, safeGate)
    case safe(lane: Int)        // 0...3, owner's safe lane
}
```

### `JKPlayer`
```swift
struct JKPlayer: Codable, Hashable {
    let seat: SeatID
    let team: JKTeam            // .a / .b
    let name: String
    let kind: Kind              // .human / .ai(personality)
    var hand: [JKCard]
    enum Kind: Codable, Hashable {
        case human
        case ai(personality: JKPersonality)
    }
}
```

`JKPersonality` is a Jackaroo-local enum (separate file) so the module doesn't depend on Poker's `AIPersonality`. Mirrors the Poker shape (`tightAggressive`, `loosePassive`, `balanced`, `bluffer`) so the lobby's avatar logic can be parameterized over either enum.

### `JKGameState`
```swift
struct JKGameState: Codable {
    var players: [JKPlayer]            // 4
    var marbles: [JKMarble]            // 16
    var deck: [JKCard]                 // draw pile (top = last)
    var firePile: [JKCard]             // discard
    var dealer: SeatID
    var currentSeat: SeatID
    var phase: JKPhase                 // .dealing / .playing / .finished
    var direction: JKDirection         // .cw / .ccw (preset-controlled)
    var handsPlayedThisDeal: Int       // for dealCycle scheduling
    var rules: JKRulesPreset
    var seed: UInt64                   // deterministic shuffle
    var rng: JKSeededRNG               // exposed so red-queen discard etc. stay deterministic
    var log: [JKGameLog.Event]
    var winner: JKTeam?
}
```

`JKSeededRNG` is a small `RandomNumberGenerator` (e.g., SplitMix64) seeded from `seed`. It's serialized as its current state in Codable form so replay reproduces every random decision.

### `JKRulesPreset`
A bag of toggles per `JACKAROO_SPEC.md` §4, all `Codable`. Provide static factory methods:
```swift
extension JKRulesPreset {
    static let jawakerBasic: JKRulesPreset
    static let jawakerComplex: JKRulesPreset
    static let community: JKRulesPreset
}
```

### `JKMove`
A single discriminated enum covers every possible move. Tuples don't get synthesized `Codable` / `Hashable` inside enum associated values, so we use a struct for 7-split allocations.

```swift
struct JKSplitAllocation: Codable, Hashable {
    let marble: MarbleID
    let steps: Int          // > 0
}

enum JKMove: Codable, Hashable {
    case fieldFromHome(card: JKCard, marble: MarbleID)
    case forward(card: JKCard, marble: MarbleID, steps: Int)
    case backward(card: JKCard, marble: MarbleID, steps: Int)
    case split7(card: JKCard, allocations: [JKSplitAllocation])           // 2 entries in twoOwn, up to 4 in multiOwn
    case swap(card: JKCard, ownMarble: MarbleID, otherMarble: MarbleID)
    case anyMarble5(card: JKCard, marble: MarbleID, steps: Int)
    /// Red queen forces a victim to discard. The acting player chooses
    /// `victim`; the resolver picks the discarded card at apply time
    /// (using `state.rng`) and logs the choice via
    /// `JKGameLog.redQueenResolved`. The move itself carries no hidden
    /// information so candidate-move enumeration stays pure.
    case redQueenDiscard(card: JKCard, victim: SeatID)
    case burnHand(cards: [JKCard])                                         // burnScope=wholeHand
    case burnCard(card: JKCard)                                            // burnScope=singleCard
}
```

Each `JKMove` carries the **card(s)** so the resolver moves them to Fire Pile in one place.

### `JKGameLog.Event`
```swift
enum Event: Codable {
    case dealStart(dealer: SeatID, cardsPerSeat: Int)
    case played(seat: SeatID, move: JKMove)
    case marbleMoved(MarbleID, from: JKPosition, to: JKPosition, via: [CellID])
    case captured(MarbleID, by: SeatID)
    case swapped(MarbleID, MarbleID, by: SeatID)
    case redQueenResolved(victim: SeatID, discardedCard: JKCard)
    case handoffEngaged(seat: SeatID)
    case burned(seat: SeatID, cards: [JKCard])
    case reshuffled
    case gameOver(winner: JKTeam)
}
```

The log is append-only and complete enough to **replay** the entire game from `seed + log`.

---

## 3. Engine architecture

### Layering
1. `JKBoardGraph` — pure data, no mutation.
2. `JKLegalMoveGenerator` — pure function `(JKGameState, SeatID) -> [JKMove]`.
3. `JKMoveResolver` — `apply(_ move: JKMove, to: inout JKGameState)`, plus path computation for animation.
4. `JackarooEngine` — owns `JKGameState`, wires up turn order, victory checks, AI calls, delegate callbacks to UI.
5. `JKAIEngine` — `chooseMove(_ state: JKGameState, for seat: SeatID, moves: [JKMove]) -> JKMove`.
6. `JackarooEngineDelegate` — UI callbacks identical in shape to `GameManagerDelegate`:
   ```swift
   protocol JackarooEngineDelegate: AnyObject {
       func didDeal()
       func didChangeTurn(_ seat: SeatID)
       func willResolve(_ move: JKMove, path: [CellID])
       func didResolve(_ move: JKMove)
       func didCapture(_ marble: MarbleID, by seat: SeatID)
       func didEngageHandoff(_ seat: SeatID)
       func didEnd(winner: JKTeam)
   }
   ```
- UI consumes the delegate to drive animations. It **never** mutates `JKGameState`.
- Engine is single-threaded and synchronous; AI move selection can be dispatched to a background queue if it grows expensive, but V1 heuristic AI is sub-ms.

### Turn loop pseudocode
```swift
func playMove(_ move: JKMove) {
    let path = JKMoveResolver.path(for: move, in: state)
    delegate?.willResolve(move, path: path)
    JKMoveResolver.apply(move, to: &state)
    delegate?.didResolve(move)
    if let winner = victoryCheck() {
        state.winner = winner
        delegate?.didEnd(winner: winner)
        return
    }
    advanceTurn()
}
```

`advanceTurn()`:
- Rotate `currentSeat` by 1 in `state.direction`.
- If the new seat's hand is empty and all hands are empty → re-deal per `dealCycle`.
- If the new seat is AI → ask AI for a move asynchronously (≥600 ms delay for pacing).

---

## 4. Legal move generation

This is the heart of the engine and the most-tested piece.

### Algorithm
```
moves = []
for card in player.hand.unique():
    for marble in player.ownableMarbles(state):     // own + partner's if handoff engaged
        moves += movesForCard(card, marble, state)
    if card.isJack:
        moves += jackSwaps(card, state)
    if card.isQueenRed && rules.queenMode == .blackTwelveRedDiscard:
        moves += redQueenDiscards(card, state)
if moves.isEmpty && rules.burnOnNoMove:
    switch rules.burnScope:
        case .wholeHand:
            moves = [.burnHand(cards: player.hand)]
        case .singleCard:
            // One burnCard move per card so the UI can highlight each
            // dead card individually; player picks which to burn.
            moves = player.hand.unique().map { .burnCard(card: $0) }
return moves
```

### `movesForCard` per card kind

For every card type below, "ownable marble" means a marble the current player is allowed to move (own marbles, plus partner marbles if `partnerHandoff` is engaged). Each card type enumerates over all eligible marble positions — **including marbles already inside Safe**, which can still be advanced deeper into the lane until they reach lane index 3.

- **Ace**: emit `fieldFromHome` for each in-Home marble (if Base cell is unoccupied by own marble or only by an opponent that can be captured). Emit `forward(1)` and `forward(11)` per ownable marble that is either on-track or in Safe (Safe advance only legal when `position.laneIndex + steps ≤ 3`; the `1` variant is the only Ace step legal inside Safe).
- **2,3,5,6,8,9,10**: `forward(faceValue)` per ownable on-track marble, plus per ownable in-Safe marble where `laneIndex + faceValue ≤ 3`. `5` additionally emits any-marble moves if `rules.fiveMode == .anyMarbleOnTrack`.
- **4**: `backward(4)` per ownable on-track marble. Marbles inside Safe cannot move backward.
- **7** in `sevenMode=twoOwn` (default): enumerate every partition `(a, 7−a)` with `1 ≤ a ≤ 6` across every pair of **distinct** ownable marbles. Reject any partition whose sub-paths fail validation. Single-marble allocation (`a=7, b=0`) is **not** legal in `twoOwn` (per `JACKAROO_SPEC.md` §7 ec 3).
- **7** in `sevenMode=multiOwn`: enumerate every partition over 1 to 4 distinct ownable marbles (sum = 7, each entry's steps ≥ 1). Cap branching at 4 marbles.
- **Jack**: `swap` for each pair (own on-track marble × opponent on-track marble). Treat partner-handoff state: if engaged, "own" includes partner marbles. Marbles inside Safe / Home / Base are never swap-targets.
- **Queen**: `forward(12)`. If `queenMode == .blackTwelveRedDiscard` and the card is a red Queen, additionally emit one `redQueenDiscard(card:, victim:)` per opponent seat. The generator does **not** pick which card the victim loses — that would either break generator purity (drawing from `state.rng`) or leak the victim's hand into the candidate-move list before commit. The resolver decides at apply time by drawing uniformly from the victim's current hand using `state.rng`, mutates state, and writes the chosen card into a `JKGameLog.redQueenResolved(victim:, discardedCard:)` event so replay is deterministic from `seed + log`.
- **King**: `fieldFromHome` per Home marble. If `kingMode == .fieldOrThirteenCapture`, also emit `forward(13)` per ownable on-track marble (capture-along-path semantics).

### Path validation (used inside every `forward`/`backward`)
```
walk N cells along direction starting at marble.position:
    step by step:
        let next = boardGraph.next(from: current, direction: state.direction)
        if cell is occupied:
            if it's own Base → block (protected base)
            if it's a 2-marble blockade → block
            if rules.cannotPassOwn && occupant.owner == mover.owner && not landing → block
        current = next
final cell:
    if landing on own marble → block
    if landing on opponent → mark as capture (unless protected/blockade)
return path or nil
```

The same walker handles Safe-entry. Mechanics:
- The card value `v` must be fully consumed: `v = stepsToGate + stepsInsideSafe` where `stepsToGate ≥ 0` is the track distance from the marble's current cell to its owner's Safe gate, walking in `state.direction`.
- `stepsInsideSafe` must land on an empty Safe-lane cell (no jumping inside Safe; final lane index ≤ 3).
- For a marble already in Safe at lane index `i`, `stepsToGate = 0` and we require `i + v ≤ 3` with every intermediate Safe cell empty.
- `safeEntryMode = cardValueAtMostRemaining` (default) is just the above with no extra constraint.
- `safeEntryMode = exactOnly` additionally requires `stepsInsideSafe` to land on the **deepest currently empty** Safe cell (forcing exact placement).
- `safeEntryMode = overflowAroundTrack` lets a marble that would overshoot Safe instead continue around the main track for the leftover steps (no Safe entry that turn).
- Marbles can be moved past their own Safe gate without entering (the player can decline Safe entry and stay on the track) — but only if the resulting on-track destination is itself legal.

---

## 5. Board graph approach

Model the board as a **directed graph of typed nodes**.

```swift
enum JKCellKind: Codable {
    case track                    // ordinary path cell
    case base(owner: SeatID)      // player's protected start cell (still a track cell, just tagged)
    case safeGate(owner: SeatID)  // last track cell before the Safe lane
    case safe(owner: SeatID, lane: Int)
    case home(owner: SeatID, slot: Int)
}

struct JKBoardGraph: Codable {
    let cells: [JKCellKind]               // indexed by CellID
    let trackOrder: [CellID]              // canonical clockwise order around the loop
    let baseCell: [SeatID: CellID]
    let safeGate: [SeatID: CellID]
    let safeLane: [SeatID: [CellID]]      // 4 cells, in order from gate
    let homePockets: [SeatID: [CellID]]   // 4 cells (off-track)

    func next(from cell: CellID, direction: JKDirection) -> CellID?
    func step(from cell: CellID, steps: Int, direction: JKDirection) -> [CellID]
}
```

- The default 100-cell loop is built procedurally at engine init time. It's pure data; no UI knowledge. (Cell count is a Kerdany-style project default per `JACKAROO_DESIGN.md` §3, not a canonical verified topology — keep the constructor parameterized.)
- Reverse moves use the same `step()` with `direction = .ccw`.
- Safe entry: the gate cell knows its owner; the walker checks `mover.owner == cell.owner.safeGate` and the remaining-steps-fit rule per `safeEntryMode`.
- "On Base" is the predicate `state.marbles.contains { $0.position == .track(graph.baseCell[seat]!) }` — Base is **not** a separate `JKPosition` case. This lets the engine represent an opponent sitting on your Base cell as a normal `track(CellID)` occupation.

Layout (pixels) lives in `JKBoardLayout.swift` and consumes the graph to position cells around the felt disk. Engine stays headless.

---

## 6. AI approach

V1: heuristic-only, no search.

```swift
func chooseMove(_ state: JKGameState, for seat: SeatID, moves: [JKMove]) -> JKMove {
    return moves
        .map { ($0, score($0, for: seat, in: state)) }
        .max(by: { $0.1 < $1.1 })!
        .0
}
```

### Scoring features (sum with tunable weights)
- `+progressDelta` — sum of Safe-distance reduction across all ownable marbles after the move (weighted ×3 for marbles entering Safe).
- `+captureBonus` — `+5 × (capturedMarble.distanceFromHome)`.
- `+blockadeBonus` — `+2` for creating a blockade at a chokepoint (Base cell, Safe gate).
- `-threatPenalty` — for each marble landing within 6 cells in front of an opponent on-track marble, subtract `(6 − distance) × 2`.
- `-handFlexibilityPenalty` — Jack/King/Ace usage costs `−1` if alternatives exist; spending a 2/3/4 costs `0`.
- `+partnerSupport` — `+1` per partner marble advanced.
- `-burnPenalty` — burning hand scores `−50`. AI burns only if it's the only option.

### Personalities (stretch, Phase 4)
Define a Jackaroo-local `JKPersonality` enum mirroring the Poker shape (`tightAggressive`, `loosePassive`, `balanced`, `bluffer`) so the two engines stay independent. For Jackaroo:
- `tightAggressive` — high `captureBonus`, high `blockadeBonus`.
- `loosePassive` — high `progressDelta`, low `captureBonus`.
- `balanced` — defaults.
- `bluffer` — random 10% chance to pick the 2nd-best move.

### Imperfect information
V1 does **not** sample opponents' hands. Treat opponent hands as unknown. (Future work: information-set MCTS.)

---

## 7. Persistence, replay, debug

### V1 persistence
- **No** durable persistence by default. Each session is in-memory.
- On `applicationWillResignActive`, optionally write `JKGameState` (Codable) + `JKBoardGraph` to a single JSON file in `Documents/jackaroo_autosave.json`. On launch, if file exists and is < 24 h old, offer "Resume game" on the menu. This is a Phase 6 polish item.

### Replay
- Every move is logged. `JackarooEngineDebug.swift` exposes:
  ```swift
  func replay(seed: UInt64, log: [JKGameLog.Event]) -> JKGameState
  func exportTranscript() -> String   // human-readable
  func importTranscript(_ s: String)
  ```
- Replay is deterministic given the seed.

### Debug surfaces (developer-only, gated by `#if DEBUG`)
- "Debug" tab in the game's gear menu: show seat hands, legal moves count per card, raw log, board graph diagnostic.
- Long-press the deck to dump `JKGameState` JSON to the clipboard.
- Optional **God mode** toggle that picks moves for any seat (helpful for QA).

### Logging
- Use existing project logger style (mostly `print` calls in `GameManagerDebug.swift`). Don't pull in a logging dependency.

---

## 8. Testing strategy

### Unit tests — `Tokiyo CasinoTests/JackarooTests/`
Organized to match the engine layers.

| Suite | Coverage |
|-------|----------|
| `JKBoardGraphTests` | Cell counts, neighbor symmetry, safe-gate ownership, clockwise/ccw step math, base-cell positions. |
| `JKMoveResolverTests` | Each card type's effect on state, capture, swap, safe entry, blockade. |
| `JKLegalMoveGeneratorTests` | Every card produces correct move set in canonical fixtures; edge cases from `JACKAROO_SPEC.md` §7 each have a named test. |
| `PartnerHandoffTests` | Handoff engages exactly when 4th marble enters Safe; mid-7-split handoff stays with same player. |
| `BurnTests` | Burn fires only when no card has any legal move. Partial-legal hands never burn. Whole-hand vs single-card scope honored per `burnScope`. |
| `JKRulesPresetTests` | Each preset's toggle bag matches the spec; King-13 capture only when toggle on; 5-any only when toggle on; CCW direction in community. |
| `JKAIEngineTests` | Picks capture over progress when weights say so; never picks burn if any alternative exists; deterministic with seeded score ties. |
| `ReplayTests` | Replaying a transcript reproduces final `JKGameState` exactly. |

Target: 100% coverage on `JKLegalMoveGenerator`, `JKMoveResolver`, `JKBoardGraph`. Coverage on AI is best-effort.

### Property tests
- Random seed × random legal-only play for 1000 hands: assert state invariants every move:
  - Exactly 16 marbles always.
  - No marble in two places.
  - Card count is constant (deck + fire + hands).
  - No game state has > 8 own marbles for any team.
  - Game terminates (either victory or no-legal-moves-anywhere within a turn cap).

### UI tests (lightweight)
- Snapshot test of `JackarooGameViewController` in 3 fixture states (deal, mid-game with blockade, end-game).
- Hot-seat curtain shows/hides on turn change.

### Manual QA checklist (Phase 6)
- Light + dark mode.
- iPhone SE (small) and iPhone 15 Pro Max (large) — board scales without overlap.
- VoiceOver labels on cards and marbles.
- Background → foreground mid-turn.

---

## 9. Performance notes

- 4 players × ~6 ownable marbles × ~5 cards in hand = ~120 candidate moves per turn worst case. Each path-walk is ≤100 steps. Cost is trivially fast on iPhone.
- Animations are the bottleneck. Step-by-step marble movement at 120 ms/cell can take ~1.5 s for a 13-King. Allow user to set "Animation speed" 1× / 1.5× / 2× in settings (Phase 6).

---

## 10. Open technical decisions

1. **Card type**: `JKCard` is its own `Codable` struct (Poker's `Card` is not `Codable`); UI atoms convert at the boundary. Confirm — alternative is to add `Codable` conformance directly to the Poker `Card` via extension and typealias. The standalone `JKCard` was chosen to keep modules decoupled.
2. **Where does `JKRulesPreset` live**? In `Jackaroo/Models/JKRulesPreset.swift` per the plan. Confirm — it's not shared with Poker.
3. **Replay file format**: JSON `JKGameLog`. Confirm — alternative is binary `PropertyList` (smaller, but harder to diff).
4. **Autosave**: confirm whether you want it in V1 or as a Phase 6 polish item. Default plan: Phase 6.
5. **AI difficulty selector**: keep AI single-difficulty for V1, or expose Easy/Normal/Hard? Default: single.
6. **Red queen discard target**: engine resolves the victim's lost card via the seeded `JKSeededRNG` at move-generation time. Confirm — alternative is to let the victim choose their own discard (adds an out-of-turn UI step in hot-seat).
7. **Threading**: synchronous turn loop on main thread (cheap heuristic AI). Confirm — if AI evaluation grows (search), we'll need a background queue.
