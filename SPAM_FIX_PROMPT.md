# Remediation Prompt — Clear App Store 4.3(a) Spam Rejection

## Context

This is an iOS app, **Tokiyo Cards** (bundle id `com.mayank.Tokiyo-Casino`), at:
`/Users/mayankjangid/ios dev/Tokiyo Casino/ios`

It is a solo-developer card-game app. The core is an **original multiplayer Texas Hold'em poker engine** (peer-to-peer via MultipeerConnectivity) plus a **Jackaroo** board game — both original and must stay intact.

The app was **rejected by App Store review under Guideline 4.3(a) – Spam** ("similar binary, metadata, and/or concept as apps previously submitted by a terminated Apple Developer Program account"). Root cause: the **home-screen UI came from a public "Tokiyo Casino" Figma Community template** (used by other apps, including likely the terminated account's), and an earlier build contained **unused open-source slot-machine code**. The poker/Jackaroo code is original; the visual identity and some leftover code are the problem.

Goal: make the app **clearly distinct in both code and visuals** from that public template so it clears 4.3(a), while keeping the original poker + Jackaroo gameplay fully working.

History: a prior pass already (a) quarantined the slot machine behind `#if ENABLE_SLOT_MACHINE`, (b) renamed the app from "Tokiyo Casino" to "Tokiyo Cards", (c) removed an old Lotto/Mines module, (d) added a one-time 1000-chip first-launch grant. We now need to go further — fully delete, not quarantine, and re-skin.

Build settings: marketing version `1.01`, current build number `3` (CURRENT_PROJECT_VERSION). Deploy target iOS 17. Privacy manifest, privacy policy gist, and App Store metadata already exist.

---

## Tasks

### 1. Completely remove the slot machine game (delete, not quarantine)
- Delete `Tokiyo Casino/View/SlotViewController.swift` and `Tokiyo Casino/ViewModel/SlotViewModel.swift` entirely.
- Delete `Tokiyo Casino/Manager/DailySpinManager.swift` if only the slot/daily-spin path used it (audit first).
- Remove the `SlotVC` scene from `Main.storyboard` completely (the whole scene, not just the segue), and any remaining `toSlotVC` / slot references.
- Remove all slot-related assets from `Res/Assets.xcassets`: `slot machine`, `slotBanner`, `spinButton`, `spinButtonPressed`, `spin button`, `coinBox`, `backgroundCoin`, and anything else slot/spin/coin-specific.
- Remove the `K.toSlotVC` constant and any other dead slot constants in `Constants.swift`.
- Keep `CoinsManager` (poker uses the chip ledger) but make sure nothing references deleted slot code.

### 2. Completely remove the "Coino" / coin game remnants
- The original storyboard/home had a third "Coino" game (outlets like `imageTokioCoino`, `buttonPlayCoino`, `openDailySpinGame`). Remove any remaining traces of it — outlets, storyboard views, code paths — so only **Poker** and **Jackaroo** remain as games.

### 3. Replace ALL audio with copyright-free audio
- The current sound files (e.g. `Rattle.m4a` and any others in `Res/`) may be from the template/unknown sources. Replace **every** audio asset with **royalty-free / copyright-free / CC0** sounds (e.g. from Pixabay, Freesound CC0, or similar) appropriate for: button taps, card deal/flip, chip/bet, win, background loop.
- Source genuinely license-free audio, add the new files to the bundle, update `SoundManager` / `BackgroundSoundManager` references to the new filenames, and remove the old audio files.
- Note in the final summary exactly which sounds were added and their source/license so it can be documented for Apple.
- The sound for both poker and jackeroo should be minimal but should be at perfect moment, first think what sounds would we need and at which point than find those sound and than implement. This should be done carefully as sound is important

### 4. Re-skin the home screen (keep layout, change the look)
- Keep the **same overall layout/structure** (the two game cards: Poker, Jackaroo; the chip balance indicator; the logo slot) so the app still works, but give it a **visually distinct background and styling** so it no longer matches the public "Tokiyo Cards" Figma template. Make it look like its own app. Use your judgment on the new background/visual style — make it original and cohesive, not a copy of the template.
- Replace the template-derived background/decoration assets (`Cloud`, `Buildings`, `ww`, etc.) used on the home screen with original styling (generated gradients/shapes/original art are fine).
- The `TokiyoCards` logo image is the developer's own — keep it.

### 5. Replace the most recognizable shared template art
- The anime-character game icons `game1icon` and `game2icon` (a redhead and a blonde) are the most identifiable shared template assets and are very likely what Apple's image-matching flagged. **Replace them with original artwork/icons** (original illustrations, or clean original-styled icons for "Poker" and "Jackaroo"). Do not keep the template anime art.
- Audit all other imagesets for template-origin art and replace/remove as needed (`blueButton`, `Heads`, `Tails`, `Ellipse`, `brownBack`, etc.). Standard playing-card faces and generic UI shapes are fine; distinctive template illustrations are not.

### 6. House-keeping
- Bump `CURRENT_PROJECT_VERSION` (build number) from 3 → 4 in both Debug and Release configs.
- Make sure no code or storyboard references any deleted asset/file (search the whole project).
- Keep the poker engine, multiplayer (MultipeerConnectivity), Jackaroo, chip ledger, privacy manifest, and first-launch 1000-chip grant working.

### 7. Verify
- Build **Release** for an iPhone simulator — must succeed with no errors.
- Build **Debug** and run the test target — tests must pass.
- Launch in the simulator and confirm: home shows only Poker + Jackaroo with the new look, no slot/coin entry points, audio plays with the new sounds, solo poker and a poker hand work.

### 8. Summarize for the Apple appeal/resubmission
At the end, produce a short bulleted list of exactly what changed (slot/coin removed, audio replaced + sources/licenses, home re-skinned, template art replaced) so it can be pasted into the App Store Connect resolution/appeal thread and a new build can be uploaded.

---

## Constraints
- Do NOT touch the poker game logic, the Jackaroo game, or the multiplayer networking — those are original and must keep working.
- Do NOT change the bundle id (`com.mayank.Tokiyo-Casino`) — it isn't user-visible and changing it loses history.
- Everything that ships must be original or genuinely license-free; the whole point is to remove any shared/template-origin code, art, and audio.
- Work through it phase by phase and verify the build after each major deletion so nothing is left dangling.
