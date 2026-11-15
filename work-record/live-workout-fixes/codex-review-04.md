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

## Round 2 — `bad36c74`, 2026-11-15

Reviewed `git diff 46e47450..bad36c74`; actual HEAD
`bad36c7496df404213f5aa6beb71e552f78b826f`, branch `ericlee4992/lock-screen-log-set`, clean at
the start of review. STATE still names the earlier implementation tip; Git and the ticket's
round-1-fix section establish this round's scope. No app/test changes or commit by the reviewer.

### Standards

1. **Medium — the new fingerprint still omits the effective load type.**
   `WorkoutTracker/Features/ActiveWorkout/WorkoutActivityContent.swift:141–155`.
   Before an entry's first completion, show a weighted `50 kg × 8` set, then change that exercise
   to bodyweight in the app. `EditExerciseLoadTypeSheet.save` changes the exercise's load type
   without clearing its draft weights/reps (`EditExerciseLoadTypeSheet.swift:120–128`). The set
   stays loggable and its fingerprint is identical, although the current card now displays reps
   only. Old Done is accepted and freezes bodyweight history instead of the weighted context
   shown by the old card. This is still the partial-field matching defect from round-1 #3 and
   violates D23/D90.

   **Fix:** include `entry.effectiveLoadType` in the fingerprint, using the frozen snapshot once
   captured. Add a stale-card test for a load-type edit before first completion and a complementary
   frozen-entry case so a later catalog edit cannot reinterpret or invalidate its snapshot.

2. **Medium — the newly added screenless rest evaluator does not recover from persistence failure.**
   `WorkoutTracker/Features/ActiveWorkout/WorkoutActivityCommands.swift:188–194`;
   `WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:258,266–267`.
   A recovering sample calls `finishRecovered`, which clears the rest fields before saving. A
   failed save reaches this log-and-return catch with the deadline still nil in memory, so future
   samples cannot retry; the previously armed cap notification/alarm remains. On degradation,
   the deadline is changed/cleared before saving and `degradedRestSetID` is set before persistence
   succeeds, also blocking retries after a failure. Later unrelated saves can persist those
   failed mutations. The old screen had this weakness, but the new background path now exposes
   it for cold Done; the start/skip rollback added this round does not cover these transitions.

   **Fix:** restore rest-owned persisted fields after failed recovery/degradation while preserving
   unrelated edits; commit runtime flags only after persistence succeeds. Keep the prior
   notification/alarm/card state consistent, and allow retry. Use the new persistence seam to
   test both failing transitions, not only starting/skipping rest.

### Spec

3. **High — the no-reading half of round-1 #4 remains unresolved.**
   `WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:138`;
   `WorkoutTracker/Features/ActiveWorkout/WorkoutActivityCommands.swift:230`.
   `restEvaluator` runs only from a received sample. With a cold Done and a denied, disabled or
   disconnected sensor, no sample arrives to invoke the fallback. The rest retains its heart-rate
   cap (typically 240 seconds) and “heart rate didn't reach the target” notification instead of
   the configured standard timer (typically 120 seconds) and no-reading explanation. D43 says
   “With no live source it degrades to the standard timer and says it degraded.” The ticket's
   new assertion that the cap-only case is already accepted by D43 does not match that decision.
   This is not a demand that code execute while iOS has suspended it: the runtime currently has
   no independent fallback trigger even while it is executing.

   **Fix:** handle a known unavailable/failed provider and expiration of the initial-reading grace
   period independently of sample arrival, establishing the appropriate persisted fallback and
   notification. Add a cold-Done test that emits no samples and advances a controlled clock.

Standards: 2 findings, worst Medium. Spec: 1 remaining finding, High; #1 also violates D90's
“as shown” contract. The successful live-screen recovery/degradation branches preserve their
prior redraw behavior, result and fallback-set ownership through the shared coordinator.

### Prior fixes and test strength

- Round-1 #1 is addressed: pending edits are saved before the completion rollback boundary;
  a completion failure restores the stamp, snapshot and memory and refreshes the card. The
  pre-save itself fails before completion is attempted, preserving pending edits in memory.
- Round-1 #2 is addressed for rest start and superset skip: completion is already saved, so the
  later rollback restores the old rest while keeping the set logged. Notification side effects
  remain after successful persistence. Finding #2 above concerns the newly added evaluator.
- Round-1 #3's set-type and exact-weight examples are fixed; effective load type is still missing.
- Round-1 #4's recovering-sample case is fixed. The test delivers through the actual fake-provider
  stream with no screen and checks the persisted-model transition and card update. No-reading
  fallback is neither triggered nor covered by that test.

