# History feature — complete UI inventory for the redesign

Scope: `WorkoutTracker/Features/History/*` plus the shared components the History screens
render (`CardioSummaryCard`, `CardioRouteMap`, `CardioDistanceSheet`, `ZoneTimeCard`,
`StatTile`, `EmptyState`, `Chip`/`UnitChip`, `SaveAsTemplateFlow`, `ExercisePickerSheet`).
Facts come from source at HEAD `a0364f2` on branch `ericlee4992/redesign-visual-proposal`.
Lines marked **Judgement** are UX opinions. Everything else was read from code.

Files (lines):
- `Features/History/HistoryView.swift` (258): tab root, list, row, unit badge, delete dialog, calendar wiring
- `Features/History/HistoryCalendarSheet.swift` (181): calendar sheet
- `Features/History/WorkoutDetailView.swift` (533): workout detail and all its dialogs and sheets
- `Features/History/ExerciseProgressView.swift` (465): per-exercise progress chart
- `Features/History/HeartRateSummarySection.swift` (164): heart-rate bar graph (also used by the finish sheet)
- `Features/History/EditLoggedSetSheet.swift` (109): set editor (edit or add)
- Shared: `Features/Cardio/CardioViews.swift` (`CardioSummaryCard` 212, `CardioDistanceSheet` 251,
  `CardioRouteMap` 298), `Features/Design/ZoneTimeCard.swift`, `StatTile.swift`, `EmptyState.swift`,
  `Chip.swift`, `Theme.swift`, `CardStyle.swift`, `ZoneColors.swift`,
  `Features/Templates/SaveAsTemplateFlow.swift`, `Features/ActiveWorkout/ExercisePickerSheet.swift`
- Domain: `HistoryRendering.swift` (titles, stats line, unit badge), `WorkoutCalendar.swift`,
  `HistoryEditing.swift`, `WorkoutSummary.swift`, `ProgressSeries.swift`, `Cardio.swift`,
  `HeartRateZones.swift`

Existing captures (current look): `work-record/ui-redesign/screenshots/06/`
(`05-history.png`, `05-history-axl.png`, `05-detail.png`, `05-detail-axl.png`,
`05-detail-heart-rate.png`, `05-chart.png`, `05-calendar.png`, `08-empty-history.png`) and
`work-record/history-templates-and-zones/screenshots/` (`14-05-detail-heart-rate*.png`,
`history-13-menu*.png`, `history-13-alert*.png`, `history-13-confirmation*.png`). Note that
`05-detail.png` predates ticket 11 and still shows a muscle icon beside the exercise name,
which the code no longer draws.

---

## 0. Current visual system these screens use (D54)

- Dark only. Tokens (asset hex): background `#0B0D10`, card `#171B21`, elevated `#222831`,
  fill `#2B323C`, hairline white 7%, text `#F6F3EC`, secondary `#B5B9C2`, tertiary `#7F8793`,
  accent amber `#FFB45E` with onAccent `#15110B`, danger `#FF6B76`, warmup `#E9D875`,
  drop `#B8A1EE`, unit kg `#97C7EE`, unit lb `#A8CDBF`, unit Mixed `#B8A1EE`.
- Heart-rate zone colours (`ZoneColors.swift`): Warm-up = tertiary, Z1 `#8ABCE5`, Z2 `#80CABE`,
  Z3 `#A5CF9A`, Z4 = accent, Z5 = danger.
- Calorie tint: History uses `#FF5E7A` (inline literal). The finish sheet uses `#F4939C`.
- Type: `Theme.hero` largeTitle rounded black; `Theme.stat` title2 rounded bold;
  `Theme.cardTitle` headline bold; `Theme.label` caption2 semibold.
- Radii: card 24, inner 16, field 10. Spacing: 4/8/12/16/24.
- `.card()` gives a card fill, 24pt radius and a 1pt hairline stroke.
- Buttons: `.secondary` has a fill background, a 44pt minimum height and inner radius, and
  lowers opacity when pressed. `.primary` is amber, 52pt high, and scales to 0.97 on press
  unless Reduce Motion is on. History uses only `.secondary`.
- **Motion and haptics in History: none.** No `withAnimation`, `.animation`, `.transition`,
  `sensoryFeedback`, `TimelineView`, `presentationDetents`, `ViewThatFits`, `@ScaledMetric`,
  `.searchable`, `.refreshable` or `.contextMenu` appear in `Features/History`. Reduce Motion is
  never read there. Every sheet opens at the default full-height detent.
- Constraints the redesign inherits:
  - Copy policy: no explanatory paragraphs; one short consequence line at most.
  - D52: plain numbers, no ≈ or "(estimated)".
  - D23: history is drawn only from snapshot strings.
  - D47/D50: edits are marked.
  - D54 says the redesign "adds shape, colour and motion, never words" and keeps every visible
    string and accessibility identifier the UI tests read. The user now explicitly allows a
    theme change. Whether the string and identifier rule still binds is a decision to reopen,
    not assume.

---

## 1. History list — `HistoryView`

- **File:** `HistoryView.swift:4–171`. Row view `WorkoutSummaryRow`: `:178–236`.
  Badge `WorkoutUnitBadgeView`: `:239–250`.
- **Presentation:** tab root. The second tab in `RootView.swift:43`, labelled "History" with
  SF Symbol `clock.arrow.circlepath`. It owns its own `NavigationStack(path:)` with
  `[Workout]` as the path.
- **How it is reached:**
  - Tapping the tab.
  - "View in History" on the post-finish receipt (`RootView.swift:76–81`) selects the tab and
    sets `historyTarget`. `openTarget()` (`:165–170`) then replaces the path with that workout,
    running on appear and on change of target. A deleted or unfinished target is dropped
    silently.
- **Job:** a reverse-chronological list of finished workouts (`@Query` filters
  `finishedAt != nil`, sorted by `startedAt` descending), grouped by month. Opens detail.

### States
1. **Empty** (`workouts.isEmpty`, `:53–64`). A centred `EmptyState`: a 128pt ring, a 96pt amber
   8% disc, the `clock.arrow.circlepath` glyph in amber, and a small `sparkle` offset to the
   top-right. Title **"No workouts yet"**, subtitle **"Finished workouts show up here."**
   (subheadline, secondary). The Calendar toolbar button is still present.
2. **List** (`:66–107`). A plain `List` with a hidden scroll background on the ink background.
   Sections are months.
3. **Accessibility sizes.** The row's day tile stacks above the text and the title may wrap to
   3 lines (`:183–190, :211`).
4. **Deep-link arrival.** The path is set straight to the detail with no list animation beyond
   the system push.

### Blocks, top to bottom
- Nav bar: large title **"History"**. Trailing toolbar button `Button("Calendar", systemImage: "calendar")`
  renders icon-only in a glass circle. Identifier `historyCalendar`.
- For each month: a section header built with `DateFormatter "MMMM yyyy"` and uppercased, e.g.
  **"SEPTEMBER 2026"** (`Theme.label`, secondary).
