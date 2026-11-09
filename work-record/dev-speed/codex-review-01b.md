# Testing workflow 01 — Codex review round 2

Reviewed 2026-11-09; Claude implemented, Codex independently reviewed.

## Scope

Reviewed `git diff 77582ad..10d1b87`, the six round-1 findings, the round-2 brief, ticket, AGENTS and relevant
DEVELOPMENT/D46 rules. Started on clean `ericlee4992/dev-01-testing-workflow` at
`fa61d66d1cecf056d3ebe2853725d42fd9bdd527`. Another session advanced HEAD to `c3af8e6` during verification;
that commit changes only `docs/STATE.md`. Verified no app, test, script, plan or project changes between those tips.
Only this report was written in the repository by this reviewer; no commit or push.

## Standards

### P2 — Make the scheduler regression tests independent of short wall-clock limits

**Location:** `WorkoutTrackerTests/RestNotificationSchedulerTests.swift:70–76`; related assertion at `:33–42`.

`theCallerIsNotKeptWaitingForTheCenter` requires the two calls to finish within 200 ms of a real `Date()` sample.
If the caller is descheduled for 200 ms between that sample and the assertion, the test fails even when both calls
correctly enqueue work and return immediately. The deadline test similarly requires less than 100 ms between the
adapter's clock read and the fake center's real `Date()` sample. These are machine-scheduling assumptions, not
solely assertions about the adapter. The ordinary passing run below does not remove that false-failure path.
This conflicts with DEVELOPMENT's controlled-clock guidance and adds timing sensitivity to a reliability ticket.

**Fix:** use the existing injected `now` closure and a fake clock advanced inside removal to assert the exact
remaining trigger interval. Prove nonblocking behavior with a controlled removal gate: observe that the caller
returned while removal remains blocked, then release and drain the queue. Use a generous timeout only as a deadlock
safeguard. Keep the existing ordered-call assertions. A source-exact adapter harness demonstrating those checks is
`/tmp/codex-dev01b/scheduler-controlled.swift` (exit 0).

No other documented-standard violations or actionable code-smell findings in the round-2 changes. The narrow
center seam and queue-drain hook serve the requested verification; no unrelated refactoring is needed.

## Spec

**P2 — Same test reliability issue, independently identified:** `RestNotificationSchedulerTests.swift:41,76`.
The brief explicitly asks whether the tests are “free of timing flakiness”; the ticket calls for fixing flakes.
The 100/200 ms wall-clock assumptions do not satisfy that requirement. Replace them with the controlled-clock and
gated-center assertions described above. No missing production behavior or scope creep found in this fix round.

## Round-1 findings checked

1. **Deadline drift: production fix resolved; test reliability needs the P2 above.** Removal finishes before the
   queue reads `now()` and constructs the interval. Serial remove/add ordering remains intact; elapsed deadlines
   retain the one-second fallback. Authorization still uses the real notification center asynchronously. The
   queue-drain hook establishes submitted-call completion, not notification delivery. The independent controlled
   harness verifies an exact 40-second interval after a simulated 20-second removal from a 60-second rest, both
   schedule/cancel orderings, the elapsed deadline, and caller return while removal is blocked.
2. **Rebuild documentation: resolved.** DEVELOPMENT requires rebuilding after app or test-source edits and limits
   reuse to unchanged compiled source.
3. **Nested test discovery: resolved.** Current plans pass; the round-1 nested-unmapped-class fixture now fails
   with exit 1 and names `UnmappedUITests` as unmapped.
4. **Missing exploration fallback: resolved.** The exact discovery block selects a valid custom DerivedData app
   and exits 0 with an absent fallback root. No HOME override or simulator installation was needed for this check.
5. **Warm-up claims: resolved.** Comment, plan-script comment and DEVELOPMENT distinguish serial ordering from
   one-clone-only parallel warm-up and require evidence before dismissing a launch failure as infrastructure.
6. **Progress counting: resolved for the reported case.** An actual-script replay appended a second passing result
   six seconds after the final marker. It waited for the quiet period, counted both results, excluded the Swift
   Testing run summary, and finished with the explicit console-count qualification. Counts remain provisional;
   the xcresult is still authoritative.

## Verified

Own environment: Xcode 27.2 (27B52), iOS 27.0, WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`.
Commands, logs and results: `/tmp/codex-dev01b/`; runner `verify.sh`, PID `16234`.

- `scripts/prepare-test-simulator.sh`: exit 0; simulator booted and left booted.
- `build-for-testing -testPlan Unit`: exit 0, succeeded, 0 errors, 31 warnings; 61.2 seconds.
  No warnings point at the changed scheduler or its new tests. `build.status`, `build.xcresult`, `build-summary.json`.
- **Unit plan: 1116/1116 logical tests passed**, 0 failed/skipped, **exit 0**, 148.5 seconds.
  Includes `RestNotificationSchedulerTests`, `RestTimerTests`, and `HeartRateRestTimerTests`. Device metrics count
  1131 parameterized executions; 54 runtime warnings on existing audio-session paths. Evidence: `unit.status`,
  `unit.log`, `unit.xcresult`, `unit-summary.json`.
- Current plan check and shell syntax checks: exit 0. Nested unmapped fixture: expected exit 1. Missing-fallback
  discovery: exit 0. Evidence: `script-checks.json`, `nested-plan-check/`, `discovery.sh`.
- Controlled-clock/gated-center adapter harness: exit 0; `scheduler-controlled.swift`, `scheduler-controlled.log`.
  This tests production adapter logic with the real SDK request/trigger types and a fake center, not delivery.
- Progress replay: exit 0; `progress-replay-result.json`, `progress-replay-output.log`.
- Reused existing Orca progress tab `term_ac1339dc-202d-4c10-bab3-b528de726cbd`; no new terminal opened.

**Author evidence inspected directly**, under
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/b075476f-cb86-4797-a96b-088b73936c7a/scratchpad/m/`:
`unit-r2.xcresult` reports **1116/1116 passed**, 0 failed/skipped (1131 parameterized executions);
`stop-fixed2.xcresult` reports **1/1 passed**, 0 failed/skipped, for
`CardioUITests/testSavedDistanceEditorKeepsEnteredUnitsAndUntouchedMeasurements`.
Both action records say `succeeded`, both logs end with `TEST EXECUTE SUCCEEDED`, and both failure arrays are empty.
Extracted summaries/actions are saved as `*-author-summary.json` and `*-author-actions.json` in the review directory.
The ticket records shell exit 0 for both; separate numeric shell-status files for these two runs were not present,
so those numeric exit codes were not independently recoverable. The actual xcresults and log markers were checked.

## Not verified

No UI rerun this round: the brief and AGENTS permit inspection of the author's artifacts because the change is on
the notification path, with no UI behavior or UI-test logic change (only a warm-up comment). No full UI run, device
notification presentation, new exploration screenshot run, or fresh daemon-pause experiment. Daemon-pause setup and
restoration for the author's round-2 run are reported by the author; the inspected xcresult proves the test passed,
not independently that the daemon was paused. Round 1 already records an independent paused-daemon check.

## Known flaky

No selected test failed in this run. The P2 above identifies a remaining false-failure path in the two new wall-clock assertions; it is a
static reliability finding, not a claim that this ordinary run reproduced it. Existing unrelated flakes remain
outside this round's scope.

Standards: **1 P2**. Spec: **1 P2** (the same test-reliability issue); no other findings on either axis.

Verdict: not clear
