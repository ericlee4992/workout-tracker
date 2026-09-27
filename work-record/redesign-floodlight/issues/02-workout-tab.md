# 02 — Floodlight: design foundation + Workout tab, template detail and editor

Type: feature (part of [01](01-implement-redesign.md))
Status: implemented and verified (targeted); Codex review pending
Implementer: Claude. Reviewer: Codex (the user's choice for this redesign).

## Scope

- Foundation (commit `b22f2c0`): `Features/Design/Look/` design system, Appearance setting,
  forced dark removed, legacy `Theme` bridged to the Floodlight palette. Details in ticket 01.
- Workout tab (`Features/Start/StartWorkoutView.swift`, `WorkoutHomePieces.swift`): large
  "Workout" title + date, gym picker row (system menu kept), the Start pair (equal capsules,
  stacking at AX) or one Resume capsule with a live clock, **This week** card (first run:
  seven quiet days), Templates grid (eager `Grid`; New Template… and Ask AI for Templates as the
  last row; AX: one column + make rows). Running template's tile carries a live dot.
- Template detail (`TemplateDetailView.swift`, `TemplatePieces.swift`): name, summary, family
  tally (target sets per family), Times run / Last run / Avg. time, exercise rows with targets,
  rest, the equipment each row starts on at this gym, superset tags + chain seal, cardio targets,
  Delete Template… last, Start pinned (Resume when this template's workout is running).
- Template editor (`TemplateEditorSheet.swift`): name field + live family strip + summary,
  exercise cards (drag handle, rep pills with per-set stepper, + adds a set, rest chip with
  Default / time, remove), chain-link seams that make/break supersets, searchable Add Exercise
  picker grouped by body area, cardio target cards, Discard changes? on a dirty Cancel.
- Domain: `SetBadges.swift` (live-workout New best / First time rules + tests; wired in the live
  area), `WeekSummary.swift` (`WeekSummaryInput`, `WeekSummaryMath`), `TemplateStats.swift`,
  `WorkoutTemplateService.resolvedMachine` (extracted from `start`, shared with the detail).
- Capture fixture: `-uiTestReset -uiTestDesignSample` (`DesignSampleFixture`): gym Iron Temple,
  Push/Pull/Leg Day templates, six finished workouts over two weeks.

## Behaviour and rules kept

- Identifiers: `gymPicker`, `startEmptyWorkout`, `startCardio`, `resumeWorkout`, `askAIRoutine`,
  `templateTile.<name>`, `openSettings`, `startTemplate`, `editTemplate`, `deleteTemplate`,
  `templateExercise.<name>`, `templateFamilies`; nav bar "Workout"; "Template name" field;
  Cancel/Save in the editor's navigation bar (first bar button stays Cancel).
- No long-press menu on tiles; Delete confirmed by alert with the kept consequence line.
- Week and tile stats only from FINISHED workouts; start-day bucketing (as History's calendar);
  warmups never count; every load type counts; family from the live `muscleGroup` (documented).
- Template detail caption "N sets · r, r, r reps" (user-kept) unchanged.

## Decisions to flag to the user

- **Week start:** "This week" follows the phone's calendar (US: Sunday first), the same weeks
  History's calendar draws. The prototype showed Monday first. Easy to switch if preferred.
- Template order stays alphabetical (existing behaviour).
- Template detail rows are not tappable yet (the prototype opens an exercise detail screen,
  which belongs to the Exercises area; revisit there).
- New editor feature from the prototype: supersets can be made in the editor (chain link).
  Drag reordering replaces the old EditButton reorder mode.

## New / changed visible strings (user may veto any)

New: date line "Thursday, Sep 24"; This week card ("This week", "N sets", "Workouts", "Time",
"Last week", "h", "min"); tile last-run date "Sep 23" and "+ N more"; Resume detail
"Push Day · 7/18 sets" (was "<gym> · N exercises"); detail "Ask AI" label, "5 exercises · 18
sets", "Times run", "Last run", "Avg. time", "Exercises", "Cardio targets" (was "Planned cardio"),
rest "1:30" with a timer glyph (was "Rest: 90s"), equipment line (machine label / tag), detail
"Resume workout"; editor "Add Exercise" (picker), "Search exercises", "Uncategorized", "Add
Cardio Target" (was "Add cardio target"), rest chip + "Default", "Set N", "Discard changes?",
"Discard Changes", "Keep Editing"; Settings "Appearance" (System / Light / Dark).
Removed: "Machines resolve to your last-used at …" caption; "Add at least one exercise below.";
the "Use exercise rest default" switch and "Rest: Ns" stepper (replaced by the rest chip).

## Tests changed

- `RedesignScreenshotUITests.test04_startLargeText`: asserted the removed "Machines resolve"
  caption; now asserts Ask AI for Templates is reachable at AXL.
- Editor-driving tests (`test04_startTemplates`, `test04_startLargeText`,
  `TemplateDetailUITests`, `CodexScreenshotUITests`) add exercises via the new picker helper
  `XCUIApplication.addTemplateExercises` (`TemplateEditorHelpers.swift`).
- `AskAIUITests`: "Add Cardio Target"; the default-rest case reads the rest chip
  (`templateRest`, value "Default, m:ss") instead of the removed switch.
- New unit tests: `WeekSummaryTests` (5).

## Verification

Selected scope (DEVELOPMENT: new feature + shared screen): build; all unit tests (Domain changed);
the Workout-tab, template and AI-template UI flows below; Default/AXL captures in light and dark.
Full UI suite deferred to the whole-redesign release candidate (ticket 01 step 4). Simulator
WT-Floodlight (iPhone 15 Pro Max, iOS 27.0). Logs and result bundles: `/tmp/wt-floodlight/results/`.

- Build `xcodebuild … -sdk iphonesimulator build`: exit 0.
- UI batch 1 (`area1-ui-1`, 17 tests): 15 passed, 2 failed — `test04_startLargeText` (asserted
  the removed "Machines resolve" caption; test updated) and
  `AskAIUITests.testAllThreeGeneratedTemplatesInPopulatedListAccessibility` (below).
  Note: batch 1 compiled before the editor rewrite, so its editor flows ran the old editor.
- UI batch 2 (`area1-ui-2`, area-1 source only, 10 tests): 9 passed — `test04_startTemplates`,
  `test04_startLargeText`, `CodexScreenshotUITests.testWorkoutScreens`, both
  `TemplateDetailUITests`, `AskAIUITests` weekly routine / edit generated week / existing
  template default rest (Default + AXL) — and the same AskAI AXL case failed.
- **Pre-existing failure, not caused by this work:** that AskAI AXL case fails identically on an
  untouched `main` (a0364f2) build on the same simulator (`base-axl.log`, exit 65,
  `AskAIUITests.swift:23`, `routineEquipment.dumbbells` never reachable in the AI routine sheet at
  AccessibilityL). Left for the AI-routine area ticket.
- Unit tests: whole `WorkoutTrackerTests` target 787 tests, 1 failure — `ThemeTests` still asserted
  the deleted `MuscleBody` colour asset; fixed (the colour is a Look token). Re-run of
  `ThemeTests`, `SetBadgeTests`, `WeekSummaryTests`: 13/13 passed, `** TEST SUCCEEDED **`.
- Captures (fixture, WT-Floodlight): `/tmp/wt-floodlight/shots/w01-{dark,light,axl}.png` — match
  `reference/captures/*/W01-final.png` apart from the week's first day (flagged above).

## Progress

- 2026-09-26: foundation committed `b22f2c0`; Workout tab, detail, editor implemented.
