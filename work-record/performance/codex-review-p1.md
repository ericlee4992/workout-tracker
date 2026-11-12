# P1 round 1 — independent Codex review

Review completed, 2026-11-12. **No P1/P2 findings; clear for the reviewed code and tooling.** Branch `ericlee4992/perf-01-workout-lag`, clean starting HEAD
`5066a33cd0e4e06aead50ba07655e6950465cbed`. Reviewed `git diff 97e63f9..HEAD`, including tooling commit
`c81a24c6` and implementation `f379ba79`. The only commit after the requested `d73570c3` updates STATE with the
reviewer's identity. No product or test source changed during this review.

## Standards

No blocking findings in the changed code or Paseo tooling. Swift 5 and iOS 26 deployment remain unchanged;
the domain cache imports no UI framework and is main-actor isolated. The tooling changes retain the reused
reviewer, Test progress terminal, worktree/handoff procedure, and protection of the release archive checkout.
The old Orca procedure is preserved and the new relative links resolve.

**P3 — residual history scan, pre-existing and nonblocking:**
`WorkoutTracker/Features/ActiveWorkout/ExercisePickerSheet.swift:50` and `:52` evaluate `recent` twice when it is
nonempty. Each calls `WorkoutTracker/Features/ActiveWorkout/LiveWorkoutPieces.swift:655`, which fetches all
finished workouts and walks their entries until it finds five distinct exercises at the selected gym.
At a new gym, or one with fewer than five historical exercises, this traverses the entire history; the
empty-workout body also calls it at `ActiveWorkoutView.swift:183`. The perf fixture's one gym with several recent
exercises does not exercise this worst case. Measure that case and cache the result for the presentation with
explicit invalidation, or scope the lookup. This is reported under review-brief item 4; it is not an introduced
regression or measured failure of the phone latency target.

## Spec

No blocking correctness findings in the changed implementation.

- The week filter drops only dates before the earliest date the existing summary can use. `WeekSummaryInput`
  returns nil only for unfinished workouts, so replacing `inputs.isEmpty` with the finished-workout query's
  `isEmpty` preserves the first-run condition, including users whose history is older than the window.
- The recorder still appends sensor rows and changes checkpoints/segment fields before `persist`. Any such
  mutation leaves the context dirty and is saved in the same refresh. Unchanged scalar assignments and empty
  saves alone are suppressed; the timer, sample callback, rest-alarm call order and cardio refresh remain intact.
- `FinishedHistoryCache` stores entry references, not set values or snapshots. Current live-screen sheets cannot
  replace finished-history membership; History requires dismissing the cover; restore waits for relaunch;
  Lock Screen and Watch paths do not replace finished-history entries. The cache preserves the fetched list's
  order, so shared badges/outcomes use the same input order. Its two counts are **not** a general remote-merge
  invalidator: an add and removal can cancel. CloudKit sync is deferred and no CloudKit capability is configured,
  so this is a future limitation rather than a reachable regression in this release.
- Shared `PerformanceHistory` entries are used only by `latestEntry(matching:)`; selection has the full
  `(finishedAt, startedAt, workout UUID, entry order, entry UUID)` tie-break. The `contains` check has the same
  completed-set criterion as the previous sorted filter.
- F5 protects committed weight or reps after row reconstruction. Template, AI-template and Repeat starts keep
  targets separate from blank actual values; carry-forward stamps `prefilledAt`; equipment/preset changes clear
  inherited drafts and preserve typed ones. Bar/unit changes use the existing commit/provenance paths. No schema
  change is needed for old drafts that already contain values with no prefill stamp.
- `PerfFixture.isEnabled` requires both the perf flag and `-uiTestReset`; the no-history flag only changes that
  fixture's count. The reset path selects the disposable UI-test store. No `[DEBUG-p1]`, `P1Probe`, or `P1_` probe
  remains in compiled app/test sources. Parked probes stay outside the synchronized source folders.

