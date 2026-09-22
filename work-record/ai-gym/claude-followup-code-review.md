# Claude code review — ticket 07, scanning/setup/copy (preliminary, static)

Reviewer: Claude (independent, AGENTS T6). Date: 2026-09-22. Stage: **static review of the
uncommitted diff against `5a894da`** in the implementation checkout
(`ericlee4992/ai-template-followup`). Scope as requested: Scan Machine entry, gym select/add in
routine setup, copy changes and their tests. The template-visibility fix is not in this diff
and is not reviewed here. No build, simulator run or capture was performed by the reviewer;
run results, captures and the commit are reviewed later.

Read: the full product diff (`GymsView.swift`, `IdentifyEquipmentSheet.swift`,
`StartWorkoutView.swift`, `AIRoutineSheet.swift`), the test diff (`AskAIUITests.swift`), the
updated ticket 07, the D58 September 22 amendment, SPEC line 64, `spec.md` follow-up, and the
call sites the diff depends on (`StartWorkoutView.select`, `GymSelection.remember`,
`TerraAccess.bypassesConsent`, `WorkoutTrackerStore.fixtureIsEnabled`, `MachineEditorSheet`
`load`/`save`, `GymEditorSheet.save`).

## Summary

The diff resolves the four P1 items of the [plan review](claude-followup-plan-review.md) the way
the ticket says: the machine editor's identity resolution and Add save are reused unchanged
through an opt-in `startsWithScanner`; the gym is sheet state with an immediate remembered pick
through `StartWorkoutView.select` (D1); the gym editor is reused with a success callback; the
copy list is recorded, including the shared scanner instruction. No schema or stored-property
change. Nothing here blocks proceeding to test evidence. Two findings need a code or test change
before final clearance (F1, F2); the rest are evidence requirements and advisories.

## Findings

### F1 — Gym picker path and the D1 side effect are untested (test gap, must fix)

`AIRoutineSheet.swift` adds a `Picker("Gym")` (`routineGym`) whose setter calls `onSelectGym`,
and `GymEditorSheet.onSave` also calls it. Both change the Workout tab's remembered gym via
`StartWorkoutView.select` → `GymSelection.remember` (`StartWorkoutView.swift:233-237`). That is
the documented behavior in the D58 amendment, but no test exercises it:

- `scanDuringRoutine` and `testRoutineScannerConsentAndFailureKeepPreferences` only use
  Add Gym…; the picker is never tapped, so selecting an existing gym, selecting **No gym**
  (which must hide Scan Machine and show the footnote), and the header switching between
  "Equipment at X" and "Available equipment" have no coverage.
- No test asserts the side effect: after Cancel on the routine sheet, the Workout tab's
  `gymPicker` should read the gym chosen inside the sheet. A user who never reads the decision
  will see their gym change; the test should prove it is the intended gym and that "No gym"
  round-trips.

Add one case: launch `-uiTestTemplate`-style populated store or create two gyms, open Ask AI,
pick gym B in `routineGym`, confirm Scan Machine appears with B's count, pick No gym, confirm
Scan Machine is gone and the footnote is present, Cancel, and assert `gymPicker` shows "No gym".

### F2 — Scanner auto-entry is presented from `onAppear` of a sheet still being presented (verify, likely fine, fallback ready)

`MachineEditorSheet.load()` sets `showingScanner = true` during `.onAppear`
(`GymsView.swift:657-660`, modifier at `:619`). This nests a `.sheet` inside a `.sheet` inside a
full-screen cover, triggered before the editor's own presentation finishes. SwiftUI normally
queues it, but a queued presentation is the classic source of "scanner does not open on the
first tap" flakiness. The tests wait 5 s for `scanShutter`, which will catch a hard failure but
not an intermittent one. Requirement for evidence: the two `scanDuringRoutine` cases and the
consent case must pass on a clean run, and the ticket must note any retry. If it flakes, move
the trigger to a `.task` on the editor's `NavigationStack` (runs after the first frame) rather
than adding a delay. Also note the UX consequence, which is acceptable but should be a sentence
in the ticket: Cancel on the scanner lands on an empty **New Machine** form that needs a second
Cancel (the tests encode this at "Scan Equipment" Cancel → "New Machine" Cancel).

### F3 — `-uiTestTerraFullRoutine` changes the fixture shape, so an existing assumption should be checked (advisory)