The new failure tests reach the intended completion/rest save boundaries and assert restoration,
memory/snapshot state, notification/alarm/card output, and retry where applicable. They would
detect removal of the rollback behavior. The stale-type/raw-weight and cold recovery cases also
exercise the prior semantic failures. This was checked by source tracing, not by editing or
mutation-testing the source. There is no dedicated pending-edit preservation test, nor tests
for this round's three findings.

### Round 2 verification

Same Xcode 27.2 (`27B52`) and booted WT-Floodlight simulator as round 1. Executed:

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
  -resultBundlePath build/results/ls04-codex-r2-unit.xcresult
# exit 0; 1307/1307, 0 failed, 0 skipped

xcodebuild test-without-building -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -testPlan Full -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath build/dd-codex -parallel-testing-enabled NO \
  -only-testing:WorkoutTrackerUITests/FloodlightSystemUITests/testRealLiveActivityDoneLogsTheSet \
  -only-testing:WorkoutTrackerUITests/FloodlightSystemUITests/testRealLiveActivityCommandsReachTheWorkout \
  -collect-test-diagnostics never -resultBundlePath build/results/ls04-codex-r2-ui.xcresult
# exit 0; 2/2, 0 failed, 0 skipped; TEST EXECUTE SUCCEEDED

git diff --check 46e47450..bad36c74
# exit 0
```

Logs and actual status files: `build/results/ls04-codex-r2-{build,unit,ui}.{log,status}`.
Both test runs completed; actual status files and xcresult summaries were checked. The two real
Lock Screen tests passed serially, including Done with the new fingerprint intent. No competing
build/test run occurred.

Author evidence inspected with `xcresulttool get test-results summary`: Unit
`build/results/ls04-r2-unit.xcresult` **1307/1307 Passed**; UI
`build/results/ls04-ui2.xcresult` **27/28**, one keyboard-unit-focus failure (`lb` versus `kg`),
actual `build/logs/ls04-ui2.status` **exit 65**. Serial rerun
`build/results/ls04-ui2-rerun.xcresult` **1/1 Passed**, with `TEST EXECUTE SUCCEEDED` in its log;
no separate shell-status file for that rerun was found. The adjacent HeartRate/FloodlightLive
selection was inspected rather than repeated, as requested.

Verified: reviewer build exit 0; Unit 1307/1307, exit 0,
`build/results/ls04-codex-r2-unit.xcresult`; real Lock Screen Done and +15s/Skip 2/2, exit 0,
`build/results/ls04-codex-r2-ui.xcresult`; author UI result and focused rerun inspected as above.
Not verified: fixes for the remaining findings; physical-device,
OS cold-launch delivery and real sensor/Watch behavior. Remaining defects are source-traced.
Known flaky: author's `FloodlightLiveUITests/testTheKeyboardUnitSwitchFollowsTheFocusedWeight`
failed under the two-worker run and passed alone; none seen in the reviewer runs.

Verdict: changes requested

## Round 3 — `60826bc3`, 2026-11-15

Reviewed `git diff bad36c74..60826bc3`; actual HEAD
`60826bc331268f8ded1c127fc1d441e2fba4ff26`, branch `ericlee4992/lock-screen-log-set`, initially
clean. Read STATE and the ticket's round-2-fix section; STATE's older implementation SHA does
not describe this review tip. Only this report was changed; no commit.

### Standards

No additional standards findings in this round's diff. Round-2 #1 and #2 are addressed:

- The fingerprint now includes `effectiveLoadType`, so an unfrozen load-type edit invalidates
  the card while an already frozen entry retains its snapshot meaning.
- Recovery/fallback saves run after pending edits have been saved. A pre-save failure exits
  before the transition and outside the rollback catch, preserving those edits. After a successful
  pre-save, the synchronous MainActor transition introduces only its own pending changes, which
  are rolled back on failure. Runtime result/fallback flags and notification/alarm changes occur
  after successful persistence; a failed transition remains retryable.
- The tick's task weakly captures the coordinator. Its strong binding is confined to an iteration,
  after the sleep. Reassignment cancels the previous task, checks cancellation after sleep, and
  installs one replacement. `end` reaches `releaseAlarm`, clears `restEvaluator`, and cancels its
  task. There is no new retain cycle or concurrent evaluation: sample/tick handling is synchronous
  on MainActor, and completed/degraded state gates subsequent evaluations.

### Spec

1. **High — the independent fallback tick is suppressed after minimizing a workout.**
   `WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:76`;
   `WorkoutTracker/Features/ActiveWorkout/WorkoutActivityCommands.swift:184`.
   The new tick assumes a non-nil `onSample` means the live screen's liveness timer is active.
   However, `ActiveWorkoutView.swift:426` installs that callback and never clears it when the
   screen disappears. Its minimize action (`:665–672`) dismisses the full-screen cover through
   `RootView.swift:126` without ending the workout runtime. The view's `onReceive(livenessTick)`
   subscription is gone, but `onSample` remains set until runtime teardown. Therefore, in the
   normal open workout → minimize → Lock Screen Done → no sensor samples flow, the new task
   wakes but skips evaluation while that callback remains installed; `evaluateRestWithoutScreen`
   also rejects the same state.
   The heart-rate cap and its cap notification remain instead of D43's standard-timer fallback.
   This still violates the ticket's explicit support for a minimized workout, even while the
   app process is executing.

   **Fix:** give the runtime reliable ownership of D43 evaluation independently of a retained
   view callback, or detach that callback when its owning screen disappears with appropriate
   workout/owner identity checks. Ensure recovery/fallback still publishes the Watch, alarm and
   card updates after the screen is dismissed. Add a regression covering a runtime that was
   claimed by the live screen, then minimized, followed by Done and no incoming samples. The new
   cold test starts with `onSample == nil`, so it cannot expose this case.

Standards: 0 new findings. Spec: 1 High finding. Round-2 #3 is fixed for a truly cold runtime,
but its new ownership guard leaves the minimized-workout path unresolved. This finding is based
on source/lifecycle tracing; it was not reproduced through a newly authored UI test.

### Regression coverage and verification

The three new tests exercise the previously missing effective-load-type match, failed recovery
followed by retry, and no-sample periodic fallback with a failed save then retry. Their assertions
would reject the corresponding round-2 behavior: stale load type would be accepted, recovery
would leave the deadline cleared on failure, and no-sample fallback would never occur. The
fallback test runs the actual periodic trigger with a shortened interval and advanced clock;
it does not invoke the evaluator directly. Test strength was inspected, not mutation-tested.
Unrelated-edit preservation and task teardown/screen ownership were traced in source rather
than covered by new dedicated tests.

Reviewer commands (Xcode 27.2 / WT-Floodlight, same environment as prior rounds):

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
  -resultBundlePath build/results/ls04-codex-r3-unit.xcresult
# exit 0; 1310/1310, 0 failed, 0 skipped; TEST EXECUTE SUCCEEDED

git diff --check bad36c74..60826bc3
# exit 0
```

