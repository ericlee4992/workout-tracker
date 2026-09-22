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

---

# Addendum 1 — template grid layout fix and F1/F2 resolutions (static, preliminary)

Date: 2026-09-22, later session. Reviewed in the implementation checkout: the uncommitted
`StartWorkoutView.swift` diff against **51da414** (the only product change; no save, query or
schema change, confirmed by `git diff 51da414 -- WorkoutTracker/`), the iOS 27 baseline evidence
(`results/followup/ios27-baseline.log`, exit file **65**, failure at `AskAIUITests.swift:23`,
`ios27-store-check.txt`), the before screenshot
`screenshots/followup/ios27-before-blank-grid.png`, and the F1/F2 tests committed in 51da414.
No build or simulator run by the reviewer; the red-to-green run `ios27-eager-grid.*` was still
pending when this was written.

## Reproduction evidence — accepted as an exact reproduction

- The before screenshot shows the Templates section with a blank block the height of one grid
  row above a row holding **Day 3 — Fitness** and **Whole Body**, then New Template… This is the
  user's report: space where the first two cards belong, third card drawn.
- The failing assertion is `reach()`'s final `exists && isHittable` on the Day 1 tile, not the
  OCR check, so the tile was not reachable at all after scrolling to the top. The store check
  lists all four template names and 24 items. Together they falsify "incomplete save" and
  make "stale @Query" unlikely (the grid reserved the height for four cells and rendered the
  later two). The remaining hypothesis, first-row cells of a nested `LazyVGrid` inside one List
  row not being instantiated on iOS 27, is what the fix targets. Same case passing on iOS 26.5
  at both sizes supports the OS-runtime variable. Evidence is sufficient to justify a
  one-variable layout change.

## Layout fix — clear on static reading, pending the green run

`StartWorkoutView.swift:61-84, 211-234`: the `LazyVGrid` becomes a `VStack` of `HStack` rows,
`columns` = 1 at accessibility sizes else 2, spacing 10 both ways, cells in the same order
(templates then New Template…), same `templateButton`/`newTemplateButton` bodies, identifiers
unchanged. Checks:

- **Equal widths.** `TemplateTile` and the New Template button both carry
  `.frame(maxWidth: .infinity)`; the odd-cell filler is `Color.clear.frame(maxWidth: .infinity)`
  with zero height, so the HStack splits every row equally and a lone last card keeps half
  width, as in the screenshot's New Template… cell. Correct.
- **Row count.** `(cells + columns - 1) / columns` with `cells = templates.count + 1`; the
  index arithmetic covers `index < templates.count`, `== templates.count` (New Template…) and
  fillers. Correct for 0..n templates and both column counts.
- **Identity.** `ForEach(0..<rows, id: \.self)` over a range that changes with the count is
  valid with `id: \.self`; cells are keyed by position, so a template that moves changes the
  content of an existing cell. `TemplateTile` has no `@State`, so nothing sticks to the wrong
  template. Acceptable.
- **Alignment.** `HStack` default centre alignment matches the previous `LazyVGrid` row
  behavior (the screenshot shows Day 3 and Whole Body centred against each other), so the look
  is unchanged. Advisory only: `HStack(alignment: .top)` would read better for unequal tiles,
  but that is a design change outside this ticket.
- **Laziness.** The parent List row still virtualizes; the collection is personal-sized, and
  the comment records why laziness was dropped. Fine.
- The ticket-15 context-menu note was shortened to one line at `templateButton`; the
  behavior (no context menu on tiles) is unchanged.

Evidence required before clearance: `ios27-eager-grid` green with actual exit 0 and its
xcresult summary; the same populated case at AccessibilityL on iOS 27; the two original
short-tile cases; `TemplateDetailUITests` and the `RedesignScreenshotUITests` Start pair on the
new layout (the row structure changed, so the Start captures must be retaken and opened); and
one run of the same case on iOS 26.5 to show no regression on the earlier runtime. A green OCR
assertion must show a non-empty "Pixels read" path at least once in the log.

## F1 — resolved in 51da414

`testRoutineGymPickerRemembersExistingGymAndNoGym` selects an existing gym in `routineGym`,
confirms Scan Machine and the count appear, cancels, and asserts the Workout `gymPicker` label
contains that gym; then selects **No gym** and asserts the Workout picker reads "No gym". The
`scanDuringRoutine` cases additionally assert, after cancelling the unsaved routine, that the
Workout picker shows the gym added in-sheet and that the two "Chest press" machines exist under
Gyms → gym detail. That covers D1 remembering, the No gym path, and "explicit machine saves
survive routine cancel" (D58 amendment). Remaining gap, advisory: no assertion that the footnote
"Choose or add a gym to save scanned machines." is present in the No gym state; add a
`staticTexts` check when convenient.

## F2 — unchanged code, resolution by evidence

`MachineEditorSheet.load()` still presents the scanner from `onAppear`. Acceptable if the three
routine-scan cases (default, AccessibilityL, consent/failure) pass on a clean run on both
runtimes with no retry. Record any retry in the ticket; if one is needed, apply the `.task`
fallback from F2 before clearance.

## Status

No blocking static finding in this diff. Clearance waits on the named evidence above and the
final commit. No merge or push is authorized by this addendum.

---

# Addendum 2 — verification scope assessment (DEVELOPMENT T8)

Date: 2026-09-22, later session. Assessed from the implementer's stated scope; no product
change since the eager-grid diff reviewed in Addendum 1. No tools or tests run by the reviewer.

Reported: the focused iOS 27 populated case passed with all three cards OCR-drawn and opened;
result collection was still finishing. Queued final scope: three domain suites (`AIGymTests`,
`WorkoutTemplateTests`, `EquipmentLifecycleTests`) plus eleven UI cases on iOS 27, and a bounded
iOS 26.5 smoke of the populated grid and the default routine scanner. Ticket records capture
equivalence: `followup-start` default/AXL share the empty fixture, the three-template captures
share the populated state, and `TemplateDetailUITests` covers row identity through deletion.

Assessment under the Verification scope table:

- The grid change is "layout within one screen" plus "shared presentation of persisted data";
  the routine-setup change is "new feature". Both rows call for build, affected UI flows, real
  default/AccessibilityL captures of the changed screens and relevant domain tests. The queued
  scope meets that. It does not need the full UI suite: the changed surfaces are the Start
  templates section and the routine sheet's equipment section, and the eleven cases exercise
  both directly plus the adjacent template detail flow.
- **Both-runtime coverage.** Requiring every scan case on both runtimes is not warranted. The
  layout defect was runtime-specific, so the populated grid on both runtimes is the right
  control; the scanner code did not change between runtimes, and the earlier 26.5 scan runs
  reached Add, Cancel and Generate at both sizes and failed only on a fixture name that has
  since been corrected. One 26.5 scanner smoke at the default size is sufficient; record the
  earlier partial runs as evidence with their actual failure line, not as passes.
- **Captures.** Replacing the historic RedesignScreenshot Start pair with the new
  `followup-start` and three-template pairs is acceptable because each pair shares one fixture
  and state at both sizes (REFERENCE — Captures). State in the ticket that the historic Start
  captures are superseded for this section, and open the new PNGs.
- **Honesty conditions.** Actual exit 0 for the focused run and for the final scope, xcresult
  summary lines with zero skipped, the OCR stdout showing recognized text for each card, and
  any retry noted. The F2 condition stands: the routine-scan cases pass without retry, or the
  `.task` fallback is applied before clearance.

Scope accepted as bounded and sufficient, conditional on the evidence above. No merge or push
is authorized by this addendum.
