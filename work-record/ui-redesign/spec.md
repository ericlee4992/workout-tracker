# UI redesign — bold, dark, card-based

## Context

The user (2026-09-10): "the app seems a bit boring, with mostly texts and it essentially doesn't
have a clean UI design." Every screen today is a stock SwiftUI `List`/`Form` with secondary grey
text; there is no design system. The user's direction, chosen 2026-09-10:

- **Style:** bold, dark, card-based (Apple Fitness / Hevy family): rounded cards, big numbers,
  one accent colour, coloured chips.
- **Scope:** the whole app, shipped screen by screen with screenshots to react to, starting with
  the active workout screen, then Start, History, Gyms, Exercises, Templates, Settings.
- **Colour:** dark only, one warm accent (orange/coral) for actions and completed sets.
- **Richness:** muscle-group colours and icons, stat tiles and progress rings, motion
  (set-complete animation, haptics, animated rest ring), illustrated empty states.

Working method (memory: UI-first): render each screen with sample data, take screenshots, get the
user's reaction, then move on. Every visible string and accessibility identifier the 46 XCUITests
depend on stays, so the suite remains the regression net.

## Constraints found (docs, tests, build settings)

- **iOS 26.0 is the real deployment target** (`IPHONEOS_DEPLOYMENT_TARGET = 26.0`, D42; CLAUDE.md's
  "iOS 17+" line is stale — fix it in passing). iOS 26 APIs, materials and the new tab bar are
  usable without availability gates. No third-party dependencies (CLAUDE.md).
- **There is no design system.** `Assets.xcassets` holds only the app icon and one `AccentColor`
  (teal-green, no dark variant). Everything is semantic colours, system text styles, one hardcoded
  7 pt badge font, ~20 `.monospacedDigit()` sites. Dark mode has never been designed or screenshot.
- **Copy policy (milestone 9 ticket 06, D52)**: no explanatory paragraphs; one short line only for a
  consequence; plain numbers, no ≈, no "(estimated)". The redesign adds shape and colour, not words.
- **Locked behaviours the visuals must not disturb**: one-tap confirm / repeat set, rows created
  only deliberately (SPEC speed bar); D33 confirm tap on scans; D53 Ask AI one button; D26/D13/D22
  rest rules; bar-mode caption `45 + 45 × 2 = 135 lb` (D39/D40); superset A/B adjacency (D48);
  finish summary 2×2 tiles + Apple-Fitness-shaped HR graph; chart tooltip in a row, not floating.
- **Tests pin visible strings**: tab names `Workout` / `History` / `Gyms` / `Exercises`; buttons
  "Scan again", "Delete Machine", "Edit Machine…", "Rename Model…", "Presets…", "Progress…",
  "Delete Workout", "Discard Workout", "View in History", "Cancel", "Done", "Close"; texts "What
  the camera read", "What AI read", "No workouts yet", "No machines yet", "Nothing deleted",
  "Zones would use", "AI calls: N", "1 exercise · 1 set", "wasn't saved", "70 kg × 8"; unit chip
  label exactly `kg`/`lb`; placeholders "Manufacturer", "Model", "City (optional)". Keep all of
  them and every `accessibilityIdentifier`. The 26 named screenshot attachments in the UI tests
  are the before/after review surface (the user prefers screenshots to descriptions — STATE).
- **Known layout defects to fix on the way** (STATE): preset chips' one-handed reachability
  mid-set; the bar-mode PREVIOUS-vs-plates caption reading as two numbers.
- Fixtures for sample-data screenshots exist: `-uiTestChartHistory`, `-uiTestHeartRateHistory`,
  `-uiTestScanFixture`, `PROTO_SCREEN=gyms|exercises`.

## What exists (inventory)

- **Four tabs** (`App/RootView.swift`): Workout, History, Gyms, Exercises. Templates are a section
  inside the Workout tab (`Features/Start/StartWorkoutView.swift`); Settings and Export are two
  sections appended to the Gyms list (`Features/Settings/AppSettingsSection.swift`,
  `ExportSection.swift`). 44 view files, ~9.5 k lines, every screen a stock `List`/`Form`.
