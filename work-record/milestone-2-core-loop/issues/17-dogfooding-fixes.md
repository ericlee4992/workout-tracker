# 17 — Dogfooding fixes (first real-use pass)

**What to build:** Fifteen faults found by driving the app (UI-test walkthrough) and by inspecting a real user session's data. None were caught by the 136 unit tests, because all of them are about behaviour in the hand rather than logic correctness.

**Blocked by:** None — 01–16 are all resolved.

**Status:** resolved

## A. Honesty / data integrity (highest priority)

- [x] **A1 — An empty set can be completed.** Tapping the checkmark with no weight and no reps persists the set; History shows "1 sets" and the detail reads `— × —`, and that row feeds records/volume/prefill. Completion must require valid reps (> 0) and, for every load type except plain `bodyweight`, a weight value. Bodyweight exercises need reps only.
- [x] **A2 — Empty workouts persist to History.** `WorkoutSession.finishInPlace` deletes draft sets and empty entries, then stamps `finishedAt` unconditionally, so Start → Finish with nothing logged leaves permanent litter. If nothing survives cleanup, delete the workout instead of finishing it.

## B. Speed (the product's core claim)

- [x] **B1 — No within-session carry-forward.** "Add Set" yields a blank row with PREVIOUS `—`; prefill only reads *previous finished workouts*. On a 4-set exercise every set is retyped. A new set must inherit weight + unit + reps from the last completed set of that same entry, arriving populated but **uncompleted** (same rule as ticket 11: one tap logs it).
- [x] **B2 — Finish always costs two taps.** The toolbar Finish only opens a dialog, on every workout including ones never derived from a template. Finish should finish; surface save-as-template in the post-finish confirmation instead.
- [x] **B3 — The numeric keyboard cannot be dismissed.** decimalPad/numberPad have no Done key and tapping elsewhere doesn't dismiss; it covers the lower set rows. Add a keyboard toolbar with Done.

## C. Navigation / trapped state

- [x] **C1 — You cannot leave an active workout.** The tab bar renders but is not hittable (`isHittable == false`); the only exits are Finish or a destructive Cancel. Allow minimising the active workout (keeping it active) with a persistent "resume" affordance on the Workout tab.
- [x] **C2 — No feedback after finishing.** Finishing drops you on the Workout tab with no confirmation and no link to the workout just logged.

## D. Equipment context discoverability

- [x] **D1 — Selected gym is not remembered** (resets to "No gym" each launch), and a no-gym workout **silently hides "Add by Machine"**, so the entire equipment-aware differentiator vanishes with no explanation. Persist the selection; when no gym is set, keep the affordance visible and explain why it's unavailable.
- [x] **D2 — Gym default unit and city are set-once.** Detail shows them read-only; the menu offers only Rename/Archive. Same for a machine's default unit. A wrong unit currently means archive-and-recreate. Make them editable.
- [x] **D3 — New machine's Add stays disabled until a label is invented**, even after picking a catalog model that could supply a sensible default label.

## E. Legibility

- [x] **E1 — History rows are headlined by the gym name**, so every workout at one gym is indistinguishable. Derive a real title: template name when `sourceTemplateID` is set, else the exercises performed (e.g. "Chest Press +2"), with the gym as subtitle.
- [x] **E2 — "1 exercises".** Hardcoded plurals in the History stats string; applies to sets too.
- [x] **E3 — Short workouts all read "0 min".** A 14-second and a 45-second workout are indistinguishable. Show seconds below a minute.
- [x] **E4 — Unit badge is orphaned** bottom-left under the map pin, far from the stats it qualifies; rows without a badge have a different left edge.
- [x] **E5 — The set-type control is an unlabelled number button** ("1"); cycling warmup/working/failure is undiscoverable and its accessibility label is literally "1". Give it a proper label and a discoverable affordance.

## Acceptance

- [x] Every box above ticked, with a regression test for A1, A2, B1 specifically
- [x] `xcodebuild test` green (unit + UI)
- [x] The UI-test walkthrough still passes end to end

## Resolution — active-workout half (A1, B1, B2, B3, C1, C2, E5), 2026-08-09

