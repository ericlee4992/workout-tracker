# Reference — the numbers and the tokens

From Apple's Human Interface Guidelines (fetched 2026-09-11 from the `tutorials/data/design/
human-interface-guidelines/*.json` endpoints) and this app's Look tokens (`Features/Design/Look/`). Quote these; do not
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

Default body 17 pt; minimum 11 pt. Avoid Ultralight, Thin and Light. Accessibility sizes run
AX1 (AccessibilityL) to AX5; this project gates at AccessibilityL and does not claim the
maximum. At those sizes: stack horizontally adjacent items, scale meaningful icons, keep the
hierarchy's order.

## Layout

- Reading order: top to bottom, leading to trailing; the most important item top-leading.
- Align to convey relation; indent to convey subordination; group with space, containers or
  separators — one device per relationship, not all three.
- Progressive disclosure: menus, nested views and scrollable sections rather than everything at
  once.
- Respect the safe area; controls float on Liquid Glass above content on iOS 26 — do not paint a
  solid bar under them.
- Hit region 44 × 44 pt minimum (the app's `.lookPrimary` style is 56 pt tall). Buttons near each
  other: distinguish by style, not size.
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

- One task; one sheet at a time. Cancel dismisses without saving; Done (or the commit verb)
  confirms; Back moves within a multi-step flow; never all three. Consider a full-screen cover
  or pushed screens for prolonged flows.

## Colour and appearances

- Apple asks for light and dark variants of every custom colour (Liquid Glass adaptivity). This app
  has both (D59): Settings → Appearance (System / Light / Dark), `Look.app(scheme)` picks the
  token set; a colour added to one set is added to the other.
- Contrast: 4.5:1 is the minimum; 7:1 is the target Apple asks you to strive for on custom
  pairs and small text. The measured Floodlight Light pairs are in `FinalLook.swift`'s header
  (text on ground / surface / raised; the action, heart, destructive, family and zone colours);
  the dark set's figures are high by construction (near-white on near-black) — measure any new
  pair, and composited colours (a tint over a surface) as composited.

## This app's tokens (`Features/Design/Look/Look.swift`, `FinalLook.swift`)

Read through `@Environment(\.look)`; `Look.app(scheme)` picks the set. The measured contrast of
every Light pair is in `FinalLook.swift`'s header.

| Token | Dark (`Look.floodlight`) | Light (`Look.floodlightLight`) | Use |
|---|---|---|---|
| `ground` | `#060708` | `#F2F3F5` | every screen's ground |
| `surface` | `#181A1E` | `#FFFFFF` | a panel, a card, a grouped row |
| `surfaceRaised` / `field` | `#22252A` | `#EBEDF0` | inner rows, fields, secondary fills |
| `hairline` | white 10 % | ink 10 % | separators and panel borders; never the only line that draws a shape |
| `action` / `live` | `#B25CFF`, `onAction` ink | `#7A2EE0`, `onAction` white | the one action / the live thing |
| `heartRate` | `#FF4F86` | `#C41D58` | heart rate |
| `destructive` | `#FF5E3A` | `#BF3510` | destruction |
| `textPrimary` / `textSecondary` / `textTertiary` | `#F4F6F8` / `#A4A9B1` / `#7F858E` | `#0B0C0E` / `#555A63` / `#62676F` | text |
| family colours | chest `#FFA03C`, back `#3D9EFF`, shoulders `#4DE0D4`, arms `#FFE15C`, legs `#84D65A` | deepened (≥ 4.7:1 on white) | the muscle families |
| zones | `zoneRamp[0…5]` | `zoneRamp[0…5]` | heart-rate zones |

Type: `look.font` — `largeTitle`/`title` Expanded Black, `heroNumber`/`statNumber`/`timer`
Expanded Heavy with monospaced digits, `cardTitle`/`sectionTitle` Expanded Heavy, body styles
standard width. Radii: `look.radius` (panel 16, row 10, field 8…); spacing: `look.space`.

Components (`Features/Design/Look/`): surfaces `.lookSurface(_:)`, `LookPanel`; buttons
`.lookPrimary` / `.lookSecondary`, `PillButtonStyle`, `StartCapsule`, glass chrome; `Chip`,
`LookList` / `LookRow`, `SegmentedPills`, `NumberStepperPill`, `EmptyStateView`, `SheetHeader`;
rings (`SetsRing`, `RestRing`, `FinishStatusRing`), charts, the week widget, muscle maps
(`MuscleMap`, `FamilyStrip`, `FamilyTally`); live pieces (`SetRowView`, `SetMarker`, `RestBar`,
`NewBestBadge`); `WrapLayout`; haptics `.setComplete`, `.restDone`, `.workoutStart`
(`Haptics.swift`). The Live Activity has its own literal copy of the palette
(`WorkoutTrackerWidget/Shared/WorkoutActivityViews.swift`: the widget cannot see `Look`).

## Captures

Each Floodlight area's capture tests (`WorkoutTrackerUITests/Floodlight*UITests.swift`) shoot light and
dark at Default and AccessibilityL with the same fixture and state; export attachments from the
result bundle and keep them in `work-record/redesign-floodlight/captures/<ticket>/`. The prototype's
reference shots are in `work-record/redesign-floodlight/reference/`. Touching a screen means retaking
its captures.