- **The screen the user lives in**: `Features/ActiveWorkout/ActiveWorkoutView.swift` (List(.plain)
  kept only for `.onMove`; header gym + timer; `HeartRateBar`; `ExerciseEntryCard` per entry;
  Add Exercise / Add by Machine footer; `RestTimerBar` in the bottom safe-area inset) and
  `ExerciseEntryCard.swift` (890 lines: card, machine pill, preset chips, SET / PREVIOUS / WEIGHT /
  REPS headers, `SetRowView` with a manual swipe-to-delete ZStack, set-type marker W/#/F/D, weight
  field + `UnitBadge`, reps field, green `checkmark.circle.fill`, bar-mode total caption, Add Set).
- **Finish**: `WorkoutFinishedSheet.swift` already has a 2×2 `statGrid` of tinted tiles and the
  shared `HeartRateSummarySection` (Swift Charts floating bars, Apple-Fitness shape).
- **History**: month-sectioned list; calendar sheet of 40 pt circles; progress chart with a manual
  drag overlay and the selection in a row.
- **Shared visual pieces today**: `UnitBadge`, `WorkoutUnitBadgeView`, preset chip, HR zone chip,
  superset badge, `BrowseMenuOption`, `Format`. Nothing else is shared; radii 14/12/10/8/6 inline.
- **Fixtures** render every important screen with sample data (see Constraints).

## Decisions taken with the user (2026-09-10)

- Bold dark card-based; dark only; one warm accent; whole app, workout screen first.
- Richness: muscle-group colours + icons, stat tiles + rings, motion + haptics, illustrated
  (SF-Symbol) empty states.
- **Settings gets its own screen**, opened by a gear button on the Workout tab; the three UI tests
  that find Settings under Gyms are rewritten in the same ticket.
- **An app icon** (the slot is empty today): a generated dark tile with the accent and a dumbbell
  glyph, rendered by a script — not artwork, but not blank.
- Record as **D54**: dark-only visual system, one accent, tokens in `Features/Design/`, no new
  explanatory copy (D52 / milestone-9 ticket 06 stand).

## Approach

Effort folder `work-record/ui-redesign/` (`spec.md`, `issues/01..09`, `screenshots/`). One branch per
ticket off `main` (`ui-redesign-NN`), fast-forward merge after Codex says "clear", push both. UI-first:
every ticket ends with screenshots exported from the simulator for the user before the next starts.

### Ticket 01 — design system + root (no layout change; everything goes dark and coral)

New files under `WorkoutTracker/Features/Design/` (buildable folders — just create them):
`Theme.swift` (tokens), `MuscleGroupStyle.swift`, `CardStyle.swift` (`.card()` / `.card(.elevated)`),
`Chip.swift` (`Chip`, `UnitChip`), `StatTile.swift`, `ProgressRing.swift`, `ButtonStyles.swift`
(`.primary` / `.secondary`), `EmptyState.swift`, `Haptics.swift` (`SensoryFeedback` presets).
Colour sets under `Assets.xcassets/Colors/` (Any appearance only):

| Asset | Hex | Role |
|---|---|---|
| `AccentColor` (name is pinned by `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`) | #FF7A3D | the one warm accent: primary buttons, completed sets, selected chips, rest ring, tab tint |
| `OnAccent` | #0A0A0C | text on accent fills (white on coral is only 2.6:1) |
| `SurfaceBackground` / `SurfaceCard` / `SurfaceElevated` / `SurfaceFill` | #0A0A0C / #1A1A1E / #26262B / #303036 | screen / cards / sheets & bars / fields & unselected chips |
| `Hairline` | white 8 % | card borders |
| `TextPrimary` / `TextSecondary` / `TextTertiary` | #F5F5F7 at 100 / 62 / 38 % | |
| `Danger` / `Warmup` / `Drop` | #FF453A / #FFD60A / #BF5AF2 | failure, warmup (off orange so it never reads as the accent), drop |
| `UnitKg` / `UnitLb` / `UnitMixed` | #5AC8FA / #63E6BE / #BF5AF2 | unit chips stay cool so the accent stays unique |

