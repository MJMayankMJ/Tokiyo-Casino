# Tokiyo Casino - Pre-Release Audit Report

**Date:** 2026-05-28  
**Status:** Fact-checked against the local project and current Apple docs  
**Project:** Tokiyo Casino iOS app  
**Target:** External TestFlight and App Store submission

---

## Fact-Check Summary

The original AI report was directionally useful, but it overstated several review outcomes as certainties. This version separates verified repository facts from review-risk judgment.

High-confidence findings:

- The repository contains no `PrivacyInfo.xcprivacy`, while app code uses `UserDefaults`. Apple documents `UserDefaults` as a required-reason API, and App Store Connect does not accept apps that use required-reason APIs without the reason declared in a privacy manifest.
- The app does not appear to use StoreKit, in-app purchases, payment processing, HTTP/HTTPS networking, web views, Firebase, analytics, ads, camera, photos, or location APIs.
- The app does use `MultipeerConnectivity` for nearby poker, so data can move between nearby devices during multiplayer. The original "no data leaves the device" claim was too broad.
- The app stores local state in Core Data, Keychain, and `UserDefaults`.
- Slots and Lotto/Mines source files and storyboard scenes are present in the app target. Because this Xcode project uses a file-system-synchronized root group, files under `Tokiyo Casino/` are target members unless explicitly excluded.
- Several old casino/slot artifacts are present in source, storyboard XML, assets, strings, and Core Data model names.
- Several `fatalError` calls are real crash risks, but the Core Data manager actually used by coin state is `CoreDataManager`, not only `AppDelegate`.

Corrected overclaims from the original report:

- Do not say Apple "will almost certainly reject" dormant source files. It is a real review risk, but the repository cannot prove Apple will inspect or reject the binary for these class names.
- Do not claim Apple policy explicitly says simulated gambling apps must use the exact in-app wording "entertainment only / no real money." Apple does regulate gambling and real-money gaming under guideline 5.3.4; clear virtual-only copy is a prudent mitigation, not a directly quoted rule from 5.3.4.
- Do not claim `GameManagerDebug.printGameState()` "still dumps in release." The method is compiled, but `rg` found no call sites.
- Do not say TestFlight review notes are missing as a repository fact. TestFlight metadata lives in App Store Connect and is not verifiable from this repo.
- Do not tell this project to remove files from "Compile Sources" as the only fix. This project has empty explicit build phases and uses synchronized folders, so exclusions must be done through Xcode target membership/exceptions, moving files out of the app folder, or build conditions.

Official Apple references checked:

- Required-reason APIs and privacy manifests: <https://developer.apple.com/documentation/BundleResources/describing-use-of-required-reason-api>
- `UserDefaults` required-reason category and `CA92.1`: <https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype>
- TestFlight external beta info: <https://developer.apple.com/testflight/>
- App Review privacy policy requirement: <https://developer.apple.com/app-store/review/guidelines/#privacy>
- App privacy metadata: <https://developer.apple.com/help/app-store-connect/reference/app-information/app-privacy>
- Gambling and lotteries guideline 5.3: <https://developer.apple.com/app-store/review/guidelines/#gaming-gambling-and-lotteries>
- App age rating questionnaire: <https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating>

---

## 1. Upload Blocker / Must Fix

### 1.1 Missing `PrivacyInfo.xcprivacy`

**Verified:** No `PrivacyInfo.xcprivacy` file exists in the project.

**Evidence:**

- `find . -name 'PrivacyInfo.xcprivacy' -o -name '*.xcprivacy'` returned no files.
- `UserDefaults.standard` is used in:
  - [SoundManager.swift](<Tokiyo Casino/Manager/SoundManager.swift>)
  - [BackgroundSoundManager.swift](<Tokiyo Casino/Manager/BackgroundSoundManager.swift>)
  - [MultiplayerEntryViewController.swift](<Tokiyo Casino/Poker /Multiplayer/UI/MultiplayerEntryViewController.swift>)

**Why it matters:** Apple identifies `UserDefaults` as a required-reason API. For this app's usage, `CA92.1` is the appropriate reason because the app reads/writes app-only settings and reconnect metadata.

**Fix:**

Create `Tokiyo Casino/PrivacyInfo.xcprivacy` and confirm it is included in the app target resources.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

---

## 2. High Review Risk / Product Clarity

