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
3. **Workout detail (H03).** Hero: the status ring (the finish receipt's `FinishStatusRing` —
   one segment per completed set in its family colour) beside "Saturday, Sep 19", the title
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

- `HistoryOverview` (new): month summary (workouts, working sets, hours), per-day signal
  (sets → intensity 0–4, families, has cardio/lifting), week grouping by the phone's calendar
  (the same weeks as Home's This week and the calendar), week titles.
- `HistoryRowFacts` (new, built once per list change from one history read): per workout the
  families (live `muscleGroup`, the documented exception), the new-best count (exercises with a
  new-best set, judged against history before that workout — `SetBadgeMath`, grouped by scope
  so the whole list is one pass), volume, unit badge.
- Detail: `FinishReceipt.build` (ring runs, families, comparison) and per-set marks via
  `SetBadgeMath.receiptMarks`.
- `HistoryEditing.addSet` (new) for the exercise menu's Add Set, marked as an edit like Add
  Exercise; abandoned (Cancel / swipe down with no values) it is removed again.
- Rules kept: warmups never count toward sets/volume/records; assisted lower is better; ties
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
tappable Sessions list; the detail ring counts completed sets like the receipt (the prototype
counted working sets only). Weeks follow the phone's first weekday, as Home.

User decisions (2026-09-27, asked in session):
1. **Notes on the detail: show and edit, marked as an edit** (like the name, D50). This
   reopens D47 for a third non-number field; record it in DECISIONS with the D54 entry.
2. **Empty History: follow the prototype** — no calendar button until the first workout;
   "Start Lifting" switches to the Workout tab and starts the usual flow.
   `HistoryCalendarUITests.testCalendarOpensWithNoHistory` is replaced accordingly.

## New / changed visible strings

New: month figures "Workouts", "Sets", "Time", "h"; week titles "This week", "Last week",
"Sep 7 – 13"; "N workouts"; month break "August" + "12 workouts · 180 sets · 9.5 h"; the
new-best count mark; unit badge "kg + lb" (was "Mixed"); detail date "Saturday, Sep 19", time
range "10:30 AM – 11:37 AM"; "Save as Template…" (button); "Workout details"; "Last
<template>"; "Exercises" + "N exercises"; "Add Set" (menu, sheet title); "Load type" (menu);
"As entered" / "Show in kg" / "Show in lb" in the units capsule; edit-set "Weight", "Reps",
"Unit", "The workout will be marked as edited.", "Delete Set" (button); calendar "Sep 2026",
"Previous month", "Next month", "N workouts · N sets · N h", "No workouts", day title
"Monday, Sep 21"; progress "Since first session" badge, "Weight records" / "Least-assistance
records · lower is better" / "Added-weight records" / "Bodyweight record", "N reps",
"Sessions", "N days"; heart-rate zones inside the plate. Approved:
"Add Note…", "Notes", "Start Lifting" on the empty screen.
Removed: the month section header "SEPTEMBER 2026", the row's gym line and chevron, "Name"
row label, the load-type chip, the toolbar menu, the long edit-set footer, the "Change /
Since first session" list row (now the badge), "No gym".

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

Planned: `HistoryOverviewTests` (month summary, intensity, week grouping and titles, a week
spanning two months), `HistoryRowFactsTests` (families, new-best count judged against the
past only, warmups out, assisted lower-is-better), `HistoryEditing` add-set test; UI tests
updated for the moved menu items and the calendar's select-then-open; new
`FloodlightHistoryUITests` captures (list, calendar, detail pages, edit set, progress) in
light/dark × Default/AXL on `-uiTestDesignSample`.

## Verification

Scope (DEVELOPMENT: new feature + shared screens): build; unit tests above plus the existing
History/records/progress Domain tests; the History UI flows — `HistoryEditingUITests`,
`HistoryTemplateUITests`, `HistoryCalendarUITests`, `WorkoutNameUITests`,
`HeartRateSummaryUITests`, `ProgressChartUITests`, `ProgressChartTooltipUITests`, the
History parts of `RedesignScreenshotUITests` and `CoreLoopUITests` (View in History), the
finish receipt's `FloodlightFinishUITests` (shared heart-rate section), `BarbellUITests`
(bar breakdown in History), `MachineDeletionUITests` (history after a machine is deleted),
`CardioUITests` (cardio in History); Default/AXL captures in light and dark.
Simulator WT-Floodlight (iOS 27.0). Results: `/tmp/wt-floodlight/results/history-*`.

## Progress

- 2026-09-27: resumed (branches verified: history = finish tip `1c3fc99`, pushed); read the
  prototype History screens and the real History code; prototype captures taken; ticket written.
