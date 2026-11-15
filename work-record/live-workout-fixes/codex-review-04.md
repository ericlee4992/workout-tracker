# Live-workout 04 — independent Codex review, round 1

Reviewed 2026-11-15: `git diff 3f4b959b..46e47450`, on branch
`ericlee4992/lock-screen-log-set`. Actual HEAD is `a234a823e2befaa4b09ad0066ebb7dda981a5aa3`;
the additional commit changes STATE only. The working tree was clean before review. No app/test
source was edited and no commit was made.

Sources: ticket 04, AGENTS.md (including its self-check list), SPEC, DECISIONS D90/D48/D43/D23,
DEVELOPMENT's verification scope, and the vendored SwiftUI/SwiftData skills. Standards and spec
were reviewed independently in parallel, then their source traces checked against the implementation.

## Standards

1. **High — a failed completion save leaves the set completed in memory.**
   `WorkoutTracker/Features/ActiveWorkout/WorkoutActivityCommands.swift:143` and `:190`.
   `WorkoutSession.toggleCompletion` changes `completedAt`, captures the entry's snapshot, and
   inserts/updates gym memory before `context.save()` (`WorkoutSession.swift:833–849`). If that
   save throws, the new command returns false without undoing those mutations or refreshing the
   card. The live context now treats the set as completed; a second Done is refused because the
   next set has advanced, and a later unrelated save/autosave can persist the supposedly failed
   completion. This contradicts the catch's claim that a failed command leaves the workout as it
   was, and AGENTS' rule against edits surviving a failed save.

   **Fix:** make completion failure restore all completion-owned changes (stamp, snapshot, memory)
   while preserving unrelated user edits, then refresh from the recovered state. Add a deterministic
   injected-save-failure regression that checks both the current context and reopened persisted
   data, and verifies retry can complete the same set.

2. **Medium — a failed rest save is still published as a running rest.**
   `WorkoutTracker/Features/ActiveWorkout/WorkoutActivityCommands.swift:147–156`.
   `RestTimerService.handleCompletionChange` assigns `restEndsAt`, `restStartedAt`, and
   `restStartedBySetID` before saving (`RestTimer.swift:204–207`); notification scheduling happens
   only after that save. If it throws, this catch merely logs, then broadcasts the unsaved deadline
   and pushes it to the card/screen. The set was successfully logged, but its displayed timer and
   Watch/audio deadline have no successful rest save and no newly scheduled notification. The
   superset-skip variant can likewise clear fields in memory while leaving the old notification
   armed when its save fails.

   **Fix:** retain the successful completion, restore the prior rest fields on a rest persistence
   failure, and publish only that recovered state; preserve notification/alarm consistency. Add
   failing-start and failing-superset-skip tests. This is a separate persistence boundary from #1.

3. **Medium — the stale-card comparison omits set classification and compares only rounded weight.**
   `WorkoutTracker/Features/ActiveWorkout/WorkoutActivityCommands.swift:134–137`;
   `WorkoutTrackerWidget/Shared/WorkoutActivityIntents.swift:83–88`.
   A shown working set changed in the app to warmup or drop keeps its ID, weight, unit and reps;
   the old card therefore still passes this guard and logs a different classification, changing
   record eligibility and rest behavior. Also, `current.weight` is a display string rounded to two
   decimals (`WeightMath.swift:46–54`), while weight entry accepts more precision. Editing
   `50.001` to `50.004` leaves both strings `"50"`, so the stale command accepts the edited stored
   value. Existing tests change reps, which does not expose either hole. This violates AGENTS'
   partial-field matching rule.

   **Fix:** carry and compare a stable completion fingerprint/version containing the raw entered
   value/unit/reps and set classification/context needed to identify what was shown; keep display
   formatting separate. Refuse and refresh on mismatch. Add stale working→warmup/drop and
   same-rounded-string weight-edit regression cases.

## Spec