### 2.1 Missing Virtual-Currency Disclaimer

**Verified:** No user-facing Swift copy was found for "entertainment only," "no real money," "no cash value," or "disclaimer." The word "virtual" appears only in internal Jackaroo comments, not as visible gambling/currency disclosure.

Current user-facing examples:

- [HomeViewController.swift](<Tokiyo Casino/View/HomeViewController.swift>) daily spin prompt: "Spin to collect coins."
- [SlotViewController.swift](<Tokiyo Casino/View/SlotViewController.swift>) daily reward result: "You collected X coins."
- [SlotViewController.swift](<Tokiyo Casino/View/SlotViewController.swift>) casino mode result: "You won X coins!" / "You lost X coins."

**Correct risk framing:** Apple guideline 5.3.4 is specifically about real-money gaming and lotteries. The codebase currently appears virtual-only, but the app name, poker, slots UI, coin balance, betting terms, and dormant Lotto/Mines code make it important to tell reviewers and users clearly that this is not real-money gambling.

**Fix:**

Add concise visible copy in-app and in metadata:

- "For entertainment only. No real money. Coins have no cash value."
- "Free virtual coins only. No purchases, withdrawals, or redemptions."

Recommended places:

- Home screen footer or settings/about screen
- Daily Spin prompt and result alert
- Poker menu or rules screen
- TestFlight review notes and App Store description
- Privacy policy/support page, if appropriate

### 2.2 Dormant Slots and Lotto/Mines Are Still in the App Target

**Verified:** Slots and Lotto/Mines code exists under the synchronized app folder and storyboard scenes exist.

| Item | Evidence | Accurate risk |
|---|---|---|
| Slot screen | [SlotViewController.swift](<Tokiyo Casino/View/SlotViewController.swift>), 566 lines | Reachable as Daily Spin, but also contains casino-game betting mode compiled into release. |
| Slot view model | [SlotViewModel.swift](<Tokiyo Casino/ViewModel/SlotViewModel.swift>) | Contains casino payout strings including a `JACKPOT!` win message and betting logic. |
| Lotto/Mines screen | [LottoViewController.swift](<Tokiyo Casino/View/LottoViewController.swift>), 642 lines | Not reachable by found Swift call sites, but storyboard scene and segue exist. |
| Lotto view model | [LottoViewModel.swift](<Tokiyo Casino/ViewModel/LottoViewModel.swift>) | Contains mines/payout logic. |
| Mine slider | [MineSliderView.swift](<Tokiyo Casino/View/MineSliderView.swift>), 297 lines | File is entirely commented out; still a source artifact. |
| Storyboard | [Main.storyboard](<Tokiyo Casino/Storyboard/Base.lproj/Main.storyboard>) | Contains `TOKIO SLOTS`, `TOKIO LOTTO`, `toSlotVC`, and `toLottoVC`. |

**Reachability verified:**

- `HomeViewController.openDailySpinGame()` performs `toSlotVC` and sets `SlotViewController.mode = .dailyReward`.
- `SlotViewController.mode` defaults to `.casinoGame`, but no release navigation path was found that presents SlotVC without changing it to `.dailyReward`.
- `K.toLottoVC` and the storyboard segue exist, but `rg` found no `performSegue` call for `toLottoVC`.
- Home removes the old storyboard cards at runtime and programmatically adds `POKER` and `JACKAROO`.

**Correct risk framing:** This is not proven to be an automatic rejection. It is still risky because unused casino screens, betting strings, and storyboard scenes conflict with a release story that only Poker, Jackaroo Coming Soon, and Daily Spin are intended to ship.

**Fix options:**

- Best: refactor Daily Spin into its own view controller/model and exclude or move the old casino Slot/Lotto/Mines files out of the app target.
- Minimum: strip `SlotViewController` and `SlotViewModel` to daily-reward-only behavior for release, delete the Lotto scene and stale home cards from `Main.storyboard`, and exclude Lotto/Mines files from the target.
- For this project specifically, use Xcode target membership/synchronized group exceptions or move dormant files outside `Tokiyo Casino/`. The `PBXSourcesBuildPhase` is empty because the target uses a synchronized root group.

### 2.3 Old Casino Strings and Assets Remain

**Verified examples:**

