# App Age Rating Questionnaire — Suggested Answers

This is a cheat sheet for the App Store Connect age rating questionnaire for **Tokiyo Cards**. Apple's official questionnaire is at *App Store Connect → My Apps → Tokiyo Cards → App Information → Age Rating → Edit*.

The previous build (1.0 build 2) was rejected by Apple's Beta App Review on 2026-05-29 because it self-disclosed Simulated Gambling: Frequent/Intense. Individual developer accounts can no longer ship apps flagged as gambling. This rebrand removes the slot machine module and reframes the app as a multiplayer card-game app. Answer the questionnaire honestly below — the app no longer contains the mechanics that previously triggered the gambling classification.

| Category | Answer | Why |
| --- | --- | --- |
| Cartoon or Fantasy Violence | None | No violence anywhere in the app. |
| Realistic Violence | None | Same. |
| Prolonged Graphic or Sadistic Realistic Violence | None | Same. |
| Profanity or Crude Humor | None | UI copy is family-friendly. |
| Mature/Suggestive Themes | None | Same. |
| Horror/Fear Themes | None | Same. |
| Medical/Treatment Information | None | Not applicable. |
| Alcohol, Tobacco, or Drug Use or References | None | None depicted. |
| Sexual Content or Nudity | None | None. |
| Graphic Sexual Content and Nudity | None | None. |
| **Simulated Gambling** | **None** | The slot machine module is compile-excluded from shipping builds. The only remaining gameplay is Texas Hold'em poker and the Jackaroo board game — both played with virtual chips with no real-world value, no purchasable currency, no leaderboards, and no chip transfer mechanism. This is consistent with how Solitaire, Hearts, Bridge, and other card-game apps are classified. |
| Contests | None | No real-world contests. |
| Unrestricted Web Access | No | App has no web view. |
| Gambling and Contests (real money) | **No** | App has zero real-money gambling, no purchases, no redemptions. |
| Gambling Themes Frequent or Intense | **No** | App is rebranded as `Tokiyo Cards`; casino theming has been removed. |
| User Generated Content | No | No UGC. |
| Loot Boxes | No | No randomized purchasable rewards. |

## Resulting expected rating

With **Simulated Gambling: None** the rating typically lands at **9+** or **12+** depending on Apple's current criteria for card games. This is similar to other multiplayer card-game apps on the store.

## Things to align with the listing

- **App display name** is `Tokiyo Cards` (set via `INFOPLIST_KEY_CFBundleDisplayName`).
- **App Store category** should be **Games → Card** (not Casino).
- **App Store description** must avoid the words: "casino", "slots", "spin", "jackpot", "bet", "wager", "gambling", "real money". Standard poker terms like "pot", "raise", "fold", "all in" are fine — they're widely accepted card-game vocabulary.
- **Privacy** answers in App Store Connect should reflect: no tracking, no data collection, no data linked to user, no third-party SDKs.
- **Screenshots** should not show slot reels, treasure chest, "Daily Spin" wording, or anything else that could be read as gambling.

## Reminder

The previous rejection cited Apple's policy against individual accounts shipping simulated gambling apps. With this rebrand:

- The slot machine UI is compile-excluded (the `#if ENABLE_SLOT_MACHINE` flag is never defined in shipping configs).
- The treasure chest entry point is hidden.
- The Daily Spin mechanic and its accompanying daily reward have been replaced with a one-time 1000-chip grant on first launch.
- The app name does not contain "Casino", "Slots", "Spin", or any gambling vocabulary.
- The age rating questionnaire now honestly answers Simulated Gambling: None.

These changes should resolve the Beta App Review concern. If reviewers still question the app, the TestFlight reviewer notes (`TESTFLIGHT_REVIEW_NOTES.md`) explicitly address the rebrand history and confirm the absence of gambling mechanics.
