# 05 — Heart rate on the workout screen

Status: resolved (real-sensor verification still owed)
Blocked by: 03

## What to build

A heart-rate bar above the exercise cards in `ActiveWorkoutView`, live while a session runs:
bpm, zone (1–5 with a compact meter), active calories, and **which sensor** it is reading.

- A stale sample (ticket 01) renders as stale — greyed with its age — never as a current number.
- An estimated max HR marks the zone as estimated (D45), in the same spirit as `≈` on converted
  weights. Tapping it opens the Settings field to fix it.
- No sensor / no permission: one line saying so, with the action that fixes it. No dead space.
- `accessibilityIdentifier`s: `hrBar`, `hrBpm`, `hrZone`, `hrCalories`, `hrSource`.

## Acceptance criteria

- [ ] Under `-uiTestHeartRate`, the bar shows a live bpm that changes, and an XCUITest asserts it.
- [ ] Stale, no-sensor and no-permission states each render distinctly and are each asserted.
- [ ] The bar does not appear at all when no workout is active.
- [ ] Zone colour is not the only signal (the number and label carry it too) — colour alone fails
      for the colour-blind and in a bright gym.
- [ ] Screenshot attached to the resolution.


## Resolution (2026-08-22)

`Features/ActiveWorkout/HeartRateBar.swift` + `MaxHeartRateSheet.swift`, wired into
`ActiveWorkoutView` with the session tied to the workout's own lifecycle (both `finishWorkout` and
`cancelWorkout` tear it down — a session that outlives its workout keeps the sensor powered).
`AppPreferences` gained `measuredMaxHeartRate` and `birthDate`, both optional (D45).
Tests: `WorkoutTrackerUITests/HeartRateUITests.swift` (2), 399 unit tests still green.

**The bug worth remembering: an accessibility identifier on a SwiftUI container propagates to
every descendant and overrides theirs.** `hrBar` on the outer `VStack` meant every element inside
reported `hrBar`, so `hrBpm`, `hrSource` and `hrCalories` were unqueryable — the tests failed
looking for children that existed and were visible on screen. Dumping the tree showed six elements
all called `hrBar`. The container now carries no identifier and the bar's presence is asserted
through its contents.

Two things the debugging turned up that were real product bugs, not test artifacts:

- **Idle rendered an empty card.** The container has padding and a background, so `EmptyView` in
  the idle branch left a blank rounded rectangle floating above the exercises. Idle now renders
  nothing at all.
- **The pulsing heart animated while stale.** A heart beating beside a number that stopped
  updating is the app performing liveness it does not have; the pulse is now tied to freshness.

**Still owed:** every state was proven against the scripted fixture, and `-uiTestHeartRate` is the
only thing that has ever fed this screen. AirPods Pro 3 on a real phone remains unverified, and
belongs on the gym-feedback list beside the scanner's.
