# P1 round 2 — independent Codex review

Review completed, 2026-11-12. **No findings; round-1 P3 resolved.** Branch `ericlee4992/perf-01-workout-lag`, clean starting HEAD
`8d395873e6de517027e7fd42e3e557ee7922c969`. Scope: `git diff 5066a33c..HEAD`, following
`codex-review-p1-r2-prompt.md`. No app or test source was edited by the reviewer.

## Standards

No findings. The round-1 P3 is resolved: the only production calls to `LiveRecentSection.exercises` are now
`ActiveWorkoutView.swift:626` and `ExercisePickerSheet.swift:114`, both lifecycle loads rather than body reads.
Caches use private view-owned state and retain model references. No schema, Swift language-mode or concurrency
changes. Test-plan mapping and `git diff --check 5066a33c..HEAD` pass.

## Spec

No findings from the source review.

- First appearance loads the recent list. The active screen loads it even with existing entries, so deleting
  the final workout entry reveals the cached section. Deleting an entry does not delete its catalog exercise.
- The active screen reloads on gym-ID change and checks the cached gym ID before display, preventing a prior
  gym's list from appearing during the transition. Minimise/resume reloads on appearance.
- The picker has one real caller, `AddExerciseSheet`. Its workout gym remains fixed during presentation;
  switching Exercises/Machines reconstructs the picker. A nil/deleted gym suppresses the recent section.
- Search hides the cached list; clearing search restores it. Both displays filter deleted exercise models.
  Reachable sheets create exercises or manage machines, but cannot delete catalog exercises or edit finished
  history. Changes made after minimising are reflected on reopening. The current single-device/relaunch-only
  restore constraints underlying the round-1 cache review remain unchanged.
- `-uiTestPerfNewGym` is consumed only inside the perf fixture, whose application caller is gated by both
  `-uiTestReset` and `-uiTestPerfStore`. The second gym correctly has no finished history. No `[DEBUG-p1]`,
  `P1Probe`, or `P1_` matches remain in app/test sources.
- `LiveRecentUITests` checks the expected Leg Press row in both the empty workout and Add Exercise, then search
  hide/restore. It does not directly exercise gym mutation, deletion of the final entry, or deletion of a catalog
  exercise; those cache lifecycle paths were reviewed statically. It is a functional test, not a timing guard.

## Verification

Original runner `/tmp/codex-p1-r2/run.sh`, PID `4031` (`runner.pid`), completed. Serial CoreLoop rerun
`/tmp/codex-p1-r2/coreloop-serial.sh`, PID `14035` (`coreloop-runner.pid`), completed; log/status/result paths
`/tmp/codex-p1-r2/coreloop-serial.{log,status,xcresult}`. Derived data `/tmp/codex-p1-r2/dd`.
Xcode 27.2 (27B52), WT-Floodlight iOS 27.0; `scripts/prepare-test-simulator.sh` ran first. Build, Unit and UI run
sequentially. The existing Paseo Test progress terminal is reused.

- Reviewer build-for-testing: passed, exit 0; `/tmp/codex-p1-r2/build.log`, `build.status`.
- Reviewer Unit plan: **1,289/1,289 passed**, zero skipped, exit 0; `/tmp/codex-p1-r2/unit.log`, `unit.status`, `unit.xcresult`.
- Reviewer focused UI: **20/21 passed**, zero skipped, exit 65; `/tmp/codex-p1-r2/ui.log`, `ui.status`, `ui.xcresult`. Two workers, only
  `AAAWarmUpUITests`, `LiveRecentUITests`, `CoreLoopUITests`, `FloodlightTourUITests`. The command uses the Full
  plan **narrowed by these four `-only-testing` arguments**, because Tour belongs to ProfileAI, not Workout;
  this is not a full-suite run.
- Reviewer serial CoreLoop rerun: **9/9 passed**, zero skipped, exit **0**;
  `/tmp/codex-p1-r2/coreloop-serial.xcresult`, `coreloop-serial.log`, `coreloop-serial.status`. No source changes
  between runs. Final counts for all bundles were inspected using `xcresulttool get test-results summary`.
- Author focused result inspected directly: **38/38 passed**, zero skipped, exit **0** in
  `/tmp/p1/focused-r2.status`; `/tmp/p1/focused-r2.xcresult`. This includes the reviewer selection plus
  `FloodlightLiveUITests` and `LivePrefillUITests`.
- Retained new-gym probe arithmetic checked: `Recent` counts sum to **47 before / 2 after**. Re-running the phase
  parser reproduces the open-sheet idle result: **1,147/916 ms** of gaps over 34 ms in five seconds
  (**23%/18%**), maximum **155/113 ms**, respectively. Files: `/tmp/p1/probe-newgym-before.log`,
  `probe-newgym-after.log`, `drive-newgym-before.log`, `drive-newgym-after.log`. This checks recorded evidence;
  it is not an independent fresh profiling run or proof of phone latency.

Verified: source/caller review; test-plan mapping and diff checks; author's focused UI 38/38, zero skipped,
exit 0, `/tmp/p1/focused-r2.xcresult`; retained measurement arithmetic; reviewer build exit 0 and Unit
1,289/1,289, zero skipped, exit 0, `/tmp/codex-p1-r2/unit.xcresult`. Reviewer parallel UI — 20/21, zero skipped,
exit 65, `/tmp/codex-p1-r2/ui.xcresult`; serial CoreLoop — 9/9, zero skipped, exit 0,
`/tmp/codex-p1-r2/coreloop-serial.xcresult`. Every selected UI case now has a passing reviewer result.

Not verified: phone measurements and user acceptance with the real store and
AirPods; fresh profiling; direct UI assertions for gym mutation and deleted-exercise cache filtering.

Known flaky: `CoreLoopUITests.testAddSetCarriesForwardTheLastCompletedSet` expected `lb` but got `kg` in the
parallel run. It passed in the unchanged serial class rerun, as did all nine CoreLoop tests. The same symptom
and isolated passes are recorded in [public-beta ticket 22](../public-beta/issues/22-one-add-exercise-button.md)
at line 70. No test failure remains unresolved. The author's round-2 focused result had no failures.

Axis summary: Standards — zero findings; Spec — zero findings. Required reviewer verification is complete.
Phone acceptance remains pending as in round 1. Only this report was written in the checkout; no commit, push,
merge, or device installation was performed.

Verdict: clear
