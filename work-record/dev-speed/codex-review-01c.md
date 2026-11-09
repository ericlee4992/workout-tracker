# Testing workflow 01 — Codex review round 3

Reviewed 2026-11-09; Claude implemented, Codex independently reviewed.

## Scope

Reviewed `git diff c3af8e6..64ee13a` against the round-2 P2, on clean
`ericlee4992/dev-01-testing-workflow` at `64ee13a006291457e2effdd5949721863f581e91`.
Read current STATE, ticket section 5, the changed tests and the prior review. The diff changes the scheduler tests,
records the fix/evidence in the ticket, and commits the prior review report. No production code changes.
Only this report was written in the repository by this reviewer; no commit or push.

## Standards

**No findings.** The prior P2 is resolved. Deadline assertions use a locked manual clock, not real elapsed time.
Clock state, event log, interval list and removal counter are protected by locks. The removal callback is configured
before scheduling and is not changed concurrently. Both ordered-call assertions are retained. No unrelated
modernization or refactoring is required.

## Spec

**No findings.** The tests now satisfy the requested controlled-clock and gated-center checks without the former
100/200 ms wall-clock limits:

- `RestNotificationSchedulerTests.swift:41–50`: removal advances the injected clock by 20 seconds; a 60-second rest
  must submit exactly 40 seconds remaining. Computing the interval before removal would fail this assertion.
- `:70–77`: a fixed past deadline preserves the exact one-second fallback check.
- `:53–67`: schedule→cancel and cancel→schedule ordering remain checked after the queue drains.
- `:80–98`: both caller methods must return before the test releases either removal. The pre-release event log
  must be empty, and both removals must acquire permits supplied by the test. A synchronous blocking regression
  exhausts the timeout and fails the assertions. The 30-second semaphore timeout is a hang safeguard, not a
  short-duration performance requirement. The test does not need the worker to have started before releasing it:
  the held gate already prevents either removal from completing before the caller returns.

The actual notification-center seam and production scheduler are unchanged from the reviewed round-2 build.

## Verified

Own environment: Xcode 27.2 (27B52), iOS 27.0, WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`.
Artifacts and runner: `/tmp/codex-dev01c/`, `verify.sh` (PID `22536`).

- `scripts/prepare-test-simulator.sh`: **exit 0**, simulator booted and left booted.
- `build-for-testing -testPlan Unit`: **exit 0**, succeeded, 0 errors, 31 warnings; no warning in the changed
  scheduler test file. Evidence: `build.status`, `build.log`, `build.xcresult`, `build-summary.json`.
- `test-without-building -testPlan Unit -only-testing:WorkoutTrackerTests/RestNotificationSchedulerTests
  -test-iterations 25 -parallel-testing-enabled NO`: **4/4 logical tests, 100/100 executions passed**,
  0 failed/skipped, **exit 0**, no runtime warnings. Evidence: `sched-x25.status`, `sched-x25.log`,
  `sched-x25.xcresult`, `sched-x25-summary.json`.
- The existing Orca progress tab `term_ac1339dc-202d-4c10-bab3-b528de726cbd` was reused; no new terminal opened.

**Author evidence inspected directly**, under
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/b075476f-cb86-4797-a96b-088b73936c7a/scratchpad/m/`:

- `sched-x25.xcresult`: **4/4 logical tests, 100/100 repeated executions passed**, 0 failed/skipped;
  `sched-x25.status` records **exit 0**.
- `unit-r3.xcresult`: **1116/1116 logical tests passed**, 0 failed/skipped (1131 parameterized executions);
  `unit-r3.status` records **exit 0**.

Both logs contain `TEST EXECUTE SUCCEEDED`, both action records report `succeeded`, and failure arrays are empty.
Extracted summaries/actions are saved as `*-author-summary.json` and `*-author-actions.json` in the review directory.
Counts distinguish logical tests from repeated/parameterized executions.

## Not verified

No independent full Unit rerun this round: only the scheduler test file changed, so the affected suite was built and
repeated 25 times, as permitted by the requested scope; the author's full Unit result was inspected directly.
No fresh UI run, exploration screenshots, device notification delivery, or daemon-pause experiment. Production/UI
code is unchanged; round-2 verification and earlier UI evidence remain applicable within their recorded limits.

## Known flaky

None seen in the selected runs. The round-2 short wall-clock false-failure paths are removed. The generous hang
guard can still fail a severely stalled process, as intended; these results do not claim unrelated historical
UI flakes are eliminated.

Standards: **0 findings**. Spec: **0 findings**. Round-2 P2 resolved.

Verdict: clear
