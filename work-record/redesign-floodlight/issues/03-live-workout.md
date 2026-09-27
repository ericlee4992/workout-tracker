# 03 — Floodlight: the live lifting workout and its sheets

Type: feature (part of [01](01-implement-redesign.md))
Status: implemented; verification in progress; Codex review pending
Implementer: Claude. Reviewer: Codex.
Branch: built on `ericlee4992/redesign-floodlight` after ticket 02.

## Scope

The live lifting workout in the chosen look — Paper Club's STRUCTURE in Floodlight's palette and
type (`Look.live(dark:)`); cardio focus and every sheet over the cover stay plain Floodlight.

- `ActiveWorkoutView`: toolbar minimise · workout name + pencil (rename) · Finish (Cancel moved
  out of the bar); header line gym · clock with seconds · N/M sets ring (`LiveHeaderLine`);
  vitals strip heart rate · active calories · total volume with the kept source line
  (`LiveVitalsStrip`); planned cardio as a list with explicit Start; Lifting | Cardio switch;
  exercise cards; "Recent at <gym>" on an empty workout; add block (Add Exercise filled unless
  resting · Add by Machine · Add Cardio); **Discard Workout…** at the end of the list (same
  confirmation dialog); the ink rest slab with "Next · Set 3 · 110 × 8" / "Next · <exercise>"
  (`LiveRestSlab` over `RestBar`).
- `ExerciseEntryCard`: title with superset letter, outlined previous-performance and "…" buttons
  (the "…" keeps its menu: Rest Durations…, Superset with next, Break superset, Delete
  Exercise), bordered equipment row (weight-stack glyph for machines), bar chip, Target caption
  (only with a planned rest, as before), assisted note, column header, rows, preset chips,
  dashed Add Set.
- `LiveSetRow` (replaces the old row): round set marker as the set-type menu, PREVIOUS with
  New best / First time sticker, weight/reps in pencil→ink boxes around the real text fields,
  unit suffix toggle, bar total, round check with stamp + ripple, swipe/menu delete. All the old
  row's commit, prefill, A1 and bar rules are carried over unchanged.
- Domain: `NextSet.swift` (`NextSetMath` — next-up set incl. superset alternation) with
  `NextSetTests`; `SetBadges.swift` (ticket 02) is now wired: marks recomputed on appear, on
  completion changes and when entries change.
- Sheets (native lists, Floodlight tokens via `lookGroupedList` / `lookListRows`): Add Exercise
  (sections head to toe with a family mark, "Recent at <gym>" first, clearer rows), equipment,
  Add by Machine, bar, rest durations, max heart rate, previous performance.
- Fixture: `-uiTestDesignLive` (Push Day running, two sets logged, rest running, machines with
  history) and `-uiTestDesignLiveEmpty` (an empty workout at Iron Temple).

## Behaviour and rules kept

Identifiers: `workoutTitle`, `minimizeWorkout`, `finishWorkout`, `workoutActivityFocus`,
`startPlannedCardio`, `hrBpm`, `hrSource`, `hrZone`, `hrZoneSetup`, `hrZoneEdit`, `hrCalories`,
`hrMessage`, `addExercise`, `addByMachine`, `addByMachineUnavailable`, `addCardio`, `addSet`,
`entryEquipment`, `barPicker`, `presetChip.*`, `supersetBadge`, `supersetWithNext`,
`breakSuperset`, `entryTitle.*`, `setRow.{setType,previous,weight,unit,reps,total,complete,
swipeDelete}`, `keyboardDone`, `exerciseOption.*`, `createExerciseFromSearch`, `newExercise`.
The heart-rate source is always named; zones only with a basis; the heart does not beat when
stale; rows are created only deliberately; rest skips between superset members (D48); D46
scheduled alarm untouched; the equipment/preset freeze rules are the session's, unchanged.

## Decisions to flag to the user

- Discard moved from the toolbar's Cancel to "Discard Workout…" at the end of the list (as the
  approved Paper-structure design). The confirmation is unchanged.
- PREVIOUS shows "105 × 8" when the unit matches the row (the approved design); VoiceOver and
  the tests still read the full "105 lb × 8".
- Sheets keep the system list/form (search, swipe, pickers) in Floodlight colours rather than
  the prototype's fully custom sheet layouts; functional additions ported where they matter
  (Add Exercise's "Recent at <gym>" and body-area sections).

## New / changed visible strings

New: vitals labels "Active calories", "Total volume", "cal"; "Recent at <gym>"; "Discard
Workout…"; rest slab "Next · Set N · W × R" / "Next · <exercise>" / "Next · Warmup";
"New best" / "First time"; "Cardio targets" (was "Planned cardio"); "Uncategorized" in Add
Exercise; the "0/0 sets" header on an empty workout (was the same count).
Changed: PREVIOUS short form (above). Removed: the toolbar Cancel.

## Tests changed

- `LiveWorkoutHelpers.discardActiveWorkout()` replaces "Cancel" → "Discard Workout" in
  `CoreLoopUITests` (2) and `HeartRateUITests` (3).
- New unit tests `NextSetTests` (6).

## Verification

Scope (DEVELOPMENT: shared workout lifecycle + new feature): build; the live-workout UI flows
below (core logging loop, supersets/rest, heart rate, bar mode, presets, machine deletion,
dumbbell counterpart, rename, cardio mix, captures); unit tests for the new Domain rules;
Default/AXL captures in light and dark. Simulator WT-Floodlight (iOS 27.0).

- Build: exit 0.
- `live-ui-1` (31 UI + 12 unit): unit `NextSetTests` 6/6 + `SetBadgeTests` 6/6 passed. UI 28
  passed, 5 failed — all five **pre-existing**: they fail identically on untouched `main`
  a0364f2 (`base-5.log`): the Exercises tab's search field (CoreLoop
  `testCreatingAnExerciseMidWorkoutLogsASetAndReachesHistory`, both `ExercisePresetUITests`),
  the Gyms model-picker type submenu (CoreLoop `testModelPickerFiltersAndSearchesDownToOneModel`)
  and History detail's heart-rate section (`HeartRateSummaryUITests.testFinishShowsTheChart…`).
  None is in a screen this ticket changes; each goes to its area's ticket.
  Passed include: CoreLoop core loop / one-tap repeat / Add Set carry-forward / swipe delete /
  minimise-resume / View in History / empty finish / gym settings; HeartRateUITests 5/5;
  BarbellUITests 2/2; MachineDeletionUITests 2/2; DumbbellCounterpart; WorkoutNameUITests 2/2;
  CodexScreenshotUITests 3/3; HeartRateSummary no-series; RedesignScreenshot
  test02 default + AXL; Cardio mixed workouts 2/2.
- Captures: `/tmp/wt-floodlight/shots/l01-{light,dark,axl,empty}.png` (fixture).

## Progress

- 2026-09-26: implemented in the scratch checkout `/tmp/wt-floodlight/live` (branch
  `ericlee4992/redesign-floodlight-live`, rebased on 37f16a0) while Codex reviewed ticket 02.
  Captures: `/tmp/wt-floodlight/shots/l01-{light,dark,axl,empty}.png`.