- `JACKPOT!` payout text in [SlotViewModel.swift](<Tokiyo Casino/ViewModel/SlotViewModel.swift>)
- `TOKIO SLOTS` and `TOKIO LOTTO` in [Main.storyboard](<Tokiyo Casino/Storyboard/Base.lproj/Main.storyboard>)
- Assets such as `slot machine`, `slotBanner`, `lottoBanner`, `backgroundLotto`, `bomb`, `diamond`
- Core Data model is still named `SlotMachineModel`

**Fix:** If Slots/Lotto are not part of v1 release, remove the unused scenes/assets/source from the app target or document the remaining Daily Spin usage clearly.

---

## 3. Crash and Stability Risks

### 3.1 Core Data `fatalError` Calls

**Verified:** Core Data load/save failures can terminate the app.

| File | Risk |
|---|---|
| [AppDelegate.swift](<Tokiyo Casino/AppDelegate.swift>) | `fatalError("Unresolved error ...")` in `persistentContainer.loadPersistentStores` and `saveContext`. |
| [CoreDataManager.swift](<Tokiyo Casino/Manager/CoreDataManager.swift>) | `fatalError("Error loading Core Data: ...")`; this is the manager actually used by `HomeViewModel` and `CoinsManager`. |

**Correct risk framing:** This is not an upload validation blocker by itself, but it is a real launch/runtime crash risk if the store cannot load or migrate.

**Fix:** Replace production `fatalError` with graceful handling: log, present recovery UI, recreate the local store only after careful consideration, or fail into a non-crashing empty state.

### 3.2 Missing Sound Files

**Verified:** The original report understated this as "may not exist." These references appear missing/misnamed:

- `LottoViewController.triggerCashOutHaptic()` requests `lotto_win_sound.mp3`, but no file with that name exists under `Tokiyo Casino/Res`.
- `LottoViewController.triggerMineHaptic()` requests `error_sound.mp3`, but the actual file is named `error_sound .mp3` with a space before `.mp3`.

**Impact:** `SoundManager.setupPlayer` logs and skips playback. This likely does not crash, but it is a release polish bug.

### 3.3 Negative Coin Balance Guard

**Verified:** [CoinManager.swift](<Tokiyo Casino/Manager/CoinManager.swift>) subtracts directly:

```swift
stats.totalCoins -= amount
```

Most callers validate first, but the manager itself does not reject over-deductions. This is a shared safety issue.

**Fix:** Make `CoinsManager.deductCoins` enforce sufficient balance and fail without mutating state when `amount > stats.totalCoins`.

### 3.4 Other Stability Notes

- `LottoViewController` force-casts collection view cells with `as! Cell`; currently mitigated by nib registration.
- `SlotViewController.viewModel` is an implicitly unwrapped optional. It is initialized in `viewDidLoad`, so current call order looks safe, but a safer non-optional setup would reduce future crash risk.
- Several UIKit-only classes use `required init?(coder:) { fatalError() }`. This is normal for programmatic-only views/controllers, but confirm none are instantiated from storyboards.

---

## 4. Privacy, Permissions, Data, and Networking

### Verified Local Permissions

| Permission | In `Info.plist` | Code usage | Notes |
|---|---:|---:|---|
| Local Network | Yes | Yes | Used by `MultipeerConnectivity` poker. |
| Bonjour Services | Yes | Yes | `_tokiyo-poker._tcp` and `_tokiyo-poker._udp` are declared. |
| Camera | No | No usage found | OK. |
| Photos | No | No usage found | OK. |
| Location | No | No usage found | OK. |
| Tracking/ATT | No | No usage found | OK. |

### Verified Networking / SDK Surface

Found:

- `MultipeerConnectivity`
- `Security` / Keychain
- `CoreData`
- `AVFoundation`, `AudioToolbox`, `CoreHaptics`

Not found by text search:

- `StoreKit`, `SKPayment`, in-app purchase APIs
- `URLSession`
- `WKWebView`
- Firebase
- Alamofire
- ad SDKs
- analytics SDKs

### Correct App Privacy Framing

The app appears to have no developer-server data collection in the repository. However, multiplayer sends local peer-to-peer data such as display names, lobby data, cards/game snapshots, and actions between nearby devices. Do not claim "no data leaves the device" without this qualifier.

Recommended App Store privacy wording to validate in App Store Connect:

- No tracking.
- No third-party analytics/ads found.
- No server-side collection found.
- Local multiplayer exchanges peer-to-peer gameplay data with nearby devices when the user chooses Play with Friends.
- Local state is stored on-device in Core Data, Keychain, and `UserDefaults`.

