# C1 + N9b independent review — round 2

Reviewed by Codex on 2026-11-11 in the same reviewer session. Checkout started clean on `ericlee4992/c1-n9b`, HEAD `4605b1b604751c5d60c773fd3dafbabd47cd3158`; reviewed `09e471b..4605b1b`, the ticket's fix record, and affected callers. Project rules and previously loaded review/SwiftUI/SwiftData/design guidance remain unchanged. Separate standards and spec checks completed. Reviewer edits only this report; no commit, push, deployment, phone installation, live inference request or key access.

## Spec — remaining finding

### R2-S1 — P2: An older Burned reply can erase a newer refresh

`WorkoutTracker/Domain/HealthNutritionSync.swift:319–328`, particularly the cache replacement at **line 328**; callers at `:300` and `Features/Today/TodayView.swift:145`.

The new calendar provider correctly computes current day bounds, but the post-await check validates only the switch's generation. Two refreshes while Read calories burned remains on share that generation. Start a query in New York, change to Los Angeles and start a new query, then let the newer answer arrive first. It stores the correct new-day key. When the older answer arrives, `burned = [start: value]` replaces that cache with the obsolete New York key. `burned(on:)` now looks up Los Angeles midnight and returns nil, so Today falls back to workout calories even though the correct Health total was already received. Out-of-order replies within one day can also overwrite a newer total.

There can be overlapping callers: enabling the part starts a refresh independently of Today's `.task(id:)`. SwiftUI task cancellation is not sufficient protection for that other caller, and `refreshBurned` itself checks neither request ordering nor task cancellation. `RefreshingNow` updates on lifecycle/day/clock events rather than periodically, so the wrong fallback can persist until another event.

**Reproduced with the actual unmodified engine**, minimal domain stubs and a controllably suspending `HealthStoring`: New York query starts at 05:00Z, newer Los Angeles query at 08:00Z; the new reply sets Burned to **600**, then the old reply of **100** changes the current-day lookup to **nil**, leaving only the old key. Build/run **exit 0**. Evidence: `/tmp/codex-c1n9b-r2/health-burned-order-probe.swift`, `health-burned-order-probe-build.log/.status`, `health-burned-order-probe.log/.status`. This is a macOS engine reproduction, not real HealthKit or UI timing evidence. A second variant starts the older query through the actual `set(.readBurned, on: true)` path from disabled defaults, then issues the newer Today-style refresh; it reproduces the same 600 → nil result without cancelling either task. Evidence: `health-burned-set-probe.swift`, `health-burned-set-probe-build.log/.status`, `health-burned-set-probe.log/.status`, build/run **exit 0**, in the same directory. The finding therefore does not depend on assuming that HealthKit ignores SwiftUI task cancellation.

**Fix:** give refreshes their own request identity/sequence, validate cancellation and current day bounds before publishing, and prevent old responses from replacing newer results. Add out-of-order overlapping energy-query tests, including different day/zone keys and a newer result for the same key. The new timezone test makes sequential calls, and the fake's energy method returns immediately, so it does not cover this race.

## Round-1 disposition

| Finding | Disposition | Evidence |
|---|---|---|
| T1 — Health weight sent through Ask AI prefill | **Fixed** | The actual sheet calls `AIRoutineFlowModel.prefillMissingMeasurements(from:)`; it uses `NutritionGoalStore.latestEnteredWeight`, restricted to `.app`. Remaining `latestWeight` callers serve local calculations or prefill-presence checks. The test checks both model/request input and saved-profile values with a newer Health row and a Health-only store. Explicit export remains the approved exception. |
| S1 — toggle-off while a query is pending | **Fixed for the reported toggle cases** | Per-part generations are checked after queries, deletes, saves and Burned reads. Read rows are fetched after the query; ID write-back also fetches live entries again. A generation mismatch throws `CancellationError`, which requests another pass for other enabled parts without reporting a false sync failure. Tests turn reading and writing off during a query. R2-S1 concerns separate refresh requests sharing one unchanged toggle generation. |
| S2 — broad equality tolerance | **Fixed** | `same` now uses a tight `1e-9` relative numerical tolerance and a millisecond date tolerance. Tests exercise 0.1 kg, 0.2 lb and 0.5 kcal edits. A real `HKQuantity` conversion/archive probe supports the numerical tolerance; details below. |
| S3 — dirty work lost after three passes | **Fixed** | `sync` clears `syncing` and schedules another bounded batch when still dirty (`HealthNutritionSync.swift:353–357`). Tests cover a save during the last batch and the actual `ModelContext.didSave` observer, rather than only manually invoking sync. |
| S4 — versions/assumed saved UUIDs | **Fixed for the reported clock/ID issue** | Each replacement version exceeds Health's existing version even after clock rollback. The adapter reads version metadata, saves explicit per-write versions, then reconciliation queries the actual matching stored UUIDs. The fake now honors version ordering, and the rollback test verifies both the new version and stored sample ID. |
| S5 — launch-time calendar | **Sequential timezone change fixed; related race above** | The provider obtains the calendar at each use, and the test verifies new local query bounds. Overlapping replies can still discard the current-zone result (R2-S1). |
| S6 — name-only edits ignored | **Fixed** | The adapter reads food-name metadata and `same` compares it. The regression verifies renamed metadata without extra samples. |
| S7 — Health rows keep old display units | **Fixed** | Existing `.health` rows convert from their exact normalized kg when the preference changes; newly imported rows explicitly preserve Health's kg value. `.app` rows stay untouched. The regression checks the Health conversion, exact `normalizedKg`, and unchanged app-entered value/unit. |

