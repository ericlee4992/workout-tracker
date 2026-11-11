# N10 independent review — round 2

Reviewed by Codex on 2026-11-11, branch `ericlee4992/nutrition-10-progress`. The checkout started clean at
`c29ceb8d3a7d2cb8c73ecec64e02af53284c86d4`; during startup HEAD advanced to
`01d6cd75c500ff934c108f631bf5dc442b759d41`. Verified that the latter changes only `docs/STATE.md` (the round-2 handoff):
app and test sources are identical to `c29ceb8`. Reviewed `7e7dd0c..HEAD`, both review briefs, the round-1 report,
N10 ticket/spec, relevant decisions and project/SwiftUI/SwiftData/design guidance. Separate standards and spec passes
completed. Only this report changes the checkout; no commit, push, merge, server action or phone installation.

## Spec

### R2-S1 — P2: Individual weigh-ins have colliding chart and row identities

`WorkoutTracker/Domain/NutritionProgress.swift:119–120`; propagated by
`WorkoutTracker/Features/Progress/NutritionProgressReading.swift:40`.

The ticket's S3 fix promises “Body weight now plots each weigh-in as measured.” The new `weighIns` preserves individual
values but discards `BodyWeightEntry.id`. `ProgressReading.Point.id` is still its `date`
(`Features/Progress/ProgressPanel.swift:11`), used by both the detail's `ForEach`
(`NutritionProgressView.swift:61`) and the line chart (`ProgressPanel.swift:378–382`). The former daily aggregation
made those dates unique; individual measurements do not have that guarantee.

**Failure scenario:** two distinct Health samples, or a manual and imported measurement, share `measuredAt`. This is
valid input: `BodyWeightLog.log` inserts without timestamp deduplication, and `HealthSyncPlan.mirror`
(`HealthNutritionSync.swift:190–196`) distinguishes samples by UUID. The two measurements now share one SwiftUI ID,
so their rows/chart marks cannot be reliably reconciled when a measurement changes or disappears. The new test covers
two different times on one day, which does not exercise this collision.

**Evidence:** `/tmp/codex-n10-r2/identity-probe.swift` copies the production `weighIns` and `ProgressReading.Point`
declarations verbatim, with minimal model stubs and the production reading's mapping in kg. It prints two distinct
input UUIDs, values `[80.0, 82.0]`, **2 points / 1 unique ID**; exit **0**, `identity-probe.log/.status`. Reversing the
same-time inputs also changes the selected latest value (82 → 80). This establishes the identity collision; it is not
a claim that disappearing rows were reproduced in a running UI.

**Fix:** carry the persisted measurement UUID through raw-weight points, the reading and the chart's sign-conversion
mapping; retain date-based keys for aggregated daily series. Use a deterministic tie-break for equal timestamps.
Add a regression with distinct entries at the identical timestamp, verifying distinct stable IDs and preservation
when one entry is edited or deleted. Do not generate fresh UUIDs while rendering.

## Standards

The same R2-S1 issue violates `swiftui-pro/references/data.md`: mutable collection identity must come from the element,
not an editable field. Both independent passes found it; it is counted once. No additional confirmed standards
violation or baseline-smell finding is asserted.

## Round-1 fixes and remaining observations