Apple also requires a Privacy Policy URL for all apps, and guideline 5.1.1 says the privacy policy link must be in App Store Connect metadata and easily accessible in the app.

---

## 5. TestFlight and App Store Metadata

These items cannot be fully verified from the repository because they live in App Store Connect.

### 5.1 External TestFlight Review Notes

**Not repo-verifiable, but required for external testing.** Apple says beta app description and beta app review information are required to share with external testers.

Use review notes like:

```text
Tokiyo Casino uses free virtual coins only. There is no real-money gambling, no purchases, no withdrawals, no redemptions, and no cash value.

What to test:
- Poker can be played solo against AI.
- Play with Friends uses nearby-device local networking through MultipeerConnectivity.
- Jackaroo is marked Coming Soon in Release builds.
- Daily Spin gives up to 2 free virtual coin rewards per day.

No login is required. The app creates a local coin balance on first launch.
```

### 5.2 Privacy Policy URL

**Required by Apple metadata.** Also add an in-app link if one does not exist.

Suggested policy contents:

- No account required.
- No real-money gambling, purchases, withdrawals, or redemptions.
- Local gameplay state stored on device.
- Local multiplayer exchanges display name and game state with nearby devices only when used.
- No analytics, ads, or third-party tracking found in the current build.
- Contact/support email.

### 5.3 Age Rating

**Repo-verifiable risk, App Store Connect action required.** The age rating questionnaire includes chance-based activity options such as Simulated Gambling. Because poker, casino naming, slot-style spin UI, virtual coins, and betting terms are present, answer the questionnaire conservatively and accurately. Do not hardcode an exact resulting rating in this report without checking App Store Connect's calculated result.

### 5.4 App Category and Screenshots

**Not repo-verifiable.** Avoid screenshots or metadata that imply real-money prizes, cash-out, withdrawals, or purchasable currency. If v1 only ships Poker, Jackaroo Coming Soon, and Daily Spin, screenshots should match that release scope.

---

## 6. Build Configuration Findings

### 6.1 Build Number

**Verified:** `CURRENT_PROJECT_VERSION = 1` for app and test targets in `project.pbxproj`.

Each uploaded build for a version needs a unique build number. Bump before upload or set up an incrementing strategy.

### 6.2 Deployment Target

**Verified:** `IPHONEOS_DEPLOYMENT_TARGET = 18.4`.

This is not a review rejection by itself, but it limits TestFlight to devices on iOS 18.4 or newer. No obvious iOS 18.4-only APIs were found in the text search. Lower to iOS 16.0 or 17.0 if the app builds and tests cleanly there.

### 6.3 Bundle Identifier

**Verified:** `PRODUCT_BUNDLE_IDENTIFIER = "com.mayank.Tokiyo-Casino-fianltwo"`.

`fianltwo` looks like a typo, but only the owner can confirm intent. Decide before creating/submitting the App Store app record because changing the bundle identifier later means a different app identity.

### 6.4 Debug vs Release Behavior

| Item | Verified behavior |
|---|---|
| Jackaroo navigation | `#if DEBUG` opens `JackarooGameViewController`; Release opens `ComingSoonViewController`. |
| Jackaroo code | Still compiled in Release because files are in the app target. |
| Protocol fixture self-test | `ProtocolGoldenFixtures.selfTest()` is behind `#if DEBUG` in `AppDelegate`. |
| Prints/logs | Many `print()` calls are unguarded and will execute if their code path runs in Release. Some multiplayer token-store prints are already DEBUG-guarded. |
| `GameManagerDebug` | Methods are compiled, but no call sites were found. |

---

## 7. Source Hygiene / Polish

These are lower priority than the upload and review risks above.

| Issue | Verified evidence | Recommendation |
|---|---|---|
| Old headers | Multiple files say `Spin Royale`; `Constants.swift` says `EmojiSlotMachine`. | Update comments for professionalism. |
| Copyright header | `Constants.swift` says `Copyright 2020 Marcy Vernon`. | Confirm provenance/license or replace/remove the header. This is source-visible, not user-visible. |
| Old Core Data model name | `SlotMachineModel.xcdatamodeld`; `CoreDataManager` loads `SlotMachineModel`. | Leave unless you are prepared to handle Core Data migration/renaming carefully. |
| Dead constants | `K.playSlots`, `K.playLotto`, `K.toLottoVC`. | Remove after deleting/retiring old storyboard paths. |
| Unguarded logs | Keychain, Core Data, Lotto, poker engine, host/client services. | Replace with a small logger that compiles out debug logs in Release. |

