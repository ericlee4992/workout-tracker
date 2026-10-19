# 22 — One Add Exercise button: Exercises | Machines tabs

Type: change
Status: **ready** (2026-10-18)
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
- **Next:** apply this branch's diff onto `ericlee4992/beta-19-bug-fixes` after ticket 21 clears (it touches
  `ActiveWorkoutView.swift` in other hunks than 21), rerun `22-ui-1`'s list (in this ticket's history: the warm-up,
  CoreLoop ×7, MachineDeletion, ExercisePreset, Redesign ×3, Codex screenshots ×2, FloodlightLive list end ×2), look
  at the captures, then Codex review 22.
