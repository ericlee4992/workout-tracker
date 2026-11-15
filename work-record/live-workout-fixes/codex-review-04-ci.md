# Live-workout 04 — CI timing review

Reviewed 2026-11-15: `git diff 26642ef8..11bd5591`, branch `ericlee4992/ci-timing-tests`,
HEAD `11bd5591e1d370e90003be21ffdd831276291ec0`. Working tree initially clean. Read STATE,
ticket 04, the failed CI log, and DEVELOPMENT's timing/test guidance. Only this report was
written; no source/test edits or commit. No UI tests were run.

## Scope and observed CI failure

The only code changes are in `WorkoutActivityContentTests.swift`: longer fixture rest/cap
durations and a shared polling helper with a five-minute wall-clock deadline and early exit.
The diff also adds the previous build-16 release review report; it is therefore test code plus
documentation, with no app/widget/watch/config/server changes.

Read `gh run view 43698481749 --log-failed` directly (exit 0; captured in
`/tmp/ls04-ci-failed.log`). It records:

- `aMinimisedWorkoutStillFallsBackWithoutAReading`: 310.757 s, failed standard-deadline and
  card-fallback assertions.
- `noReadingFallsBackToTheTimerWithoutAScreenOrASample`: 310.762 s, the same two assertions.
- `aFailedRecoverySaveKeepsTheRestAndTheNextReadingRetries`: 314.081 s, failed eventual
  recovery assertion.

The complete run failed with five issues across those three tests. These durations exceed
the original 120-second standard rest and 240-second cap and support the expiry explanation.
The log does **not** independently establish the new helper comment's assertion that a
three-second polling budget expired: the fallback-ID assertions passed, while the resulting
deadline/card assertions failed. The prior loop's sleeps were also stretched by scheduling.

## Standards

1. **Medium — the failed-save assertions can pass before a failure has been attempted.**
   `WorkoutTrackerTests/WorkoutActivityContentTests.swift:589–595` and `:612–618`.
   The recovery and fallback tests still wait only 400/300 ms before checking that state is
   unchanged and restoring successful saving. A slow runner can resume the test before the
   sensor consumer/evaluator has called the injected failing save. The unchanged-state checks
   then inspect the untouched initial state, and the later successful callback/tick satisfies
   the positive assertions. The test can pass even with rollback removed. This is a pre-existing
   weakness, not an assertion newly deleted by this diff; the requested slow-runner review
   cannot treat these sleeps as evidence that rollback was exercised.

   **Fix:** acknowledge an actual transition-save attempt in the injected closure, await it,
   then assert restored state before allowing successful saving. Distinguish this attempt from
   the preliminary save of unrelated pending changes, for example by checking that the expected
   rest-field mutation is present at the failing save boundary. Add assertions that the failure
   happened and that retry succeeded. Without that acknowledgement, report these checks as
   timing-dependent coverage rather than guaranteed detection of the original rollback defects.

## Spec / remaining timing dependence

2. **Medium — the unchanged 20-second no-reading grace can still make the recovery fixtures fail.**
   `WorkoutTrackerTests/WorkoutActivityContentTests.swift:501–513` and `:557–570`.
   Raising the standard rest to an hour and the cap to two hours does not control the coordinator's
   clock. Done starts the rest and periodic evaluator before `await commands.logSet(...)` finishes
   settling the runtime/card. If scheduling delays the test continuation or first sample ingestion,
   an overdue tick can run with an empty monitor after the 20-second grace. It then persists the
   standard fallback and sets `degradedRestSetID`. The later recovering sample is deliberately
   ignored by the coordinator's degraded-set guard. A larger cap and five-minute wait cannot
   undo that transition, so correct app code can still fail these recovery tests under a slow
   schedule.

   **Fix:** freeze the fixture's domain clock before starting the runtime/rest and advance it
   explicitly for each scenario. Keep recovery tests inside the no-reading grace until their
   intended sample has been processed; move fallback tests past the grace deliberately. Keep
   real-time waits only as bounded hang protection. DEVELOPMENT's verification guidance already
   calls for a controlled clock for persistent timing failures. Also correct the polling comment
   to distinguish observed expiry from an unproven polling-timeout diagnosis.

   This is **not** a 15-second stale-sample rejection: when all samples are stale,
   `HeartRateSample.current(asOf:)` retains the newest sample/source, and the rest rule checks
   recovery before freshness. The remaining race is fallback **before** the sample is ingested.

Standards: one coverage finding, Medium. Spec: one remaining timing finding, Medium. These are
test reliability/coverage issues; this branch changes no production behavior.

The positive assertions have not been weakened: exact standard deadlines, fallback/card state,
recovered results and screen ownership are still checked, so missing evaluation or stale ownership
still fails. The new polling helper exits as soon as its condition holds. Longer fixture deadlines
remove the observed short-rest expiry window, but do not establish deterministic timing or prove
that the negative failure path was reached. Findings above are source-traced; no mutation test or
controlled scheduler-starvation reproduction was run.

## Verification

Xcode 27.2 (`27B52`), WT-Floodlight / iOS Simulator 27.0. Executed:

