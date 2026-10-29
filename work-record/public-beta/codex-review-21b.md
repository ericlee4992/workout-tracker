# Codex review — ticket 21, round 2

Reviewed 2026-10-23 on `ericlee4992/beta-19-bug-fixes`, HEAD
`de3db7c80ca31ea4ed0137e0af8261a1b8a4536b`. Scope:
`git diff 3e61150..HEAD -- WorkoutTracker WorkoutTrackerTests`, against the two round-1 P2
findings and the round-2 prompt. The intervening STATE/ticket-23 records do not change product
code. Working tree was clean.

## Standards

No open findings. Checked the new controller methods against their actual callers, including
all three termination catch paths and RootView recovery. No stored-format, dependency or UI
layout changes. The system presenter's implementation is unchanged in this round.

## Spec and lifecycle

**P2 #1 closed.** `ActiveWorkoutView.swift:833`, `:850` and `:875` call `reopenActivity()` after
failed ordinary finish, templated finish and cancellation. Its guard at `:884` requires an
attached, undeleted, unfinished workout before removing that ID from the controller's `ended`
set. Thus the early-save failure identified in round 1 no longer permanently suppresses a
resumed workout's card. Successfully finished/deleted workouts remain protected against late
pushes. `WorkoutActivityTests.aReopenedWorkoutShowsItsCardAgain` verifies that ending,
reopening and showing the same ID requests another card.

**P2 #2 closed.** `RootView.swift:131` now distinguishes successful recovery from errors with
`do/catch`. Successful recovery passes whether a live workout exists; failure passes nil.
`WorkoutActivityController.reconcileAtLaunch` sweeps only for a known false, preserving cards
for both true and unknown. The guided-tour and already-presented-workout guards remain.
`theLaunchSweepNeedsAKnownAbsence` verifies all three states.

No new regression identified. The new tests exercise controller policy; the three catch
handlers and their live-workout guards were source-reviewed, not tested by injecting actual
SwiftData save failures. The possible same-ID adoption window during asynchronous termination
was compared with `c3952da`: asynchronous ending and adoption already existed there, and no
new ActivityKit race was demonstrated by this round's changes.

## Independent verification

Both commands used `WorkoutTracker.xcodeproj`, scheme `WorkoutTracker`, SDK `iphonesimulator`,
destination `platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674`, and
`-derivedDataPath /tmp/codex-21/DerivedData`.

| Check | Result | Evidence |
|---|---|---|
| `xcodebuild … build` | **Exit 0; BUILD SUCCEEDED** | `/tmp/codex-21/build-round2.log`, `build-round2.status`, `build-round2.xcresult` |
| `xcodebuild test … -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:WorkoutTrackerTests/WorkoutActivityTests -only-testing:WorkoutTrackerTests/WorkoutActivityProviderTests -only-testing:WorkoutTrackerTests/WorkoutActivityContentTests` | **Exit 0; 36 passed, 0 failed, 0 skipped; TEST SUCCEEDED** | `/tmp/codex-21/unit-round2.log`, `unit-round2.status`, `unit-round2.xcresult` |
| `git diff --check 3e61150..HEAD -- WorkoutTracker WorkoutTrackerTests` | **Exit 0** | No whitespace errors in the reviewed code/test changes |

Inspected actual process exits, status files, success markers and the xcresult summary. The
tests ran on WT-Floodlight, iOS **27.0**, with no runtime warnings. All three requested suites
ran; the separate `WorkoutActivityCommandsTests` suite does not exist, as noted in round 1.
Command coverage is included in `WorkoutActivityContentTests`.

**Independent UI tests skipped.** Round-1 UI evidence remains recorded in that report; no new
UI run or phone verification is claimed here. The phone check remains with the user on build 9.

Only this new report was written. No commit or push.
Standards: **0 open findings**. Spec/lifecycle: **0 open findings**.

Verdict: clear
