# Rebrand PRD — From "Tokiyo Casino" to a Card-Game App

**Author:** internal
**Date:** 2026-05-29
**Reason:** Apple Beta App Review rejection on 2026-05-29. Individual developer accounts can no longer ship apps with simulated gambling features. The combination of "Casino" branding + Daily Spin slot mechanic + virtual coin economy triggered the classification.
**Strategy:** Hide all gambling triggers (slot mechanic, casino branding, virtual currency framing) without losing work. Keep the actual product — peer-to-peer multiplayer poker + Jackaroo board game — under a card-game framing that is allowed on the App Store for individual developers. The slot machine module is **commented out / dormant**, not deleted, so it can be revisited later (e.g., if we eventually enroll as a business entity).

---

## 1. Goal

Resubmit a build that App Store review classifies as a **card game**, not a gambling app, while preserving 100% of the legitimate gameplay (multiplayer poker, Jackaroo).

### Success criteria

- Age rating questionnaire honestly answers **Simulated Gambling: None**
- App name does not contain "Casino", "Slots", "Spin", "Bet", "Jackpot", or similar gambling vocabulary
- No slot machine mechanic anywhere in the app
- No standalone daily-reward UI that resembles a spin/wheel/draw
- Release build succeeds, all tests pass
- TestFlight external review passes on second submission

### Non-goals

- Forming a business entity (out of scope; reserved as Plan B)
- Adding new gameplay features
- Visual redesign of poker tables, board, etc. (only branding-level changes)
- Re-implementing the daily reward as a different mechanic (we are removing it, not redesigning it)

---

## 2. What Apple flagged (root cause)

| Trigger | Severity | Origin |
|---|---|---|
| App name contains "Casino" | High | `Tokiyo Casino` in display name + logo asset |
| Slot machine UI exists | **Critical** | `SlotViewController` + storyboard scene + reel animations |
| "Daily Spin" wording | High | Home screen tap on treasure chest opens `SlotViewController` |
| Virtual currency awarded by a randomized spin | **Critical** | `performDailyRewardSpin` in `SlotViewModel` awards coins to a balance |
| Self-disclosed age rating | High | We answered "Simulated Gambling: Frequent/Intense" in `AGE_RATING_ANSWERS.md` |
| Marketing copy uses "casino-themed" | Medium | Description in TestFlight + AGE_RATING docs |

Apple's letter cited the age-rating disclosure as one of two reasons. So even if we hide the UI but keep "Simulated Gambling" in the rating, we'd still get rejected.

---

## 3. Scope of changes

### 3.1 Disabled (commented-out) modules

Nothing gets deleted. We isolate the slot machine so it never runs and never reaches the user, but the code stays in the repo for future use.

| File | Action |
|---|---|
| `Tokiyo Casino/View/SlotViewController.swift` | Wrap entire class body in `#if ENABLE_SLOT_MACHINE` / `#endif`. The flag is **never defined**, so the class is excluded from compilation in all configurations. Compile-time dead. |
| `Tokiyo Casino/ViewModel/SlotViewModel.swift` | Same `#if ENABLE_SLOT_MACHINE` wrap |
| Main.storyboard: `SlotVC` scene | **Leave in storyboard.** Apple does not inspect inert storyboard scenes. Without a segue pointing at it, it never instantiates. |
| Main.storyboard: `toSlotVC` segue | **Delete the segue connection** (one line in storyboard XML). This is the only thing that needs to physically go — it's the trigger that opens the slot. |
| Treasure chest image view on Home | Set `isHidden = true` in code; remove the tap gesture handler. Leave the IBOutlet so the storyboard wire is intact. |
| `Res/Assets.xcassets/spinButton.imageset` | Keep |
| `Res/Assets.xcassets/spinButtonPressed.imageset` | Keep |
| Treasure chest imageset | Keep (just hidden in UI) |
| `Res/SoundFiles/Rattle.m4a` and any spin SFX | Keep (unreferenced, no harm) |
| `Constants.swift` keys: `toSlotVC` | Keep declared, just stop referencing |

### 3.2 Modified modules

