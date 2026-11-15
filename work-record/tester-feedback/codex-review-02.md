# Codex review — tester feedback 02, round 1

Reviewed `git diff b4104c9f..18207d90` on `ericlee4992/add-gym-from-train`, HEAD `18207d902b71e4e7003a00034e133a8728189ebc`. Scope: ticket 02, option C/D89, the remembered-gym behavior (ticket 17 D1), new caller plus existing editor/selection helpers, tour integration, tests and docs. No implementation files changed; no commit or merge performed.

## Standards

1. **P2 — failed Add can leave a gym behind after Cancel, or duplicate it on retry.** New integration: `WorkoutTracker/Features/Start/StartWorkoutView.swift:141`; failing implementation: `WorkoutTracker/Features/Gyms/GymEditorSheet.swift:185–195`. New Gym inserts `created` into the shared ModelContext and then saves. If that save throws, the catch only sets an error message; the inserted object remains pending. Cancel at `GymEditorSheet.swift:50` merely dismisses, so a subsequent save can persist the unwanted gym. Retrying Add allocates another Gym instead of removing/reusing the failed insertion. This violates AGENTS' failed-save/Cancel data-safety rule and the explicitly requested failed-save behavior for the new Train path. **Fix:** discard this attempt's insertion on failure or create in an isolated transaction/context, without rolling back unrelated user edits. Add deterministic regression coverage for failed Add → Cancel and failed Add → retry, checking both pending and reopened persisted state. This is an existing helper defect newly exposed through the Train entry point, not a claim that the new sheet modifier introduced the helper's bug.

2. **P2 — the new gym can be saved and shown as selected even when remembering it failed.** `WorkoutTracker/Features/Start/StartWorkoutView.swift:141,390–393`, called after the first save at `GymEditorSheet.swift:190`. `select(created)` changes `selectedGym` before `GymSelection.remember` attempts a second save. That error is caught with `assertionFailure`; in Release it returns normally, so GymEditorSheet dismisses as if the entire Add/select operation succeeded. The previous selection is not restored, and a reopen before another successful save can restore the old persisted choice instead of the displayed new one. Debug instead traps. **Fix:** make new-gym creation and preference selection one fallible operation, publishing local selection/dismissing only after success; alternatively propagate the second failure and restore both in-memory preference fields and the previous selection. Add a deterministic selection-persistence failure test. This is likewise an inherited helper failure relevant to the newly added callback; normal Save passing does not cover it.

Both findings are established by the failure-path control flow; this review did **not** force a disk/save failure in the running app. No unrelated modernization or baseline code-smell findings.

## Spec

No additional findings in the normal-path implementation:

- Option C is implemented: no active gyms → “Add Your Gym…” row; otherwise the menu ends in a divider and “Add Gym…”. Both use the existing New Gym editor.
- Successful Save calls `select(created)`; untouched Cancel does not call `onSave`. The UI tests assert the newly selected name and Gyms' separate “Current” badge, so they would fail if selection/remembering were simply omitted. They do not inject either failure in findings 1–2.
- `restoreSelectedGym` runs once per screen lifetime, so it does not overwrite the new selection on dismissal. Active-gym filtering, archived-gym invalidation and the empty-list branch remain intact. Existing `GymSelectionTests.rememberedGymSurvivesReopen` tests an actual disk-store reopen; together with the UI badge and restore source this supports persistence on successful save, though the new UI suite does not relaunch the entire app.
- The tour anchor remains attached to the row; the sample has a gym and therefore still shows the disabled picker. The changed tour assertions remain meaningful: the inert test must advance through the highlighted row while sample controls stay disabled, and returning to the user's empty store requires the add row and no sample picker.
- The row has an explicit accessible label and wrapping text; existing controls/layout are reused and no new animation is introduced. Inspected real default and AccessibilityL empty-row/menu captures in `build/captures/tf02-final/`: the new controls are readable, without truncation. No new Reduce Motion issue found.
- README and D89 accurately describe the intended successful path. The existing editor's failure behavior prevents treating the Save/Cancel promises as unconditional until findings 1–2 are fixed. Test-plan mapping includes TrainAddGymUITests in TodayTrain.

