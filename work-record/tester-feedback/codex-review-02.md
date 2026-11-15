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


## Round 2

Reviewed `git diff 18207d90..fb5b1519` at `fb5b15197ddf722704395773a68c2b8be8b255b5`, branch `ericlee4992/add-gym-from-train`. Only this report changed during review; no implementation edits or commits.

### Standards

1. **R2-1, P2 — failed post-commit resolution silently skips the selection callback.** `WorkoutTracker/Features/Gyms/GymEditorSheet.swift:192–201`: after `GymCreation.create` has committed both the gym and `selectedGymID`, the main-context fetch is wrapped in `try?`. A fetch error or missing result skips `onSave` and still reaches `dismiss()`. Train's local `selectedGym` consequently stays on the previous gym while the persisted preference points to the new one; `restoreSelectedGym` has already run once and does not repair this on dismissal. The new comment explicitly permits this failure. This violates AGENTS' errors-as-absence rule and the displayed/remembered selection agreement the fix is intended to guarantee. **Fix:** retain the successfully committed ID and handle resolution/completion explicitly, surfacing and recovering a failed handoff without rerunning creation. A retry after commit must resolve the same ID, not insert another gym. Alternatively make the selection callback independent of this optional fetch while preserving reliable context-safe model access. Add a regression that commits successfully, fails resolution, then recovers, checking one gym, one committed selection and the final displayed pick. Static control-flow finding; no fetch fault was injected in this review.

The original failed-save cleanup is fixed: the helper disables autosave, writes gym and selection together, rolls back only its isolated context, and rethrows. The screen's save-error branch runs before any callback. No unrelated edits are rolled back. No additional standards findings.

### Spec and caller checks

The same R2-1 failure violates D89's selected-and-remembered promise; there are **no additional independent Spec findings**.

- `GymCreation` resolves the original transaction issues: a failing creation save leaves neither gym nor selection pending in the screen; a successful creation save stores both together. The second-save window is removed from Train's new-gym callback, which now only assigns its local selection after success.
- All GymEditorSheet callers checked: Train and Ask AI set `selectsCreated: true`; Gyms' add defaults to false; GymDetail's edit mode retains the existing update behavior. Ask AI still uses its existing `select → onSelectGym` callback; creation has already persisted the selection, so this does not independently reproduce the original two-save failure.
- Main-context visibility in the normal path is **observed**, not just inferred: the independent Train add test fetches/receives the new gym, displays it as selected, and checks Gyms' “Current” badge from AppPreferences. Empty-store creation also passes at default and AccessibilityL. No stale-main-context defect was observed in these successful flows.
- The four new helper tests assert meaningful persisted outcomes: one save with both gym data and selected ID, not-selecting preserving the old ID, failed save followed by another screen save leaving no gym, retry producing exactly one, and unrelated pending edits surviving failure. These address the prior failure scenarios at the helper boundary; old tests exercised only successful persistence and untouched Cancel. No mutation run against the old implementation was performed. The new tests read fresh contexts and do not cover the post-save fetch/callback failure in R2-1; UI results supply ordinary main-context refresh evidence.

Standards: **1 P2**. Spec: **the same P2**, no additional finding. One unique remaining issue.

### Verification

Xcode **27.2 (27B52)**; WT-Floodlight (`9E822EF6-DC67-4958-AEA2-D53D2D36D674`), iOS 27.0; own derived data `build/dd-codex`. Reviewer runs were serial and did not overlap.

| Check | Exit | Result / evidence |
|---|---:|---|
| `scripts/prepare-test-simulator.sh` | 0 | Ready/booted |
| `python3 scripts/test-plans.py --check` | 0 | Current mapping |
| `git diff --check 18207d90..fb5b1519` | 0 | Clean |
| Independent build | 0 | BUILD SUCCEEDED; `build/logs/codex-tf02-r2-build.log` |
| Independent Unit plan | 0 | **1295/1295**, 0 failed/skipped; `build/results/codex-tf02-r2-unit.xcresult` |
| Independent TrainAddGymUITests only | 0 | **8/8**, 0 failed/skipped; `build/results/codex-tf02-r2-ui.xcresult` |

Counts were read from actual xcresult summaries (`xcrun xcresulttool get test-results summary --path …`, inspection exit 0), and independent process exits from `build/logs/codex-tf02-r2-{build,unit,ui}.status`. Logs and saved summary JSONs are alongside those files.

