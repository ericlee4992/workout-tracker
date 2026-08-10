# 17 — Dogfooding fixes (first real-use pass)

**What to build:** Fifteen faults found by driving the app (UI-test walkthrough) and by inspecting a real user session's data. None were caught by the 136 unit tests, because all of them are about behaviour in the hand rather than logic correctness.

**Blocked by:** None — 01–16 are all resolved.

**Status:** ready-for-agent

## A. Honesty / data integrity (highest priority)

- [x] **A1 — An empty set can be completed.** Tapping the checkmark with no weight and no reps persists the set; History shows "1 sets" and the detail reads `— × —`, and that row feeds records/volume/prefill. Completion must require valid reps (> 0) and, for every load type except plain `bodyweight`, a weight value. Bodyweight exercises need reps only.
- [ ] **A2 — Empty workouts persist to History.** `WorkoutSession.finishInPlace` deletes draft sets and empty entries, then stamps `finishedAt` unconditionally, so Start → Finish with nothing logged leaves permanent litter. If nothing survives cleanup, delete the workout instead of finishing it.

## B. Speed (the product's core claim)

- [x] **B1 — No within-session carry-forward.** "Add Set" yields a blank row with PREVIOUS `—`; prefill only reads *previous finished workouts*. On a 4-set exercise every set is retyped. A new set must inherit weight + unit + reps from the last completed set of that same entry, arriving populated but **uncompleted** (same rule as ticket 11: one tap logs it).
- [x] **B2 — Finish always costs two taps.** The toolbar Finish only opens a dialog, on every workout including ones never derived from a template. Finish should finish; surface save-as-template in the post-finish confirmation instead.
- [x] **B3 — The numeric keyboard cannot be dismissed.** decimalPad/numberPad have no Done key and tapping elsewhere doesn't dismiss; it covers the lower set rows. Add a keyboard toolbar with Done.

## C. Navigation / trapped state

- [x] **C1 — You cannot leave an active workout.** The tab bar renders but is not hittable (`isHittable == false`); the only exits are Finish or a destructive Cancel. Allow minimising the active workout (keeping it active) with a persistent "resume" affordance on the Workout tab.
- [x] **C2 — No feedback after finishing.** Finishing drops you on the Workout tab with no confirmation and no link to the workout just logged.

## D. Equipment context discoverability

- [ ] **D1 — Selected gym is not remembered** (resets to "No gym" each launch), and a no-gym workout **silently hides "Add by Machine"**, so the entire equipment-aware differentiator vanishes with no explanation. Persist the selection; when no gym is set, keep the affordance visible and explain why it's unavailable.
- [ ] **D2 — Gym default unit and city are set-once.** Detail shows them read-only; the menu offers only Rename/Archive. Same for a machine's default unit. A wrong unit currently means archive-and-recreate. Make them editable.
- [ ] **D3 — New machine's Add stays disabled until a label is invented**, even after picking a catalog model that could supply a sensible default label.

## E. Legibility

- [ ] **E1 — History rows are headlined by the gym name**, so every workout at one gym is indistinguishable. Derive a real title: template name when `sourceTemplateID` is set, else the exercises performed (e.g. "Chest Press +2"), with the gym as subtitle.
- [ ] **E2 — "1 exercises".** Hardcoded plurals in the History stats string; applies to sets too.
- [ ] **E3 — Short workouts all read "0 min".** A 14-second and a 45-second workout are indistinguishable. Show seconds below a minute.
- [ ] **E4 — Unit badge is orphaned** bottom-left under the map pin, far from the stats it qualifies; rows without a badge have a different left edge.
- [x] **E5 — The set-type control is an unlabelled number button** ("1"); cycling warmup/working/failure is undiscoverable and its accessibility label is literally "1". Give it a proper label and a discoverable affordance.

## Acceptance

- [ ] Every box above ticked, with a regression test for A1, A2, B1 specifically
- [ ] `xcodebuild test` green (unit + UI)
- [ ] The UI-test walkthrough still passes end to end

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