Standards: **2 P2 save-failure findings**. Spec: **0 additional findings**.

## Verification

Toolchain: Xcode **27.2 (27B52)**; WT-Floodlight, iOS 27.0, UDID `9E822EF6-DC67-4958-AEA2-D53D2D36D674`. Own derived data: `build/dd-codex`. All reviewer simulator tests ran serially.

| Check | Exit | Result / evidence |
|---|---:|---|
| `scripts/prepare-test-simulator.sh` | 0 | WT-Floodlight ready/booted |
| `python3 scripts/test-plans.py --check` | 0 | Current mapping |
| `git diff --check b4104c9f..18207d90` | 0 | Clean |
| Independent `xcodebuild … build` | 0 | `BUILD SUCCEEDED`; `build/logs/codex-tf02-build.log` |
| Independent Unit plan | 0 | **1291/1291**, 0 failed/skipped; `build/results/codex-tf02-unit.xcresult` |
| Independent requested UI scope | 0 | **10/10**, 0 failed/skipped; `build/results/codex-tf02-ui.xcresult` |

The UI scope was exactly `TrainAddGymUITests` (8) plus `FloodlightTourUITests/testShowTourFromSettings` and `testTheAppUnderTheTourIsInert` (2). No other UI classes were rerun. Actual process exits are recorded in `build/logs/codex-tf02-{build,unit,ui}.status`; logs and summary JSONs are alongside them. Both reviewer xcresult summary inspections exited 0 and confirmed the counts above.

**Author artifacts inspected, not rerun:**

- `build/results/tf02-ui.xcresult`: **22 passed, 5 failed, 0 skipped / 27**, original exit **65** confirmed in `build/logs/tf02.status`. Failures were four tour tests using the former empty-store picker location and the Ask AI gym test's goal-entry wait. The revised tour helper now reads the add-row slot; our two requested tour tests pass against that fix.
- `build/results/tf02-rerun.xcresult`: **11/11 passed**, 0 failed/skipped (the full tour class plus the Ask AI gym test). The log contains `TEST EXECUTE SUCCEEDED`; author reports exit 0, with no separate rerun status file present. Both author xcresult inspection commands exited 0. The five initial failures are not reported as new unresolved product regressions.

Exact independent commands (runner `build/codex-tf02-run.py`, PID **90151**, completed):

```sh
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' -derivedDataPath build/dd-codex build

xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' -derivedDataPath build/dd-codex test -testPlan Unit -parallel-testing-enabled NO -resultBundlePath build/results/codex-tf02-unit.xcresult -collect-test-diagnostics never

xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' -derivedDataPath build/dd-codex test -testPlan Full -parallel-testing-enabled NO -resultBundlePath build/results/codex-tf02-ui.xcresult -collect-test-diagnostics never -only-testing:WorkoutTrackerUITests/TrainAddGymUITests -only-testing:WorkoutTrackerUITests/FloodlightTourUITests/testShowTourFromSettings -only-testing:WorkoutTrackerUITests/FloodlightTourUITests/testTheAppUnderTheTourIsInert
```

**Verified:** independent build, Unit **1291/1291**, requested serial UI **10/10**, all exit **0**; plan/whitespace checks; author results and real default/AccessibilityL captures inspected; successful persistence and normal Cancel paths covered.

**Not verified:** forced creation/selection-save failures (findings are static analysis and lack regression coverage); end-to-end app relaunch after creation (existing domain disk-reopen coverage instead); device-only behavior; dedicated last-gym-delete/new-add UI transition (source and existing archive/selection coverage inspected). No server checks were needed for this app-only change.

**Known flaky:** the author's Ask AI goal-entry wait failed in the broader parallel run and passed serially; exact timing cause was not independently established. No failures or flakes observed in this review's runs. The four original tour failures were stale test assumptions corrected before this review, not classified as flakes.

Verdict: changes requested
