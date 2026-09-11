# Reference — the numbers and the tokens

From Apple's Human Interface Guidelines (fetched 2026-09-11 from the `tutorials/data/design/
human-interface-guidelines/*.json` endpoints) and this app's `Theme.swift`. Quote these; do not
re-derive them.

## iOS text styles at the default (Large) size

| Style | Weight | Size | Leading | Emphasized |
|---|---|---|---|---|
| Large Title | Regular | 34 | 41 | Bold |
| Title 1 | Regular | 28 | 34 | Bold |
| Title 2 | Regular | 22 | 28 | Bold |
| Title 3 | Regular | 20 | 25 | Semibold |
| Headline | Semibold | 17 | 22 | Semibold |
| Body | Regular | 17 | 22 | Semibold |
| Callout | Regular | 16 | 21 | Semibold |
| Subhead | Regular | 15 | 20 | Semibold |
| Footnote | Regular | 13 | 18 | Semibold |
| Caption 1 | Regular | 12 | 16 | Semibold |
| Caption 2 | Regular | 11 | 13 | Semibold |

Default body 17 pt; minimum 11 pt. Avoid Ultralight, Thin and Light. Test the largest
accessibility size (AXL and up): stack horizontally adjacent items, scale meaningful icons, keep
the hierarchy's order.

## Layout

- Reading order: top to bottom, leading to trailing; the most important item top-leading.
- Align to convey relation; indent to convey subordination; group with space, containers or
  separators — one device per relationship, not all three.
- Progressive disclosure: menus, nested views and scrollable sections rather than everything at
  once.
- Respect the safe area; controls float on Liquid Glass above content on iOS 26 — do not paint a
  solid bar under them.
- Hit region 44 × 44 pt minimum. Buttons near each other: distinguish by style, not size.
- Size classes, not device type, decide layout.

## Buttons

- One or two prominent (filled, accent) buttons per view.
- Prominent = the most likely action; primary role never destructive.
- Label starts with a verb where a short label beats an icon ("Start Empty Workout", "Add Gym…").
- Always a press state.

## Lists

- Text-heavy collections are lists; widely varying sizes or many images are collections.
- Grouped style (headers, footers, spacing) for hierarchy; plain for a single flat set.
- Row: leading image, short text; a disclosure indicator navigates, an info button explains.
- Reorder and swipe live on rows.

## Tab bar

- Navigation only; never actions. Up to five tabs, always visible except under a modal; filled
  SF Symbols; one-word labels; a badge only for critical information.
- iOS 26: floats on glass above content; may minimise on scroll with an accessory.

## Sheets

- One task; one sheet at a time; Cancel pairs with Done; Back for a multi-step flow; never all
  three. Long or multi-step tasks: a full-screen cover or pushed screens.

## Colour and dark appearance

- Semantic colours adapt; custom colours need both variants even in a dark-only app (Liquid
  Glass adaptivity). This app is dark only by decision (D54); the window forces `.dark`.
- Contrast: 4.5:1 minimum; 7:1 for custom foreground/background pairs and small text.
- Dark Mode backgrounds are base and elevated: sheets and modals sit on the elevated one.
- SF Symbols wherever possible; separate light/dark artwork only when an asset fails in one.
- Same colour, same meaning, everywhere.

## This app's tokens (`Features/Design/Theme.swift`, `Assets.xcassets/Colors`)

| Token | Value | Use |
|---|---|---|
| `SurfaceBackground` | `#0B0D10` | every screen's ground |
| `SurfaceCard` | `#171B21` | a card, a grouped row |
| `SurfaceElevated` | `#222831` | a sheet, a menu |
| `SurfaceFill` | `#2B323C` | secondary buttons, the day tile |
| `Hairline` | white 7 % | separators only |
| accent | `#FFB45E` | the one action / the live thing; `OnAccent` `#15110B` text on it |
| `Warmup` | `#E9D875` | warmup sets |
| `Danger` | `#FF6B76` | heart rate, destructive |
| `UnitKg` / `UnitLb` / `UnitMixed` | | unit chips |
| `TextPrimary` / `TextSecondary` / `TextTertiary` | `#F6F3EC` / `#B5B9C2` / `#7F8793` | text on ink |
| Radius | card 24, inner 16, field 10 | |
| Space | 4 / 8 / 12 / 16 / 24 | |
| `hero` | largeTitle rounded black | one number or title per screen |
| `stat` | title2 rounded bold | a figure |
| `cardTitle` | headline bold | a row or card title |
| `label` | caption2 semibold | a small label (sentence case unless it is a unit) |

Components: `.card(.standard | .elevated)`, `Chip(tint:selected:)`, `UnitChip`, `StatTile`,
`ProgressRing`, `EmptyState(title:symbol:)`, `MuscleIcon(group:)`, `WrapLayout`,
`.buttonStyle(.primary | .secondary)`; haptics `.setComplete`, `.restDone`, `.workoutStart`
(`Haptics.swift`).

## Captures

`WorkoutTrackerUITests/RedesignScreenshotUITests.swift` — one test per screen, default size and
AccessibilityL; export with `.scratch/ui-redesign/export-shots.py`; the record lives in
`.scratch/ui-redesign/screenshots/<ticket>/`.
