# 21 — The Live Activity stays after cancelling a workout

Type: bug
Status: **ready** (2026-10-18)
Blocked by: —
Implementer: Claude; Reviewer: Codex.
Branch: `ericlee4992/beta-19-bug-fixes` off `main` `1f0e040` (tickets 19–22 together).
Ships in: **build 9**.

## Report (the user, 2026-10-18)

"Even after cancelling a workout, the live activity still appears."

## Expected

Cancel → Discard Workout ends the Lock Screen / Dynamic Island card at once, every time; nothing brings it back.

## First look (Claude, 2026-10-18; to confirm by reproducing)

- `cancelWorkout()` (`ActiveWorkoutView.swift:866`) ends the card via `stopHeartRate()` (`:667-676`), then
  `session.cancel` deletes and saves the workout, then `dismiss()`.
- Suspect: while the screen is still up (dismiss animation), the 2 s `livenessTick` (`:66`, `:428`) or
  `onChange(restEnd)` calls `pushActivityState()` (`:735`), whose only guard is `!workout.isDeleted` — SwiftData's
  `isDeleted` is not reliably true after the delete is saved — so `show()` finds no tracked workout and **starts a new
  card** for the cancelled workout.
- Fix direction: the controller remembers workouts it ended and refuses to show them again; ending also clears any
  stray system cards; a launch/foreground sweep ends cards whose workout is not live.

## Acceptance

1. Reproduce (Simulator) and record the cause.
2. Unit test: after `end(workoutID:)`, `show(workoutID:)` for the same ID starts nothing.
3. Cancel, finish and minimize→cancel all leave no card (manual Simulator check; phone check by the user on build 9).

## Code map

- `WorkoutTracker/Domain/WorkoutActivityController.swift` (controller `:35-100`, system presenter `:144-210`).
- `WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift` (`stopHeartRate`, `pushActivityState`, cancel).

## Progress

