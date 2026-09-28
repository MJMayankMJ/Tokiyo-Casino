# Tokiyo Cards — home & launch

## Intent

A calm shelf of games, with familiar anime characters and real playing cards layered in front of them. Marin remains the 5-3-2 character; Poker retains its orange-haired character. The app chrome follows the 5-3-2 table in both appearances. No floating tiles, city scenery, slot-machine props, or perpetual animations.

## Sources of truth

- `View/HomeDesign.swift`: layout, typography, game-button rendering and press state.
- `View/HomeViewController.swift`: screen assembly, wrapping game grid, chips, profile, onboarding and navigation.
- `View/HomeGameCatalog.swift`: game metadata, preview selection and controller factories. Add games here.
- `View/HomeCardPreview.swift`: foreground cards, clipped effect canvas, reset and cancellation.
- `TeenDoPaanch/UI/TDPMomentEffects.swift` and `Poker /UI/Components/PokerMomentEffects.swift`: existing game effects, with compact home entry points.
- `TeenDoPaanch/UI/TDPTheme.swift`: all home color roles.
- `Storyboard/Base.lproj/LaunchScreen.storyboard`: real iOS launch screen.
- `Res/Assets.xcassets/TokiyoMark.imageset`: scalable two-card/sparkle mark, light and dark variants. The sparkle echoes the existing minimal card backs. This replaces the home/launch branding; the installed app icon is unchanged.

## Tokens

| Role | Light | Dark | Source |
| --- | --- | --- | --- |
| Page | `#F1E8D2` parchment | `#101214` graphite | `TDPTheme.page` |
| Game/card surface | `#FFFDF7` | `#191B1D` | `TDPTheme.raised` |
| Artwork surface | `#F7EFD9` | `#222427` | `TDPTheme.raisedAlt` |
| Border | `#DACDA8` | `#202225` | `TDPTheme.hairline` |
| Primary text | `#1F1A12` | `#EDEFF1` | `TDPTheme.ink` |
| Secondary text | `#4A4231` | `#CED1D5` | `TDPTheme.inkSoft` |
| Brand/category | `#4B7B53` | `#79DD9F` | `TDPTheme.accent` |
| Play fill | `#C99540` | `#79DD9F` | `TDPTheme.primary` |
| Play ink | `#2E220D` | `#0C2416` | `TDPTheme.primaryInk` |

Launch requires asset-catalog colors because UIKit code does not run there. `HomePage`, `HomeInk` and `HomeSoftInk` duplicate their corresponding `TDPTheme` values and must stay in sync.

| Layout token | Value |
| --- | --- |
| `HomeDesign.pageInset` | 24 pt |
| `HomeDesign.sectionGap` | 28 pt |
| `HomeDesign.cardGap` | 16 pt |
| `HomeDesign.cardRadius` | 24 pt, continuous |
| `HomeDesign.cardInset` | 24 pt |
| `HomeDesign.maxWidth` | 820 pt, centered |
| `HomeDesign.wideBreakpoint` | 700 pt of available safe-area width |
| Card minimum height | 208 pt stacked; 270 pt side by side |
| Profile target | 44 × 44 pt |
| Header mark | 34 × 42 pt |
| Launch mark | 90 × 108 pt |

System typography scales with Dynamic Type: heading 34 semibold/largeTitle; game names 32 semibold/title1; body 14/subheadline; game detail 12/caption1; disclaimer 11/caption2. Header uses a fixed-size 24 pt bold brand wordmark and a Dynamic Type monospaced-digit chip count. No custom display font is needed.

## Layout and content

Home order: brand, virtual-chip balance, profile, short introduction, Poker button, 5-3-2 button, supporting copy and the existing virtual-chip disclaimer. Content scrolls vertically when needed; the safe area protects it from the status bar and home indicator. Wide windows use two equal-width game buttons per row. Additional games create additional rows; an odd final game retains one column’s width. Smaller windows stack the buttons. Tablet content is capped at `maxWidth` to keep it readable.

Each entire game tile is one button. Its Play pill is a visual affordance within that target. Character artwork is 55% of the tile width (previously 62%) and blends toward the opaque copy surface. Cards sit above the portrait and its fade, creating foreground depth. Their effect viewport occupies the rightmost 49% of the tile and clips flashes, particles, and callouts inside the artwork. Artwork crops below the portrait without changing the tap area. Decorative image views ignore touches.