- **S1, initial Health display:** fixed. Today's day page reads `HealthSync.burned(on:)`, uses the same
  `FoodDayMath.burned` selection as Today, and refreshes on appearing/read-setting changes. Past days remain workout-only;
  the goal and remaining budget are unchanged. The new UI regression passed for both goal and no-goal cases (412 on
  Today and on today's day page).
- **Refresh limitation — advisory, not a second finding:** `DayFoodView.swift:100` keys its task only by
  `[isToday, readBurned]`. Same-day foreground/clock/time-zone updates to `now` do not change this key, unlike Today's
  `BurnedRefresh(now:on)`. `HealthSync.sync()` itself does not refresh active energy. A retained Today tab may refresh
  the shared cache, so stale visible Burned was not established. Prefer including `now` in this page's refresh key;
  a foreground/time-zone UI regression with changing fake energy would settle the lifecycle behavior.
- **S2:** fixed. `days`, `weeklyRate` and `change` count calendar days; the new spring/fall New York assertions passed.
  `BarDomain` now extends its last day by calendar addition, rather than 86,400 seconds. Its endpoint was source-checked;
  no DST-specific chart screenshot was taken.
- **S3:** the original daily-average-as-individual-measurement mismatch is corrected for distinct timestamps. Body weight
  uses raw weigh-ins and shows times; Weight trend retains daily averaging. R2-S1 prevents full clearance of the change.
- **T1:** fixed. Both fresh captures select Tuesday, Nov 10 and show “50 g under goal,” with the same fuel figures at
  light Default and dark AccessibilityL. Today's “to go” wording remains. Also inspected the author's `n10att3/day.png`.
- **Performance note:** the trend now advances a sliding window over sorted daily points. Its actual caller supplies
  sorted `dailyWeights`; the new equivalence test passed. The trend stage is linear; no physical-device benchmark was run.
- **Capture gap:** the capture tests open Weight trend, not Body weight. The newly timestamped Body weight detail rows
  have no fresh default/AccessibilityL capture in this run. Check those rows when fixing R2-S1; no clipping finding is
  asserted without a render demonstrating it.

## Verification

Xcode **27.2**, WT-iPhone27 **`47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`**, iOS **27.0**. Ran the preparation script first,
then a fresh build-for-testing into `/tmp/codex-n10-r2/dd`. Unit and UI runs were sequential; UI used two workers,
followed by a serial failure rerun with unchanged binaries. Commands, process identities, tested HEAD and logs are
in `/tmp/codex-n10-r2/` (`run.py`, `runner.pid/.log`, `serial.py`, `serial-runner.pid/.log`, `*.command.json`).

- **Build:** exit **0**, `build.log/.status`.
- **Unit plan:** **1,272/1,272**, **0 failures/skips**, exit **0**; `unit.xcresult`, `unit-summary.json`, `unit.log/.status`.
  Includes the 15-test `NutritionProgressTests` suite and the new DST, individual-measurement and sliding-window cases.
- **Requested UI:** warm-up + `NutritionProgressUITests` + `TodayFoodUITests`: **11/13 passed**, **2 failures**,
  **0 skipped**, exit **65**; `ui.xcresult`, `ui-summary.json`, `ui-tests.json`, `ui.log/.status`.
  NutritionProgress **4/5**, TodayFood **6/7**, warm-up **1/1**.
- **Serial rerun:** both failed methods plus warm-up **3/3 passed**, **0 failures/skips**, exit **0**;
  `ui-serial.xcresult`, `ui-serial-summary.json`, `ui-serial.log/.status`. Every requested UI case has passing evidence;
  the initial failures remain preserved.
- **Failure details:** `NutritionProgressUITests.testCaptureDarkAccessibility` at `:151`, waiting for the Weight trend
  navigation bar after tapping its panel (same symptom as round 1); `TodayFoodUITests.testALogFromLogFoodReachesTodayAndSetGoalsOpensTheGoals`
  at `:152`, waiting for `logFoodAdd.Greek yogurt` after tapping Log food. Details: `ui-failure-nutrition.json` and
  `ui-failure-today.json`. Neither reproduced in the unchanged serial rerun; their precise causes are not established.
- **Captures:** exported NutritionProgress attachments to `attachments/` and `serial-attachments/` with manifests.
  Inspected fresh default/AccessibilityL past-day fuel cards and Weight trend pages. The past-day pair is
  `attachments/23580123-7162-452E-B685-5FDA21922CD0.png` and
  `serial-attachments/A972D63E-8C89-4CE9-9E62-F503BCD82488.png`.
- **Other checks:** test-plan consistency and `git diff --check 7e7dd0c..c29ceb8` exit **0** (`test-plans.*`, `diff-check.*`).
  Identity probe exit **0**, as described above.
- **Author evidence:** directly inspected `n10r2-unit.xcresult` (**1,272 passed**, no failures/skips) and
  `n10r2-ui.xcresult` (**13 passed**, no failures/skips) at the supplied scratchpad path. Saved summaries as
  `author-n10r2-unit-summary.json` and `author-n10r2-ui-summary.json`. No matching author `.status` files were found;
  their shell exit codes were not independently established. Reviewer runs above have captured exit codes.

Spec: **one P2**. Standards: the **same P2**, no additional findings. **One unique finding; no P1/P3.**

Verified: fresh build exit **0**; Unit **1,272/1,272**, exit **0**, `/tmp/codex-n10-r2/unit.xcresult`; all **13 requested UI
cases** have passing evidence across `ui.xcresult` (**11/13**, exit **65**) and `ui-serial.xcresult` (**3/3 including
warm-up**, exit **0**); test-plan/diff checks exit **0**; identity collision probe exit **0**; inspected paired captures.

Not verified: duplicate-ID visual reconciliation at runtime; same-day foreground/time-zone Health refresh behavior;
new Body weight timestamp rows at AccessibilityL; real HealthKit/device behavior; device performance with large histories;
human VoiceOver; runtime Reduce Motion; DST-specific chart rendering; the full UI suite. No phone install.

Known flaky: NutritionProgress dark AccessibilityL capture (Weight trend navigation wait, also observed in round 1)
and TodayFood log/navigation test (Greek yogurt wait) failed in parallel and passed serially unchanged. Preserve both
bundles; follow-up context is N10's review record. The confirmed identity collision is independent of these UI failures.

Verdict: not clear
