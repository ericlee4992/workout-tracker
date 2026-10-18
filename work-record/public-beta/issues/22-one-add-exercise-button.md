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

