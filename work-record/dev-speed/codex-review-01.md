# Testing workflow 01 — independent review

Reviewed 2026-11-09 by Codex; implementation by Claude.

## Scope

Reviewed `git diff 4204fbc..77582ad` on `ericlee4992/dev-01-testing-workflow`, initially clean at
`77582ad71f3897ef900bf65330cc043107b10251`. Read AGENTS, STATE, the full brief/ticket, DEVELOPMENT's testing sections,
the relevant domain context/ADRs, changed source/scripts/plans, and actual test artifacts. Only this report was
written in the repository; no implementation edits, commit, or push. Own simulator operations used WT-iPhone27.

## Spec and correctness findings

### 1. P2 — Preserve the notification's absolute deadline across queue/daemon delays

**Location:** `WorkoutTracker/Domain/RestTimer.swift:62–70`.

The relative trigger interval is computed before entering the queue and before the potentially blocking removal.
For a rest ending in 60 seconds, a 20-second queue/removal delay causes the adapter to submit a fresh 60-second
trigger at t+20: the notification is now due at t+80, while the persisted rest deadline remains t+60. This matters
when the app is backgrounded and the system owns delivery (D46). Moving the blocking call off the main thread is
correct, but retaining its pre-wait interval introduces deadline drift.

**Evidence:** a temporary harness uses the production adapter unchanged, a controlled center that blocks removal
for 0.6 seconds, and the real SDK `UNTimeIntervalNotificationTrigger`. Its `nextTriggerDate()` at submission is
**0.610 seconds later** than the requested deadline. The harness exits 0 after asserting that drift; it does not
pretend to have delivered a real notification. See `/tmp/codex-dev01/deadline-repro.swift` and `deadline-repro.log`.
Apple documents that trigger tracking begins when the request is added.
[Apple scheduling API](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/add%28_%3Awithcompletionhandler%3A%29).

**Fix:** retain the absolute `date`, perform removal on the serial queue, then compute the remaining interval and
construct the request immediately before adding it. Handle an already-elapsed deadline explicitly. Add an
adapter-level delayed-removal/queued-work test; the existing injected notification spies do not exercise this delay.

### 2. P2 — Rebuild the test bundle after editing tests

**Location:** `docs/DEVELOPMENT.md:98–99`.

The instruction to use `test-without-building` “while only tests change” executes the previous compiled test bundle.
An edited assertion or newly added test can therefore appear verified without executing the new source. This
contradicts the ticket's requirement never to claim untested behavior works.

**Fix:** require `build-for-testing` after application **or test-source** edits. Reuse the bundle only when source
is unchanged—for example, when changing the selected tests or launch arguments.

### 3. P2 — Discover nested UI-test classes in the plan coverage check

**Location:** `scripts/test-plans.py:51–54`.

`glob("*.swift")` checks only the test folder's top level. A class added under
`WorkoutTrackerUITests/Nested/UnmappedUITests.swift` is compiled by the filesystem-synchronized target but silently
escapes every area plan, and `--check` still exits **0**. Thus the new coverage guard does not uphold its “every UI
class” promise. The current tree is fully mapped; this is a failure of the guard for a valid subsequent addition.

**Fix:** discover test sources recursively and add a check that a nested unmapped class causes failure. Reproduced
without repository edits in `/tmp/codex-dev01/nested-plan-check/`; `result.json` records the unexpected exit 0.

### 4. P2 — Treat missing optional exploration-search roots as successful omissions

**Location:** `scripts/explore.sh:34–37`.

If `DERIVED` points to a valid built app but the fallback `~/Library/Developer/Xcode/DerivedData` directory does not
exist, the final false directory check becomes the loop's exit status. `pipefail` propagates it into `app=$(...)`,
and `set -e` exits silently before using the app that was found. This breaks the documented automatic lookup on a
machine that uses only custom derived data.

