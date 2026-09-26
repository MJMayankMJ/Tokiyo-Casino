# Teen Do Paanch (5‑3‑2) — Product & Rules PRD

**Status:** Phases 1-6 built and audited (2026-09-14) — see §13
**Owner:** Mayank Jangid
**Date:** 2026‑09‑09
**Codename / prefix:** `TDP`
**Sibling docs:** `JACKAROO_SPEC.md`, `JACKAROO_TECH_SPEC.md`, `OFFLINE_FRIENDS_PRD.md`

---

## 0. Naming

The game is known by the seat‑quota sequence, and different regions recite the
sequence starting from a different seat:

| Name | Recited from |
| --- | --- |
| **5‑3‑2** | trump selector → third → dealer |
| **3‑2‑5** | third → dealer → trump selector |
| **2‑3‑5** | dealer → third → trump selector |
| **Teen Do Paanch / तीन दो पाँच** | Hindi for "three two five" |

They are the same game. **In‑app we ship the title "Teen Do Paanch" with the
subtitle "5‑3‑2"**, matching the way the user asked for it while remaining
searchable for the more common spellings. All code uses the `TDP` prefix.

---

## 1. Research summary

### 1.1 Sources consulted

| Source | Weight | Notes |
| --- | --- | --- |
| [pagat.com — 3‑2‑5](https://www.pagat.com/quotawhist/3-2-5.html) | **Authoritative** | John McLeod's card‑game archive. Most precise on the card‑pull procedure and its two restrictions. |
| [games.porg.es — Teen Do Pānch](https://games.porg.es/games/teen-do-panch/) | Corroborating | Concise ruleset; confirms deck, packets, quotas, pull mechanic. |
| [anujdecoder/teen-do-paanch](https://github.com/anujdecoder/teen-do-paanch) | **Reference implementation** | TS engine + AI + P2P net. `docs/GAMEPLAY.md` is a complete, implementation‑grade ruleset. See §1.3. |
| [catsatcards.com](https://www.catsatcards.com/Games/ThreeTwoFive.html), [blitzpoker.com](https://www.blitzpoker.com/blogs/3-2-5-card-game/), Play Store "3 2 5 card game" | Sanity checks | Confirm quotas, deck size, general shape. |

### 1.2 Existing implementations — survey

A GitHub sweep across `3-2-5 card game`, `teen do paanch`, `teendopanch`,
`2-3-5` returned ~10 repositories. All are hobby projects at 0–1 stars:

| Repo | Lang | License | Verdict |
| --- | --- | --- | --- |
| `anujdecoder/teen-do-paanch` | TypeScript / React | **none** | Best by a wide margin. Engine split into `deck / roles / legalMoves / scoring / khichai / reducer / ai`, plus `net/protocol.ts`, unit tests, and a written ruleset. |
| `gnsharma/teen-do-paanch` | TypeScript / React | **none** | UI‑heavy (shadcn); phase components confirm the same phase model (`TrumpSelection → Dealing → Playing → CardPull → Redistribution`). Thin engine. |
| `hiralgabhane/3-2-5-card-game` | Python / Flask | **none** | Venv committed; little reusable logic. |
| `amulyahwr/3_2_5_CardGame` | Java | **none** | 2018 term project, 4 source files. |
| `saquibrazak/teendopanch` | C++ | **none** | University assignment scaffold (Euchre‑derived). |
| `suket123/2-3-5-Card-Game` | Python | **none** | 3 files. |
| `nverdhan/tdpAppCordova` | Cordova | **none** | 2015, abandoned. |

### 1.3 Position on reuse

**We do not copy code.** Every candidate repo lacks a `LICENSE`, which under
default copyright means all rights reserved — vendoring any of it into a
shipping App Store binary is not an option. They are also all
TypeScript/Python/Java/C++, so nothing would port to UIKit + Swift without a
full rewrite regardless.

**We do reuse the rules.** Game rules and mechanics are not copyrightable
subject matter; only a particular expression of them is. `docs/GAMEPLAY.md` in
the reference repo is a prose ruleset, and its rule‑bearing modules resolve
edge cases that every prose write‑up omits (pull ordering, khichai return
legality, role rotation direction). §2 of this document is the
canonical ruleset we derived, cross‑checked line by line against Pagat.

**If we later want the code**, the clean path is to open an issue asking the
author to add an MIT/Apache‑2.0 license. That is a request, not a blocker — the
ruleset below is sufficient to build from.

---

## 2. Canonical ruleset (v1 default)

This section is normative. The engine implements this fixed classic ruleset;
house-rule variants are not exposed in the shipped game.

### 2.1 Players

Exactly **three**. No more, no fewer, in v1.

### 2.2 Pack

30 cards, built from a standard 52‑card deck:

- Remove every **2, 3, 4, 5, 6** (20 cards).
- Remove the **7♣** and **7♦** (2 cards).
- Keep **7♥** and **7♠**.

Result: 8‑9‑10‑J‑Q‑K‑A in all four suits (28) + 7♥ + 7♠ = **30**.

**Rank, high → low:** `A K Q J 10 9 8 7`.

Spades and hearts have 8 cards; clubs and diamonds have 7. This asymmetry is
intentional and part of the game's texture — a spade/heart trump has one more
card behind it.

**Suit order** (used only for tie‑breaks in trump selection and for hand
sorting): `♠ > ♥ > ♦ > ♣`.

### 2.3 Seats, roles, quotas

Seats are `0, 1, 2`, play runs **clockwise**. With the dealer at seat `D`:

| Role | Seat | Quota | Notes |
| --- | --- | --- | --- |
| **Trump selector** | `(D + 1) % 3` — dealer's left | **5** | Chooses trump, leads first trick. Hardest quota, most control. |
| **Third** | `(D + 2) % 3` — dealer's right | **3** | |
| **Dealer** | `D` | **2** | Easiest quota, no control. |

Quotas sum to 10 = the number of tricks. **This makes the game strictly
zero‑sum: Σ(tricks) = Σ(quota) = 10, therefore Σ(delta) = 0 in every round.**
The engine asserts this invariant after every round.

> **Note on handedness.** Pagat describes the game counter‑clockwise with the
> trump selector on the dealer's *right*. That is a mirror image of the above
> and is strategically identical. We ship clockwise/dealer's‑left to match the
> reference implementation and Jackaroo's existing clockwise table layout.

**Rotation:** after each round the roles rotate one seat clockwise — the
outgoing trump selector becomes the next dealer.

### 2.4 First dealer

Each player draws one card from the shuffled pack. **Highest rank deals.** Tied
players redraw among themselves until one rank is unique. (Suit is not used as
a tie‑break here — redraw instead, so the draw feels fair.)

### 2.5 The deal

Cards are dealt face down in the order **trump selector → third → dealer**, in
three packets:

1. **5 cards** each.
2. → *Trump is chosen* (§2.6).
3. **3 cards** each.
4. **2 cards** each.

Each player ends with **10 cards**. The 5‑3‑2 packet sizes are where the game's
alternate name comes from and are the reason the trump decision is made on
partial information.

### 2.6 Trump selection

The trump selector looks at their first five cards and picks **one** of:

| Option | Mechanic | Information revealed |
| --- | --- | --- |
| **1. Name a suit** | Selector declares any of the four suits. | Everyone knows trump. Selector's hand strength is implied. |
| **2. Open the seventh card** | The **middle card of the selector's next 3‑card packet** (their 7th card overall) is turned face up. Its suit is trump. | Everyone sees one of the selector's cards. |
| **3. Highest of the next three** | After the 3‑packet is dealt, the **highest card among the selector's three** sets trump (rank first; `♠ > ♥ > ♦ > ♣` on a rank tie). | Trump suit only — the card itself stays concealed. |

Options 2 and 3 are the "I don't like my five cards" escape hatches: they trade
away control for a chance at a suit the selector is actually long in, and they
leak less about the hand than a confident naming does.

Trump is a permanent, public property of the round once resolved.

### 2.7 Play of the tricks

- The **trump selector leads the first trick**.
- The selector may lead any card, including trump.
- Play proceeds clockwise.
- **Follow suit if able.** A player holding the led suit must play it.
- If void, a player may **play a trump or discard any other suit**. A discard
  can never win the trick.
- There is **no obligation to beat** cards already played (no "must overtrump").
- **Trick winner:** the highest trump if any trump was played; otherwise the
  highest card of the led suit.
- The winner leads the next trick.
- Ten tricks complete the round.

### 2.8 Scoring

For each player, at the end of a round:

```
delta = tricks_won − quota
```

Positive for over‑quota, negative for under, zero for exact. This delta drives
the next round's khichai only; it is not the point score. Each trick won is
worth **one point**, so a player's session score is their cumulative number of
tricks. Because quotas sum to the trick count, the three deltas always sum to
zero.

### 2.9 Khichai — the card pull

*"Khichai" (खिंचाई) — literally "the pulling". This is the mechanic that makes
5‑3‑2 what it is: last round's failure follows you into this one.*

**When:** after all ten cards of the *new* round have been dealt and trump is
set, but **before the first lead**. Never in round 1.

**Who:** based on the **previous round's deltas**. Players who finished **over**
quota (creditors) pull from players who finished **under** quota (debtors).

**How many:** one card pulled per trick over quota; one card surrendered per
trick under quota. Since deltas sum to zero, supply always equals demand.

**Pull order** (matters when more than one player is over or under):

- If **two players are over quota**: the trump selector pulls first, then the
  third player, then the dealer. This mirrors Pagat's table order for clockwise
  play.
- If **two players are under quota**: a creditor pulls first from the dealer
  (if the dealer is under), then from the third player, then the trump selector.

**The exchange, one card at a time:**

1. The debtor fans their 10 cards **face down**.
2. The creditor picks one **blind** — they do not know what it is, and the
   third player never sees it.
3. The creditor looks at it. They now hold 11 cards.
4. The creditor **returns any one card** to the debtor — including the one they
   just drew. (The UI keeps the drawn card outlined so it's clear which it was.)

> **No return restrictions (decided 2026‑09‑26).** Written rules vary: Pagat and
> CatsAtCards forbid returning the drawn card *and* require keeping two of the
> returned suit; Ways to Play and GameRules.com have no suit rule; CardzMania
> makes "Min Suit" an option (2 / 1 / off); one open-source implementation lets
> the drawn card go straight back. The game has no governing body, so this
> table plays with no restriction on the returned card.

**Result:** both players are back to 10 cards. The debtor has gained an unknown
card and lost a card the creditor chose to be rid of. Repeat for each owed card.

#### 2.9.1 Settling up — give up tricks or give cards (table rule, 2026‑09‑26)

Before any pull, each debtor chooses **per creditor**:

- **Give up the tricks.** No cards move. For **this round only** the debtor's
  target rises by the amount owed and the creditor's falls by the same amount
  (you owe Kabir 2: your 3 → 5, Kabir's 5 → 3). The three targets still sum to
  10, so deltas still cancel. Scoring is unchanged — one point per trick; the
  shifted targets only decide next round's settling.
- **Give cards** — the classic pull above.

**Not twice in a row:** a debtor may not give up tricks to the **same** creditor
in consecutive rounds; that debt must be settled in cards. Giving up tricks to a
different creditor is fine, and a round in between clears the lock.

**Arranging (when cards are given):** if the debtor *and* at least one of their
pullers are people, the debtor gets **10 seconds** (Done ends it early) to
rearrange their own face-down order; the puller then picks a position in that
order. Against a bot puller there is no window — a bot picks blind at random,
so the order can't matter. The order starts shuffled, is set **once per round**,
and each card handed back is slipped in at a **random position**. The window's
clock is host-authoritative (a deadline, not a restartable timer).

A creditor owed more than their whole target has an effective target below
zero; screens show it as 0.

### 2.10 Session length and winner

A session is **a multiple of three rounds** (default: 3, offerable as 6 or 9),
so every player deals, selects trump, and sits third an equal number of times.
At each multiple of three the host may end the session or add three more.

**Winner:** most cumulative trick points. Ties are shown as ties — no tie‑break
round in v1.

---

## 3. Rules configuration

The shipped game intentionally has one ruleset: §2. The only table setting is
session length (3, 6, 9, or another multiple of three). Permanent-trump sevens,
first-lead restrictions, loser-deals, slam bonuses, running debt, and optional
khichai are not implemented; adding any of them would require an explicit,
versioned house-rules mode.

---

## 4. Modes

Identical in shape to Poker and Jackaroo — one game, three ways to fill three seats.

| Mode | Seats | Network |
| --- | --- | --- |
| **Practice** | 1 human + 2 AI | none |
| **Pass & play** | 2–3 humans on one device (AI fills the rest) | none |
| **Friends** | 1–3 humans across devices, AI fills empty seats | MPC, host‑authoritative |

**The mix is the point.** A Friends table with two phones and one AI is a
first‑class configuration, exactly as in Poker — the host seats humans as they
join and fills the remainder with bots at start. All modes are **completely
offline**: no server, no account, no internet. Friends mode uses
MultipeerConnectivity over local Wi‑Fi/Bluetooth, the same as `OFFLINE_FRIENDS_PRD.md`.

**Coins:** none. Follows Jackaroo (`JACKAROO_SPEC.md` §5) rather than Poker —
pure score, no wallet, no gambling surface.

---

## 5. User experience

### 5.1 Entry

New tile on `HomeViewController` alongside Poker and Jackaroo →
`TeenDoPaanchEntryViewController` (mirrors `JackarooEntryViewController`):

```
  TEEN DO PAANCH
      5‑3‑2

  [ Practice        ]   1 human vs 2 AI
  [ Pass & Play     ]   share this device
  [ Play with Friends ] nearby devices
  [ How to play     ]
```

### 5.2 Table layout

Three seats: **you at the bottom**, opponents top‑left and top‑right. Each seat
shows name, role badge, and a live **quota pill**.

The quota pill is the core HUD element and must be readable at a glance:

```
   ┌──────────┐
   │  3 / 5   │   tricks won / quota
   │  ▲ +0    │   projected delta
   └──────────┘
```

- **Amber** while below quota, **green** at or above, with the delta signed.
- The trump suit sits in a persistent badge at table centre; if trump came from
  an opened seventh card, that card is shown face up beside it for the round.
- Tricks won are stacked face down beside each seat — countable at a glance.

### 5.3 Round flow (screens)

1. **Deal 5** — cards fly out in packets, selector → third → dealer.
2. **Trump prompt** *(selector only; others see "Waiting for <name>")* — a
   sheet with the three options. Naming a suit shows four large suit buttons.
3. **Deal 3, deal 2** — remaining packets, with the seventh card flipped if
   option 2 was taken.
4. **Khichai** *(rounds 2+, if anyone missed quota)* — see §5.4.
5. **Play** — ten tricks. Legal cards are full opacity; illegal cards dim to
   40% and cannot be lifted. On an illegal tap, the reason appears as a toast
   (for example, "You must follow hearts").
6. **Round result** — a delta banner per seat, running totals, and
   `Next round` / `End session` (the latter only at a multiple of three).

### 5.4 The khichai screen

This is the moment the game is remembered for, so it gets a dedicated,
deliberately theatrical screen.

**As creditor (pulling):** the debtor's ten cards fan out face down and
slightly separated. You tap one. It flips toward you with a lift animation —
**only you see it**. Your hand is then shown with the new card highlighted, and
every card you may legally return is enabled; nothing is blocked; the pulled card stays outlined
with the reason on long‑press ("You'd be left with only one spade").

**As debtor (being pulled from):** you see your own fan face **up** (it's your
hand) with a scrim, and a "…pulling" indicator on the creditor's seat. You are
**not** told which card was taken until it leaves your hand, and you are never
told what the creditor considered returning. The returned card lands in your
hand with a highlight.

**As the third player:** you see a neutral animation between the two seats —
one card each way, both face down. You learn *that* a swap happened and between
whom, never *what*.

### 5.5 Pass & play privacy

Reuses `JKHandoffOverlay` verbatim: a full‑screen "Pass to <name>" curtain
between turns, tap‑and‑hold to reveal. Khichai on one device shows the fan face
down to the creditor and never renders the debtor's faces.

### 5.6 Friends lobby

Reuses the Poker lobby chrome (`MultiplayerDesign`, host/join VCs) with three
fixed seats and no blind/chip settings. Host controls session length, AI
difficulty for filled seats, and start.

---

## 6. Engine architecture

Mirrors the Jackaroo layering (`JACKAROO_TECH_SPEC.md` §3): a pure, testable,
`Codable` engine with zero UIKit imports, wrapped by view controllers.

```
Tokiyo Casino/TeenDoPaanch/
├── Models/
│   ├── TDPCard.swift            30-card pack, rank/suit, ordering
│   ├── TDPPlayer.swift          seat, hand, tricksWon, score, kind
│   ├── TDPGameState.swift       root Codable snapshot
│   ├── TDPRound.swift           trump, tricks, deltas
│   ├── TDPGameLog.swift         event stream for replay/debug
│   └── TDPSeededRNG.swift       reuse JKSeededRNG shape
├── Game Engine/
│   ├── TeenDoPaanchEngine.swift   phase machine, public API
│   ├── TDPDealer.swift            pack build, shuffle, 5-3-2 packets
│   ├── TDPTrumpSelection.swift    the three options
│   ├── TDPLegalMoves.swift        follow-suit + trick resolution
│   ├── TDPTrickResolver.swift     winner determination
│   ├── TDPScoring.swift           deltas, debts, session end
│   ├── TDPKhichai.swift           pull order, blind draw, return
│   ├── TDPAIEngine.swift          see §7
│   ├── TDPAutosave.swift          resume-in-progress
│   └── TDPAudio.swift
├── Multiplayer/                  see §8
└── UI/
    ├── Components/   TDPCardView, TDPQuotaPill, TDPTrickPile,
    │                 TDPTrumpBadge, TDPKhichaiFanView, TDPHandStrip
    ├── View/         TDPTableView (+Layout, +Updates)
    └── ViewControllers/  Entry, Menu, Game, Rules, Lobby, Summary
```

### 6.1 Phase machine

```
                    ┌─────────────┐
     new session ──▶ │ firstDealer │  (draw for deal, once)
                    └──────┬──────┘
                           ▼
                    ┌─────────────┐
        ┌─────────▶ │  dealFive   │
        │           └──────┬──────┘
        │                  ▼
        │           ┌─────────────┐
        │           │ trumpChoice │ ◀── selector acts
        │           └──────┬──────┘
        │                  ▼
        │           ┌─────────────┐
        │           │ dealThreeTwo│  (+ reveal 7th if option 2)
        │           └──────┬──────┘
        │                  ▼
        │           ┌─────────────┐
        │           │   khichai   │  (skipped round 1 / no debts)
        │           └──────┬──────┘
        │                  ▼
        │           ┌─────────────┐
        │           │    play     │  10 tricks
        │           └──────┬──────┘
        │                  ▼
        │           ┌─────────────┐
        └───────────┤ roundResult │
      more rounds   └──────┬──────┘
                           ▼ session complete
                    ┌─────────────┐
                    │  finished   │
                    └─────────────┘
```

### 6.2 Core state

```swift
public struct TDPGameState: Codable {
    public var players: [TDPPlayer]        // exactly 3
    public var dealerSeat: TDPSeat?
    public var phase: TDPPhase
    public var trump: Suit?
    public var trumpMethod: TDPTrumpMethod?
    public var currentTurnSeat: TDPSeat?
    public var leadSuit: Suit?
    public var currentTrick: [TDPTrickPlay] // 0…3 entries
    public var trickNumber: Int            // 0…9
    public var roundNumber: Int            // 1-based
    public var scores: [String: Int]        // cumulative trick points by seat
    public var roundHistory: [TDPRoundScore]
    public var khichaiQueue: [TDPKhichaiStep]
    public var seed: UInt32
    public var rng: TDPRNG
}
```

Derived, never stored: `quota(for:)`, `role(of:)`, `legalCards(for:)`,
`projectedDelta(for:)`.

### 6.3 Determinism

Everything random flows through `TDPRNG` (shuffle, first‑dealer draw,
blind khichai draw when the creditor is AI, AI tie‑breaks). A seed replays a
whole session exactly — the basis for the replay tests and for bug reports.

---

## 7. AI

Three difficulties, matching Poker's `Difficulty.swift` tiering.

### 7.1 What the AI must decide

1. **Trump selection** — from 5 cards, pick a suit or take an escape hatch.
2. **Card play** — every trick, quota‑aware.
3. **Khichai** — which face‑down card to pull (blind, so: which *position*,
   i.e. genuinely random), and which card to return.

### 7.2 Trump selection heuristic

Score each suit over the visible 5 cards:

```
suitScore(s) = 2.0 × count(s)
             + 1.5 × (holds A of s)
             + 1.0 × (holds K of s)
             + 0.5 × (holds Q of s)
             + 0.4 × (suit length in pack: 8 for ♠/♥, 7 for ♦/♣)
             + 0.8 × (count of off-suit aces)          // side entries
```

Compare `max(suitScore)` against a quota‑scaled threshold — the selector needs
5 tricks, so the bar is high. Below threshold, prefer **highest‑of‑three**
(cheapest information leak) over **open the seventh** (leaks a card). Easy AI
just names its longest suit.

### 7.3 Card play

**Easy** — legal‑random with a mild "win the trick if cheap" bias.

**Medium** — rule‑based, quota‑aware:
- Track cards played, suits each opponent has shown void in, and trumps
  outstanding.
- When behind quota: take tricks when winnable at reasonable cost; lead long
  suits to draw trumps; cash side aces early.
- When at or above quota: **keep taking** — delta is unbounded upward, so
  there is no reason to duck for your own sake. Switch to *denial*: prefer
  plays that stop the opponent nearest their quota from making it.
- Never waste a high trump on a trick already lost.

**Hard** — **determinized Monte Carlo**. Sample N (≈ 120, tuned to a 400 ms
budget) full deals consistent with everything public (cards played, revealed
seventh card, known voids, khichai facts the AI is entitled to know), solve
each perfect‑information deal with a shallow alpha‑beta over remaining tricks,
and play the card with the best average delta. This is the standard,
well‑understood approach for imperfect‑information trick games and reuses the
sampling discipline already in `EquityCalculator`.

### 7.4 Khichai heuristic

- **Pulling** is blind by construction — the AI picks a uniformly random index
  via the seeded RNG. No cheating: the AI must not read the debtor's hand.
  This is enforced by passing the AI a `TDPKhichaiView` that exposes only the
  *count* of the debtor's cards.
- **Returning:** return the lowest‑value card (which may be the pulled one), where
  value weights trumps heavily, then aces/kings, then length in the suit.
  Prefer returning from the longest non‑trump suit.

### 7.5 Anti‑cheat invariant

`TDPAIEngine` receives a **redacted** state — its own hand plus the public
record — never `TDPGameState.players[*].hand` for other seats. Enforced by a
dedicated type (`TDPAIView`) rather than by convention, and covered by a test
that a determinized AI given a seeded deal cannot outperform its own
information bound.

---

## 8. Multiplayer protocol

Host‑authoritative, transport‑neutral, byte‑stable JSON — the exact model that
already works for Poker (`OFFLINE_FRIENDS_PRD.md` §3–4).

### 8.1 Transport reuse

`TDPMPCTransport` implements the small `TDPTransport` interface and keeps the
Teen Do Paanch wire contract isolated from Poker. `TDPLobbyAdvert` publishes
the table id, host name, seats joined, round count, and started state.

### 8.2 Protocol constants

```swift
enum TDPProtocol {
    static let version: Int = 2
    static let mpcServiceType = "tokiyo-tdp"   // ≤15 lowercase ASCII
    static let warnPayloadBytes  =  8 * 1024
    static let maxPayloadBytes   = 32 * 1024
    static let totalSeats = 3
    static let staleAwaySeatSeconds: TimeInterval = 5 * 60
}
```

Each envelope carries `protocolVersion`, `tableId`, `roundNumber`, `sequence`,
`senderPeerId`, `type`, and `payload`, encoded with `.sortedKeys` so fixtures
stay byte-stable for a future Android client.

### 8.3 Message types

```
Lobby     joinRequest, joinAccepted, joinRejected, lobbySnapshot,
          startGame, peerLeft
Game      clientView, intent, intentRejected, hostEndingTable
Conn      ping, pong
```

### 8.4 Hidden information over the wire — the hard part

Two secrets must never reach the wrong client. The host is the only holder of
full state; clients receive redacted snapshots.

**Hands.** Each peer receives a separately built `clientView`. It contains the
recipient's cards and only `handCount` for every other seat.

**The khichai draw.** The blind pull is the genuinely novel case, because the
creditor must learn *one* card of the debtor's hand and no more:

1. Creditor's client sends a `khichaiDraw` intent with a `fanIndex` — an index
   into a **host-shuffled** presentation order, so the index carries no
   information about which card it is.
2. The **host** resolves the index to a card. The debtor's hand never leaves
   the host.
3. The next redacted `clientView` includes the drawn card and legal return ids
   **only** for the creditor.
4. The creditor sends a `khichaiReturn` intent containing a card id.
5. **Host re‑validates the return authoritatively** (the card must be in hand) and rejects an illegal
   return rather than trusting the client, then publishes fresh redacted views.

A compromised client can therefore learn exactly one card per pull it is
entitled to, which is the game's own rule.

### 8.5 Disconnect

Before play, a disconnected guest's seat is reopened. Mid-game the table is
stopped and the seat is never handed to an AI; a quota game would be distorted
by a bot inheriting a human's result and card pulls.

---

## 9. Edge cases the v1 engine must handle

1. **Selector opens with trump** → legal; the classic rules allow any lead.
2. **Trump by highest‑of‑three ties on rank** → suit order `♠ > ♥ > ♦ > ♣`.
3. **First‑dealer draw ties** → redraw among tied players only; rebuild the
   30-card draw pack for every tie so repeated ties cannot exhaust it.
4. **Khichai with two creditors and one debtor** (deltas `+2, +1, −3`) → pull
   order per §2.9; the queue is expanded to one task per owed card and
   processed sequentially.
5. **Khichai with one creditor and two debtors** (`+3, −1, −2`) → creditor
   drains the dealer first (if under), then the third player, then the selector.
6. **A creditor pulls a card and their only legal returns are all trumps** →
   any card may go back, so a legal return always exists.
7. **Everyone hits quota exactly** → no khichai; skip the phase silently.
8. **A player wins all 10 tricks** → deltas `+5, −3, −2`; next round's
   khichai moves 5 cards.
9. **Pass‑and‑play with 2 humans + 1 AI** → handoff overlay must not appear
    when the next actor is the AI.
10. **Autosave restore mid‑khichai** → the queue and any half‑resolved task are
    part of `TDPGameState`; restore lands back on the same prompt.
11. **Session end lands exactly at a multiple of 3** → offer End/Continue;
    anywhere else, `End session` is disabled.

---

## 10. Testing

Mirrors `Tokiyo CasinoTests/JackarooTests/`, as `TeenDoPaanchTests/`.

**Unit**
- `TDPDeckTests` — 30 cards, exact composition, no duplicates, correct ranks.
- `TDPDealTests` — 5‑3‑2 packets, deal order, 10 each, pack exhausted.
- `TDPRolesTests` — quota mapping for all 3 dealer positions; rotation over 9
  rounds returns to start.
- `TDPTrumpSelectionTests` — all three options, seventh‑card index, rank+suit
  tie‑break.
- `TDPLegalMovesTests` — follow‑suit, void freedom, and any-card opening lead.
- `TDPTrickResolverTests` — highest trump wins, highest led suit otherwise,
  and discards never win.
- `TDPScoringTests` — one point per trick, delta maths, and
  **`Σ delta == 0` after every round**.
- `TDPKhichaiTests` — pull order for all six delta configurations; R1
  enforcement; the pigeonhole invariant across 10 000 random hands; card
  conservation (30 cards in play, always).

**Property**
- Random full sessions, 1 000 seeds: hand sizes always 10 before play; no card
  ever duplicated or lost across deal + khichai; deltas sum to zero; the game
  always terminates in exactly 10 tricks per round.

**Protocol**
- Golden fixtures per message type, byte‑compared (`.sortedKeys`), matching
  `ProtocolGoldenFixtures.swift`.
- **Redaction tests**: no public snapshot ever contains another seat's cards;
  `khichaiDrawResult` sent to non‑creditors carries no card.
- Host rejects an illegal `khichaiReturn` (a card not in hand).

**AI**
- Determinized AI never reads hidden state (type‑level, plus a runtime assert).
- Hard beats Medium beats Easy over 1 000 seeded sessions, with the margin
  reported.
- AI turn latency under 400 ms on an iPhone 12, Release.

**UI smoke**
- Full seeded game through `TDPGameViewController` with all‑AI seats.
- Khichai screen renders for creditor / debtor / observer without leaking faces.

---

## 11. Open decisions — need your call

1. **Session length default** — 3 rounds (one full role rotation, ~6 min) or 6?
2. **Permanent sevens** — off by default (recommended) or on? It's the most
   commonly cited house rule and materially changes card values.
3. **Coins** — confirm no coins, matching Jackaroo rather than Poker.
4. **Title** — "Teen Do Paanch" with "5‑3‑2" subtitle, or lead with "5‑3‑2"?
5. **Ask the reference repo's author for a license?** Not needed to build, but
   if they relicense we could at least port their test vectors as a
   cross‑check. Your call whether to open the issue.

---

## 12. Implementation phases

Sized to match the Jackaroo phase plan.

| Phase | Scope | Exit criteria |
| --- | --- | --- |
| **1. Models & deal** | `TDPCard`, pack, `TDPGameState`, dealer/rotation, 5‑3‑2 deal, seeded RNG | Deck + deal + roles tests green |
| **2. Core round** | Trump selection (3 options), legal moves, trick resolution, scoring, phase machine | A full 10‑trick round plays headless; `Σ delta == 0` |
| **3. Khichai** | Mandatory previous-round pull order, blind draw, return, queue | Delta configurations tested; card conservation holds |
| **4. AI** | Easy + Medium; redacted `TDPAIView`; trump + play + khichai heuristics | Full AI‑only sessions run clean; no hidden‑state access |
| **5. UI** | Table, hand strip, quota pills, trump badge, khichai screen, round/session summary, rules screen, handoff overlay | Practice + pass‑and‑play fully playable |
| **6. Multiplayer** | Transport generalization, `TDPProtocol`, host/client services, lobby, redaction, reconnect | 3 devices complete a session; golden fixtures + redaction tests green |
| **7. Hard AI & polish** | Determinized Monte Carlo, animation timing, audio, autosave/resume, variant sheet | Hard > Medium over 1 000 seeds; ≤400 ms turns in Release |

---

## 13. Build status — 2026-09-14

Implemented and audited. **34 focused Teen Do Paanch tests green**, including
1,000 seeded full-session simulations.

| Phase | Status | Notes |
| --- | --- | --- |
| 1. Models & deal | **done** | 30-card pack, 5-3-2 deal, roles, seeded RNG |
| 2. Core round | **done** | All three trump options, legal moves, tricks, one-point-per-trick scoring |
| 3. Khichai | **done** | Mandatory previous-round pull; blind draw; no return restrictions (dropped 2026‑09‑26); score unchanged. |
| 4. AI | **done** | Easy + Medium. Reads only its own hand; pulls blind |
| 5. UI | **done, unstyled** | Playable table, quota pills, khichai screen, handoff curtain, rules. Visual pass deferred |
| 6. Multiplayer | **done** | `tokiyo-tdp` over MPC, host-authoritative, redaction enforced by `TDPViewBuilder` |
| 7. Hard AI & polish | **not started** | Monte Carlo AI, autosave, variants UI, audio |

### Deviations from this document, and why

- **`TDPMPCTransport` duplicates Poker's `MPCTransport`** rather than §8.1's
  shared generalisation. Poker is shipping; a behaviour-preserving refactor of
  its transport was not worth the risk for a demo. Fold the two together when a
  third game needs it.
- **Jackaroo's home tile is temporarily replaced** by Teen Do Paanch. Jackaroo's
  code is untouched and still compiles; restoring it means adding the enum case
  back in `HomeViewController`.

### How the hidden-information claims are verified

`TDPTransport` is a protocol, so `TDPLoopbackTransport` runs a real host↔guest
session in-process. `testGuestNeverReceivesAnotherSeatsCards` scans every byte
the host put on the wire for card ids still held by other seats and asserts
none appear — with a guard against passing vacuously, plus the converse check
that the guest's own hand *does* arrive. `TDPKhichaiUITests` drives the real
view controller and asserts the debtor and the third player never see the
pulled card, on screen or in a label.

---

## Sources

- [pagat.com — 3‑2‑5](https://www.pagat.com/quotawhist/3-2-5.html)
- [games.porg.es — तीन दो पाँच · Teen Do Pānch](https://games.porg.es/games/teen-do-panch/)
- [anujdecoder/teen-do-paanch](https://github.com/anujdecoder/teen-do-paanch) (rules reference only — unlicensed, no code reused)
- [gnsharma/teen-do-paanch](https://github.com/gnsharma/teen-do-paanch)
- [catsatcards.com — Three Two Five](https://www.catsatcards.com/Games/ThreeTwoFive.html)
- [blitzpoker.com — 3 2 5 card game](https://www.blitzpoker.com/blogs/3-2-5-card-game/)
- [cardzmania.com — Teen Do Panch](https://www.cardzmania.com/TeenDoPanch)
