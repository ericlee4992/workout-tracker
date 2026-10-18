# Ticket 17 — cardio-only pause clock review

Reviewed `git diff main...HEAD`, with main pinned to `ef11a8e1762e67ba6aeb0e30f977dbc7318f84c9` and implementation
`fde78f0246307a53229c6425830abb80e4fa1f7b`, against ticket 17, D64, the cardio timer spec and the cited decisions.
HEAD advanced to `fe3c0712b815e294bdf4b6250b52a902d4659ba9` during review; that checkpoint changes only STATE and the
ticket, not the tested implementation.

1. **P2 — The Live Activity's workout clock stays cached through pause/resume.**
   **Location:** `WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift:747–777`;
   `WorkoutTracker/Features/ActiveWorkout/WorkoutActivityContent.swift:55`.
   `make` initializes the new `workoutClock`, but `activityState` caches that result under a key that includes the
   unfinished segment's ID, not its recording/paused state. Subsequent pushes refresh `state.cardio` only. During
   a second cardio segment, pausing therefore leaves the cached `.running(since:)` header ticking. A base created
   while paused similarly leaves `.stopped` frozen after resuming. The correct state produced by a Lock Screen
   command can also be overwritten by the next cached in-app push. **Fix:** refresh `state.workoutClock` beside
   `state.cardio` before returning the state. Keep the stable running origin so unchanged ticks still compare equal.
   Test the cached push path across pause/resume, not only the pure `workoutClock` helper used by the new test.

2. **P2 — Multi-segment History detail still hides the workout's total active time.**
   **Location:** `WorkoutTracker/Features/History/WorkoutDetailView.swift:227–228,270`;
   `WorkoutTracker/Features/Cardio/CardioCards.swift:179,199`.
   An 18-minute run followed by a 2-minute cycle now correctly yields 20 minutes in the History row and finish tile.
   Opening History detail selects one segment as its hero and unconditionally removes the workout-time tile.
   That hero shows only its segment's 18 minutes; the cycle has its separate card. The detail header shows a
   wall-clock range, not the aggregate active time, so the workout's 20-minute total is absent. The filter predates
   this branch but is a missed consumer of D64's new History time requirement. **Fix:** retain the aggregate
   `summary.workoutTime` tile when multiple recorded segments exist; suppress it only when the single segment hero
   represents the entire workout. Extend the multi-segment regression to open History detail and verify the total.

3. **P3 — The header remains hidden after the only cardio segment ends.**
   **Location:** `WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift:458–466`.
   `ringIsWorkoutTime` checks only cardio-only classification and segment count. After End Cardio, the open segment
   and its live ring disappear, but the header clock remains hidden while cardio focus is selected. D64 limits
   hiding to one **open** segment; the Live Activity already handles this state with `.stopped`. The ended card still
   carries its own duration, limiting the impact. **Fix:** also require `unfinishedCardio != nil` before hiding the
   header, and test End Cardio on a one-segment cardio-only workout.

Other checks: the derived live/finished cardio-only rules agree with the completed-set/recorded-cardio History
facts. Finish closes recording segments and removes drafts; History deletion prunes empty entries. Pauses and
inter-segment gaps are excluded, and the normal finish lifecycle fixes active time at the finish. Adding an exercise
restores wall time while live. History rows, week/month totals, template statistics and finish tiles use the new
derived time. Heart-rate chart axes still use `summary.duration`; exports retain timestamps/raw cardio fields, and
HealthKit timing boundaries were not changed.

The new live timer closures guard deleted workouts and traverse current-workout relationships rather than fetching
history each tick. The paused-for helper has no remaining source/test/widget caller; the pill now says only Paused.
`ContentState.workoutClock` is optional and synthesized decoding remains compatible with the existing old-payload
test. SwiftData models and export shapes are unchanged; the summary fields are derived values, and the optional
Live Activity field is not a workout-store migration. No Gate S requirement introduced by this diff.

Verification personally performed with **Xcode 27.1 (27A9275)** on **WT-Floodlight, iOS 27.0**:

```sh
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator \
  -configuration Debug -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath /tmp/wt-review16-dd -resultBundlePath /tmp/wt-review17-20261018/build.xcresult build

xcodebuild test -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator \
  -configuration Debug -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath /tmp/wt-review16-dd -resultBundlePath /tmp/wt-review17-20261018/unit.xcresult \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:WorkoutTrackerTests/CardioOnlyTimeTests \
  -only-testing:WorkoutTrackerTests/CardioReadoutTests \
  -only-testing:WorkoutTrackerTests/CardioTests \
  -only-testing:WorkoutTrackerTests/WorkoutActivityContentTests \
  -only-testing:WorkoutTrackerTests/WorkoutSummaryTests
```

Build: **exit 0, BUILD SUCCEEDED**. Unit selection: **exit 0, TEST SUCCEEDED; 54 passed / 0 failed / 0 skipped**,
confirmed in the log, actual exit-status files and `xcresulttool get test-results summary`. Artifacts:
`/tmp/wt-review17-20261018/{build,unit}.{log,status,xcresult}`. These tests do not exercise the cached Live Activity
refresh or the missing History-detail aggregate. Optional UI tests were **skipped**; no device Live Activity check
was performed. `git diff --check` passed. Only this report was added; no commit or push.

Verdict: not clear