**Fix:** wrap each root's `find` in an explicit `if`, so an absent optional root is a successful skip. The exact
discovery pipeline exited **1** with a valid first root and absent fallback, but **0** and selected the app with
both roots present. Reproduction: `/var/folders/f_/qhy5xsds1h9bs0wf1wkdnx9w0000gn/T/codex-dev01-discovery-vknz8sjm/discovery.sh`.
The test supplies explicit roots; it does not override HOME or alter repository files.

### 5. P3 — Limit the warm-up ordering and failure claims

**Location:** `WorkoutTrackerUITests/AAAWarmUpUITests.swift:3–8`, `scripts/test-plans.py:20`,
`docs/DEVELOPMENT.md:30–31`.

One alphabetically first class does not warm every parallel worker. The author's `par1.log:74–80` starts Profile
on Clone 1, runs AAAWarmUp on Clone 2, and starts Live on Clone 3. The single warm-up cannot absorb the other clones'
first-launch cost. Its comment also categorically attributes a lone failure to runner readiness, although this
assertion can equally detect an application launch/initial-screen regression.

**Fix:** describe the observed serial ordering, not a parallel per-worker guarantee. Keep per-worker preparation
separate, and require logs/crash evidence before dismissing a warm-up failure as infrastructure.

### 6. P3 — Do not present incomplete console tallies as the final test count

**Location:** `scripts/test-progress.sh:11–12,31–32`.

The script exits on the final marker even when Xcode prints additional parallel test-result lines afterward.
Both author parallel logs put the marker at line 156 with only **22** pass lines before it; the xcresults contain
**42** passing tests. The visible tab consequently ended at **22/42**. The Unit monitor likewise ended at 1104 while
the result summary reports 1112; the Swift regex also matches the aggregate `Test run … passed after` line.

**Fix:** keep live log counts explicitly provisional. For final counts, wait for producer completion and read the
xcresult, or omit final numeric totals when they cannot be established reliably. Do not substitute the estimated
expected count. Exclude aggregate Swift Testing summaries from individual-test counts.

## Standards and diagnosis checks

- **85 polling loops, 29 files:** reversing only the new guard syntax recreated every complete original file
  byte-for-byte. Bounds, multiline predicates, bodies, assertions and test methods are preserved. Predicates and
  their helpers read UI state; the one `waitForExistence` predicate waits/queries without mutating UI. Early exit
  after the first success is the intended change. Evidence: `/tmp/codex-dev01/polling-inverse-check.json` (exit 0,
  85 rewrites, zero mismatches) and `polling-loop-review.json`.
- **Hang diagnosis is supported:** both extracted app-main-thread spindumps show
  `CardioSession.start → RestTimerService.skip → UserNotificationScheduler.cancel → removePendingNotificationRequests`
  waiting for a synchronous XPC reply. Evidence: `spindump-main/D63FABF2-2D8C-435D-9B8C-A03689CEC33D.txt:112–129` and
  `spindump-s5-capture/55A38542-7632-4C1E-A696-6083661EC6A4.txt:112–129`, under `/tmp/codex-dev01/`.
- **Queue ordering:** sequential schedule/cancel invocations enqueue their remove/add operations on the same
  private serial queue; the old detached add Task can no longer be submitted after a later cancel. No production
  caller reads pending requests synchronously after cancel. Existing domain tests use synchronous spies, so they
  establish the requested effects rather than notification-daemon completion. Authorization still uses its existing
  Task—the comment saying *every* center call uses this queue is broader than the code.
- **API contract:** Apple allows adding requests from any app thread and describes pending-request removal as
  asynchronous. The observed iOS 27 implementation nevertheless blocks in synchronous IPC in these traces; that
  evidence supports moving the calls off the main thread without redefining the public API contract.
  [Apple add API](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/add%28_%3Awithcompletionhandler%3A%29),
  [Apple removal API](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/removependingnotificationrequests%28withidentifiers%3A%29).