Tokens: radii card 20 / inner 12 / field 10 / chips Capsule; spacing 4/8/12/16/24, card padding 16;
fonts `hero` (largeTitle rounded bold, monospaced digits), `stat` (title2 rounded bold), `cardTitle`
(headline), `label` (caption semibold, tracking 0.6, uppercase headers); everything else semantic
so Dynamic Type survives. The one hardcoded 7 pt font (`ExerciseEntryCard.swift:728`) → `.caption2`.
Success = accent. `SetType.markerColor` (`ExerciseEntryCard.swift:19`) rewritten to tokens.

Muscle-group map (all 14 catalog groups; hex in code, they are data not theme): Chest #FF5E7A,
Shoulders #FFD84D, Triceps #B48CFF, Back #4FA3FF, Biceps #7B8CFF, Forearms #8FA3B8, Core #2ED3C6,
Quads #43C463, Hamstrings #A3E048, Glutes #FF8AD8, Calves #7FE3B0, Hips #D9A066, Neck #A0A0B0,
Full Body #F5F5F7, unknown #6E6E78 — each with an SF Symbol; `MuscleIcon(group:)` = 36 pt rounded
square, 18 % tint fill. `ThemeTests` asserts every catalog group has a non-fallback entry and every
symbol resolves (`UIImage(systemName:)`).

Components consolidate what exists: `UnitBadge` (`StartWorkoutView.swift:346`) keeps its type and
call sites, body becomes a `Chip` whose only child is `Text(unit.rawValue)` — the `setRow.unit` label
must stay exactly `kg`/`lb`. Preset chip (`ExerciseEntryCard.swift:198`), zone chip
(`HeartRateBar.swift:157`, keeps its 5-bar meter), superset badge (`:283`), `WorkoutUnitBadgeView`
→ `Chip`. `StatTile` keeps the `.accessibilityElement(children: .combine)` + label + id pattern
from `WorkoutFinishedSheet.swift:224–243`. `PrimaryButtonStyle`: accent fill, `OnAccent` label,
52 pt, radius 14, 0.97 scale when pressed. No shadows anywhere (muddy on dark, costs GPU).

Root: `WorkoutTrackerApp.swift` → `RootView().preferredColorScheme(.dark)` (window level, so
alerts, menus, keyboard and every sheet follow); `RootView` `.tint(accent)`; tab names untouched.
**Baseline first**: commit `WorkoutTrackerUITests/RedesignScreenshotUITests.swift` (one test per
screen, each ending in a named `XCTAttachment`) and export `screenshots/before/` from `main` before
any visual change. Also fix CLAUDE.md's stale "iOS 17+" line to iOS 26 (D42).

### Ticket 02 — active workout (`ActiveWorkoutView.swift`, `ExerciseEntryCard.swift`, `RestTimerBar.swift`, `HeartRateBar.swift`)

- Header: gym as a chip, elapsed time in `hero`, completed-set count as an accent chip.
- `HeartRateBar` → `.card()`, bpm in `stat` red, zone `Chip`; ids `hrBpm`/`hrZone`/… unchanged.
- `ExerciseEntryCard` → `.card()` with `MuscleIcon` leading the title; machine/bar pills → chips.
- **Reachability fix**: preset chips move from above the headers to just above "Add Set" (under
  the thumb); ids `presetChip.*` unchanged.
- Set rows: set number in a 28 pt circle (accent + `OnAccent` digit when completed); fields on
  `SurfaceFill` radius 10; completed row washed `accent.opacity(0.10)` over the row's OPAQUE
  background (load-bearing for the manual swipe, `:515`); checkmark accent with a spring scale
  0.8→1 and `.sensoryFeedback(.setComplete)`. **Swipe mechanics untouched**: `swipeDeleteWidth`
  88, `DragGesture(minimumDistance: 14)`, `setRow.previous` stays a single `Text`.
- **Bar-mode two-numbers fix**: the weight field, unit chip and the `setRow.total` caption become
  one `SurfaceFill` block so "plates in, total out" reads as one thing; `setRow.previous` stays
  the last total, dimmed. Strings unchanged (`45 + 45 × 2 = 135 lb`).