4. **High — cold-background Done starts a heart-rate rest without its recovery/fallback evaluator.**
   `WorkoutTracker/Features/ActiveWorkout/WorkoutActivityCommands.swift:147`.
   Ticket acceptance requires “heart-rate rests as configured (D43)” and “a cold background
   launch.” This call starts the heart-rate cap, but `HeartRateRestRule.evaluate` is called only
   by `ActiveWorkoutView.evaluateHeartRateRest` (`ActiveWorkoutView.swift:702–747`), wired through
   that view's sample callback and liveness timer (`:426`, `:442`). The runtime created by the
   command before any view exists only checks the cap alarm, refreshes cardio and invokes an
   optional view callback (`WorkoutHeartRateCoordinator.swift:128–136`). Consequently, even
   received recovering samples cannot end this rest early; absent readings also cannot switch it
   to the configured standard duration. The user gets the cap behavior until the screen opens.
   The existing cold test exercises +15s/runtime attachment, not a newly started heart-rate rest.

   **Fix:** own threshold evaluation and no-reading fallback in the workout runtime, together with
   notification/alarm/Watch/card updates, and share that path with the screen. Test cold Done
   without constructing a view, using recovering samples and a controlled no-reading interval.

The spec axis also independently found #3's stale-classification defect: D90 promises logging the
set “as shown” and refusing a card that lags the workout. Standards: 3 findings, worst High (#1).
Spec: 2 findings (#3 and #4), worst High (#4). No separate modernization or code-smell findings.

## Verification

Environment: Xcode 27.2 (`27B52`); booted WT-Floodlight, iPhone 15 Pro Max, iOS Simulator 27.0,
UDID `9E822EF6-DC67-4958-AEA2-D53D2D36D674`. Selected scope: Unit plan plus the seven
`FloodlightSystemUITests`, serial; inspect the author's adjacent live/core-loop result as requested.

Commands executed by the reviewer:

```sh
scripts/prepare-test-simulator.sh
# exit 0

xcodebuild build-for-testing -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath build/dd-codex
# exit 0; TEST BUILD SUCCEEDED

xcodebuild test-without-building -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -testPlan Unit -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath build/dd-codex -parallel-testing-enabled NO -collect-test-diagnostics never \
  -resultBundlePath build/results/ls04-codex-unit.xcresult
# exit 0; 1302/1302 tests, 0 failed, 0 skipped

xcodebuild test-without-building -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -testPlan Full -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath build/dd-codex -parallel-testing-enabled NO \
  -only-testing:WorkoutTrackerUITests/FloodlightSystemUITests -collect-test-diagnostics never \
  -resultBundlePath build/results/ls04-codex-system.xcresult
# exit 0; 7/7 tests, 0 failed, 0 skipped; TEST EXECUTE SUCCEEDED

git diff --check 3f4b959b..46e47450
# exit 0
```

Logs/status: `build/results/ls04-codex-{build,unit,system}.{log,status}`. Both reviewer runs
completed; actual shell status files and xcresult summaries were checked. Unit reports 1,302
tests (1,322 executions including parameterized cases). The system selection passed all four
Light/Dark × Default/AccessibilityL gallery tests (15 states each, including the 160 pt checks),
the real-card +15s/Skip test, the real-card Done test, and cancellation. The Done test verified
the completed-set count increased by one and the app's rest was running.

Inspected `xcrun xcresulttool get test-results summary` and the test tree for the author's
`build/results/ls04-ui.xcresult`: **32/32 passed, 0 failed, 0 skipped**. Actual shell status in
`build/logs/ls04-ui.status` is **exit 0**. It contains FloodlightLiveUITests (20), CoreLoopUITests
(9), the real Done test (1), and two gallery tests (2). Those adjacent suites were not rerun.
The result contains invalid-frame runtime warnings, without test failures; the reviewed capture
does not establish their cause. Visually inspected the committed real-card Done sequence, the
author's light/default and dark AccessibilityL ready card/expanded island attachments, and the
reviewer's matching captures plus the real card after Done. The values and Done controls fit;
the after-Done card shows the running rest and updated set count. Reviewer's attachments are in
`build/results/ls04-codex-captures/` (manifest maps filenames to tests/capture names).

The four findings above are source-traced defects, not failures reproduced by the existing tests.
The successful-completion/stale-reps tests are useful, but there is no injected persistence-error,
stale-kind/raw-weight, or cold-Done heart-rate evaluation test guarding these cases.

Verified: build — exit 0; Unit — 1302/1302, exit 0, `build/results/ls04-codex-unit.xcresult`;
FloodlightSystemUITests — 7/7, exit 0, `build/results/ls04-codex-system.xcresult`; author's adjacent
UI evidence inspected — 32/32, exit 0, `build/results/ls04-ui.xcresult`.
Not verified: physical-device behavior; OS cold-background intent delivery and real sensor/Watch
behavior; fixes for the four findings. Failure paths above were established by source tracing,
not injected runtime failures.
Known flaky: none seen.

Verdict: changes requested