Logs/status files: `build/results/ls04-codex-r3-{build,unit}.{log,status}`. Build and Unit run
completed; actual exit status and xcresult summary were inspected. No competing build/test run.

Inspected the author's `build/results/ls04-r3-ui.xcresult` summary and actual log
`build/logs/ls04-r3-ui.log`: **7/7 Passed, 0 failed, 0 skipped**, `TEST EXECUTE SUCCEEDED`.
It contains HeartRateUITests (5) and real Lock Screen Done plus +15s/Skip (2), all serial.
The author reports exit 0; no separate retained shell-status file for this UI run was found.
Also inspected `build/results/ls04-r3-unit.xcresult`: **1310/1310 Passed**, no failures/skips.
UI was not rerun this round, as requested: no screen/UI-test source changed, and repeating these
existing cases would not exercise the missing minimized/no-sample lifecycle regression.

Verified: reviewer build exit 0; Unit 1310/1310, exit 0,
`build/results/ls04-codex-r3-unit.xcresult`; author's UI 7/7 and Unit 1310/1310 result bundles inspected.
Not verified: the minimized/no-sample path and its fix;
physical-device, OS cold-launch delivery and real sensor/Watch behavior.
Known flaky: prior round's keyboard-unit-focus case failed under parallel load and passed alone;
not selected this round. None seen in this round's reviewer run.

Verdict: changes requested

## Round 4 — `09c19957`, 2026-11-15

Reviewed `git diff 60826bc3..09c19957`; actual HEAD
`09c19957ba21e1e63e6c464e2d87079e72fdca5d`, branch `ericlee4992/lock-screen-log-set`, clean at
review start. Read STATE and the ticket's round-3-fix section, and verified the actual source
against Git. STATE still names the earlier implementation tip. Only this report was edited;
no commit was made.

### Standards

No findings. The previous save boundaries and stale-card guards remain intact. The new ownership
methods associate the callback with its workout; release from a different workout leaves the
current claim alone. The installed evaluator captures its commands owner weakly and resolves the
currently attached workout dynamically, rather than retaining the workout from an earlier command.