- For each workout, a card row (`WorkoutSummaryRow`, wrapped in a plain `Button` that appends
  to the path; identifier `historyWorkoutRow`; clear row background; no separators; insets
  4/0/4/0):
  - **Day tile:** a `Theme.fill` rounded rect (inner radius) with a minimum size of 52×56.
    It shows the day number (`.dateTime.day()`, `Theme.stat`, monospaced) over the weekday
    (`.weekday(.abbreviated)`, uppercased, `Theme.label`, secondary), e.g. "10 / THU".
  - **Title:** `workout.historyTitle` (`Theme.cardTitle`, 1 line, or 3 when stacked). Rule from
    `HistoryRendering.title`: the typed name, else the template snapshot name, else the first
    exercise or cardio activity name plus "+N" (e.g. "Chest Press +2"), else **"Workout"**.
  - **Gym line:** `Label(historyGymName ?? "No gym", systemImage: "mappin.and.ellipse")`, caption,
    secondary.
  - **Stats line:** `historyStatsLine`, caption, tertiary. Examples:
    "1 exercise · 1 set · 45 min", "2 exercises · 9 sets · 52 min · 1 cardio activity", or
    cardio-only "1 cardio activity · 30 min". Durations use `HistoryRendering.durationLabel`:
    under 60s gives "45s", otherwise floored "N min".
  - Inline after the stats line, a **unit badge** when any completed sets exist, derived from
    the actual set units: `UnitChip` "kg" (tinted `#97C7EE`) or "lb" (`#A8CDBF`), or a
    `Chip` "Mixed" (`#B8A1EE`). Chips are caption semibold, 12% tint capsules.
  - A trailing `chevron.right` (caption semibold, tertiary).
  - Padding 16, `.card()`, card-shaped content shape.

### Controls
- Tapping a row pushes `WorkoutDetailView`.
- **Trailing swipe:** "Delete" (`trash`, tinted `Theme.danger`) sets `confirmingDelete`. There
  is no leading swipe.
- The Calendar button presents `HistoryCalendarSheet` (§2).
- There is no search, filter, sort, context menu, pull to refresh or summary header.

### Dialog: delete workout from the list (`:135–150`)
- `.confirmationDialog` titled **"Delete this workout?"** with a visible title.
- Buttons: **"Delete Workout"** (destructive) deletes the workout and saves. **"Cancel"** (cancel).
- Message: **"{n} set(s) across {m} exercise(s) will be permanently deleted. Records are
  recalculated without them."**, plus " Recorded cardio and any routes will also be deleted."
  when the workout has cardio.
- **Judgement:** this message omits the volume figure that the detail screen's version
  includes (§3.12). The two delete dialogs for the same action read differently.

### Accessibility identifiers
- `historyWorkoutRow` (16 test references)
- `historyCalendar` (5)

### Dynamic Type, motion, haptics
- The day tile uses minimum sizes, so it grows with text. The row stacks at accessibility sizes.
- No motion or haptics.

### Judgements
- Rows are visually identical when the same exercise repeats (see `05-history.png`: five
  "Seated Chest Press / No gym / 1 exercise · 1 set · 45 min · lb" cards). Nothing
  differentiates sessions: no volume, no heart rate or calories, no PR marker, no muscle or
  cardio icon, no time of day.
- The "No gym" line repeats on every row and carries no information.
- The list has no overview at the top: no week or month totals, streak, frequency or volume
  trend. It opens straight into rows.
- The month header style ("SEPTEMBER 2026", full month) is inconsistent with the calendar's
  "Aug 2026" (short month).
- The chevron inside a card is redundant with the whole card being tappable.
- The unit badge sits in the stats line and reads as an odd green or blue pill with little
  meaning at a glance.

---

## 2. Calendar sheet — `HistoryCalendarSheet`

- **File:** `HistoryCalendarSheet.swift:8–181`. Presented from `HistoryView.swift:117–134`.
- **Presentation:** `.sheet` at the default full-height detent, with its own `NavigationStack`.
- **How it is reached:** the History toolbar "Calendar" button, whether or not the list is empty.
- **Job:** month grids that mark every day on which a finished workout started. Tapping a marked
  day opens that session.

### Data
`WorkoutCalendar(startedAt:)` (`Domain/WorkoutCalendar.swift`):
- Months run from the first marked month, or today's month, through today's month. There are
  never future months, and the list is oldest first.
- Weekday symbols are `veryShortStandaloneWeekdaySymbols`, rotated to the locale's first weekday.
- Month title uses the template "MMM yyyy", e.g. **"Aug 2026"**.

### Blocks, top to bottom
- Nav bar with inline title **"Calendar"**. Leading toolbar `Button("Close", systemImage: "xmark")`
  (renders icon-only, amber X). Identifier `closeCalendar`.
- **Pinned weekday header** (`safeAreaInset(.top)`): a 7-column grid of single letters
  ("S M T W T F S"; `Theme.label`, secondary, 8pt vertical padding) on the background colour.
- `ScrollView` → `LazyVStack` (24pt spacing, 16pt horizontal padding, 24pt bottom padding).
  One **card per month**:
  - Month title (`Theme.cardTitle`), identifier `calendarMonth`.
  - A 7-column grid with 8pt row spacing and 0 column spacing. Padding cells are
    `Color.clear` 44pt high. Day cells are 40×40.
- **On appear:** `proxy.scrollTo(lastMonth, anchor: .bottom)` jumps to the newest month with
  no animation.

### Day-cell states (`CellStyle`, `:100–138`)
Each state lists fill / ring / text / weight / tappable / accessibility label.

| State | Fill | Ring | Text | Weight | Tappable | Accessibility label |
|---|---|---|---|---|---|---|
| plain | clear | none | text | regular | no | "Day N" |
| future | clear | none | tertiary | regular | no | "Day N" |
| today | clear | secondary 2pt | text | semibold | no | "Today" |
| marked | accent disc | none | onAccent | semibold | yes | "Workout on day N" |
| markedToday | accent disc inset 4pt | secondary ring | onAccent | bold | yes | "Workout today" |
| markedFuture | clear | accent ring | text | semibold | yes | "Workout on day N, dated in the future" |

- Numerals use `.body.monospacedDigit()`.
- Identifier on every cell: `calendarDay.yyyy-MM-dd` (POSIX Gregorian key).

### Controls and commit semantics
- Tapping a marked day calls `onPick(day.date)`. The presenter computes
  `WorkoutCalendar.workoutToOpen(on:)`, which picks the **latest-started** workout that day,
  stores it, and closes the sheet.
- On dismiss, `destinationAfterCalendar` re-validates the pick: not deleted, finished, and no
  other navigation pending. If it passes, the path is replaced with `[workout]`. A pending
  "View in History" target wins over the calendar pick.
- "Close" dismisses without a pick. Swiping down does the same.