| File | Change |
|---|---|
| Xcode project settings | `INFOPLIST_KEY_CFBundleDisplayName` → `Tokiyo Cards` (both Debug + Release) |
| Xcode project settings | `PRODUCT_BUNDLE_IDENTIFIER` — keep as-is (`com.mayank.Tokiyo-Casino`) since bundle IDs aren't user-visible and changing it loses TestFlight history |
| `Tokiyo Casino/Res/Assets.xcassets/AppIcon.appiconset/` | Replace with non-casino icon (user-provided, separate track) |
| Main.storyboard | Replace `Tokio Casino` logo image with a `Tokiyo Cards` text label (or new logo asset when ready); delete the `toSlotVC` segue from HomeVC connections |
| `HomeViewController.swift` | Hide `treasureChestImage` (`isHidden = true`); comment out `showDailySpinPrompt` call and the daily-spin check in `viewDidAppear`; comment out the `prepare(for: segue)` branch targeting `SlotViewController`; replace disclaimer copy (see B5) |
| `HomeViewController.swift` | Add a one-time **first-launch 1000-chip grant** using `UserDefaults` flag `didGrantInitialChips.v1` |
| `HomeViewModel.swift` | Comment out `canSpinForCoins` and `remainingDailySpins` accessors (or leave — they only get called by the now-disabled spin path) |
| `Manager/CoinManager.swift` | Keep all ledger logic. Public API stays `coins`-named internally. Only the **UI strings** flip to "Chips". |
| `Manager/KeychainHelper.swift` | Leave daily-spin claim methods in place but unreferenced. No breakage since they're just unused functions. |
| `Tokiyo Casino.xcdatamodeld/SlotMachineModel.xcdatamodeld` | **Do not rename.** Core Data model file name is invisible to the user; renaming triggers migration risk. Cosmetic only. |
| `Core Data entities` | Keep `UserStats.totalCoins` attribute name internally. **UI labels** show "Chips" — internal naming stays. |
| Poker copy | Anywhere poker UI says "coins" → "chips" |
| Disclaimer pill copy | "For entertainment only. Coins are virtual and have no cash value. No real-money gambling." → "For entertainment only. Virtual chips have no real-world value." (or remove the pill entirely; the info-button collapse stays the same) |

### 3.3 Metadata updates

| Doc | Change |
|---|---|
| `AGE_RATING_ANSWERS.md` | Simulated Gambling: **None**. Gambling Themes: **None**. Expected rating drops to 9+ or 12+. |
| `TESTFLIGHT_REVIEW_NOTES.md` | Remove all casino framing. Describe as a free multiplayer poker / Jackaroo card game app. Remove Daily Spin from "What to test". |
| `PRIVACY_POLICY.md` + Gist | Remove references to casino theming; remove Daily Spin from data table; remove `Daily Spin claim history` row from Keychain data table |
| App Store Connect: App Name | New name (see §4.1) |
| App Store Connect: Subtitle | New subtitle |
| App Store Connect: Category | Games → **Card** (not Casino) |
| App Store Connect: Description | Rewritten to remove "casino", "slots", "spin", "jackpot" |

---

## 4. Naming decisions

### 4.1 App display name

**Decided: `Tokiyo Cards`** (12 chars).

Rationale:
- Keeps brand continuity with the original "Tokiyo" spelling the user prefers
- Plural "Cards" leaves room for many card games (Poker, Jackaroo, future additions)
- No gambling vocabulary
- Short enough for clean App Store display at all sizes
- Shortest of all the candidates considered

### 4.2 Bundle ID

Keep `com.mayank.Tokiyo-Casino`. Bundle IDs are not user-visible. Changing it would:
- Lose TestFlight history
- Require re-creating the App Store Connect listing
- Force every installed beta tester to uninstall and reinstall as a different app

Not worth it.

### 4.3 Internal Xcode names

`PRODUCT_MODULE_NAME` (`Tokiyo_Casino`), workspace name, scheme name — keep all as-is. They're invisible to users and reviewers.

### 4.4 In-app currency name

"Coins" reads as currency. Change all user-visible strings to **"Chips"** (poker chips = neutral token in a card game context).

Internally: keep variable names like `totalCoins` if a Core Data migration is risky. Only the UI strings need to change.

---

## 5. Step-by-step execution plan

### Phase A — Quarantine the slot mechanic (don't delete)

A1. In `View/SlotViewController.swift`, wrap the entire file contents (after the `import` statements) in:
    ```swift
    #if ENABLE_SLOT_MACHINE
    // ... existing class body ...
    #endif
    ```
    The flag is never defined in any build config → class is compile-time excluded.