- **A1** — `WorkoutSession.isLoggable(reps:weightValue:loadType:)` is the rule: positive reps
  always, plus a non-nil weight value for `weighted`/`assisted`/`bodyweightPlus` (0 is a real
  answer there — it mirrors ticket 12's `RecordsMath.isEligible` — nil never is); plain
  `bodyweight` logs on reps alone. `toggleCompletion` throws `WorkoutSessionError.setNotLoggable`
  rather than persisting `— × —`; the guard only blocks the completing direction, so an
  already-completed row (including legacy data) can always be un-completed. The row's checkmark
  is disabled and greyed until the values *on screen* satisfy the rule, so it never fails
  silently.
- **B1** — `addSet(to:)` seeds the new row from the entry's last **completed** set (weight value,
  unit, reps, normalizedKg), uncompleted, so one tap logs it. No completed set yet → unchanged
  behaviour (unit only, leaving ticket 11's cross-workout prefill to fill it). `applyPrefill`
  now refuses a row whose entry already has a completed set: PREVIOUS still shows cross-workout
  history as a reference label, but today's numbers own the inputs.
- **B2** — Finish finishes. The from-scratch save-as-template dialog is gone; the D18
  template-drift prompt still runs for workouts with a `sourceTemplateID`.
- **B3** — Keyboard toolbar with Done on the focused row only (clearing focus runs the same
  end-editing commit, so ticket 07's durability boundary is untouched).
- **C1** — Toolbar chevron-down minimises the cover with the workout still active; the Workout
  tab shows a "Resume workout" row (gym · N exercises) that reopens it via the existing
  newest-active-wins `resumableWorkout`. Cancel stays destructive-with-confirmation.
- **C2** — New `WorkoutFinishedSheet`: what was saved (exercises · sets · gym), "View in
  History", and the relocated "Save as Template", all skippable with Done.
- **E5** — The set-type marker is a Menu with Warmup/Working/Failure (checkmarked), labelled
  "Set type: working". Compact W/#/F visual unchanged; `WorkoutSession.setType(_:of:)` added.

Tests: `WorkoutTrackerTests/SetLoggingTests.swift` (8 new — load-type loggability rules, empty
completion leaves no trace/snapshot/memory, per-load-type completion, guard never invalidates a
completed set, carry-forward seeds/stays-uncompleted/ignores later drafts/outranks cross-workout
prefill) and two new UI tests (`testAddSetCarriesForwardTheLastCompletedSet`,
`testMinimizeKeepsTheWorkoutActiveAndResumeReopensIt`). Existing fixtures that completed empty
sets now log weight+reps. Suite: 144 unit + 3 UI green.

Not done here (owned by the sibling agent): A2, D1–D3, E1–E4 — the Acceptance boxes stay open
until those land.

## Resolution — history/gyms half (A2, D1–D3, E1–E4), 2026-08-09

- **A2** — `finish` now returns `WorkoutFinishOutcome` (`.saved` / `.discardedEmpty`).
  `finishInPlace` counts the entries that survive cleanup; zero survivors means the workout is
  *deleted* rather than stamped, so Start → Finish with nothing logged leaves no trace — including
  for the strays `startWorkout`/`resumableWorkout` auto-finish. The C2 sheet takes an optional
  workout: nil renders "Nothing to save · No sets were completed, so this workout wasn't saved."
  with no History link and no save-as-template, so a discarded workout is *said*, not vanished.
  `RootView` presents it through a per-finish `FinishConfirmation` (a deleted workout cannot be a
  `sheet(item:)` subject).
- **D1** — `AppPreferences.selectedGymID` (scalar, ticket 02 noted) + `Domain/GymSelection.swift`:
  every pick is remembered, restored once per screen lifetime, and an archived or deleted gym
  resolves back to "No gym" rather than sneaking past archival. "Add by Machine" is no longer
  hidden for no-gym workouts — it stays visible, disabled, under "Pick a gym to log by machine".
- **D2** — `EquipmentLifecycle.update(gym:…)` / `update(machine:…)`. Ticket 06's add sheets are now
  `GymEditorSheet` / `MachineEditorSheet`, create-or-edit by an optional target: gym name + city +
  default unit, machine label + default unit. Gym detail gained an "Edit Gym…" row next to the
  values it shows, and the machine context menu offers "Edit Machine…" in place of the rename
  alert. A machine's *model* still changes only through "Correct Model…" (D10 past-vs-future), and
  seeded catalog models/exercises stay read-only (D24).
- **D3** — Picking a catalog model fills the label from the model name, so Add is immediately
  enabled. Only a label the sheet wrote itself is ever overwritten; a model-less machine still
  needs one typed.
- **E1** — `HistoryRendering.title(templateName:exerciseNames:)`: template name wins, else the
  exercises performed ("Chest Press +2", duplicates collapsed), else "Workout". Names come from
  entry SNAPSHOTS (D23), so a later rename never retitles history. Gym is the subtitle, taken from
  `snapshotGymName` with the live gym as fallback.
- **E2/E3** — `HistoryRendering.pluralized` and `durationLabel` (seconds below a minute, minutes
  above, never negative) feed one `statsLine`; the detail screen uses the same duration label.
- **E4** — The unit badge moved inline, straight after the stats it qualifies, so every row has the
  same left edge whether or not it has one.

Tests: `WorkoutSessionTests` (+3 — empty finish deletes across a reopen, one completed set
survives, empty strays discarded; `startWorkoutFinishesLingeringActives` now logs a set so it still
tests finishing rather than discarding), `HistoryRenderingTests` (+7 — title precedence, snapshot
sourcing under a live rename, pluralization, sub-minute durations), `GymSelectionTests` (+3, new),
`EquipmentLifecycleTests` (+2 — gym/machine update, blank-name rejection), and two new UI tests
(`testFinishingAnEmptyWorkoutDiscardsItAndSaysSo`, `testGymSettingsAreEditableAndModelNamesTheMachine`).
Suite: 159 unit + 5 UI green.

## Resolution — post-review fixes (Codex cross-review 3), 2026-08-09

The two halves above were written in parallel; the review found a data-loss seam between them
plus four D23/A1 leaks. Fixes, in the reviewer's severity order:

- **CRITICAL — an empty template workout erased its template.** `TemplateDriftService.apply`
  deletes every `TemplateItem` and rebuilds from the resolved snapshot; with nothing completed
  (B2 kept the D18 prompt, A2 made finish discard empties) the resolved snapshot was empty, so
  "Update Template"/"Update Both" deleted all items and wrote none back — and `resolve` then
  discarded the workout, so the receipt said "nothing was saved" while the template was gone.
  `apply` now returns without touching the template when the workout has no completed entries,
  and `shouldPrompt` no longer offers the question at all: with nothing logged there is nothing
  the template could be updated *from*. The guard lives in the domain service, so it holds for
  the finish screen, the replace-active-workout path, and any future caller.
- **D23 — history titles read live rows.** `Workout.sourceTemplateName` and
  `Workout.snapshotGymName` are captured when the workout starts (schema note in ticket 02).
  `historyTitle` is now a snapshot-only property (no live `WorkoutTemplate` query in
  `HistoryView` at all) and `historyGymName` falls back to the workout's own snapshot rather
  than to `gym?.name`. Renaming or deleting a template, or renaming a gym, leaves finished rows
  untouched.
- **A1/D19 — frozen entries validated with the live load type.** `ExerciseEntry
  .effectiveLoadType`: once `snapshotCapturedAt` is set the snapshot decides; before the freeze
  the live exercise still does. `WorkoutSession.loadType(of:)` and `ExerciseEntryCard` both read
  it, so a catalog reconciliation or an exercise edit mid-workout can no longer let a weighted
  snapshot accept reps-only and recreate `— × reps` rows.
- **C2 — "View in History" now opens the workout.** `HistoryView` takes a `target` binding that
  it consumes into its navigation path (on appear as well as on change, since the tab may be
  created only after the request); `RootView` hands it the workout the receipt is about.
- **E1 — title dedup keyed on snapshot exercise IDs.** `HistoryRendering.title` takes
  `[HistoryExercise]` (id + name) and collapses repeats by id, so two distinct exercises sharing
  a display name stay two exercises.
- **Minor — UI and domain disagreed on weight validity.** `WorkoutSession.weightValue(from:)` /
  `isLoggable(weightText:repsText:loadType:)` own the parsing for both the view and
  `commitWeight`, and reject what `StoredWeight` rejects (negative, NaN, infinite). The
  checkmark can no longer light up on input the store will refuse.
- **Minor — post-finish summary read the live gym**; it uses `historyGymName` like the rest of
  history.
- **Minor — E5 had no visible menu affordance.** The set-type marker keeps its 34×28 footprint
  and gains a 7-point chevron, so it reads as a control with options rather than a number.

Tests: `TemplateDriftTests.emptyTemplateWorkoutNeverTouchesItsTemplate` (parameterized over all
four resolutions — 3-item template, nothing completed, template intact after both `apply` and
`resolve`, workout discarded), `HistoryRenderingTests` (+2 — rename/delete the template and
rename the gym after logging, row unchanged; same-named distinct exercises not collapsed),
`SetLoggingTests` (+2 — frozen entry validates with the snapshot load type while a fresh entry
follows the live one; on-screen loggability matches what the store accepts), and a new UI test
`testViewInHistoryOpensTheWorkoutJustLogged`. Suite: 164 unit + 6 UI green.

Not changed (correct per the review): the carry-forward prefill contract, the loggable-set
guard's shape, and the empty-workout discard.