### Accessibility identifiers
- `historyCalendarSheet` on the whole sheet (2 test references)
- `closeCalendar` (1)
- `calendarMonth` (2)
- `calendarDay.<date>` (2)

### Dynamic Type, motion, haptics
- None. Cells are a fixed 40×40 frame with body text. **Judgement:** likely to clip at
  AccessibilityL (unverified; there is no AX capture of the calendar).

### Judgements
- The calendar is a plain amber-disc mark grid. It carries no information beyond "trained that
  day": no count, no lifting-vs-cardio distinction, no intensity or volume shading, no streak,
  no month totals.
- When two workouts share a day, only the newest opens. There is no chooser and no indicator
  that a second workout exists.
- The scroll grows unbounded from the first workout. There is no month or year jump and no
  swipeable month pager.
- The empty-history calendar shows only the current month with no marks and no message.
- The pinned weekday header floats above the month cards but not inside them, so the letters
  line up only by shared padding.

---

## 3. Workout detail — `WorkoutDetailView`

- **File:** `WorkoutDetailView.swift:4–503`.
- **Presentation:** pushed onto History's `NavigationStack`
  (`navigationDestination(for: Workout.self)`, `HistoryView.swift:151`).
- **How it is reached:** a list row tap, a calendar pick, or "View in History" from the receipt.
- **Job:** show a logged session and allow every sanctioned edit:
  - rename
  - edit, delete or add sets
  - retype an entry's load type
  - remove an exercise
  - add an exercise
  - edit cardio distance
  - save as a template
  - delete the workout
  - switch the display unit

### Chrome
- Inline nav title: the workout's start **date**,
  `startedAt.formatted(date: .abbreviated, time: .omitted)` → **"Sep 10, 2026"**.
- Trailing toolbar **Menu**, identifier `workoutDetailMenu`. Its label is
  `Label(displayUnit?.rawValue ?? "As entered", systemImage: "scalemass")`, which renders
  **icon-only as a scale/kettlebell glyph** in the toolbar. Menu contents, in order:
  1. **"Save as Template…"** (`square.on.square`), identifier `saveAsTemplate`. Shown only when
     `WorkoutTemplateService.canSaveAsTemplate(workout)`, followed by a Divider.
  2. **"Delete Workout…"** (`trash`, destructive), identifier `deleteWorkout`.
  3. Divider.
  4. Inline `Picker("Units")` with the options **"As entered"**, **"Show in kg"** and
     **"Show in lb"** (checkmark on the current one). Display only; storage is untouched (D9/D52).
- **Judgement:** destructive and template actions hide behind a unit-scale icon. The icon
  suggests "units" only, so Delete and Save as Template are undiscoverable. The unit state
  is not visible anywhere on the page itself.

### Body
A `List` (inset-grouped look with a hidden scroll background on the ink background). Sections
appear top to bottom as follows.

**3.1 Header section** (`:46–81`). Row background is the card colour with hairline separators.
- **Name row:** a plain `Button` containing `LabeledContent("Name")`. The value is
  `historyTitle` (1 line) plus a `pencil` glyph (caption2, secondary). Identifier
  `historyWorkoutName`. Tapping opens the rename alert (§3.9).
- **Gym and duration row:** `Label(historyGymName ?? "No gym", systemImage: "mappin.and.ellipse")`,
  a Spacer, then `durationLabel ?? "—"` ("45 min" or "45s") in secondary. Subheadline.
- **Conditional row:** `Label("Saved as template “{name}”", systemImage: "checkmark")`, subheadline,
  secondary, identifier `savedTemplateConfirmation`. Appears after Save as Template succeeds,
  for this view's lifetime only.
- **Judgement:** the screen is titled with a date, and a form row labelled "Name" carries the
  title. Start and end **time of day** appear nowhere, only the date and duration. The gym line
  again says "No gym". The header is a settings-style form row, not a hero.

**3.2 "Lifting" pseudo-header** (`:83–86`). Only appears when the workout has both cardio and
lifting entries. It is a `Text("Lifting")` headline row marked `.isHeader`, with a clear
background and no separator.
- **Judgement:** inconsistent with the "Cardio" section below, which uses a system list header.

**3.3 One Section per exercise entry** (`:87–174`), ordered by
`WorkoutSession.orderedEntries`. Row background is the card colour with hairline separators.

Section header (custom, `.textCase(nil)`):
- **Exercise name:** `entry.snapshotExerciseName`, `Theme.cardTitle`, text colour.
- **Subtitle:** a horizontal row that stacks vertically at accessibility sizes.
  - **Equipment label** `snapshotEquipmentLabel` (caption, secondary). It takes one of these
    forms: "{machineLabel} · {modelName or 'unknown model'}", or a free-weight tag
    ("Barbell", "Dumbbell", "Cable", "Smith machine", "Bodyweight", "Machine"), or
    **"No equipment"**, plus " · {preset}" when a preset was logged.
  - **Load-type chip-menu:** a `Chip` showing `snapshotLoadType.badge` ("Weighted",
    "Bodyweight", "BW + added", "Assisted"). Identifier `historyEntryLoadType`. Tapping it opens
    a **Menu**:
    - The four load types; the current one has a `checkmark` and the others use an empty
      system-image name. Choosing one calls `HistoryEditing.retype`.
    - Divider.
    - **"Remove Exercise"** (`trash`, destructive), identifier `removeHistoryExercise`. Opens the
      confirmation in §3.11.
- **D51 provenance line** (conditional): **"Reclassified from {oldName} · {date abbreviated}"**,
  caption2, secondary, identifier `historyReclassifiedMark`.
- **Trailing chart button:** `chart.xyaxis.line` in amber on a 32×32 circle filled amber 12%.
  Accessibility label "Progress chart", identifier `historyEntryChart`. It opens the progress
  sheet (§4) on THIS entry's variation.

Set rows (completed sets only, in set order):
- **Marker disc:** 28×28, `Theme.fill` circle, `Theme.label` monospaced. It shows
  `set.type.marker` ("W" in warmup yellow, "F" in danger red, "D" in drop purple) or, for
  working sets, the number `index + 1` in text colour.
- **Main line:** "{weight} × {reps}" in body semibold, monospaced, e.g. "120 lb × 8".
  - Weight comes from `WeightMath.displayLabel`: as entered, or converted plain under the unit
    toggle.
  - Missing values render as **"—"**, so a plain-bodyweight set reads **"— × 12"**.
- **Bar breakdown caption** (caption2, secondary; D39): "45 + 45 × 2 = 135 lb" or
  "45 lb bar = 45 lb". Shown only while the display is as entered or matches the set's unit.
- Row interaction: `.accessibilityElement(children: .combine)`, identifier `historySetLine`.
  **Tapping anywhere** opens `EditLoggedSetSheet` (§5). **Trailing swipe** "Delete" (`trash`,
  destructive, default red) opens the set-delete confirmation (§3.10).
