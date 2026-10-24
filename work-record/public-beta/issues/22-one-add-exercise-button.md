# 22 — One Add Exercise button: Exercises | Machines tabs

Type: change
Status: **review clear** (Codex round 2, 2026-10-23) — on the branch; merge after the user's go-ahead
Blocked by: —
Implementer: Claude; Reviewer: Codex.
Branch: `ericlee4992/beta-19-bug-fixes` off `main` `1f0e040` (tickets 19–22 together).
Ships in: **build 9**.

## Report (the user, 2026-10-18)

"During a workout, is there a need to for both add exercise and add machine button? Can we maybe combine them into one
button?"

## Decision (the user, 2026-10-18)

- **One picker, two tabs** ("Recommended"): the live workout's add block has **Add Exercise** and **Add Cardio**
  only. Add Exercise opens one sheet with **Exercises | Machines** at the top. Exercises = today's picker; Machines =
  today's Add by Machine list for the workout's gym (machine-first logging, D7, unchanged: auto-fill, station chooser,
  Add Machine…, delete).
- No gym: the Machines tab says "Pick a gym to log by machine" (the text the disabled button shows now).
- The sheet opens on Exercises.
- Reopens the add block's three-button layout (live-workout-fixes D1 / ticket 17 "Add by Machine stays visible,
  disabled") → record as a new decision.

## Acceptance

1. Live workout: two buttons (Add Exercise, Add Cardio) at default and AccessibilityL.
2. Add Exercise → Machines → a single-exercise machine adds its entry with the machine; a station shows the chooser.
3. No gym: Machines tab explains; Exercises works.
4. UI tests that tapped `addByMachine` go through the tab instead (CoreLoop, MachineDeletion, ExercisePreset,
   screenshot suites); onboarding tour checked for references.

## Code map

- `WorkoutTracker/Features/ActiveWorkout/LiveWorkoutPieces.swift:588-650` (`LiveAddBlock`).
- `WorkoutTracker/Features/ActiveWorkout/ExercisePickerSheet.swift`, `AddByMachineSheet.swift`, presenting site in
  `ActiveWorkoutView.swift`.

## Progress

### Build (Claude, 2026-10-18) — WIP on `ericlee4992/beta-22-wip` (off `3e61150`, before ticket 21's round-1 fixes)

- `AddExerciseSheet` (new, `Features/ActiveWorkout/`): `ExercisePickerSheet` (mode 0) or `AddByMachineSheet` (mode 1),
  each given the switch `AddExerciseModePicker` (`SegmentedPills` "Exercises" | "Machines", id `addExerciseMode`) as
  its first list row; opens on Exercises. The machine tab's title is "Add Exercise"; with no gym it says "Pick a gym
  to log by machine" (`addByMachineUnavailable`) instead of the empty list and Add Machine….
- `LiveAddBlock`: Add Exercise (primary unless resting/cardio) and Add Cardio (full-width secondary below); `hasGym`,
  `addByMachine` and the disabled-button note removed. `ActiveWorkoutView`: one sheet (`AddExerciseSheet`),
  `showMachinePicker`/`hasGym` removed.
- D65 recorded in `docs/DECISIONS.md`; README "Fast logging" mentions picking by machine; comment in
  `MachineDeletion.swift` updated.
- UI tests: every `addByMachine` tap now taps `addExercise` then "Machines" (CoreLoop, MachineDeletion,
  ExercisePreset, Codex/Redesign screenshot suites); CoreLoop's no-gym test checks the Machines tab's explanation;
  `FloodlightLiveUITests` list-end captures also shoot the sheet's two tabs (`beta-22-add-{exercises,machines}-…`).

### Verification so far