At accessibility text sizes, portraits are hidden, copy receives the full inner card width, and the header stacks vertically. Card heights grow with their content. Long text wraps rather than being ellipsized; game names use local literal strings and no character limit. Profile names retain the existing app-wide 16-character policy; home shows only the avatar. Visual balances use locale-aware compact notation; VoiceOver reads the full localized amount.

Launch is a static centered brand group, 10 pt above the screen midpoint. It uses native labels and vector artwork. iOS controls its duration: no fake progress, minimum wait, or extra splash overlay.

## Interaction and states

| Component/state | Behavior |
| --- | --- |
| Game button/default | Theme surface and border, character, title and Play affordance |
| Pressed | 0.985 scale and 0.82 opacity; 140 ms transition, interruptible |
| Reduced Motion | Opacity press feedback; reveal final cards for 150 ms and route, without throws, shakes, particles or flashes |
| Poker activation | Show K♠ and A♠ as two angled hole cards, with 10♠, J♠ and a face-down Q♠ in a smaller row above; flip Q♠ to complete the royal flush; reuse the existing score pops, tremble, royal-flush rays, foil sheen and confetti; push existing `MenuViewController` after about 1.16 s |
| 5-3-2 activation | Start with K♠ and 10♠; play J♥ above them, reuse the existing slam and FIRST CUT burst; push existing `TDPEntryViewController` after about 0.98 s; retain system back navigation |
| Repeated activation during preview/navigation | Ignore until home appears again |
| Return / profile / background / width breakpoint | Cancel pending work and restore the initial cards; stale completions cannot navigate |
| Profile activation | Present existing profile sheet |
| First launch | Preserve existing full-screen profile onboarding and one-time 1,000-chip grant |
| Balance update | Refresh on appearance and coin-change notification; no layout-bouncing animation |
| Theme change | Update UIKit dynamic colors and resolved gradient/border colors in place |
| Missing artwork | Game copy and button remain available on themed surface |
| No saved stats | Show zero chips until the existing data source updates |
| Offline/slow network | Both screens use bundled resources; no network or loading dependency |
| Empty catalog / disabled / loading / error | No home loading/error state: catalog entries describe installed games; game-specific states remain in their entry screens |
| Hover / swipe / long press | Native pointer behavior; vertical scroll only; no custom gestures |

## Accessibility

Use native UIKit accessibility rather than ARIA. The brand is one text element; the balance reads the full count with “virtual chips.” Profile is a 44 pt control. Both game buttons expose button traits, game name, subtitle, and “Choose how to play.” Portraits and duplicate Play text are decorative. Reading/focus order follows the visual hierarchy, with Poker before 5-3-2. Standard Switch Control and Full Keyboard Access activate the native controls. No unsolicited screen-reader announcement occurs for decorative art or balance refreshes. Intro title has heading semantics. Secondary copy uses `inkSoft`, including the always-visible disclaimer.

## Verification

`HomePresentationTests` exercises the real Main storyboard, entry into both games, return to home, profile presentation, and the 5-3-2 back button. Its layout-review test exports light/dark phone, compact-phone, tablet and launch renders plus an accessibility-size render. Review images are attached to the Xcode test result and written to `/tmp/tokiyo-home-review` for local inspection. Interaction checks cover initial card state, short effect duration, cancellation, duplicate taps, backgrounding, and a fixture catalog of five games to verify row wrapping. Active-cut and active-royal renders capture the effect mid-play.

### Result

The static redesign was validated on iPhone 17 / iOS 26.2. The interaction update adds a fresh focused test run covering the preview effects and catalog expansion. The render matrix covers 320 × 568, 402 × 874 and 834 × 1194 pt, light/dark appearances, and the largest accessibility text size. Phone and launch previews are saved in `previews/`. Tablet and compact sizes are rendered in a test-host window; they are not separate physical-device runs.

## Art provenance

Bundled character portraits were generated with the built-in image-generation tool, using the existing `game1icon` and `game2icon` as edit references. Original assets remain intact. Final assets:

- `Res/Assets.xcassets/HomeMarin.imageset/marin.png`
- `Res/Assets.xcassets/HomePokerGirl.imageset/poker-girl.png`

The vector Tokiyo mark is implemented directly as SVG. Final character prompts are preserved in `ART-PROMPTS.md`.