- **Judgements:**
  - Nothing tells the user that a set row is tappable: no chevron, no pencil, no pressed state.
  - The number counts warmups: a W then a working set shows "W, 2". The active workout's
    `ExerciseEntryCard.workingIndex` excludes warmups and would show "W, 1". The numbering is
    inconsistent between screens.
  - "— × 12" for bodyweight sets looks broken.
  - There is no per-exercise summary (best set, volume, e1RM, set count) and no PR badge.
  - There is no "Add set" to an existing exercise. The only add path is "Add Exercise…",
    which creates one set.
  - Superset grouping (`ExerciseEntry.supersetGroupID`, D48) is not shown; supersetted entries
    render as unrelated sections.
  - The load-type chip doubles as the only path to "Remove Exercise", hiding a destructive
    action behind a label-like chip.
  - A refused retype (a set that the new type cannot express) fails **silently**, because
    `retype` returns false and nothing is shown.
  - The chart button is 32×32, below the 44pt target.

**3.4 "Cardio" section** (`:176–181`). Only when `recordedCardio` is non-empty. It has a system
Section header **"Cardio"**, then one `CardioSummaryCard` per segment (§7) with a clear row
background and no separators.

**3.5 Heart-rate tiles** (`:186–223`). Only when the workout is not deleted and
`summary.hasHeartRate` (an average, max or active-calories value exists). The Section has no
header, zero row insets and a clear background. Identifier `historyHeartRateSection` on the
Section. It holds a 2-column `LazyVGrid` of `StatTile`s. Each tile appears only if its fact
exists (D44):

| Tile label | Value | Symbol | Tint | Identifier | Accessibility text |
|---|---|---|---|---|---|
| **"Average"** | "{n} BPM" | `heart.fill` | danger | `historyAverageHR` | "Average, n BPM" |
| **"Maximum"** | "{n} BPM" | `bolt.heart.fill` | danger | `historyMaxHR` | "Maximum, n BPM" |
| **"Active calories"** | "{n} CAL" | `flame.fill` | `#FF5E7A` | `historyActiveCalories` | "Active calories, n CAL" |
| **"Total calories"** | "{n} CAL" | `flame` | `#FF5E7A` | `historyTotalCalories` | "Total calories, n CAL" |

- Total calories are active plus basal, shown only when both exist.
- `StatTile` layout: symbol and label on one line (caption, secondary, 2 lines, 0.85 minimum
  scale) above the value (`Theme.stat`, 1 line, 0.8 minimum scale). Padding 16, `.card()`.
- **Judgements:**
  - The code comment says "The same tiles as the receipt", but they have drifted.
    - Labels: the receipt says "Avg. heart rate" and "Max heart rate"; History says "Average"
      and "Maximum".
    - Icons: the receipt uses `arrow.up.heart.fill` for max; History uses `bolt.heart.fill`.
    - Calorie tint: `#F4939C` on the receipt, `#FF5E7A` here.
    - Order: the receipt runs time/volume, calories, HR; History runs HR, calories.
    - History has **no Workout time or Total volume tile**, although `WorkoutSummary.totalVolumeKg`
      is computed.
    - The receipt goes to one column at accessibility sizes; History stays at 2 columns.
  - These tiles have **zero** horizontal insets, while the HR chart and zone cards below have
    16pt insets. The left edges visibly misalign (see `14-05-detail-heart-rate-zones.png`:
    tiles at x≈38, chart card at x≈75).

**3.6 Heart-rate graph** (`HeartRateSummarySection`, §6). Shown when `summary.hasHeartRateSeries`
and an interval exists.

**3.7 Time in zones** (`:237–245`). Shown when any zone has seconds greater than zero. It is a
`ZoneTimeCard` (§8) with 4/16/4/16 insets and identifier `historyZoneCard`.

**3.8 Add Exercise section** (`:248–259`):
- `Button("Add Exercise…", systemImage: "plus")` with the `.secondary` style. It is
  left-aligned and sized to its content, not full-width. Identifier `addHistoryExercise`. It
  opens `ExercisePickerSheet` (§9).
- Section footer: **"Recorded as defined today, without equipment."**
- **Judgement:** the button sits *below* cardio, heart rate and zones, far from the exercises it
  adds to.

**3.9 Edited mark** (`:261–271`). Shown only if `historyEditedAt` is set:
- `Label("Edited {date abbreviated, time shortened}", systemImage: "pencil.circle")`, e.g.
  **"Edited Sep 12, 2026 at 3:45 PM"**. Caption, secondary, clear background.
- Identifier `historyEditedMark`.
- Set by every edit path: sets, retype, remove, add, rename, and cardio distance change.

### 3.9a Rename alert (`:281–294`)
- `.alert("Workout Name")` containing a `TextField` whose placeholder is `derivedTitle` (the
  title without a typed name) and whose text is the current typed name. Identifier
  `workoutNameField`.
- Buttons **"Save"** (identifier `saveWorkoutName`) and **"Cancel"**. There is no message.
- Save calls `HistoryEditing.rename`: a blank name clears to the derived title, and the change
  is marked as an edit.

### 3.10 Delete-set confirmation (`:333–347`)
- Title **"Delete this set?"**, with the buttons **"Delete Set"** (destructive) and **"Cancel"**.
- Message: **"This set is removed permanently, and records and volume are recalculated without it."**
- Deleting the last set of an exercise **silently prunes the whole entry** (`pruneIfEmpty`).
  **Judgement:** this is not stated in the dialog.

### 3.11 Remove-exercise confirmation (`:318–332`)
- Title **"Remove this exercise?"**, with the buttons **"Remove Exercise"** (destructive) and
  **"Cancel"**.
- Message: **"{exercise} and its {n} set(s) will be permanently removed from this workout.
  Records are recalculated without them."**

### 3.12 Delete-workout confirmation (from the menu, `:348–362`)
- Title **"Delete this workout?"**, with the buttons **"Delete Workout"** (destructive) and
  **"Cancel"**.
- Message: **"{n} set(s) across {m} exercise(s), {volume} kg of volume, permanently deleted.
  Records are recalculated without them."**, plus " Recorded cardio and any routes will also be
  deleted." when there is cardio.
- On confirm, the workout is deleted and saved, and the view calls `dismiss()` to pop.
- **Judgement:** the volume is **hard-coded "kg"** (`Format.weight(impact.volumeKg) kg`),
  ignoring the unit preference and the view's unit toggle.

### 3.13 Save as Template flow (`SaveAsTemplateFlow.swift`, shared with the finish sheet)
- **Naming alert** **"Save as Template"**:
  - `TextField("Template name")`, prefilled with "Workout {medium date}", e.g. "Workout Sep 10, 2026".
  - **"Save"**, disabled when the name is blank. **"Cancel"**.
  - Message: **"Saves exercises, sets and target reps — not weights or rest times."**, or with
    cardio **"Saves lifting exercises, sets and target reps. Cardio, weights and rest times are
    not included."**
- **Failure alert** **"Couldn't Save Template"** with an **"OK"** button. Its message is one of:
  - "Give the template a name and try again."
  - "This workout has no completed sets or recorded cardio to save as a template."
  - The cardio-target error text.
  - "The template could not be saved: {error}".