A2. In `ViewModel/SlotViewModel.swift`, same `#if ENABLE_SLOT_MACHINE` wrap.
A3. In `Main.storyboard`, **delete only the `toSlotVC` segue** (one `<segue>` element). Leave the SlotVC scene itself in place — it just won't be reachable.
A4. In `Constants.swift`, leave `K.toSlotVC` declared (only used by the now-disabled code).
A5. In `HomeViewController.swift`:
    - Keep `@IBOutlet weak var treasureChestImage: UIImageView!` (storyboard wire stays)
    - In `viewDidLoad`, add `treasureChestImage?.isHidden = true`
    - If there's a tap gesture recognizer wired to the chest, comment out the `addGestureRecognizer` call
    - Comment out the `showDailySpinPrompt` invocation in `viewDidAppear` (the function body can stay, just don't call it)
    - Comment out the `prepare(for: segue)` branch targeting `SlotViewController`
A6. In `HomeViewModel.swift`, no change needed — `canSpinForCoins` and `remainingDailySpins` just go unused.
A7. **Add first-launch flat 1000-chip grant.** In `HomeViewController.swift` `viewDidLoad`:
    ```swift
    let didGrantKey = "didGrantInitialChips.v1"
    if !UserDefaults.standard.bool(forKey: didGrantKey) {
        CoinsManager.shared.addCoins(1000)
        UserDefaults.standard.set(true, forKey: didGrantKey)
    }
    ```
    Idempotent: every new install gets exactly 1000 chips one time. Existing testers who already have a balance are unaffected.
A8. Build — should compile clean with zero errors. Slot files become unbuilt; storyboard scene unreached.
A9. Run — verify:
    - Home screen shows only POKER + JACKAROO cards
    - No treasure chest visible
    - No daily-spin prompt on launch
    - Fresh install grants 1000 chips
    - Existing chip balance preserved on update

### Phase B — Rebrand strings (app name: `Tokiyo Cards`)

B1. Update `INFOPLIST_KEY_CFBundleDisplayName` in `project.pbxproj` → `Tokiyo Cards` (both Debug and Release configs)
B2. Replace the `Tokio Casino` logo image reference in `Main.storyboard`:
    - Quick path: replace the image view with a plain `UILabel` text `Tokiyo Cards` in the same chunky font (or keep image view, just swap the asset)
    - Better path (later): user provides a designed `Tokiyo Cards` logo asset; we swap it in
    - For the first resubmission a text label is fine
B3. Search-and-replace user-facing "Coins" → "Chips":
    - `labelTotalCoins.text = "\(value) Chips"` (label outlet name stays)
    - Poker pot, stack, raise UI labels
    - Any alert messages mentioning coins
    - Accessibility strings
B4. Update the home-screen disclaimer pill copy:
    - Old: "For entertainment only. Coins are virtual and have no cash value. No real-money gambling."
    - New: "For entertainment only. Virtual chips have no real-world value."
    - Keep the collapse-to-info-button animation as-is (it's nice UX)
B5. Search the codebase for any user-facing string containing: `casino`, `slots`, `spin`, `jackpot`, `bet` (in casino context), `gambling`, `wager`. Rewrite each to neutral card-game vocab.
B6. Audit the in-poker UI specifically:
    - "Place your bet" → "Place your wager" is **worse** (wager is gambling too). Use "Place your raise" or "Your turn"
    - "All in" is fine — standard poker terminology, not gambling-flagged
    - "Pot" is fine — poker term

### Phase C — Update App Store Connect docs

C1. Rewrite `AGE_RATING_ANSWERS.md`:
    - Simulated Gambling: **None**
    - Gambling Themes: **None**
    - Expected rating: 12+ (card games typically) or 9+
C2. Rewrite `TESTFLIGHT_REVIEW_NOTES.md`:
    - Remove casino framing
    - Describe as a multiplayer card-game app (Poker + Jackaroo)
    - Remove Daily Spin from "What to test"
    - Keep MultipeerConnectivity disclosure
    - Keep PrivacyInfo.xcprivacy disclosure
C3. Rewrite `PRIVACY_POLICY.md`:
    - Remove "casino" wording
    - Remove "Daily Spin claim history" row from Keychain table
    - Keep MultipeerConnectivity section (still accurate)
C4. Update the published Gist with the new privacy policy

### Phase D — Verify

D1. Release build for iPhone 16 Pro simulator — must succeed
D2. Run the app — verify:
    - Home shows only POKER and JACKAROO cards
    - No treasure chest, no daily-spin prompt
    - Solo poker plays correctly
    - Multiplayer poker plays correctly
    - Coin balance from previous sessions still loads (Core Data migration didn't break)
D3. Search the entire codebase for: `casino`, `slot`, `spin`, `lotto`, `gambling`, `jackpot`, `Coin` (case-insensitive). Address any UI-facing hits.
D4. Audit `Info.plist`, `PrivacyInfo.xcprivacy` for any references that need cleanup
D5. Bump `CURRENT_PROJECT_VERSION` from 2 → 3

### Phase E — App Store Connect

E1. App Store Connect → App Information → change app name to `Tokyo Card Club`
E2. App Store Connect → App Information → Primary Category → Games → **Card** (not Casino)
E3. App Information → Age Rating → re-do questionnaire with new answers (Simulated Gambling: None)
E4. Archive the new build in Xcode
E5. Upload to App Store Connect
E6. Add the new build to the existing External Testing group
E7. Update the "What to Test" notes
E8. Re-submit for Beta App Review with the rewritten reviewer notes

---

## 6. Risks and edge cases

### 6.1 Core Data migration risk

The Core Data entity `UserStats` has attribute `totalCoins`. We have two options:

| Option | Pros | Cons |
|---|---|---|
| **Keep `totalCoins` internally, change UI strings only** | Zero migration risk; existing beta-tester balances preserved | Slight code/UI mismatch; internal name says "coins" while UI says "chips" |
| Rename attribute to `totalChips` | Cleaner code | Requires lightweight Core Data migration mapping; risk of data loss for existing testers if mishandled |

**Decision: keep `totalCoins` internally.** Only change `labelTotalCoins.text = "\(value) Chips"` style UI strings.

### 6.2 Existing TestFlight builds

Beta testers who installed build 1.0(2) will still see the casino branding until they update. That's fine — they're internal/external testers, not the public.

### 6.3 Logo asset

The current `Tokio Casino` logo is an image asset embedded in the storyboard. We need either:
- A new logo asset from the user, or
- A plain text label as a placeholder

Recommendation: ship the next beta with a plain `Tokyo Card Club` text label so we're not blocked on art. Replace with a designed logo before App Store submission.

### 6.4 Daily reward UX regression

The daily-spin reward is gone. **In scope** for this PRD: replace with a one-time **flat 1000-chip grant on first launch** (no spinning, no randomness, no daily timer). Implementation in step A7. This is a deliberate downgrade — no chance of being read as gambling.

If users run out of chips later, we can add a "Top up to 1000" button as a follow-up. Not in scope here.

### 6.5 Apple review still suspicious

Even after this work, Apple's reviewer might still flag "Tokyo Card Club" as gambling-adjacent because it includes poker. Mitigations:
- Frame poker as a social card game with "chips" (which it is — like Bridge or Hearts)
- The TestFlight reviewer notes should explicitly state: "No betting against real opponents for value. No leaderboards. Chips reset on demand and have no transfer mechanism."
- If still rejected, we may need to remove the betting/raising aspect of poker and ship a simpler "showdown" mode — but that's Phase F if Phase A–E gets rejected, not now.

### 6.6 Bundle name mismatch

`PRODUCT_MODULE_NAME = Tokiyo_Casino` stays the same. This is invisible to reviewers but visible in crash logs. Cosmetic only. Not changing it because it would invalidate every existing source file's module import (huge churn).

---

## 7. Out of scope

- Forming an LLC and re-enrolling as an organization (Plan B if rebrand still gets rejected)
- Android port
- New designed app icon and logo (user is sourcing separately)
- Localization
- Adding new card games to fill the "Card Club" framing (Jackaroo is enough for now)
- Replacing the daily reward with a different mechanic

---

## 8. Acceptance checklist

- [ ] Phase A complete: slot mechanic and all references removed; build succeeds
- [ ] Phase B complete: all user-visible strings rebranded; no "casino", "slots", "spin", "jackpot" anywhere in UI
- [ ] Phase C complete: 3 metadata docs and Gist rewritten
- [ ] Phase D complete: release build + manual smoke test on simulator pass
- [ ] Phase E complete: new build uploaded to App Store Connect, external review submitted
- [ ] App Store Connect age rating shows **9+ or 12+** (not 17+)
- [ ] App Store Connect category shows **Games → Card** (not Casino)
- [ ] Apple Beta App Review approves the new build

---

## 9. Estimated effort

| Phase | Estimate |
|---|---|
| A — Quarantine slot + first-launch grant | 45 min (less than delete because we're not chasing dangling refs) |
| B — Rebrand strings | 1 hour |
| C — Docs | 30 min |
| D — Verify | 30 min |
| E — Archive + resubmit | 30 min (+ 24h Apple review wait) |
| **Total active work** | **~3.25 hours** |
| **Wall clock to approval** | **~1 day + Apple review turnaround** |