`AIRoutineSheet.swift` now builds `prefix(6)` strength rows under the new flag and one otherwise.
Behavior under the existing flags is unchanged (`prefix(1)` of the same first option), so the
routine, edit and detail cases keep their expectations. The flag is gated through
`WorkoutTrackerStore.fixtureIsEnabled`, so it cannot fire outside `-uiTestReset`. Fine; record
the flag in DEVELOPMENT's simulator/UI-test section or the ticket so the next reader knows why
the populated cases render six-exercise tiles.

### F4 — `GymEditorSheet` failure handling changed for the Gyms tab too (scope note, acceptable)

The gym editor no longer `assertionFailure`s and dismisses on a failed save; it shows the error
and stays (`GymsView.swift:409-411, 476-479`). That is an improvement and matches
`MachineEditorSheet`, but it is a behavior change on a screen outside the ticket's stated scope.
Record it in the ticket's string list ("error text shown in New Gym/Edit Gym") and keep the
`.red` usage consistent with the machine editor (pre-existing convention; a Theme token swap is
out of scope).

### F5 — Evidence still required for reachability rules (AGENTS: gated settings must be reached)

- The no-key path from this entry (`scannerAISettings` inside identify sheet inside editor inside
  cover) cannot occur under `-uiTestTerra` because the fixture stands in for a client. Existing
  coverage of that screen from the Gyms entry is the only evidence; state that in the ticket
  rather than claiming it was tested from routine setup, or add a fixture flag that leaves the
  client nil.
- The consent test proves the photo consent screen is reachable here and that Cancel at each
  level preserves goals, extras, cardio and routine consent. Good.

### F6 — Copy and identifiers (REVIEW item 11) — clear

Changed strings match the ticket's list: Workout row "Ask AI for Templates" (identifier
`askAIRoutine` kept; the test asserts the label), shared capture instruction
"Scan a machine or its label" (global; recorded), new "Scan Machine",
"Choose or add a gym to save scanned machines.", reused "Gym", "No gym", "Add Gym…". No UI test
queried the old instruction string. Routine title and Settings "Ask AI" unchanged as decided.

### F7 — Refresh semantics (plan item 5) — clear by construction, confirm by test

`availableMachines` reads a main-context `@Query` of unarchived `MachineInstance` and filters by
the selected gym; the editor saves on the environment context, so the count and `options`
refresh without leaving the sheet. The `scanDuringRoutine` case asserts "1 saved machines" then
"2 saved machines", Generate enabled with no extras and no cardio, and "Seated Chest Press" in
day 0. That is the acceptance I asked for. Repeated identical-label machines remain distinct
(count-based assertion, correct since labels are not unique).

### F8 — OCR-backed tile assertion (advisory, for the visibility work)

`assertDrawn` uses Vision on the app screenshot with a normalized region of interest; the
lower-left origin conversion is correct and the check is scale-independent. Two cautions for
when it becomes the regression gate: it runs after `reach`, so it only proves the tile is drawn
once it has been scrolled to, and Vision on the simulator needs the run to show it actually
recognized text at least once (a false "not drawn" on a blank read would look like the bug).
Keep the captures beside the OCR result.

## Design and decisions

- D56 unchanged: one photo, Terra identification, editable proposal, editor Add commits;
  identity resolution and user-space model creation live only in `MachineEditorSheet.save()`.
- D58 amendment recorded as a dated subsection under the table; SPEC line 64 and `spec.md`
  updated consistently. Acceptable; no DECISIONS row text was rewritten.
- ios-design: Scan Machine is a plain Form row, Generate stays the only prominent command; the
  new picker is native (value + disclosure). The ticket now has state sentences and per-tell
  lines. Captures named in the tests: `followup-start`, `followup-no-gym`, `followup-empty-gym`,
  `followup-capture`, `followup-scanned-equipment` at default and AccessibilityL with the same
  fixture; the reviewer will open them.

## What clears this part at final review

F1 test added and passing; F2 cases green on a clean run with any retry recorded; F3–F5 noted
in the ticket; captures opened; actual exit codes and xcresult summary lines for the named scope
(`AskAIUITests` new and existing routine/scan cases, `TemplateDetailUITests`, `AIGymTests`,
`WorkoutTemplateTests`, `EquipmentLifecycleTests`, clean build). No merge or push is authorized
by this review.