- Success adds the "Saved as template “…”" row (§3.1). There is no toast, haptic or animation.

### Sheets presented from detail
Presented on the List; a sheet attached to a Section never presents.
- `EditLoggedSetSheet(record:)` for an existing set (§5).
- `ExerciseProgressView` in a `NavigationStack` (§4).
- `ExercisePickerSheet` (§9).
- `EditLoggedSetSheet` for the set just created by Add Exercise (`pendingNewSet`). **On dismiss,
  if that set is still not loggable, the whole new entry is deleted.** This is how Cancel
  abandons an addition.
- `CardioDistanceSheet`, presented from inside `CardioSummaryCard` (§7).

### Data states that change the layout
- **Lifting only.** Header, entries, then HR, zones, Add, Edited.
- **Cardio only.** Header, then Cardio, HR, zones, Add, Edited. No "Lifting" label.
- **Both.** The "Lifting" pseudo-header appears.
- **HR aggregates without a series.** Tiles appear but no chart. This is a workout logged
  before series existed.
- **Series present.** The chart card appears.
- **Zones present.** The zone card appears.
- **No HR at all.** None of the HR blocks render; they are omitted, not zeroed.
- **Saved as template.** The confirmation row appears.
- **Edited.** The edited mark appears at the bottom.
- **Reclassified entries.** The provenance line appears.
- **Unit toggle set to kg or lb.** All weights convert and bar breakdowns hide.
- **Transient deleted workout.** Guards render empty strings and nil summaries during the pop.
- **Emptied workout.** Deleting every set leaves a workout shell with only the header and Add.
  There is no empty state, and the list row then reads "0 exercises · 0 sets · 45 min".
  **Judgement:** there is no designed state for this.

### Accessibility identifiers (test reference counts)
- `historyWorkoutName` (5)
- `savedTemplateConfirmation` (0)
- `historySetLine` (3)
- `historyEntryLoadType` (0)
- `removeHistoryExercise` (0)
- `historyReclassifiedMark` (0)
- `historyEntryChart` (2)
- `historyAverageHR` (0)
- `historyMaxHR` (0)
- `historyActiveCalories` (0)
- `historyTotalCalories` (0)
- `historyHeartRateSection` (4)
- `historyZoneCard` (3)
- `addHistoryExercise` (0)
- `historyEditedMark` (3)
- `workoutNameField` (0)
- `saveWorkoutName` (0)
- `saveAsTemplate` (2)
- `deleteWorkout` (1)
- `workoutDetailMenu` (2)

A count of 0 means no literal match in the test targets; the identifier may still be read
through a composed string.

### Dynamic Type, motion, haptics
- Entry subtitle stacks at accessibility sizes (`:115–118`).
- Name row is `lineLimit(1)`, so it truncates at large sizes.
- No motion, no haptics, no Reduce Motion handling.

### Other judgements for the detail screen
- It has no hero summary: no big numbers for volume, duration, sets or PRs at the top.
  Compare the finish receipt, which has time and volume tiles and per-exercise "N sets · best X"
  lines in amber (`WorkoutFinishedSheet.swift:205–300`). History detail shows less than the
  receipt the user saw a minute earlier.
- `Workout.notes` exists in the model (`Models.swift:285`) but no UI anywhere reads or writes it.
- Section header styles are mixed: a custom card-title header per exercise, a system "Cardio"
  header, the pseudo-row "Lifting", the system "Heart rate" header (inside
  `HeartRateSummarySection`), and "Time in zones" as a title *inside* its card.
- Set rows sit in inset-grouped cells, while tiles and cardio use floating cards. The screen
  mixes two visual languages.

---

## 4. Exercise progress — `ExerciseProgressView`

- **File:** `ExerciseProgressView.swift:15–465`.
- **Presentation:** a `.sheet` wrapping a `NavigationStack`, at the default detent. It has **no
  toolbar and no Close or Done button**; the only way out is swiping down.
- **How it is reached:**
  1. The History detail entry chart button (`WorkoutDetailView.swift:297–309`). The chart opens
     on that session's variation: snapshot load type, machine ID or free-weight tag, and preset.
  2. Outside this scope: the Exercises tab row context menu "Progress…"
     (`ExercisesView.swift:80, :134–143`), with no initial variation, so it defaults to the
     most-trained one.
- **Job:** plot one exercise's per-day progression for one variation (D36: never pooled).
- **Nav title:** inline, the exercise name.

### Data
- `history` fetches all `SetRecord`s whose snapshot exercise ID matches, from finished and
  non-deleted workouts.
- `ProgressSeriesMath.series` filters by load type, equipment and preset, drops warmups, groups
  by calendar day, and takes the best set per day. Best means:
  - most reps for bodyweight
  - least assistance for assisted
  - heaviest otherwise
- Volume and e1RM are computed per day.
- The display unit is the **app preference** (`AppPreferences`), not the detail screen's toggle.
- Variation labels come from `ProgressSeriesMath.labels`. Examples:
  - "Chest Press #1"
  - "Barbell · Wide grip"
  - "No equipment recorded"
  - Collisions escalate by adding the load-type badge, then the gym, and finally "(2)".

### Blocks and states, top to bottom
1. **Variation picker Section.** Shown only when `availableVariations.count > 1`. It is a
   `Picker("Variation")` in `.menu` style, on a card row, with identifier `chartVariationPicker`.
   Options read **"{label} · {n} day(s)"** or **"{label} · nothing eligible"**. The rendered look
   is a "Variation" label with the amber value and chevrons below it (see `05-chart.png`).
