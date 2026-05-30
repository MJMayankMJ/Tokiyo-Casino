# TestFlight External Review Notes — Tokiyo Cards

Paste the section below into **App Store Connect → TestFlight → Test Information → Beta App Review Information → Notes** before submitting the build for external review.

---

## Notes for the reviewer

Tokiyo Cards is a **free-to-play, entertainment-only multiplayer card-game app**. The app contains Texas Hold'em poker (solo vs AI, and peer-to-peer multiplayer) and a Jackaroo board game (multiplayer Indian board game similar to Ludo). There is no real money involved.

**Rebrand history (important context for review):**
A previous build (`1.0 (2)`, submitted as `Tokiyo Casino`) was rejected on 2026-05-29 because it contained a Daily Spin slot mechanic and self-disclosed Simulated Gambling: Frequent/Intense in the age rating. This build (`1.0 (3)`) is a rebrand with the following changes:

- App renamed from `Tokiyo Casino` → `Tokiyo Cards`
- Slot machine module compile-excluded via `#if ENABLE_SLOT_MACHINE` (flag is never defined in shipping configs)
- Treasure chest UI entry point hidden
- Daily randomized spin reward replaced with a one-time flat 1000-chip grant on first launch
- Age rating questionnaire now answers **Simulated Gambling: None**
- App Store category changed from Casino to **Games → Card**

**What the app does:**
- **No in-app purchases.** No StoreKit, no payment processing, no consumables, no subscriptions.
- **No real-money gambling.** Chips are virtual, granted on first install (1000 chips), and have **no cash value**. There is no way to purchase, withdraw, redeem, transfer, or exchange chips for anything outside the app.
- **No login or account.** First launch creates a local virtual chip balance.
- **No analytics, ads, or third-party tracking SDKs.**
- **No server backend.** All gameplay state lives on-device in Core Data, Keychain, and UserDefaults. We use Apple's MultipeerConnectivity framework for nearby device-to-device play only — there is no remote server we operate.

### What to test

1. **Cold launch** — opens to Home with no crash. POKER and JACKAROO cards are visible. No treasure chest, no daily-spin prompt.
2. **First-launch chip grant** — a fresh install (delete + reinstall) shows the chip balance at 1000.
3. **Solo Poker** — tap POKER → Menu → Solo. Play through one hand against AI.
4. **Multiplayer Poker** ("Play with Friends") — tap POKER → Menu → Play with Friends. iOS will prompt for Local Network permission. Allowing it discovers nearby iPhones running Tokiyo Cards. Denying it should not crash the app.
5. **Jackaroo** (in Release builds) — tap JACKAROO → opens a "Coming Soon" screen. The full Jackaroo game is hidden in Release.
6. **Chip persistence** — virtual chip balance survives app kill/relaunch.
7. **Privacy manifest** — `PrivacyInfo.xcprivacy` is bundled inside the app and declares `UserDefaults` (`CA92.1`).

### Privacy notes

- Required-reason API: `UserDefaults` (`CA92.1`).
- Local Network permission is requested only when the user starts Play with Friends.
- No tracking, no NSUserTrackingUsageDescription, and ATT is not invoked.

### Demo account

Not required. The app has no login.

### Contact

pawan99tiwari@gmail.com