## Verification

Completed runner: `/tmp/codex-p1/run.sh`, recorded PID `80489` (`/tmp/codex-p1/runner.pid`); derived data
`/tmp/codex-p1/dd`. All three commands exited 0; no build/test process remains from this run.
Xcode 27.2 (27B52), WT-Floodlight iOS 27.0 simulator, prepared with `scripts/prepare-test-simulator.sh`.
Build, Unit, then focused UI run sequentially; UI uses two workers. The existing Paseo Test progress tab is reused.

- Reviewer `build-for-testing`: passed, exit 0; `/tmp/codex-p1/build.log`, `build.status`.
- Reviewer Unit: **1,289/1,289 passed**, zero skipped, exit 0; `/tmp/codex-p1/unit.log`, `unit.xcresult`,
  `unit.status`. Counts read directly with `xcresulttool get test-results summary`.
- Reviewer focused UI: **27/27 passed**, zero skipped, exit 0; `/tmp/codex-p1/ui.log`, `ui.xcresult`, `ui.status`.
  Counts read directly from the final xcresult. Selected UI classes: `AAAWarmUpUITests`, `LivePrefillUITests`,
  `FloodlightLiveUITests`, `CoreLoopUITests`.
- `python3 scripts/test-plans.py --check`: exit 0. Tooling relative-link checks passed.
- Author xcresults inspected directly: Unit 1,289/1,289; clean prefill 1/1; Workout 73/74, exit 65 in
  `/tmp/p1/workout-1.status`; failed case `FloodlightLiveUITests.testACompletedSetCanBeCorrectedInPlace` received
  `102.` instead of `102.5`. Its isolated rerun is 1/1 with `TEST EXECUTE SUCCEEDED` in the log. Bundles:
  `/tmp/p1/unit-clean.xcresult`, `prefill-clean.xcresult`, `workout-1.xcresult`, `workout-1-rerun.xcresult`.
- The author's `/tmp/p1/prefill-nofix.log` records the rebuilt row showing 55 instead of typed 77 at the final
  assertion. The clean result passes. The reviewer does not disable the guard or edit sources to rerun red.
- Recalculated retained idle probe windows: baseline 8,356 ms / worst 2,213 ms; heart-rate baseline 18,986 ms /
  worst 3,632 ms; fixed no-sensor 51 ms; fixed heart-rate 2,287 ms / worst 83 ms; no-history heart-rate control
  1,063 ms / worst 68 ms. Re-running the phase parser reproduces the ticket's fixed/control driven percentages.
  These validate the recorded arithmetic, not an independent fresh profiling run or phone performance.

Verified: build-for-testing — exit 0; Unit — 1,289/1,289, zero skipped, exit 0, `/tmp/codex-p1/unit.xcresult`;
focused UI — 27/27, zero skipped, exit 0, `/tmp/codex-p1/ui.xcresult`; test-plan mapping and tooling links; author
result bundles and retained probe arithmetic inspected.

Not verified: phone latency and user acceptance with the real store and AirPods;
hardware sensor/Watch behavior; fresh Release profiling; independent red run; sparse/new-gym recent-list latency.

Known flaky: author's parallel `FloodlightLiveUITests.testACompletedSetCanBeCorrectedInPlace` dropped the final digit,
then passed alone (already tracked by Floodlight 11 and release R). It also passed in this reviewer
parallel run; no reviewer test flake observed. The UI bundle retains the existing "Invalid frame dimension
(negative or non-finite)" runtime warning also present in the author's prefill/Workout bundles; no test failed.

Axis summary: Standards — one nonblocking P3 residual scan; Spec — no blocking implementation findings, phone
acceptance pending. Required reviewer verification is complete. This clearance does not close ticket acceptance
criteria 1–2: the phone measurements and the user's feel still need the planned development-build check.

Only this report was written in the checkout. No commit, push, merge, or device installation was performed.

Verdict: clear