The periodic task intentionally now lives with the app's evaluator. It uses a weak coordinator
capture and skips dispatch when `workoutID` is nil. End/cancel clears attachment and callback
ownership; installing a replacement evaluator cancels the previous task. The task can remain
asleep between workouts, but cannot evaluate an unattached workout. The screenless path also
fetches the requested workout and rejects deleted/finished workouts.

### Spec

No findings. The round-3 minimized-workout defect is addressed:

- The screen claims samples when its task attaches the runtime and releases its own workout's
  claim on disappearance. Minimize therefore hands evaluation to the runtime; resume reclaims
  it. An old screen's disappearance cannot release a different workout's claim.
- `WorkoutActivityCommands.install` installs the evaluator before the UI runs
  (`WorkoutTrackerApp.prepare` calls it). It remains available after finish/cancel for the next
  attached workout. Normal replacement tears down the old runtime and clears its claim first.
- Each runtime sample/tick routes to one owner: the claimed screen or the runtime evaluator.
  The screen also retains its existing liveness timer. These checks are synchronous on MainActor;
  cleared-rest and degraded-set guards prevent duplicate recovery/fallback transitions when
  successive checks run. The screen retains its redraw path; the runtime publishes the Watch,
  alarm and card updates when the screen has released ownership.

Standards: 0 findings. Spec: 0 findings. The remaining finding from round 3 is closed; no earlier
blocking finding remains open in the reviewed implementation.

### Test strength and verification

The new minimized-workout test checks another workout cannot release the claim, the matching
release clears it, no-sample fallback runs through the actual periodic trigger, the card reports
fallback, and the released screen is never invoked. The visible-screen test checks ticks reach
the screen and not the runtime handler. Those assertions detect the prior retained-callback and
tick-routing behavior. The real SwiftUI claim/release calls and finish/cancel/second-workout
paths were additionally traced in source. No mutation testing or new reviewer test code was used.

Reviewer commands, Xcode 27.2 (`27B52`), WT-Floodlight (iPhone 15 Pro Max, iOS Simulator 27.0):

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
  -resultBundlePath build/results/ls04-codex-r4-unit.xcresult
# exit 0; 1312/1312, 0 failed, 0 skipped

xcodebuild test-without-building -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -testPlan Full -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath build/dd-codex -parallel-testing-enabled NO \
  -only-testing:WorkoutTrackerUITests/FloodlightSystemUITests/testRealLiveActivityDoneLogsTheSet \
  -only-testing:WorkoutTrackerUITests/FloodlightSystemUITests/testRealLiveActivityEndsWhenTheWorkoutIsCancelled \
  -collect-test-diagnostics never -resultBundlePath build/results/ls04-codex-r4-ui.xcresult
# exit 0; 2/2, 0 failed, 0 skipped; TEST EXECUTE SUCCEEDED

git diff --check 60826bc3..09c19957
# exit 0
```

Actual status files and xcresult summaries inspected. Reviewer logs/status files:
`build/results/ls04-codex-r4-{build,unit,ui}.{log,status}`. Runs were sequential, with no competing
build/test run. The two real Lock Screen tests independently verified Done and cancellation.

Author evidence inspected: `build/results/ls04-r4-unit.xcresult` **1312/1312 Passed**;
`build/results/ls04-ui4.xcresult` **26/28**, two failures, zero skips, actual
`build/logs/ls04-ui4.status` **exit 65**. Failures were the keyboard unit-focus assertion and the
real-activity cancellation test's precondition that the card was visible. Both passed in
`build/results/ls04-ui4-rerun.xcresult` (**2/2**, zero failures/skips; rerun log says
`TEST EXECUTE SUCCEEDED`; no separate rerun shell-status artifact found). The adjacent
HeartRate/FloodlightLive results were inspected rather than rerun. Parallel Notification Center
contention is the author's explanation for the cancellation failure, not independently established
here; the reviewer's serial cancellation check passed as well.

Verified: reviewer build exit 0; Unit **1312/1312**, exit 0,
`build/results/ls04-codex-r4-unit.xcresult`; real Lock Screen Done and cancellation **2/2**, exit 0,
`build/results/ls04-codex-r4-ui.xcresult`. Author's adjacent UI result and serial rerun inspected.
Not verified: physical-device behavior, OS cold-background launch delivery, and real sensor/Watch
hardware; a dedicated end-to-end UI test of minimize → resume → second workout (unit coverage
and lifecycle source tracing were used).
Known flaky: author's parallel keyboard-unit-focus and Live Activity cancellation cases failed
and then passed serially. None seen in this round's reviewer runs.

Verdict: clear
