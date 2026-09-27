# 05 — Floodlight: History

Type: feature (part of [01](01-implement-redesign.md))
Status: in progress — ticket written 2026-09-27; implementation next
Implementer: Claude. Reviewer: Codex.
Branch: `ericlee4992/redesign-floodlight-history` (scratch checkout `/tmp/wt-floodlight/history`),
stacked on the ticket-04 finish tip `1c3fc99`.

## Scope

The History tab in the approved Floodlight design (`../reference/captures/*/H01-final.png`,
`H03-final.png`; the other History screens from the read-only prototype
`redesign-prototype/RedesignPrototype/Sources/Screens/History/`, captured 2026-09-27 into the
session scratchpad: H02 calendar, H05 edit set, H06 progress, H07 empty).

1. **History list (H01, H07).** Large "History" title, calendar button. A **month card**: the
   current month's name, three figures (Workouts · Sets · Time "7.9 h") over a **heat strip**
   of every day of the month (one cell per day, brighter with more sets; today dashed; future
   outlined; tapping it opens the calendar). Workouts grouped by **week** ("This week",
   "Last week", "Sep 7 – 13") with the week's workout count, each week one list panel; older
   months open with their name and totals in one line. A row: day number + weekday (only on a
   day's first workout), title, "6:40 PM · 55 min · 14 sets", the families trained (muscle
   maps), a new-best count mark, the unit badge when it says something ("kg + lb", or a unit
   that is not the app's), "Edited"; trailing, the volume in the app unit (cardio-only: the
   distance). Swipe to delete stays (same confirmation). Empty: an unlit ring, "No workouts
   yet" and one command.
2. **Calendar (H02).** One month at a time: title "Sep 2026" with previous/next chevrons (and a
   sideways swipe), the month's totals, weekday initials, day cells lit by the day's sets
   (cardio adds a run glyph), today dashed, the selected day outlined. Tapping a trained day
   **selects** it; the day's workouts are listed under the grid (all of them, not only one);
   tapping a workout opens it. Close button top-leading.
3. **Workout detail (H03).** Hero: the working-set ring (`HistoryHeroRing` — one segment per
   working set in its family colour, the count in the middle) beside "Saturday, Sep 19", the title
   (tap to rename, pencil) and "10:30 AM – 11:37 AM · Iron Temple"; families + new-best count +
   unit badge; the Edited line. **Save as Template…** as a visible secondary button (was in the
   toolbar menu). **Workout details** tiles in the Finish order (`FinishTileGrid`). **Last
   <template>** comparison (`ComparisonBars`). **Heart rate**: the chart in the Floodlight
   plate with **time in zones inside the same plate** (the restyle deferred from ticket 04).
   **Exercises** ("N exercises"): one panel per exercise (a superset's members share one panel,
   lettered A/B): name, progress-chart button, "…" menu (Add Set, Load type, Remove Exercise),
   the snapshot equipment line with its glyph and a load-type badge when not weighted, the
   D51 "Reclassified from…" line, then the set rows (round set marker W/1/2/F/D, "135 lb × 10",
   bar breakdown, NEW BEST / First time, a faint pencil; tap to edit, swipe to delete).
   **Add Exercise…** (dashed). Cardio cards (unchanged cards under a Floodlight heading).
   **Notes** (see decisions). **Delete Workout…** visible at the end (same confirmation).
   Toolbar: back, and a units capsule "As entered ▾" (As entered / Show in kg / Show in lb).
4. **Edit Set (H05).** A Floodlight sheet: Cancel · "Edit Set" (or "Add Set") · Save; the
   exercise and equipment; the set marker with the date and its NEW BEST mark; set type as
   segmented pills; Weight × Reps as two big number boxes with − / + (5 lb / 2.5 kg, 1 rep);
   Unit kg | lb; the bar breakdown; "The workout will be marked as edited."; **Delete Set**
   (confirmed). AX sizes: boxes stacked, type as a menu.
