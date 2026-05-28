# TestFlight External Review Notes — Tokiyo Casino

Paste the section below into **App Store Connect → TestFlight → Test Information → Beta App Review Information → Notes** before submitting the build for external review.

---

## Notes for the reviewer

Tokiyo Casino is a **free-to-play, entertainment-only** virtual casino-style app. There is no real money involved.

- **No in-app purchases.** No StoreKit, no payment processing, no consumables, no subscriptions.
- **No real-money gambling.** Coins are virtual, awarded daily for free, and have **no cash value**. There is no way to withdraw, redeem, transfer, or exchange them for anything outside the app.
- **No login or account.** First launch creates a local virtual coin balance.
- **No analytics, ads, or third-party tracking SDKs.**
- **No server backend.** All gameplay state lives on-device in Core Data, Keychain, and UserDefaults. We use Apple's MultipeerConnectivity framework for nearby device-to-device play only — there is no remote server we operate.

### What to test

1. **Cold launch** — opens to Home with no crash. POKER and JACKAROO cards are visible.
2. **Solo Poker** — tap POKER → Menu → Solo. Play through one hand against AI.
3. **Multiplayer Poker** ("Play with Friends") — tap POKER → Menu → Play with Friends. iOS will prompt for Local Network permission. Allowing it discovers nearby iPhones running Tokiyo Casino. Denying it should not crash the app.
4. **Jackaroo** (in Release builds) — tap JACKAROO → opens a "Coming Soon" screen. The full Jackaroo game is hidden in Release.
5. **Daily Spin** — tap the treasure chest on Home. The prompt explains coins are virtual with no cash value. Up to 2 free spins per day. After spending both, the app shows "No spins left today."
6. **Coin persistence** — virtual coin balance survives app kill/relaunch.
7. **Privacy manifest** — `PrivacyInfo.xcprivacy` is bundled inside the app and declares `UserDefaults` (`CA92.1`).

### Privacy notes

- Required-reason API: `UserDefaults` (`CA92.1`).
- Local Network permission is requested only when the user starts Play with Friends.
- No tracking, no NSUserTrackingUsageDescription, and ATT is not invoked.

### Demo account

Not required. The app has no login.

### Contact

pawan99tiwari@gmail.com