- **Plans:** current coverage is complete (45 area classes plus shared warm-up). Full remains the default and
  contains both targets without selected-test restrictions. CI's Unit selector and the backup-export UI selector/
  `TEST_RUNNER_WT_BACKUP_EXPORT` remain compatible by source inspection. No coverage-data consumer was found that
  requires the removed collection. Keyboard preparation is device-scoped; explicit-app exploration and empty-array
  handling passed source/mock checks. Shell syntax checks and the current-tree plan check exit 0.
- **Measurement deviation:** retaining catalog reconciliation is reasonable given the measured fingerprint fast
  path and sub-second potential saving; a host-app/schema redesign was not introduced merely to satisfy the
  original optimization idea. The caller/UI assertion coverage has not been reduced.

## Verified

Own runs: Xcode 27.2 (27B52), iOS 27.0, WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B` only.
Artifacts/derived data: `/tmp/codex-dev01/`.

- `scripts/prepare-test-simulator.sh <WT-iPhone27>`: **exit 0**, device booted and left booted.
- `build-for-testing`: **exit 0**, xcresult `succeeded`, **0 errors, 31 warnings**; `build.log`, `build.xcresult`,
  `build-summary.json`.
- `python3 scripts/test-plans.py --check` and shell syntax checks: **exit 0** for the current tree/scripts.
- **Unit plan:** **exit 0**, **1112/1112 logical tests passed**, 0 failed/skipped. The device/legacy metrics count
  **1127 executions**, including parameterized cases. Evidence: `unit.log`, `unit.xcresult`, `unit-summary.json`.
  The summary records 54 runtime warnings, predominantly existing audio-session main-thread warnings; this review
  does not diagnose those unchanged paths.
- **Focused UI, serial:** **exit 0**, **11/11 passed**, 0 failed/skipped—AAAWarmUp 1, Cardio 9, goals-number-pad 1.
  Evidence: `ui.log`, `ui.xcresult`. Two non-failing invalid-frame runtime warnings were recorded.
- **Paused-daemon check:** **exit 0**, **1/1 passed** with WT-iPhone27's validated `usernotificationsd` stopped for
  the entire focused cardio test. It was then resumed and verified not stopped. The harness uses `finally`, signal
  cleanup and an independent watchdog. Evidence: `paused-daemon-check.py`, `paused-fixed.log`,
  `paused-fixed.xcresult`, `paused-fixed.status.json` (`stopped_through_test: true`, `resumed: true`). An initial
  identity check refused a truncated process name before sending any signal; the corrected full-field validation
  selected the device's daemon under its `launchd_sim`. No other device or host daemon was stopped.
- The existing Test progress (Claude r2) tab was reused throughout; no new terminal was opened.

**Author artifacts inspected directly:** session
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/b075476f-cb86-4797-a96b-088b73936c7a/scratchpad/m/`:
`unit-full` and `unit-plan` passed (1112 logical/1127 parameterized executions); `ui-cardio` and `ui-cardio2` each
9/9; `par1` and `par2` each 42/42; `stop-old` failed 1/1 and `stop-fixed` passed 1/1. Status files where present and
the logs' final markers agree. Extracted metrics/failures: `/tmp/codex-dev01/author-evidence.json`.

## Not verified

No fresh full UI run, second independent parallel typing run, old-build rebuild, real-device notification delivery,
or backup export was performed. The old failing controlled artifact and both original spindumps were inspected;
the fixed paused-daemon half was repeated independently. The delayed-deadline harness tests production adapter
logic with a controlled center and the real trigger, not end-to-end notification presentation. The exploration
discovery failure is a shell reproduction; no extra screenshot run was needed to establish it.

## Known flaky

No selected test failed in the independent runs. The original cardio-start hang no longer reproduced with the
daemon paused, and both author parallel runs were clean. This does not claim all unrelated historical flakes are
eliminated. The notification deadline regression in finding 1 still requires a fix.

Standards/polling audit: **0 findings**. Spec/runtime/workflow: **4 P2s and 2 P3s**. Resolve and re-review.

Verdict: not clear