---

## 8. Prioritized Fix List

### P1 - Fix Before Upload

| Issue | Why | Action |
|---|---|---|
| Missing privacy manifest | App uses required-reason `UserDefaults`. | Add `PrivacyInfo.xcprivacy` with `NSPrivacyAccessedAPICategoryUserDefaults` and reason `CA92.1`. |
| Privacy policy | Required for all apps; must be accessible in metadata and app. | Create/host policy and add an in-app link. |
| Virtual-only disclosure | Review clarity for casino/poker/coin UX. | Add "No real money / no cash value" copy in app and metadata. |
| Core Data `fatalError` | Real production crash risk. | Replace with non-crashing recovery/error handling in `CoreDataManager` and `AppDelegate`. |
| App Store/TestFlight review notes | Required for external testers and helpful for review. | Provide clear no-real-money notes and test instructions. |
| Age rating questionnaire | Simulated gambling/chance-based activity likely applies. | Answer accurately in App Store Connect. |

### P2 - Strongly Recommended Before External TestFlight

| Issue | Action |
|---|---|
| Dormant Slots/Lotto/Mines artifacts | Remove/exclude/refactor unused casino-game code and storyboard scenes, especially `toLottoVC` and old cards. |
| `SlotViewController` mixed daily/casino behavior | Split Daily Spin into its own release-safe screen or remove casino mode from release. |
| Missing/misnamed sounds | Add `lotto_win_sound.mp3` or change the code; rename `error_sound .mp3` to `error_sound.mp3` or change the code. |
| Unguarded release prints | Replace with a no-op-in-release logger or wrap debug-only logs. |
| Build number | Bump from `1` before each upload. |
| Bundle ID typo | Confirm whether `fianltwo` is intentional before first submission. |
| Deployment target | Lower from iOS 18.4 if no 18.4-only APIs are needed. |

### P3 - Cleanup

| Issue | Action |
|---|---|
| Old file headers | Rename `Spin Royale` / `EmojiSlotMachine` comments. |
| Dead constants | Remove after storyboard cleanup. |
| Core Data model name | Consider later with a deliberate migration plan. |
| Crash reporting | Optional. If added, update privacy disclosures and SDK privacy requirements. |

---

## 9. Manual Verification Checklist

Run these on a Release scheme before upload:

| # | Test | Expected result |
|---|---|---|
| 1 | Cold launch | App opens to Home with no crash. |
| 2 | Home cards | Only `POKER` and `JACKAROO` are visible. |
| 3 | No old cards visible | `TOKIO SLOTS` and `TOKIO LOTTO` are not visible at runtime. |
| 4 | Poker solo | Menu opens, solo game can play through a hand. |
| 5 | Poker multiplayer | Local Network prompt appears when starting nearby play. |
| 6 | Deny Local Network | App handles denial without crashing. |
| 7 | Jackaroo in Release | Opens Coming Soon, not the full debug game. |
| 8 | Daily Spin prompt | Shows virtual-only/no-cash-value language. |
| 9 | Daily Spin result | Awards coins and shows remaining spin count. |
| 10 | Daily Spin exhausted | Shows no spins left and returns home cleanly. |
| 11 | Coin persistence | Balance persists after app kill/relaunch. |
| 12 | Sound paths | No missing-sound logs for normal flows. |
| 13 | Console check | Release logs do not expose cards, player state, tokens, or misleading `$` currency. |
| 14 | App bundle check | `PrivacyInfo.xcprivacy` is present in the built `.app`. |

---

## Final Verdict

The original report had real findings, but the "Apple will reject" language was too aggressive except for the missing required-reason privacy manifest. Treat the current state as **not ready for external TestFlight/App Store upload** until at least the privacy manifest, privacy policy, virtual-currency disclosure, Core Data crash handling, review notes, and age rating are addressed.

The app's core "virtual coins only" story is supported by the current code search: no StoreKit, no IAP, no payments, no server networking, no ads, and no analytics were found. The main release risk is that the project still contains legacy casino/slot/lotto artifacts that make that story harder to review cleanly.