- Footer: Add Exercise `.primary`, Add by Machine `.secondary`.
- `RestTimerBar` → elevated bar with a 44 pt accent `ProgressRing`, time in `stat`, "+15s"
  secondary, "Skip" primary; `.sensoryFeedback(.restDone)` on expiry.
- `List(.plain)` + `.onMove` + clear row backgrounds stay exactly as they are.
Compare: `bar-mode-card`, `heart-rate-bar`, `workout-named-live`. Flags `-uiTestReset -uiTestHeartRate`.
Gates: CoreLoop, Barbell, ExercisePreset, HeartRate, WorkoutName, DumbbellCounterpart.

### Ticket 03 — finish summary (`WorkoutFinishedSheet.swift`, `HeartRateSummarySection.swift`)

A 120 pt `ProgressRing` (sets completed / logged) with the duration inside; `statGrid` → `StatTile`s
(time accent, calories #FF5E7A, avg HR `Danger`; ids and combined labels unchanged); volume/sets
rows become tiles; "Time in zones" → a stacked bar by zone colour with the durations under it;
HR chart bars `Danger`→accent gradient, grid `Hairline`; View in History `.primary`, Save as
Template `.secondary`. Compare `workout-summary`, `finish-heart-rate`. Gates: HeartRate,
HeartRateSummary, CoreLoop (`1 exercise · 1 set`, `wasn't saved`).

### Ticket 04 — Start (`StartWorkoutView.swift`, `TemplateEditorSheet.swift`) + the gear button

Resume banner → accent-bordered card with a pulsing dot; gym picker `Menu` label → gym card
(`gymPicker` stays on the Menu); "Start Empty Workout" → full-width `.primary` hero with
`.sensoryFeedback(.workoutStart)`; templates → cards with up to five `MuscleIcon`s. **Gear button**
in the toolbar (`openSettings`) pushes `SettingsView` (ticket 05 builds it; this ticket adds the
button behind a placeholder). Gates: CoreLoop setup, HeartRate, MachineDeletion.

### Ticket 05 — Settings screen (`Features/Settings/SettingsView.swift`, new)

Moves `AppSettingsSection` and `ExportSection` out of the Gyms list into a `SettingsView` (a
grouped list of cards: Units & rest, Heart rate zones, Ask AI, History update note, Export).
Ids unchanged (`heartRateZonesSettings`, `askAISettings`, `dumbbellMoveNote`, `exportSummary`,
`exportCSV`, …). **Same commit rewrites the tests that navigate there**: `HeartRateUITests`
(zones from settings), `AskAIUITests.testAPreselectedPlateNeverOffersAskAI` (the `askAISettings`
"On" check), `ExportUITests` — Workout tab → `openSettings` instead of Gyms tab. `GymsView`
loses the two sections. Screenshot `05-settings`.

### Ticket 06 — History (`HistoryView`, `WorkoutDetailView`, `HistoryCalendarSheet`, `ExerciseProgressView`)

Rows → cards (`historyWorkoutRow` stays on the row), month headers as `label`; empty state →
`EmptyState("No workouts yet")`; calendar: keep 40 pt `Button`s with `calendarDay.*` (and the
non-button empty day), workout day = accent fill, today = hairline ring; detail sections as cards
with `MuscleIcon`, set lines' strings untouched; charts: accent `LineMark` (catmullRom) + accent
`AreaMark` gradient, grid `Hairline`, the manual `chartOverlay` drag untouched and card padding
≤ 16 so the tooltip test's normalized drag still lands. Compare the nine history/chart shots.
Gates: HistoryCalendar, ProgressChart, ProgressChartTooltip, HistoryEditing, HeartRateSummary.

### Ticket 07 — Gyms (`GymsView.swift`, `MachineDeletion.swift`, `ScanMachineLabelSheet.swift` tokens only)

Gym rows → cards with a machine-count chip; `GymDetailView` machine rows → cards with the model
as a chip; Add Machine `.primary`; "Deleted machines (N)" stays a `NavigationLink`; "No machines
yet" → `EmptyState`; pickers/editors get chips and button styles only; the scan sheet takes tokens
only (all its strings and ids untouched). Compare `delete-machine-confirmation`, `scan-results`,
`ask-ai-*`, `suggest-exercises`, `equipment-counterpart`. Flags `PROTO_SCREEN=gyms`,
`-uiTestReset -uiTestScanFixture -uiTestAskAI`. Gates: MachineDeletion, ScanMachineLabel, AskAI,
DumbbellCounterpart.

### Ticket 08 — Exercises + pickers/sheets (`ExercisesView`, `NewExerciseSheet`, `ExercisePresetsSheet`, `EditExerciseLoadTypeSheet`, `ExercisePickerSheet`, `AddByMachineSheet`, `MachinePickerSheet`, `BarPickerSheet`, `PreviousPerformanceSheet`, `ExerciseRestSettingsSheet`, `MaxHeartRateSheet`)

`MuscleIcon` + equipment-tag chips on every exercise row; filter ids and the "Search exercises"
prompt stay; sheets' primary actions `.primary`. Flags `PROTO_SCREEN=exercises -uiTestReset`.
Gates: ExercisePreset, DumbbellCounterpart, CoreLoop (create-from-search).

### Ticket 09 — empty states, app icon, Live Activity tint, docs

Every remaining `ContentUnavailableView` / "No … yet" → `EmptyState` with byte-identical strings.
**App icon**: `scripts/render-app-icon.py` (PIL, already installed) draws a 1024² #0A0A0C tile
with a coral rounded shape and a dumbbell built from rectangles/circles → `AppIcon.appiconset/AppIcon.png`
+ `filename` in its `Contents.json`; committed so the build is reproducible. Live Activity
(`WorkoutTrackerWidget/WorkoutActivityView.swift`): background #1A1A1E and accent #FF7A3D as hex
literals (the widget target does not share the asset catalog). SPEC "Visual design" paragraph,
D54 finalised, STATE, `screenshots/` before/after gallery referenced.

## Screenshot workflow (every ticket)

```sh
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=WT-iPhone' build-for-testing
xcodebuild test-without-building -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=WT-iPhone' \
  -only-testing:WorkoutTrackerUITests/RedesignScreenshotUITests/test02_activeWorkout \
  -only-testing:WorkoutTrackerUITests/BarbellUITests \
  -resultBundlePath work-record/ui-redesign/results/02.xcresult
xcrun xcresulttool export attachments --path work-record/ui-redesign/results/02.xcresult \
  --output-path work-record/ui-redesign/screenshots/02-raw     # then rename via manifest.json
```
`results/` gitignored; `screenshots/*.png` committed (the review record). One extra run per ticket
at `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL` for Dynamic Type.
Show the PNGs to the user (SendUserFile) before the next ticket.

## Risks and containment

- **Test breakage** — each ticket names its gate classes; run them before every commit, the full
  suite detached (`nohup … &`, ~25 min) before merge. Never put an identifier on a multi-child
  container; combined elements keep `.accessibilityElement(children: .combine)` first.
- **Swipe-to-delete on set rows** — opaque row background, `swipeDeleteWidth` 88, gesture
  threshold 14, `setRow.previous` a single `Text` at the left: unchanged.
- **Chart drag** — no gesture-bearing wrappers around the `Chart`; card padding ≤ 16.
- **Copy policy** — Codex's standing check on every diff: no new `Text("…")` literal except
  numbers/symbols; empty states and chips reuse existing strings.
- **Dark-only vs system light** — fixed hex tokens plus the window-level scheme; recorded as D54.
- **Dynamic Type** — semantic fonts only; one AXL screenshot per ticket.
- **List performance** — stroke + fill cards, no shadows/blur.
- **Settings move** — tests rewritten in the same commit as the move (ticket 05).

## Verification per ticket

1. `xcodebuild build` clean. 2. Unit suite (698 + `ThemeTests`). 3. The ticket's gate UI classes +
`RedesignScreenshotUITests` for its screens; PNGs exported, committed, sent to the user. 4. Full UI
suite detached before merge (46 + new, green). 5. Codex cross-review in a visible Orca terminal
(`codex "$(cat prompt)"`, watch the report file) to "clear"; Resolution in the ticket; STATE/SPEC/
DECISIONS updated; fast-forward merge; push both.