2. One of three confidence states:
   - **Empty** (`.empty`). An `EmptyState` with the `chart.xyaxis.line` symbol, then a
     subheadline in secondary, centred, with 24pt horizontal padding. Clear row. Identifier
     `progressEmpty`.
     - With more than one variation: title **"Nothing to chart here"**, description **"No
       eligible sets under {variation}. Warmups do not count. Pick another variation above."**
     - Otherwise: title **"No sets logged yet"**, description **"Log {exercise} in a workout
       and its progress appears here."**
   - **Single** (`.single`). Section header **"One session"**, then one `LabeledContent` row:
     the date (abbreviated) and the as-entered value, e.g. "120 lb × 8" or "12 reps".
     Identifier `progressSinglePoint`.
   - **Series** (`.series(days)`). One card Section containing:
     - A segmented `Picker("Metric")` with **"Best set" / "Volume" / "1RM"**. Only "Best set" is
       offered unless the load type is weighted. **Judgement:** a one-segment segmented control
       is pointless.
     - **The chart**, 240pt high, identifier `progressChart`:
       - an `AreaMark` with an amber gradient from 35% to 0
       - a `LineMark` in amber, 2.5pt wide with a round cap
       - a `PointMark` at each day
       - monotone interpolation
       - Y-axis label (`chartYAxisLabel`) is one of: "Weight ({unit})", "Assistance (less is
         better) ({unit})", "Added weight ({unit})", "Reps", "Volume ({unit})", "1RM ({unit})".
       - X-axis: about 4 automatic date marks with hairline grid and secondary labels.
       - Y-axis: automatic marks with a hairline grid. **Judgement:** Charts' default includes 0,
         so real progress looks flat (95→120 on a 0–150 axis in `05-chart.png`).
     - **Selection:** a `chartOverlay` with a `DragGesture(minimumDistance: 0)` snaps to the
       nearest day. It draws a `RuleMark` in secondary at 50% and an enlarged `PointMark`
       (size 140).
       - There is no haptic tick. The selection persists after the finger lifts, and nothing
         clears it.
     - **Selection row:** `LabeledContent(date abbreviated)` with the value, identifier
       `chartSelection`. It falls back to the last point when nothing is selected. The value
       shows best set as entered ("120 lb × 8"), or volume or 1RM in the display unit, or "—".
     - **Footer** when days < 4: **"Only {n} days logged — read the shape with caution."**
   - **Change Section.** Shown when the change is computable (series, and a non-zero first
     value). Header **"Change"**, row **"Since first session"** with a value of "+26%" or
     "-5%" (`Theme.stat`, amber when ≥ 0, secondary when negative).
     - **Judgement:** the change always uses the **best-set** metric even when Volume or 1RM is
       selected, so the number contradicts the chart on screen.
     - For assisted exercises the sign is inverted so that improvement is positive.

### Accessibility identifiers
- `chartVariationPicker` (3)
- `progressEmpty` (2)
- `progressSinglePoint` (1)
- `progressChart` (3)
- `chartSelection` (3)
- The selection row also has an accessibility label "{date}, {value}".

### Dynamic Type, motion
- None specific. Fixed chart height of 240. No animation when switching metric or variation.

### Judgements
- There is no PR or records presentation here: no marks for record days, no best-ever figure,
  no rep-max table. See §10.
- There is no time-range control (1M/3M/1Y/All) and no per-point navigation to that workout.
- There is no close button in the sheet.

---

## 5. Edit / add set sheet — `EditLoggedSetSheet`

- **File:** `EditLoggedSetSheet.swift:11–109`.
- **Presentation:** a `.sheet` at full height, wrapping a `NavigationStack` and a native `Form`.
  The SPEC keeps editors as native Forms with the system look.
- **How it is reached:**
  - (a) Tapping a set row in detail. The mode is edit.
  - (b) Automatically after "Add Exercise…" picks an exercise, with the new one-set entry. The
    mode is add, **but it is titled and labelled identically**.
- **Job:** correct only the numbers of one logged set: weight, unit, reps and type. Snapshot
  fields are never editable (D23/D47).

### Blocks
- Inline nav title **"Edit Set"**. Leading **"Cancel"** (`cancellationAction`, dismisses).
  Trailing **"Save"** (`confirmationAction`), disabled unless the input is loggable. Identifier
  `saveEditedSet`.
- One Form Section:
  - Header: the entry's snapshot exercise name, or "Set", or empty if deleted.
  - `LabeledContent("Weight")` holding a right-aligned `TextField` with a decimal pad and
    identifier `editSetWeight`. Its placeholder is **"Assistance"** for assisted exercises and
    **"Weight"** otherwise.
  - A segmented `Picker("Unit")` with **kg | lb**.
  - `LabeledContent("Reps")` holding a right-aligned `TextField("Reps")` with a number pad and
    identifier `editSetReps`.
  - `Picker("Set type")` in the default Form menu style, with **"Warmup" / "Working" /
    "Failure" / "Drop"**.
  - Footer: **"The exercise and equipment this set was logged against stay as they were —
    editing a set never restates what machine you used. The workout will be marked as edited."**

### Validation and commit
- Save is enabled when `WorkoutSession.isLoggable` passes: reps greater than 0, and a weight
  required for every load type except plain bodyweight. A comma decimal is accepted.
- Save calls `HistoryEditing.apply`, which validates through `StoredWeight` and rejects
  negative, NaN or infinite values. It re-derives `normalizedKg`, may drop the bar provenance,
  marks the edit, saves and dismisses.
- If `apply` refuses, **nothing happens** and no error is shown.
- Cancel or a swipe-down in edit mode discards. In add mode it also deletes the new entry
  (§3 sheets).

### States
- **Edit.** The fields are prefilled on first appear.
- **Add.** Fields are empty, type is Working, and the unit is the new set's default.
- **Assisted.** The placeholder reads "Assistance".
- **Bodyweight.** The weight field is still shown although it is optional.

### Judgements
- The footer is a 3-sentence paragraph, which the copy policy would call too long.
- Add mode reads "Edit Set", gives no hint that Cancel removes the exercise, and cannot add a
  second set.
- The weight field is shown for bodyweight.
- There is no stepper or quick +/- control, no "previous" reference, and no RPE or notes field.
- The unit segmented control sits between weight and reps, separating the pair.
- A bar-mode set shows only the total with no bar context.

---

## 6. Heart-rate graph — `HeartRateSummarySection`

- **File:** `HeartRateSummarySection.swift:24–164`.
- **Presentation:** an inline List `Section`. Shared by `WorkoutFinishedSheet` (`:116`) and
  History detail (`WorkoutDetailView.swift:225`).
- **Job:** Apple-Fitness-style graph of heart rate across the workout.
- **Renders nothing** when there is no drawn range or no slots.

### Blocks
- Section header **"Heart rate"** (system list header).
- A card (`.padding(16).card()`, row insets 4/16/4/16):
  - **Chart**, 160pt high, identifier `heartRateChart`, accessibility label
    **"Heart rate over {m:ss}, average {n} BPM, maximum {n} BPM"**.
    - One `RectangleMark` per display slot, covering the slot's low−0.5 to high+0.5 bpm and
      inset 30% horizontally. The fill is a gradient from accent at the bottom to danger at the
      top, corner radius 1. At most about 110 bars, from 15-second buckets.
    - Gaps (0) are not drawn.
    - Y domain is the drawn range ± max(4, range/8).
    - Y axis on the trailing side, labelled **only** at the low and high bpm (caption2, secondary,
      monospaced). No gridlines.
    - X axis: hairline separators at 0, ⅓ and ⅔ of the duration. Each is labelled with a
      **clock time**, e.g. "6:29 PM", from `startedAt + elapsed`, `time: .shortened`. At
      accessibility sizes only the first label shows.
  - Caption **"{n} BPM AVG"** (caption semibold, danger colour, monospaced), identifier
    `heartRateAverageCaption`. Shown only when the average exists.

### Accessibility identifiers
- `heartRateChart` (6)
- `heartRateAverageCaption` (2)

### Judgements
- There is no scrubbing or selection on the heart-rate chart, although the progress chart has
  one. There is no max marker and no zone colouring of the bars: they use one amber→red gradient
  regardless of zone.
