# 05 — Workout on the lock screen (Live Activity)

Status: open
Blocked by: — (independent; sequenced last because it adds a target)
Covers user ask **5**.

## Mechanism

ActivityKit Live Activity + a **widget extension target**. Shows live heart rate, the rest
countdown, and elapsed time on the lock screen and Dynamic Island.

**D46 applies directly and makes this a good fit:** the app pushes state to the system and the
*system* renders and counts down. Nothing has to execute at a deadline — which is exactly the trap
that cost four attempts on the rest alarm. A rest countdown should use a `Text(timerInterval:)`
style so the system ticks it, not the app.

## What to watch for — this is the shape that hid two bugs already

A new target with its own lifecycle is precisely the arrangement that produced the watch
rest-countdown bug: the receiver rendered a field nothing ever sent. So:

- **Assert the activity is STARTED and UPDATED**, not merely that the view compiles. No test in
  this repo asserts a message is ever sent to the watch, and that is why that bug shipped.
- Adding a target must not break the simulator test run (ticket 02 of milestone 7 — embedding the
  watch app broke every XCUITest). Verify the full suite still runs.
- The activity must END on every path that ends a workout — finish, cancel, discard, and the
  "finish it and start new" recovery in `StartWorkoutView`. An orphaned Live Activity is the same
  class of bug as an orphaned heart-rate session (codex-review-2 #2).

## Acceptance criteria

- Starting a workout starts a Live Activity; ending it by ANY path ends the activity.
- Heart rate and rest countdown update on the lock screen.
- The rest countdown is system-ticked, not app-ticked.
- Full unit + UI suites still run and pass with the new target present.
- A test asserts the activity is started and updated, not just that it renders.

## Notes

Check whether a free Apple account provisions what ActivityKit needs before building — the same
"verify before committing to it" step D41 took for HealthKit, which saved a wasted milestone.