- `build-for-testing` (`runs/22-build-1.log`, WT-iPhone27): exit 0.
- Targeted UI run `22-ui-1` (17 tests, 3 workers) **stopped by the pause before any result** — not run.
- 2026-10-23, rebased onto `de3db7c` (clean). `22-ui-2` (same 17, 3 workers, the machine also running Codex):
  10 passed, 8 failed. Sorted out by `22-base` (the branch WITHOUT ticket 22, WT-Floodlight, serial: the 6 failing
  tests that exist there + warm-up **7/7 passed**) vs `22-ui-3` (ticket 22, serial): core loop, minimize, Redesign
  test02 and both list-end captures **passed** (their `22-ui-2` failures were load: focus not taken, app not launched);
  3 real failures remained:
  - `ExercisePresetUITests` ×2 — **a test-rewrite bug**: the file's variable `add` names both Add by Machine and the
    Gyms tab's Add Machine button, and the rewrite inserted "tap Machines" after both. Removed from the Gyms helper.
  - `FloodlightLiveUITests` list end ×2 (in `22-ui-2`): `app.buttons["Exercises"]` also matched the tab bar's
    Exercises tab — the switch's pills are now queried by their identifier `addExerciseMode`.
  - `CoreLoopUITests/testAddSetCarriesForwardTheLastCompletedSet` — failed in `22-ui-2` ("kg" ≠ "lb") and `22-ui-3`
    ("Add Set should append a row"), each time with another test run sharing the machine; alone it **passed** in
    `22-ui-4` and **3/3** in `22-ui-5` (`-test-iterations 3`). Load, not this change.
- `22-ui-4` (serial, after the preset-helper fix): warm-up, `testAddSetCarries…`, `ExercisePresetUITests` ×2 —
  **4/4 passed**, exit 0.
- Polish after the captures: the Machines tab's section header is now the Exercises tab's `LookSectionLabel`
  ("Machines at Iron Temple", machine symbol) instead of the old grey list header.
- `22-final` (serial, with that change): warm-up, `FloodlightLiveUITests` list end light default + AccessibilityL
  (incl. the sheet's two tabs), `MachineDeletionUITests/testDeleteMidWorkout…`, `CoreLoopUITests/
  testFinishingAnEmptyWorkout…` (no gym → the Machines tab explains), `ExercisePresetUITests` ×2 — **7/7 UI passed**
  (with 14 unit tests in the same run), `TEST SUCCEEDED`, exit 0.
- Captures: `runs/shots22c/live-fixes-02-list-end-light-{default,axl}.png` (two buttons) and
  `beta-22-add-{exercises,machines}-light-{default,axl}.png` (from `22-ui-3`, before the header polish).
- Full targeted list over the runs: CoreLoop ×7, MachineDeletion, ExercisePreset ×2, Redesign ×3, Codex screenshots
  ×2, FloodlightLive ×2 — every one has a passing run on the final or near-final code (`22-ui-3/4/5`, `22-final`).
- **Next:** apply this branch's diff onto `ericlee4992/beta-19-bug-fixes` after ticket 21 clears (it touches
  `ActiveWorkoutView.swift` in other hunks than 21), rerun `22-ui-1`'s list (in this ticket's history: the warm-up,
  CoreLoop ×7, MachineDeletion, ExercisePreset, Redesign ×3, Codex screenshots ×2, FloodlightLive list end ×2), look
  at the captures, then Codex review 22.
- Commits for review: `e33cb00` (the build) + `8657703` (test fixes, header, verification) — `git diff 2ab1711..8657703` (pushed).

### Codex round 1 (2026-10-23): not clear — [codex-review-22.md](../codex-review-22.md)

One **P3**: the Machines header passed `LookIcon.machine` (the app's own glyph, `"lookicon.machine"`) to
`LookSectionLabel`, which drew it with `Image(systemName:)` — no glyph. No functional findings; Codex's build exit 0.

**Response (Claude):** `LookSectionLabel` draws its symbol with `LookIcon(symbol, style: .footnote)`, which renders the
app's glyphs and falls back to `Image(systemName:)` at the same font for an SF Symbol (so the other callers — Add
Chart's and the picker's "Recent at …" — render as before). `22-r1` (WT-Floodlight): both list-end capture tests
**passed**; the machine glyph now shows beside "Machines at Iron Temple" at default and AccessibilityL
(`runs/shots22r/beta-22-add-machines-light-{default,axl}.png`). The run's warm-up (`CardioUITests/
testSavedDistanceEditor…`, untouched code) failed on the fresh runner — the known first-test issue it exists to absorb.

### Codex round 2 (2026-10-23): **clear** — [codex-review-22b.md](../codex-review-22b.md)

The header glyph is closed and `LookSectionLabel`'s other callers are unaffected; Codex's rebuild exit 0. Ticket 22
done on the branch; not merged.