Inspected, **not rerun**, the author's `build/results/tf02-r2-ui.xcresult`: **11/11 passed**, 0 failed/skipped (Train 8, TemplateMachines 2, Ask AI existing-gym/no-gym selection 1). Log contains TEST EXECUTE SUCCEEDED; author-reported exit 0, no separate exit-status file present. The author's full Unit result `build/results/tf02-r2-unitplan.xcresult` is also **1295/1295**, 0 failed/skipped. Both inspection commands exited 0. Ask AI's new-gym creation itself has no UI case, as the ticket acknowledges; its callback was traced statically. No other UI classes were run by this reviewer.

Exact independent commands (runner `build/codex-tf02-r2-run.py`, PID **99532**, completed):

```sh
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' -derivedDataPath build/dd-codex build

xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' -derivedDataPath build/dd-codex test -testPlan Unit -parallel-testing-enabled NO -resultBundlePath build/results/codex-tf02-r2-unit.xcresult -collect-test-diagnostics never

xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' -derivedDataPath build/dd-codex test -testPlan Full -parallel-testing-enabled NO -resultBundlePath build/results/codex-tf02-r2-ui.xcresult -collect-test-diagnostics never -only-testing:WorkoutTrackerUITests/TrainAddGymUITests
```

**Verified:** independent build, Unit **1295/1295**, Train UI **8/8**, all exit **0**; ordinary main-context gym/preference visibility; helper rollback/retry tests; other caller source and author UI artifacts inspected.

**Not verified:** forced post-commit fetch/resolution failure (R2-1); Ask AI's Add Gym path end-to-end; device-only behavior. No claim that successful tests cover these failure paths.

**Known flaky:** no failures or flakes observed this round. Round 1's author-side parallel goal-typing failure remains historical, with a passing serial rerun recorded above.

Verdict: changes requested


## Round 3

Reviewed `git diff fb5b1519..f3758033` at HEAD `f3758033c5345256dd9d84e7a699a05dc41a0b6f`, branch `ericlee4992/add-gym-from-train`. No implementation edits or commits. The explicitly accepted limitation after the Cancel button retries resolution and still fails is respected below.

### Standards

R2-1 is fixed for Add/retry: `GymCreation.resolve` throws for missing rows; `GymAddAttempt` records the ID after successful creation and before fallible resolution. Failed creation leaves it unset, while failed resolution retains it, so another Add resolves the same gym without another insert. The sheet displays the error, leaves Add available, locks saved fields, and calls `onSave`/dismisses only after resolution succeeds. Normal Cancel and editing an existing gym remain unchanged. No additional standards finding in that state transition.

### Spec

1. **R3-1, P2 — interactive dismissal bypasses the final recovery attempt.** `WorkoutTracker/Features/Gyms/GymEditorSheet.swift:84–86` leaves the sheet swipe-dismissable. The recovery retry exists only in `cancel()` at `:216–220`, invoked by the header button. After a committed save and failed resolution, dragging down closes the sheet without running that retry; neither Train nor Ask AI's presenting sheet supplies an equivalent dismissal callback. Train can therefore remain on its old selection even when the next resolution would succeed. The accepted residual is an explicit Cancel **after one final hand-back attempt**; this gesture bypasses that attempt. **Fix:** apply `.interactiveDismissDisabled(addAttempt.committedID != nil)` to the sheet content, retaining the explicit Cancel button as the accepted exit, or provide equivalent recovery on every dismissal path. A failure-state interaction check should establish that a swipe cannot bypass recovery. Static finding; the post-commit failure was not injected into the running sheet this round.

Apart from R3-1, the new regression tests address the prior finding: `aFailedHandBackRetriesTheSameGym` requires the initial error, a retained committed ID, exactly one create and gym, and a final returned gym matching persisted selection. It would fail a retry that recreates the row or ignores the resolution error. `resolvingAGymThatIsNotThereThrows` rejects treating absence as success. The existing transaction/failure/persistence tests remain relevant. All four GymEditorSheet caller intentions remain intact.

Standards: **0 new findings**; Spec: **1 P2 dismissal-path finding**. The user-accepted Cancel-button fallback itself is **not** a finding.

### Verification

Xcode **27.2 (27B52)**; WT-Floodlight (`9E822EF6-DC67-4958-AEA2-D53D2D36D674`), iOS 27.0. Independent derived data `build/dd-codex`; serial execution.

