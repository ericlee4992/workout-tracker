# 21 — The Live Activity stays after cancelling a workout

Type: bug
Status: **in review** (Codex round 1, 2026-10-18)
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

### Cause (Claude, 2026-10-18) — confirmed

- **Probe** (a throwaway unit test, `runs/21-probe.log`): after `WorkoutSession.cancel` (delete + save) the workout
  reports `isDeleted=false`, `finishedAt=nil`, `modelContext=nil`. So `pushActivityState()`'s guard
  (`!workout.isDeleted, workout.finishedAt == nil`) passes for a cancelled workout.
- `cancelWorkout()` ends the card (`stopHeartRate` → `end(workoutID:)`, which clears the controller's tracked id),
  then cancels (which also clears the rest, moving `restEnd`), then dismisses. Until the screen is gone, its 2-second
  `livenessTick` and `onChange(restEnd)` still call `pushActivityState()` → `show()` sees no tracked workout and
  **requests a new card** for the deleted workout.
- **UI reproduction on the unfixed code** (`wt-repro`, real Live Activity on WT-iPhone27): run `21-repro` — after the
  cancel the Lock Screen showed a new card ("Lateral Raise · 0/1 sets · Iron Temple", a fresh clock;
  `runs/shots21r/21-after-cancel.png`); the test still passed because it only looked for the rest buttons, which a
  card with no rest does not have. `21-repro-3` (same code) showed no card: the stray card depends on a push landing
  during the dismissal — a race. The controller unit test below reproduces it deterministically.

### Build (Claude, 2026-10-18)

- `WorkoutActivityController`: remembers the workouts whose card it ended (`ended`) and refuses `show()` for them;
  `end(workoutID:)` with nothing tracked sweeps; `endAny()` ends **every** card the app posted
  (`presenter.endAll()`), not only the tracked one.
- `WorkoutActivityPresenting.endAll()`: the system presenter ends every `Activity<WorkoutActivityAttributes>` plus a
  just-requested one not yet listed; the silent presenter counts `sweeps`.
- `ActiveWorkoutView.pushActivityState()`: also requires `workout.modelContext != nil`.
- `RootView.recoverActiveWorkout()`: with no live workout at launch, ends any card left over (an app that quit right
  after a cancel, before the end reached the system).
- Tests: `WorkoutActivityTests` + 4 (late push after end, after endAny, next workout still shows, sweep with nothing
  tracked); `FloodlightSystemUITests/testRealLiveActivityEndsWhenTheWorkoutIsCancelled` (real card, mid-rest
  fixture, cancel, wait past the 2-second tick, no `activity-content-view` on the Lock Screen).

### Verification (Claude, 2026-10-18)

- Unit `21-unit-1` (WT-iPhone `432F2F5D-…`, iOS 26.5): `WorkoutActivityTests`, `WorkoutActivityProviderTests`,
  `WorkoutActivityContentTests` — **34 tests, 3 suites passed**, exit 0.
- Unit `21-unit-2` (WT-iPhone27, iOS 27, right after the 3-iteration UI run): 3 failures in
  `WorkoutActivityProviderTests`/`WorkoutActivityContentTests` (Watch rest-feed ordering) after **151 s** — the
  machine was saturated. Re-run `21-unit-3` with the fix: those two suites **21/21 passed** in 0.7 s, exit 0; the
  same suites on the unfixed code (`21-unit-base`): 21/21. Not caused by this change (neither test touches the
  controller's end path). `21-unit-4`: `WorkoutActivityTests` **13/13 passed** on iOS 27, exit 0.
- UI `21-ui-1` (fixed code, real Live Activity, WT-iPhone27, `-test-iterations 3`): warm-up 3/3,
  `testRealLiveActivityCommandsReachTheWorkout` 3/3, `testRealLiveActivityEndsWhenTheWorkoutIsCancelled` **3/3
  passed**, `TEST SUCCEEDED`, exit 0.
- Not checked: the phone (the user, with build 9).
- Commit for review: `67de6eb` (pushed).

### Codex round 1 (2026-10-18): not clear — [codex-review-21.md](../codex-review-21.md)

Two **P2** lifecycle findings (Codex's build exit 0, unit 34/0/0): **#1** the card is suppressed (`ended`) before a
finish/cancel that can still throw, so a workout left live could never show its card again; **#2** the launch sweep
treated a failed `resumableWorkout()` (`try?` → nil) as "no live workout" and could end a live workout's card.

**Response (Claude) — written, NOT yet verified (paused by the user mid-run, 2026-10-18):**
- #1: `WorkoutActivityController.reopen(workoutID:)`; `ActiveWorkoutView.reopenActivity()` calls it in the catch of
  `finishWorkout`, `finishTemplatedWorkout` and `cancelWorkout` when the workout is still live. Test
  `aReopenedWorkoutShowsItsCardAgain`.
- #2: `WorkoutActivityController.reconcileAtLaunch(hasLiveWorkout: Bool?)` sweeps only on a known `false`;
  `RootView.recoverActiveWorkout` uses do/catch and passes `nil` on an error. Test `theLaunchSweepNeedsAKnownAbsence`.
- **Next:** run `-only-testing:WorkoutTrackerTests/WorkoutActivityTests -only-testing:WorkoutTrackerTests/
  WorkoutActivityProviderTests -only-testing:WorkoutTrackerTests/WorkoutActivityContentTests` (the run `21-unit-r1`
  was stopped before it finished), then write the round-2 section of `codex-review-21-prompt.md` and send it to the
  Codex terminal "Codex review 19-22".
