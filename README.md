# TokioCasino

An iOS casino app (UIKit). Games include Poker (with offline pass-and-play),
Slots, and **Jackaroo** — an offline board game.

## Jackaroo

A 4-player, 2-team marble-and-cards board game, playable solo against AI or
hot-seat (2–4 humans pass one device).

- **Headless, deterministic engine** (`Tokiyo Casino/Jackaroo/Game Engine/`):
  a pure legal-move generator + resolver driven by a seeded RNG, so every game
  is replayable from its seed + move log.
- **Three rulesets**: Jawaker **Basic**, **Complex** (King-13 capture, 5-on-any-
  marble), and **Community** (multi-marble 7s, red Jack/Queen, 4-then-5 deals),
  selectable on the menu and switchable from the in-game gear menu.
- **Heuristic AI** with four personalities (progress / capture / blockade /
  threat scoring).
- **Polish**: step-by-step marble animation (1×/1.5×/2× speed), sound + haptics,
  win confetti, VoiceOver turn announcements, and crash-recovery autosave with a
  "Resume game" entry on the menu.

Tests live in `Tokiyo CasinoTests/JackarooTests/`. Run them with parallel
testing disabled against a single booted simulator (see the test-running notes
in the project memory).