- `scripts/prepare-test-simulator.sh`: exit **0**, ready/booted.
- `git diff --check fb5b1519..f3758033`: exit **0**.
- Independent build: exit **0**, `BUILD SUCCEEDED`; `build/logs/codex-tf02-r3-build.log` and `.status`.
- Independent `GymCreationTests` + `GymSelectionTests`: **9/9 passed**, 0 failed/skipped, exit **0**; `build/results/codex-tf02-r3-unit.xcresult`. Actual summary inspected with `xcrun xcresulttool get test-results summary --path …` (exit **0**); log/status and summary JSON in `build/logs/codex-tf02-r3-unit.*`.
- Author artifacts inspected: `build/results/tf02-r3-unit.xcresult` **1297/1297**, and `build/results/tf02-r3-ui.xcresult` **10/10** (Train 8 + TemplateMachines 2), each 0 failed/skipped. Both summary-inspection commands exit **0**; corresponding logs contain successful test-execution markers. Author-reported process exits **0**; separate author status files are absent.
- **No UI tests rerun.** The inspected author UI covers unchanged normal entry/save/cancel flows. The new recovery logic is exercised in the independent unit suite; repeating the normal Train UI cases would not exercise the failed-resolution swipe escape in R3-1. Failure-state sheet appearance and dismissal were inspected statically, not claimed as runtime-verified.

Exact independent commands (runner `build/codex-tf02-r3-run.py`, PID **8026**, completed):

```sh
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' -derivedDataPath build/dd-codex build

xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' -derivedDataPath build/dd-codex test -testPlan Unit -parallel-testing-enabled NO -resultBundlePath build/results/codex-tf02-r3-unit.xcresult -collect-test-diagnostics never -only-testing:WorkoutTrackerTests/GymCreationTests -only-testing:WorkoutTrackerTests/GymSelectionTests
```

**Verified:** independent build and focused gym suites **9/9**, exit **0**; author full Unit **1297/1297** and UI **10/10** inspected; create-once/retry and missing-row behavior verified by the new unit tests.

**Not verified:** failure-state sheet controls/interactive dismissal at runtime (R3-1); no reviewer UI execution this round; Ask AI Add Gym/device-only behavior remain outside the current UI evidence. The explicitly accepted Cancel-after-retry residual remains documented in the ticket.

**Known flaky:** none observed this round. Earlier parallel goal-entry timing failure remains historical, with its successful serial rerun above.

Verdict: changes requested


## Round 4

Reviewed `git diff f3758033..9fd6b713` at HEAD `9fd6b713abe739d875703b0f4d90963f59f1affc`, branch `ericlee4992/add-gym-from-train`. Only this report changed during review; no implementation edits or commits.

### Standards

No remaining findings. The root `.interactiveDismissDisabled(addAttempt.committedID != nil)` prevents a swipe from bypassing recovery after a committed Add. It leaves ordinary add sheets, creation-save failures and existing-gym editing swipe-dismissable because their committed ID is nil. Explicit Add and Cancel still use their existing recovery paths and programmatic dismissal.

### Spec

**R3-1 resolved.** Add retries the same saved gym; Cancel makes its final resolution attempt before closing. The accepted residual if that explicit Cancel attempt also fails is preserved. All findings from rounds 1–3 are resolved. Standards: **0**; Spec: **0**.

### Verification

- Independent build, exit **0**, `BUILD SUCCEEDED`: `build/logs/codex-tf02-r4-build.log`; actual process exit in `build/logs/codex-tf02-r4-build.status`. Runner `build/codex-tf02-r4-build.py`, PID **11163**, completed. Own derived data `build/dd-codex`.
- `git diff --check f3758033..9fd6b713`: exit **0**.
- Inspected author `build/results/tf02-r4-ui.xcresult` with `xcrun xcresulttool get test-results summary --path …`: inspection exit **0**, **8/8 passed**, 0 failed/skipped. `build/logs/tf02-r4-ui.log` contains `TEST EXECUTE SUCCEEDED`; author reports process exit **0**, with no separate author status file present.
- No further Unit/UI runs, as requested for this one-line modifier. Round 3's independent gym suites **9/9** and inspected full Unit **1297/1297** remain applicable to unchanged domain code. The failure-state dismissal guard was verified in source, not through a forced UI fetch failure.

```sh
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' -derivedDataPath build/dd-codex build
```

**Verified:** independent build exit **0**; author Train UI **8/8** inspected; dismissal guard correctly depends on the saved-attempt state. All review findings resolved.

**Not verified:** failure-state swipe blocking at runtime; no new reviewer test execution this round; earlier device/Ask AI creation UI limitations remain. The explicitly accepted Cancel-after-final-retry fallback remains as documented in the ticket.

**Known flaky:** none observed this round; prior history remains above.

Verdict: clear
