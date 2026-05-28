# Tokiyo Casino — Privacy Policy

**Effective date:** 2026-05-28
**App:** Tokiyo Casino (iOS)
**Bundle ID:** com.mayank.Tokiyo-Casino
**Contact:** pawan99tiwari@gmail.com

This policy describes what Tokiyo Casino does and does not do with your data.

## At a glance

- **No account or login is required.**
- **No real-money gambling, no in-app purchases, no withdrawals, no redemptions, and no cash value.** All coins in the app are virtual and used only inside the app for entertainment.
- **No third-party analytics, advertising, or tracking SDKs.** We do not link a device identifier or user profile to any external service.
- **All gameplay data is stored locally on your device.**
- **Optional local multiplayer** lets the app exchange limited gameplay data between nearby devices using Apple's MultipeerConnectivity framework. Nothing is sent to a server we operate.

## What we collect

Tokiyo Casino does **not** collect, transmit, or store personal information on any server we control. We have no developer-side database, no analytics pipeline, and no advertising integrations.

### Data stored on your device

The following is stored locally on the device only and never leaves the device unless you use Play with Friends (see below).

| Data | Where it lives | Why |
| --- | --- | --- |
| Virtual coin balance | Core Data | Daily reward and gameplay state |
| Daily Spin claim history | Apple Keychain | Enforces the daily limit |
| Sound mute preference, reconnect metadata, last display name | UserDefaults | Remembers app-only settings |

Required-reason API disclosure: we use `UserDefaults` under the `CA92.1` reason ("Accessing app-only settings and state"). This is declared in our app's `PrivacyInfo.xcprivacy` manifest.

### Local multiplayer ("Play with Friends")

When you start a multiplayer poker session, the app uses Apple's MultipeerConnectivity framework to discover nearby iPhones and exchange gameplay messages directly between devices. The data exchanged is limited to:

- the display name you chose,
- lobby state (who is hosting, who is joining, whether the game has started),
- gameplay events (cards dealt to you, community cards, betting actions, round results),
- minimal reconnect tokens kept locally to recover a dropped peer.

This data is **not** sent to any server we operate, and is **not** stored after the session ends, except for the local reconnect token. We do not have access to it.

The app declares Bonjour service types `_tokiyo-poker._tcp` and `_tokiyo-poker._udp` and requests Local Network permission. You can decline this permission, in which case the multiplayer feature will not work, but the rest of the app will.

## What we do **not** collect

- No real name, email, phone number, or address.
- No precise location.
- No camera, photo library, microphone, contacts, or health data.
- No advertising identifier.
- No third-party analytics or crash reporting.
- No payment information of any kind — we have no in-app purchases.

## Data retention and deletion

Because nothing is sent to our servers, deleting the app removes everything except the Keychain-stored daily-spin history, which iOS retains until the device is fully reset or the app is reinstalled and resets it. There is no account to delete on our side because there are no accounts.

## Children

Tokiyo Casino does not knowingly target children under 17. The app contains simulated card-game gameplay (poker, Daily Spin). Parents who want to restrict access can use iOS's built-in Screen Time and content restrictions.

## Changes to this policy

If this policy changes, we will update the "Effective date" above and ship a new build with the updated link.

## Contact

For privacy questions, email **pawan99tiwari@gmail.com**.