## Standards and API assessment

No separate new standards finding. R2-S1 also concerns ownership of asynchronous results and is counted once.

The tiny HealthKit probe at `/tmp/codex-c1n9b-r2/quantity-roundtrip.swift` exercises kg↔lb, kcal↔joule and g↔kg conversions plus secure archive/decode for representative values, including lb-entered normalized weight and fractional calories. It passed with maximum observed relative conversion delta **0**, exit **0** (`quantity-roundtrip.log/.status`). It uses the real macOS HealthKit quantity APIs, not a numerical stand-in; it does **not** exercise a Health database save/read or prove database date precision.

The corrected plain-sample rationale is reasonable: correlations are acknowledged as supported, while separate quantities were chosen for independent type permissions and deletion of zero macros. No new consent/copy behavior was introduced. C1's reviewed wording changes remain unchanged.

Read-back returns only confirmed matching IDs. A post-save mismatch is not itself marked dirty (`reconcile:422–423`), so recovery from a concurrently rejected replacement may wait for another trigger. No real competing-writer/store-visibility case was reproduced here; this is a remaining integration test gap, not an additional counted defect or a claim that the clock fix failed.

## Verification

Prepared WT-iPhone27 **`47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`**, iOS **27.0**, then freshly built into `/tmp/codex-c1n9b-r2/dd` with Xcode **27.2 (27B52)**. Tests use those unchanged binaries. Runner commands/process evidence: `/tmp/codex-c1n9b-r2/run.py`, `runner.log`, `runner.pid`. Progress reused the existing Orca tab; no new terminal opened.

- **Build:** exit **0**, `build.log` / `build.status`.
- **Unit plan, serial:** **1,256/1,256 definitions, 1,276 successful executions, 0 failures, 0 skips**, exit **0**. `unit.xcresult`, `unit-summary.json`, `unit.log` / `.status`.
- **HealthNutritionSyncTests separately, serial ×10:** **24 definitions / 240 successful executions, 0 failures, 0 skips**, exit **0**. `health10.xcresult`, `health10-summary.json`, `health10.log` / `.status`.
- **UI first pass, two workers:** **19/20 passed, 1 failed, 0 skipped**, exit **65**. AppleHealth **4/4**, routine **14/15**, warm-up **1/1**. `ui.xcresult`, `ui-summary.json`, `ui.log` / `.status`. `FloodlightAIRoutineUITests.testBackKeepsInputsAndLeavingTheWeekAsksFirst` failed at initial **Train → Templates** navigation (`TabNavigation.swift:18`, called by `FloodlightAIRoutineUITests.swift:157,344`), before the changed Ask AI prefill path. Inspected the actual failure tree in `ui-failure.json`.
- **Serial rerun, unchanged binaries:** prepared the simulator again, then ran warm-up plus the entire routine class: **16/16 passed** (routine **15/15**, warm-up **1/1**), **0 failures, 0 skips**, exit **0**. `ui-serial.xcresult`, `ui-serial-summary.json`, `ui-serial.log` / `.status`; commands/PID in `serial.py`, `serial-runner.log`, `serial-runner.pid`. Every requested UI case has passing evidence; the initial failed bundle remains preserved.
- **Captures:** exported the fresh Apple Health PNGs and manifest to `/tmp/codex-c1n9b-r2/health-attachments/`; inspected light/default and dark/AccessibilityL scrolled refusal/footnote captures. They remain readable. The routine capture tests also completed in the serial rerun; no view layout was changed in this fix round.
- **Author evidence inspected directly:** `r2-health10` reports **24 definitions / 240 executions**, `r2-unit` **1,256 definitions / 1,276 executions**, and `r2-ui` **20/20**, all passed with no failures/skips. Summaries saved as `author-r2-*-summary.json`.
- **Consistency:** `git diff --check 09e471b..4605b1b` passed. HEAD and product/test source remained unchanged through both reviewer runs. The prior server/copy/test-plan mapping checks were not repeated because this diff does not change those areas.

Verified: fresh build **exit 0**; Unit **1,256/1,256 definitions / 1,276 executions**, **exit 0**, `/tmp/codex-c1n9b-r2/unit.xcresult`; isolated Health suite **240/240 executions**, **exit 0**, `/tmp/codex-c1n9b-r2/health10.xcresult`; AppleHealth **4/4** in `ui.xcresult`; routine **15/15** plus warm-up **1/1**, **exit 0**, `/tmp/codex-c1n9b-r2/ui-serial.xcresult`; inspected fresh captures, HKQuantity conversion/archive results and both Burned-order engine probes.

Not verified: real HealthKit authorization/denial, persistent-store quantity/date round trips, real replacement/deletion and competing-version behavior, physical-device query timing, phone installation, or live server requests. The Burned race was reproduced against the production engine with a controlled store, not through app UI or a real Health database. Full UI coverage, human VoiceOver and runtime Reduce Motion were not exercised. Earlier round-1 device/network limits remain applicable.

Known flaky: `FloodlightAIRoutineUITests.testBackKeepsInputsAndLeavingTheWeekAsksFirst` failed during initial Train navigation in parallel and passed in the complete serial class rerun without code/binary changes. Its precise cause is not established. Preserve `ui.xcresult`, `ui-failure.json` and `ui-serial.xcresult` with the UI reliability evidence. No other test failed this round.

Standards: **0 separate new findings**. Spec: **1 P2**, R2-S1; no new P1/P3. The prior fixes are supported by source and regression evidence, but the out-of-order Burned refresh must be resolved before clearance.

Verdict: not clear