5. **Progress chart (H06)** (`ExerciseProgressView`, also opened from the Exercises tab):
   title, variation capsule menu ("Chest Press 2 · 6 days"), metric pills (Best set / Volume /
   1RM, weighted only), one panel with the selected day as the big number, "Since first
   session" change badge, the chart (line + points, new-best bursts, the dragged selection
   rule, y-axis padded around the data); **records** by rep count ("Weight records",
   `RecordsMath.repCountBests`); **Sessions** (newest first, tap opens that workout).
   The empty and single-session states keep their strings.
6. **Heart-rate test fix.** `HeartRateSummaryUITests.testFinishShowsTheChartAndHistoryShowsItAgain`
   (:66) fails on iOS 27 because the `historyHeartRateSection` identifier sits on a List
   `Section` that iOS 27 does not expose; the section becomes one element container with the
   identifier.
7. **Shared formatter.** The live vitals strip's running volume switches to
   `LookFormat.groupedDecimal` so it agrees with the receipt (7.5 stays 7.5).

Not in this ticket: the cardio-only detail hero with the route map and splits (H04) and the
cardio card restyle — both belong to the Cardio area; a cardio-only workout here shows the
standard hero without a ring and the existing cardio cards.

## Domain (derived on read, unit-tested)

- `HistoryOverview` (new): month summary (workouts, completed sets, hours), per-day signal
  (sets → intensity 0–4, families, has cardio/lifting), week grouping by the phone's calendar
  (the same weeks as Home's This week and the calendar), week titles.
- `HistoryWorkoutFacts` + `HistoryOverviewMath.facts` (built once per list change from one history read): per workout the
  families (live `muscleGroup`, the documented exception), the new-best count (record scopes with a
  new best — the receipt's "New bests" lines — judged against history before that workout — `SetBadgeMath`, grouped by scope
  so the whole list is one pass), volume, unit badge.
- Detail: `FinishReceipt.build` (ring runs, families, comparison) and per-set marks via
  `SetBadgeMath.receiptMarks`.
- `HistoryEditing.addSet` (new) for the exercise menu's Add Set, marked as an edit like Add
  Exercise; abandoned (Cancel / swipe down with no values) it is removed again.
- `HistoryEditing.setNotes` (new): notes edited in History, trimmed, marked (user decision).
  `ProgressSeriesMath.scoped / recordDays / change(first:last:)` for the progress chart.
- Rules kept: warmups never count toward volume, records or the ring (the row's and month's
  "sets" count every completed set, as the receipt does); assisted lower is better; ties
  are not bests; first time is not a best; frozen snapshots only (D23); display conversions
  plain (D52), storage untouched.

## Screen jobs, bold element, wireframes (ios-design steps 1–2)

- **List, populated:** exists so the user can find a past workout in one tap; the eye lands on
  the month card's figures (top-leading). Runner-up: the week lists.
- **List, empty:** exists to invite the first workout; the eye lands on the command.
- **Calendar:** exists so the user can find a day in one tap; the eye lands on the month grid.
- **Detail:** exists so the user can review or correct one workout; the eye lands on the hero
  ring + title (top). Save as Template is the only button in the first viewport and is
  secondary (outlined), not filled.
- **Edit Set:** exists to correct one set's numbers; the eye lands on the two number boxes;
  Save (filled) is the one prominent command.
- **Progress:** exists to see an exercise's trend; the eye lands on the selected value.

```
History (list)                      Workout detail                   Edit Set (sheet)
┌────────────────────────┐          ┌────────────────────────┐       ┌────────────────────────┐
│                  [cal] │          │ <            [As ent▾] │       │ Cancel  Edit Set  Save │
│ History        (large) │          │ (ring 22)  Sat, Sep 19 │       │ Seated Chest Press     │
│ September              │          │            Whole Body ✎│       │ Chest Press 2 · model  │
│┌──────┬──────┬───────┐ │          │            10:30–11:37 │       │ (2) Thu, Sep 17 [BEST] │
││ 9    │ 155  │ 7.9 h │ │          │ [maps] [✸2] [kg+lb]    │       │ Warmup|Working|Fail|Drop│
││Workouts Sets │ Time  │ │          │ ✎ Edited Sep 20 …      │       │ Weight        Reps     │
│├──────┴──────┴───────┤ │          │ [ Save as Template… ]  │       │ ┌──────┐ × ┌──────┐    │
││ ▮▮▯▮▮▮▯▮  heat strip │ │          │ Workout details        │       │ │105 lb│   │  8   │    │
│└─────────────────────┘ │          │ ┌─────────┬──────────┐ │       │ └──────┘   └──────┘    │
│ This week   3 workouts │          │ │1:07:00  │25,810 lb │ │       │ [−][+]     [−][+]      │
│┌─────────────────────┐ │          │ │421 cal  │531 cal   │ │       │ Unit          [kg|lb]  │
││23 Leg Day    24,136 │ │          │ │121 bpm  │153 bpm   │ │       │ The workout will be …  │
││Wed 6:40·55m·14   lb │ │          │ └─────────┴──────────┘ │       │ [   Delete Set   ]     │
││   [maps][✸1][kg+lb] │ │          │ Last Whole Body (bars) │       └────────────────────────┘
│├─────────────────────┤ │          │ Heart rate (chart+zones│
││21 Pull Day   11,370 │ │          │ Exercises   7 exercises│
│└─────────────────────┘ │          │ ┌[A] Bench Press 📈 … ┐│
│ Last week   4 workouts │          │ │ Barbell             ││
│ …                      │          │ │ (W) 45 lb × 10     ✎││
└────────────────────────┘          │ │ (1) 135 lb × 10 BEST││
                                    │ └────────────────────┘ │
                                    │ [+ Add Exercise…]      │
                                    │ Notes / Delete Workout…│
                                    └────────────────────────┘
```

Relative sizes: the month card's figures (`bigNumber`) are the largest content on the list;
row titles and trailing volumes are Headline-class. On the detail the ring (112 pt) and the
title (`title`) lead; tile figures are `statNumber`.

Structure: both screens stay a SwiftUI `List` (not the prototype's ScrollView) so rows keep the
native swipe-to-delete the tests and VoiceOver use; each block is a clear list row, each
exercise and each week a section drawn as one Floodlight panel.

## Rules and identifiers kept

List: `historyWorkoutRow` (each row), `historyCalendar`, swipe "Delete" → "Delete this
workout?" / "Delete Workout" / Cancel with the named impact. Calendar: `historyCalendarSheet`,
`calendarMonth`, `calendarDay.yyyy-MM-dd` (a tappable button on every trained day),
`closeCalendar`; the C2 target and the "push after the sheet closes" rule. Detail:
`historyWorkoutName` (the title button), `workoutNameField`, `saveWorkoutName`,
`saveAsTemplate`, `savedTemplateConfirmation`, `deleteWorkout`, `historySetLine`,
`historyEntryChart`, `historyEntryLoadType` (the "…" menu), `removeHistoryExercise`,
`addHistoryExercise`, `historyReclassifiedMark`, `historyEditedMark`,
`historyHeartRateSection`, `heartRateChart`, `heartRateAverageCaption`, `historyZoneCard`,
`historyAverageHR` / `historyMaxHR` / `historyActiveCalories` / `historyTotalCalories` (now
tiles in the Finish grid), every confirmation's text. Edit set: `editSetWeight`,
`editSetReps`, `saveEditedSet`. Progress: `progressChart`, `progressEmpty`,
`progressSinglePoint`, `chartSelection`, `chartVariationPicker`.
Kept behaviour: edits never re-resolve snapshots (D47) and stamp `historyEditedAt`; load-type
retype (A1 refusal); an abandoned Add Exercise leaves nothing; the progress chart opens on the
entry's own variation and never pools variations (D36); the finish receipt's heart-rate
section keeps its `.receipt` style and its tests.
Removed identifier: `workoutDetailMenu` (the toolbar menu is gone; its three items are on the
page). Tests that opened it are updated.

## Decisions for the user

Following the approved prototype (veto any): calendar selects a day and lists its workouts
(two taps to open instead of one; a day with two workouts shows both); Save as Template… and
Delete Workout… are visible on the page instead of in the toolbar menu; rows no longer show
the gym (the detail does); edit-set footer shortened to "The workout will be marked as
edited."; Add Set in a past exercise's menu; the progress chart gains rep-count records and a
tappable Sessions list; the detail ring counts WORKING sets as the prototype does (labelled
"working sets"; the receipt's ring counts every completed set, the row's "N sets" too). Weeks follow the phone's first weekday, as Home.

User decisions (2026-09-27, asked in session):
1. **Notes on the detail: show and edit, marked as an edit** (like the name, D50). This
   reopens D47 for a third non-number field; record it in DECISIONS with the D54 entry.
2. **Empty History: follow the prototype** — no calendar button until the first workout;
   "Start Lifting" switches to the Workout tab and starts the usual flow.
   `HistoryCalendarUITests.testCalendarOpensWithNoHistory` is replaced accordingly.

## New / changed visible strings

New: month figures "Workouts", "Sets", "Time", "h"; week titles "This week", "Last week",
"Sep 7 – 13" / "Aug 30 – Sep 5"; "N workouts"; month break "August" + "12 workouts · 180 sets ·
9.5 h"; the new-best count mark (spoken "N new bests"); unit badge "kg + lb" (was "Mixed") or
the one non-app unit; row meta "6:40 PM · 55 min · 14 sets" (cardio only: "… · 9:15 /mi");
detail date "Saturday, Sep 26", time range "6:10 PM – 7:05 PM · Iron Temple", ring "N working
sets"; "Save as Template…" (button); "Workout details"; "Last <template>"; "Exercises" /
"Lifting" + "N exercises"; "Add Set", "Load type", "Options" (exercise menu); units capsule
"As entered ▾" / "kg" / "lb" with "Show in kg" / "Show in lb"; "Add Note…", "Notes"; edit set
"Add Set" (title), "Weight"/"Assistance", "Reps", "Unit", "Decrease/Increase <field>",
"The workout will be marked as edited.", "Delete Set" (button); set delete message gains
"<Exercise> has no other sets, so it is removed from this workout too." when it is the last
set; calendar "Sep 2026", "Previous month", "Next month", "N workouts · N sets · N h", day title
"Saturday, Sep 26", "No workouts"; progress "Since first session" badge ("Up 20 percent…"),
"Weight records" / "Least-assistance records · lower is better" / "Added-weight records" /
"Bodyweight record", "N reps", "Sessions", "N days", "One session", Close; empty History
"Start Lifting". Heart rate: the zones sit inside the chart's plate (receipt and History).
Changed: the detail's bar title is the workout's title once scrolled (was the date).
Removed: month section header "SEPTEMBER 2026", the row's gym line and chevron, the detail's
"Name" row, the load-type chip, the toolbar menu (`workoutDetailMenu`), the long edit-set
footer, the "Change / Since first session" list row, "No gym", "Finished workouts show up here.",
the separate "Heart rate" tiles (now the Workout details tiles, as on the receipt).
Kept: row volume as a whole number in the app unit (a mixed-unit workout's detail tile keeps
its decimals, D25).

## Tells (ios-design step 4)

- Same container on everything: absent — cards only for groups (month card, week lists,
  exercise panels, tiles, plates); hero, headings and buttons sit on the ground.
- Chips: deliberate — a row's marks are the families (maps), the new-best count and at most
  one unit badge; they wrap (flow layout).
- All-caps labels: absent (the month header lost its uppercase).
- Middle-dot metadata: deliberate for the frozen stat lines ("6:40 PM · 55 min · 14 sets").
- Accent everywhere: absent — violet only on Save (edit set), selection and links; new bests
  use the positive mark.
- Equal full-width blocks: absent — the month card leads the list; the hero leads the detail.
- Phone-sized website: absent. First viewport: list = card + this week; detail = hero, Save
  as Template, tiles.
- Control dressed as primary: absent — the units capsule and the variation menu are quiet
  capsules with a disclosure.
- Only survives default size: answered by the AXL captures (rows stack, hero stacks, boxes
  stack, figures stack).

## Tests

- New unit tests: `HistoryOverviewTests` (9: month summary, intensity, days, weeks across a
  month end and their titles, unit badge, new-best counts judged against the past only incl.
  assisted/ties/warmups, row facts, Add Set + abandoned prune, notes), `ProgressSeriesTests` +2
  (record days, scoping and per-metric change).
- New UI captures `FloodlightHistoryUITests` (6): list, calendar, detail pages, edit set,
  progress chart in light/dark × Default/AXL on `-uiTestDesignSample -uiTestDesignHistory`,
  and the empty screen in light/dark (no calendar button; Start Lifting).
- Updated: `HistoryEditingUITests` (Delete Workout… on the page), `HistoryTemplateUITests`
  (Save as Template… on the page), `HistoryCalendarUITests` (select a day → its row opens it;
  the detail's date line instead of a date nav title; new `testAnEmptyDayIsSelectableAndMonthsPage`;
  the empty-store case replaced by `testEmptyHistoryHasNoCalendarAndStartsLifting`),
  `HeartRateSummaryUITests` and `RedesignScreenshotUITests.test05_historyHeartRateLargeText`
  (zone legend reads "Zone 2, 14:15"), `CoreLoopUITests` (row meta "… · 1 set"; the set line's
  label), `BarbellUITests` (set line label carries value and bar breakdown), progress tests and
  `test05_history` use `revealedSearchField()` (iOS 27 search drawer).

## Verification

Scope (DEVELOPMENT: new feature + shared screens — History, the finish receipt's shared
heart-rate plate and tiles, the progress chart the Exercises tab also opens): build; unit tests
for the new Domain rules and the neighbouring records/progress/receipt tests; every History UI
flow; the finish receipt; flows that land in History (core loop, bar mode, machine deletion,
cardio); captures light/dark × Default/AXL. Full UI suite deferred to the whole-redesign release
candidate (ticket 01 step 4). Simulator WT-Floodlight (iOS 27.0); logs, exits and result bundles
`/tmp/wt-floodlight/results/history-*`.

- `history-unit-1`: `HistoryOverviewTests`, `SetBadgeTests`, `FinishReceiptTests` 28/28, exit 0.
- `history-build-1`: exit 65 (a `set` property name parsed as a setter); `history-build-2..4`: exit 0.
- `history-cap-1`: `FloodlightHistoryUITests` 6/6, exit 0 — first captures, reviewed; fixes applied.
- `history-ui-1` (exit 65): unit 64/64 (`HistoryOverviewTests`, `ProgressSeriesTests`,
  `ChartPresetScopingTests`, `SetBadgeTests`, `FinishReceiptTests`); UI 42 of 46 passed —
  HistoryEditing 2/2, HistoryTemplate 3/3, HistoryCalendar 3/3, WorkoutName 1/2,
  HeartRateSummary 2/3, ProgressChart 2/2, ProgressChartTooltip 4/4, RedesignScreenshot
  test05_history/historyHeartRate 2/4, CoreLoop 3/3, FloodlightFinish 8/8, Barbell 2/2,
  MachineDeletion 1/1, Cardio mixed 2/2, HeartRate finishing summary 1/1, FloodlightHistory 6/6.
  Failures: HeartRateSummary :66 (the pre-existing one — the plate now sits under the tiles and
  the lazy List only builds it once scrolled; the test now scrolls to it),
  `test05_historyLargeText` / `test05_historyHeartRateLargeText` (same: sections below the fold
  at AXL; now scrolled to), `WorkoutName…HistoryShowsIt` (the receipt's Done tap was dropped
  mid-presentation — passed unchanged on rerun).
- `history-ui-2` (exit 65): the two AXL screenshot tests and WorkoutName 2/2 passed;
  HeartRateSummary 2/3 — the finish case failed earlier on a "View in History" button half under
  the receipt's bar (hittable but the tap hit the bar); the test's scroll-back now also requires
  it clear of the bar.
- `history-ui-3` (exit 65): **`testFinishShowsTheChartAndHistoryShowsItAgain` passed** (the
  pre-existing iOS 27 failure is fixed); ProgressChartTooltip 4/4; the capture runs failed a new
  assertion: a swipe starting on the progress chart did not scroll the page. Probed: the chart
  itself scrolls fine; a SwiftUI drag of any kind on it (plain, simultaneous, after a long press)
  traps the scroll, and `chartXSelection` never fires in a scroll view. Fix: tap to pick
  (simultaneous `SpatialTapGesture`) and a UIKit pan that only begins on a mostly-horizontal
  motion (`HorizontalScrubGesture`) — probe: the page scrolls from the chart (401 → 249) and the
  drag still selects. ProgressChartUITests' one-session case also failed there on the same
  dropped Done tap; its helper now waits for the receipt.
- `history-ui-4`: **exit 0 — 13/13**: FloodlightHistory 6/6 (incl. "a swipe on the chart scrolls
  the page"), ProgressChartTooltip 4/4, ProgressChart 2/2, RedesignScreenshot test05_history.
- Captures: `../captures/05/floodlight-05-{list,calendar,detail,editset,progress}-{light,dark}-{default,axl}*.png`,
  `floodlight-05-empty-{light,dark}.png` (46 files, from `history-ui-4`).
- Not exercised: Reduce Motion by a test (the simulator setting is not toggled; checked by
  reading each animation's gate), VoiceOver by a person.

## Progress

- 2026-09-27: resumed (branches verified: history = finish tip `1c3fc99`, pushed); read the
  prototype History screens and the real History code; prototype captures taken; ticket written.
- 2026-09-27: Domain `HistoryOverview` + tests (`history-unit-1`: 28/28 with SetBadge 9 and
  FinishReceipt 10, exit 0). Screens rebuilt: list, calendar, detail, edit set, progress chart;
  heart-rate section is one plate (chart + zones) shared with the receipt (`ZoneTimeCard`
  deleted; `FinishTile.summaryTiles` shared). Fixture `-uiTestDesignHistory` for captures.
  First captures `history-cap-1` 6/6 passed (exit 0), reviewed: fixed neutral toolbar tint,
  whole-number row volumes, progress Close button, chart scrub needs a short press (a bare
  drag scrolls the page), short dates. UI tests updated for the moved menu items, the
  calendar's select-then-open, zone legend labels, iOS 27 search drawer (progress tests).
  Next: targeted UI batch `history-ui-1`.

## Codex review 05 — response (round 1)

Report: [codex-review-05.md](../codex-review-05.md) — not clear; 1 high, 5 medium, 3 low. All
accepted.

1. **High — an abandoned Add Set / Add Exercise survived.** `.sheet(item:onDismiss:)` clears the
   item before `onDismiss` runs, so the cleanup read nil (inherited for Add Exercise). The detail
   keeps the added set in its own `addedSet` for the cleanup. New `HistoryEditFlowsUITests`:
   Add Set → Cancel, → swipe the editor away (nothing left, counted on the list row), → Save
   (kept); Add Exercise → swipe away (nothing left).
2. **Medium — chart record days ignored reps.** `ProgressSeriesMath.recordDays` ranks each day's
   best with `RecordsMath.outranks` (100 kg × 8 after 100 kg × 5 is a best; a repeat is not).
   Test `moreRepsAtAnEqualLoadIsARecordDay`.
3. **Medium — a Sessions row could open the wrong workout.** The day → workout map now picks
   the workout holding the day's best set, by the series' own rule.
4. **Medium — the metric hero showed 0 for a missing 1RM and rounded volume.** The hero shows the
   plotted value with its precision, "—" when the day has none; the default and the chart's
   selection only land on days with a value for the metric.
5. **Medium — quadratic new-best count.** `SetBadgeMath.newBestCounts` sweeps each scope once in
   time order with a running incumbent (the best set completed before the workout started).
   Test `newBestCountsAgreeWithTheReceiptForEveryWorkout` (reps at equal load, a same-day tie,
   assisted) checks the list's count against `FinishReceipt.build` for every workout.
6. **Medium — VoiceOver: the adjustable chart had no value.** It now carries the selected
   day and value ("Sat, Sep 26, 60 lb × 8, New best") as its accessibility value.
7. **Low — light calendar contrast.** The lightest lit step is 0.62 (white on the composited
   ink 5.6:1; was 4.35:1).
8. **Low — Edit Set lacked the NEW BEST mark.** The detail passes the set's saved mark; it
   shows beside the date (under it at AX sizes) and steps aside while the fields differ.
   Asserted in the capture test (`editSetBadge`).
9. **Low — capture gaps.** The editor captures open one fixed set (Leg Extension, set 1,
   70 lb × 10) at every size and add the lower half (footer, Delete Set); the empty screen has
   AXL captures. `HistoryEditFlowsUITests` also covers notes (saved, marked) and deleting an
   exercise's last set from the editor and by a swipe (the dialog says the exercise goes).
- Ticket wording: build 1's actual exit 65 recorded.
- **Found while verifying:** the list's row facts went stale after an abandoned Add Set (the
  prune is unmarked, so `historyEditedAt` did not change and the row kept "10 sets"). The list
  now also rebuilds its facts whenever it reappears.

Verification (round 2): `history-build-5` exit 0.
- `history-ui-5` (exit 65): unit 66/66 (`HistoryOverviewTests` 10, `ProgressSeriesTests`,
  `ChartPresetScopingTests`, `SetBadgeTests`, `FinishReceiptTests`); FloodlightHistory 8/8
  (fixed edit-set state + lower half, `editSetBadge` asserted, empty AXL); HistoryCalendar 3/3;
  ProgressChartTooltip 4/4; HistoryEditing 1/2 (its helper tapped the receipt's Done
  mid-presentation — now waits); HistoryEditFlows 0/5 (test mechanics: the title button leaves
  the lazy list when scrolled, buttons under the tab bar; and the stale-facts bug above).
- `history-ui-6` (exit 65): HistoryEditFlows 4/5, HistoryEditing 2/2; notes failed finding the
  alert's field by identifier (system alert fields drop it).
- `history-ui-7`: **exit 0** — notes 1/1.
- Captures refreshed from `history-ui-5` (52 files in `../captures/05/`).

## Codex review 05b — response (round 2)

Report: [codex-review-05b.md](../codex-review-05b.md) — not clear; one medium (all round-1
findings resolved).

- **Abandoned exercise left its family in the open detail's hero (medium).** The prune is
  unmarked, so the detail's cached receipt/marks were not rebuilt. `discardIncompleteAddition`
  now rebuilds them after a successful prune. `testAnAbandonedAddExerciseLeavesNothing` covers
  Cancel and swipe-away, and after each checks the exercise count, the hero's families
  (`historyHeroFamilies` reads "Legs", no Chest) and, on the list, the row's set count.

Verification (round 3): `history-ui-8` **exit 0** — HistoryEditFlows 5/5 (build included).