- The header sits outside the card while "Time in zones" sits inside its card.
- `Format.duration` in the accessibility label gives "62:30" for workouts over an hour.

---

## 7. Cardio summary card, route map, distance sheet (shared)

### `CardioSummaryCard`
- **File:** `CardioViews.swift:212–249`. `showsRoute` defaults to true in History; the active
  workout passes false.
- **Blocks:**
  - `Label(activity.name, systemImage: activity.symbol)` in headline, text colour. Identifier
    `cardioSummary.{activityRawValue}` (16 test references).
    - Names: "Indoor Walk", "Indoor Run", "Indoor Cycle", "Elliptical", "Rowing",
      "Stair Stepper", "Outdoor Walk", "Outdoor Run", "Outdoor Cycle".
    - Symbols: `figure.walk`, `figure.run`, `figure.indoor.cycle`, `figure.outdoor.cycle`,
      `figure.elliptical`, `figure.rower`, `figure.stair.stepper`.
  - A metrics grid, 2 columns (1 at accessibility sizes), 16pt spacing, built from
    `CardioMetric` (caption label, secondary; `Theme.stat` value plus a subheadline unit):
    - **"Time"**: `Format.elapsed` ("m:ss" or "h:mm:ss").
    - **"Distance"**: "%.2f" plus "km"/"mi". Only when a distance exists.
    - **"Average pace"**: "m:ss" plus "/km". For non-speed activities.
    - **"Average speed"**: "%.1f" plus "km/h". For cycling.
    - **"Avg. heart rate"**: n "bpm".
    - **"Active calories"**: n "cal".
  - **Route map** (`CardioRouteMap`, 180pt high). Only when a route exists.
  - **Distance button**, which opens `CardioDistanceSheet`. Identifier
    `cardioSummaryEditDistance` (12 test references). It is a caption row with a 44pt minimum
    height and secondary colour, reading **"Enter distance"** when there is none, else the
    source caption ("Entered distance", or "GPS" for GPS), else **"Distance"**, followed by a
    trailing `pencil`.
  - Padding 16, `.card()`.
- **Judgement:** the calorie unit casing differs from the tiles: "cal" in lowercase here, "CAL"
  in History's tiles. "Avg. heart rate" here versus "Average" in the History tile.

### `CardioRouteMap`
- **File:** `CardioViews.swift:298–320`.
- A MapKit `Map` with an `.automatic` initial position and **`interactionModes: []`, so it
  cannot be panned, zoomed or tapped**.
- One `MapPolyline` per route portion (portions never join across pauses) in `AccentColor`,
  4pt wide.
- `.standard(elevation: .flat, pointsOfInterest: .excludingAll)`, clipped to a 16pt radius.
- Accessibility label "Recorded cardio route", identifier `cardioRoute` (4).
- **Judgement:** there are no start or finish pins, no pace colouring, and no way to expand to
  full screen.

### `CardioDistanceSheet`
- **File:** `CardioViews.swift:251–296`.
- **Presentation:** a `.sheet` from the card, full height, with a `NavigationStack` and a `Form`.
  The title **"Distance"** uses the default large display mode, unlike the other sheets here,
  which are inline.
- **Blocks:**
  - `TextField("Distance")` with a decimal pad, identifier `cardioDistanceField`.
  - A segmented `Picker("Unit")` with **km | mi**, identifier `cardioDistanceUnit`.
  - Conditional **"Measured: {x.xx} {unit}"** (subheadline, secondary).
  - **"Enter the machine’s distance. Clear it to use the measured distance."** (footnote, secondary).
  - An error line in danger colour: **"Enter a distance of zero or more."** or **"This workout
    has already finished."** The second appears only if the segment was deleted.
- **Toolbar:** **"Cancel"**, and **"Save"**, which is disabled until the text or unit changes.
  Save's identifier is `saveCardioDistance`. Saving on a finished workout marks it edited.

---

## 8. Time in zones — `ZoneTimeCard` (shared)

- **File:** `Design/ZoneTimeCard.swift:9–54`. Used by the finish sheet and History detail.
- **Blocks:**
  - Title **"Time in zones"** (`Theme.cardTitle`).
  - A 12pt-high stacked bar. Each present zone's width is proportional to its time, via
    `ZoneBarLayout.widths` with 2pt gaps and 3pt corner radius. Hidden from accessibility.
  - For each present zone, one row: an 8pt coloured dot, the label ("Warm-up", "Zone 1" …
    "Zone 5", caption), a Spacer, then the duration `Format.duration` ("32:30"; caption
    semibold, monospaced). The row is combined for accessibility.
- Padding 16, full width, `.card()`.
- Only zones with more than 0 seconds are drawn.
- **Judgements:**
  - `HeartRateZone.descriptionText` already exists ("Very light", "Light — endurance",
    "Moderate — aerobic", "Hard — threshold", "Maximum", "Below training intensity") but is
    never shown here.
  - There are no percentages.
  - Durations over an hour read "75:00".

---

## 9. Add Exercise picker — `ExercisePickerSheet` (shared with the active workout)

- **File:** `ActiveWorkout/ExercisePickerSheet.swift:4–88`.
- **Presentation:** a `.sheet` from History detail's "Add Exercise…".
- **Blocks:**
  - Inline title **"Add Exercise"**. Leading **"Cancel"**.
  - `.searchable` with the prompt **"Search exercises"**. Multi-token matching.
  - Card section: one `ExerciseRow` per exercise.
    - Name in `Theme.cardTitle`.
    - Muscle group caption.
    - Equipment-tag chips.
    - A load-type chip in amber when not Weighted.
    - The chips wrap via `WrapLayout`. At accessibility sizes the load-type chip joins the wrap.
    - Identifier `exerciseOption.{name}`.
  - When the search has no match: **"Create “{search}”"** (`plus`), identifier
    `createExerciseFromSearch`.
  - Section with **"New Exercise…"** (`plus`, `.secondary`), identifier `newExercise`. It opens
    `NewExerciseSheet`, which is in the Exercises feature and out of scope.
- **Commit:** picking an exercise calls `HistoryEditing.addEntry`. The snapshot comes from
  today's definition with no equipment, and the workout is marked edited. The view saves and
  opens the set editor in add mode (§5).

---

## 10. Records / PR presentation

- **There is none in History.**
  - No PR badges on list rows, set rows, entries, the calendar or the progress chart.
  - History mentions records only in dialog copy: "Records are recalculated without them",
    "records and volume are recalculated without it".
- Records surface only in the active workout's `PreviousPerformanceSheet`, which is out of this
  scope. Its titles are "Weight records", "Least-assistance records · lower is better",
  "Added-weight records", "Bodyweight record", and it has a "Most reps" row.
- The domain supports records in full (SPEC "PRs"):
  - best weight per rep count up to 12
  - Brzycki e1RM
  - three layers: machine, model and exercise
  - assisted ranks least assistance best; bodyweight+ ranks most added weight; bodyweight
    ranks most reps
  - warmups excluded