```sh
scripts/prepare-test-simulator.sh
# exit 0

xcodebuild build-for-testing -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath build/dd-codex
# exit 0; TEST BUILD SUCCEEDED

xcodebuild test-without-building -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -testPlan Unit -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath build/dd-codex -parallel-testing-enabled NO \
  -only-testing:WorkoutTrackerTests/WorkoutActivityContentTests -collect-test-diagnostics never \
  -resultBundlePath build/results/ls04-ci-codex-unit.xcresult
# exit 0; 31/31 passed, 0 failed, 0 skipped

git diff --check 26642ef8..11bd5591
# exit 0
```

Actual build/test status files and xcresult summary inspected. Logs/status:
`build/results/ls04-ci-codex-{build,unit}.{log,status}`.

Branch CI [43700178994](https://github.com/ericlee4992/workout-tracker/actions/runs/43700178994)
was still **in progress** at the last read, on the reviewed `11bd5591` SHA; no CI success is
claimed. A later passing run would not remove the scheduling/coverage windows above.

Verified: build exit 0; WorkoutActivityContentTests **31/31**, exit 0,
`build/results/ls04-ci-codex-unit.xcresult`; failed main CI log read directly; no production-code changes.
Not verified: final branch CI result, scheduler-starvation reproduction, mutation testing, full
Unit plan or UI (only the requested focused unit suite was rerun).
Known flaky: the three tests failed in main CI as documented above and passed in this focused
local run; the remaining timing dependencies prevent calling the flake resolved.

Verdict: changes requested

## Round 2 — `2f5e7db1`, 2026-11-15

Reviewed `git diff 11bd5591..2f5e7db1`. On entry the shared checkout was on the release branch
at `6075d1ba`, with this existing report untracked. Switched to the requested
`ericlee4992/ci-timing-tests` branch and verified HEAD
`2f5e7db14c8385e9f23ddf918ae1d0838a658fde` before building. Only
`WorkoutActivityContentTests.swift` changes in this revision; no production changes. Only this
report was edited by the reviewer; no commit or UI tests.

### Standards

No findings. Round-1 #1 is addressed: the failing closures now acknowledge the transition's
own save, using the already-cleared recovery deadline or already-moved fallback deadline to
distinguish it from a preliminary save. Each test waits for and explicitly asserts a failure
attempt before inspecting rollback or restoring successful saving. The evaluator, save closure
and catch execute synchronously on MainActor, so the awaiting test cannot observe the counter
between the thrown save and rollback. Removing rollback would fail the restored-field assertion;
premature fallback marking would fail the marker assertion; never evaluating would fail the
attempt assertion. Exact retry/deadline/card assertions remain.

### Spec / timing

No findings. Round-1 #2 is addressed: the coordinator clock is frozen before Done in the cold
fixtures and before attachment/Done in the minimized fixture. Scheduler delays cannot advance
it past the 20-second no-reading grace. Fallback cases move it explicitly to the recorded rest
start plus 30 seconds. The polling comment now correctly distinguishes observed expiry from
an unproven polling-timeout diagnosis.

Not every clock is frozen: polling uses wall time as hang protection; rest persistence and
sample timestamps still use real time. The one-hour standard rest and two-hour cap exceed
CI's configured 600-second per-test allowance, so those deadlines cannot expire during an
otherwise permitted test run. A stale fixture sample retains its source and is evaluated for
recovery before freshness, as checked in round 1. No remaining domain-transition timing race
was found within that test allowance. The polling helper still exits early when its condition
holds. These conclusions are based on source tracing plus the focused run, not mutation testing
or deliberately starving the local main actor.

Standards: 0 findings. Spec: 0 findings. Both round-1 findings are closed.

### Verification

Xcode 27.2 (`27B52`), WT-Floodlight / iOS Simulator 27.0. Rebuilt the reviewed commit before testing:

```sh
scripts/prepare-test-simulator.sh
# exit 0

xcodebuild build-for-testing -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath build/dd-codex
# exit 0; TEST BUILD SUCCEEDED

xcodebuild test-without-building -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -testPlan Unit -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' \
  -derivedDataPath build/dd-codex -parallel-testing-enabled NO \
  -only-testing:WorkoutTrackerTests/WorkoutActivityContentTests -collect-test-diagnostics never \
  -resultBundlePath build/results/ls04-ci-codex-r2-unit.xcresult
# exit 0; 31/31 passed, 0 failed, 0 skipped

git diff --check 11bd5591..2f5e7db1
# exit 0
```

Actual status files and xcresult summary inspected. Logs/status:
`build/results/ls04-ci-codex-r2-{build,unit}.{log,status}`.

Read branch CI [43700754494](https://github.com/ericlee4992/workout-tracker/actions/runs/43700754494)
again after local verification: **in progress**, head SHA matches `2f5e7db1`, no conclusion yet.
This clears the code review; it does not claim that CI has passed.

Verified: reviewer build exit 0; WorkoutActivityContentTests **31/31**, exit 0,
`build/results/ls04-ci-codex-r2-unit.xcresult`; only test source changed in this revision.
Not verified: final branch CI result, local scheduler-starvation reproduction, mutation testing,
full Unit plan or UI (not requested this round).
Known flaky: the three failures in main CI are historical evidence from before these fixes;
no failures seen locally this round. Remote validation remains pending.

Verdict: clear