- `WorkoutSummary.exercises[].bestSet` and `totalVolumeKg` are already computed for every
  workout and are unused by History.
- **Judgement:** this is the largest "missing details / not engaging" gap in the area.

---

## 11. Cross-cutting judgements (History area)

1. **No celebration or engagement layer.** There are no PRs, streaks, weekly summaries, trends
   on the list, haptics, animated chart reveal, or selection feedback.
2. **Two visual languages on the detail screen.** Inset-grouped form rows (header, sets) sit
   beside floating cards (tiles, charts, cardio, zones). The horizontal insets misalign:
   0 / 16 / 20.
3. **Hidden and overloaded controls:**
   - Delete and Save as Template sit behind a scale icon.
   - Remove Exercise sits behind the load-type chip.
   - Set editing is an invisible tap target.
   - The chart button is 32pt.
4. **Receipt vs History drift.** The same data is shown with different labels, icons, tints,
   order and column behaviour. History omits time, volume and best sets.
5. **Numbers inconsistencies:**
   - warmup-inclusive set numbering
   - "— × reps" for bodyweight sets
   - the detail delete dialog's volume in hard-coded kg
   - "Change" ignores the selected metric
   - the chart Y-axis includes 0
6. **Missing details:**
   - start and end time of day
   - notes (the model field is unused)
   - supersets
   - per-exercise best, volume and e1RM
   - add a set to an existing exercise
   - a multi-workout-day chooser
   - a progress close button
   - an interactive route map
   - zone descriptions and percentages
   - an empty-shell workout state
7. **Silent failures:** a refused retype, and a refused `apply` in the set editor. Neither gives
   feedback.
8. **Presentation:** every sheet is full height with no detents.
9. **Test and string contract.** Many identifiers and strings are read by UI tests:
   - `HistoryCalendarUITests`, `HistoryEditingUITests`, `HistoryTemplateUITests`
   - `HeartRateSummaryUITests`, `ProgressChartUITests`, `ProgressChartTooltipUITests`
   - `WorkoutNameUITests`, `CardioUITests`, `CoreLoopUITests`
   - `RedesignScreenshotUITests`, `DumbbellCounterpartUITests`

   A redesign that renames strings must plan test updates or keep the identifiers.

---

## 12. Flat checklist — every screen and state in scope

**History list** (tab root)
- [ ] History list — populated, month-grouped cards (`HistoryView`)
- [ ] History list — empty state ("No workouts yet" / "Finished workouts show up here.")
- [ ] History list — row at accessibility size (stacked day tile, 3-line title)
- [ ] History row variants: named / template-titled / "X +N" / "Workout" fallback; with gym / "No gym"; lifting-only / cardio-only / mixed stats line; unit badge kg / lb / Mixed / none
- [ ] History list — trailing swipe "Delete"
- [ ] Dialog: "Delete this workout?" from the list (with and without the cardio sentence)
- [ ] Toolbar: Calendar button
- [ ] Deep-link arrival from "View in History" (push straight to detail)

**Calendar sheet**
- [ ] Calendar sheet (`HistoryCalendarSheet`): pinned weekday row, month cards, Close
- [ ] Calendar day cells: plain, future, today, marked, markedToday, markedFuture
- [ ] Calendar with empty history (current month only)
- [ ] Calendar pick → dismiss → push detail; a same-day multi-workout pick opens the newest

**Workout detail** (pushed)
- [ ] Workout detail (pushed): date title, toolbar menu
- [ ] Detail toolbar menu: Save as Template… (conditional), Delete Workout…, Units picker (As entered / Show in kg / Show in lb)
- [ ] Detail header section: Name row (tap to rename), gym plus duration, "Saved as template" row
- [ ] Alert: "Workout Name" rename
- [ ] "Lifting" pseudo-header (cardio plus lifting only)
- [ ] Exercise entry section header: name, equipment/preset line, load-type chip-menu, reclassified line, chart button
- [ ] Load-type menu: Weighted / Bodyweight / BW + added / Assisted (checkmark) plus Remove Exercise
- [ ] Set rows: marker W / F / D / number; weight × reps; bar breakdown caption; converted-unit state
- [ ] Set row tap → edit; trailing swipe "Delete"
- [ ] Dialog: "Delete this set?"
- [ ] Dialog: "Remove this exercise?"
- [ ] Dialog: "Delete this workout?" from detail (with volume and optional cardio sentence)
- [ ] Alert: "Save as Template" (lifting copy / cardio copy; Save disabled when blank)
- [ ] Alert: "Couldn't Save Template" (4 message variants)
- [ ] Cardio section (header "Cardio") with CardioSummaryCard(s)
- [ ] Heart-rate tiles: Average / Maximum / Active calories / Total calories (each optional)
- [ ] Heart-rate graph card ("Heart rate", bars, clock ticks, "N BPM AVG")
- [ ] Heart-rate graph at accessibility size (first tick label only)
- [ ] Time in zones card (only the zones present)
- [ ] Add Exercise… button plus footer "Recorded as defined today, without equipment."
- [ ] Edited mark "Edited {date time}"
- [ ] Detail variants: lifting-only, cardio-only, mixed, no HR, HR without series, HR plus series plus zones, emptied workout shell
- [ ] Detail at accessibility size (stacked equipment line and chip)

**Sheets from detail**
- [ ] Sheet: EditLoggedSetSheet — edit mode (Weight/Assistance, Unit, Reps, Set type, footer, Cancel/Save)
- [ ] Sheet: EditLoggedSetSheet — add mode after Add Exercise (Cancel removes the new exercise)
- [ ] Sheet: ExercisePickerSheet ("Add Exercise", search, rows, "Create “…”", "New Exercise…")
- [ ] Sheet: CardioDistanceSheet ("Distance", field, km/mi, "Measured:", instruction line, error line, Cancel/Save)

**Cardio summary card**
- [ ] CardioSummaryCard metrics: Time, Distance, Average pace or Average speed, Avg. heart rate, Active calories
- [ ] CardioRouteMap (static; only when a route exists)
- [ ] Cardio distance button states: "Enter distance" / "Entered distance" / "GPS" / "Distance"

**Exercise progress** (sheet)
- [ ] Sheet: ExerciseProgressView (title = exercise; no close button)
- [ ] Progress: variation picker (more than one variation; "· N days" / "· nothing eligible")
- [ ] Progress: empty — "No sets logged yet" / "Nothing to chart here" variants
- [ ] Progress: single session ("One session" row)
- [ ] Progress: series — metric picker (Best set / Volume / 1RM; single segment for non-weighted), chart, drag selection, selection row, footer "Only N days logged…" (under 4 days)
- [ ] Progress: Change section "Since first session" (positive in amber / negative in secondary)
- [ ] Progress: Y-axis label variants (Weight / Assistance (less is better) / Added weight / Reps / Volume / 1RM)

**Records**
- [ ] Records/PR presentation — none exists in History (design gap to fill)
