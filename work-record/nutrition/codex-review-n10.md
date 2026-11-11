# N10 independent review — round 1

Reviewed by Codex on 2026-11-11. Checkout started clean on `ericlee4992/nutrition-10-progress`, HEAD `7e7dd0cb83b6e7444534cb2f4568571e67da4d16`; reviewed `54d5f80..7e7dd0c`. Read the brief, N10 ticket, relevant decisions, approved prototype files at `design/soft-approved-2026-11-07`, and applicable project/review/SwiftUI/SwiftData/design guidance. Separate standards and spec passes completed. Only this report changes the review checkout. Additional UI probes used an archived copy under `/tmp/codex-n10/navigation-probe`, with production app code unchanged and review-only test methods added there. No commit, push, deployment or phone installation.

## Spec

### S1 — P2: Today's food page drops Health's Burned total

`WorkoutTracker/Features/History/DayFoodView.swift:23–33`.

The page recognizes today for wording, but always passes the workout-only result of `FoodDayMath.day` to its fuel card. It neither reads nor refreshes `HealthSync`. With Read calories burned enabled, opening today's food through History or a nutrition chart can therefore show a different Burned value from Today. The ticket's workout-only exception applies to **past** days.

**Reproduced through the app UI:** using existing food/Health fixtures, Today displayed **412 cal Burned**; History → the same current day's food displayed **320**, while both displayed the same **1,065 cal eaten**. The serial diagnostic assertion failed specifically on `320 != 412`, not navigation. Evidence: `/tmp/codex-n10/health-page-ui.xcresult`, `health-page-ui-summary.json`, `health-page-ui.log/.status` (**exit 65**, warm-up passed and the consistency test failed), with both screenshots in `health-page-attachments/`. This uses the real production views/data flow with fake Health, not a physical HealthKit store.

**Fix:** when `isToday`, use the same Health refresh and `FoodDayMath.burned(workouts:health:)` rule as Today; preserve workout-only Burned for past days and leave the goal/remaining budget unchanged. Add a current-day navigation regression with Health enabled, including the goal and no-goal cases.

### S2 — P2: Weekly weight rate disappears across spring daylight saving time

`WorkoutTracker/Domain/NutritionProgress.swift:139–141`.

The points are calendar-day buckets, but `weeklyRate` divides elapsed seconds by 86,400 before checking for seven days. In New York, March 2–9, 2026 is seven calendar days but only 167 hours. A valid week's data therefore returns `nil` and the chart loses its weekly-rate caption. Fall's extra hour also slightly distorts the rate.

**Reproduced using the actual domain functions** with minimal data-structure stubs: seven spring-transition days return nil; the next ordinary seven-day interval returns −1.0. Seven fall-transition days produce −0.994083 rather than −1.0. Evidence: `/tmp/codex-n10/nutrition-math-probe.swift`, build/run logs/status (**exit 0**); fall outputs are also in the trend probe logs below. The existing November test's tolerance permits the smaller fall distortion and does not exercise the spring threshold.

**Fix:** use the calendar-day distance for both the minimum-span check and weekly-rate denominator. Add explicit spring/fall cases with points at local day starts.

### S3 — P3: “Each weigh-in” labels daily averages as individual measurements

`Domain/NutritionProgress.swift:34,109–114`; `Features/Progress/NutritionProgressReading.swift:23–25,41`; `Features/Progress/NutritionProgressView.swift:60–65`.

Two measurements on one day, 80 kg in the morning and 82 kg in the evening, become one **81 kg** point, headline and “Weigh-ins” row. Neither measurement was 81 kg, yet Add Chart says “Each weigh-in” and the single-state note says “One weigh-in.” The approved prototype uses that same individual-measurement wording.

Daily aggregation is intentional and tested, so averaging itself is not counted as wrong. The mismatch is how the result is described. The domain probe above confirms `[80, 82] → [81]`.

**Fix:** either show individual measurements for Body weight, or explicitly label its daily averages, including the detail list and single-point note. Retain the trend's documented aggregation and record any new wording in the ticket.

## Standards

### T1 — P3: Past-day protein copy still says “to go”

`WorkoutTracker/Features/Today/TodayFood.swift:35–37,125–137`.

`isToday` changes calories from “left” to “under,” but the protein caption ignores it. The fresh **Tuesday, Nov 10** capture, taken Nov 11, correctly shows “1,823 cal under” while still saying **“50 g to go.”** This is the same future-directed wording the new historical mode was intended to remove.

**Fix:** apply `isToday` to the protein deficit caption too, keeping today's wording and using retrospective wording such as “g under goal” for past days. Record the copy choice and capture an explicitly selected past day at default and AccessibilityL. Evidence: `/tmp/codex-n10/attachments/6E40FBFF-6F97-4AAE-8DFD-8E9E4E4E045C.png`. This is a copy inconsistency, not a nutrition-calculation defect.

No separate new standards defect is asserted. S1's inconsistent shared figure is also a standards concern and is counted once.

## Other assessment

- Food aggregation uses each day's dated goal; missing days remain blank and are excluded from averages. Macro shares use 4/4/9 and largest-remainder percentages sum to 100. Latest-goal chart lines and the absence of a weight-goal line follow the ticket's recorded choices; no target body weight exists in the model.
- History unions food-only and workout days, keeps workout ordering, and adjusts panel first/last boundaries correctly. The shared toast preserves Today's styling, identifiers, restore action and timeout behavior.
- An additional serial UI probe checked the potentially fragile chart route: one logged food → Calories chart → day page → delete its last entry → empty day/Undo → restored entry. It **passed**, including an actionable Undo after the chart's day row disappeared. Evidence: `navigation-ui.xcresult`, **2/2 including warm-up**, exit **0**. No navigation-loss finding is asserted.
- Nutrition pins keep the established `cardio.activity` string envelope with a supported metric placeholder. Older readers can decode the string and hide the unknown activity without dropping other pins; unknown future nutrition charts remain hidden. Pins stay outside SwiftData.
- `SegmentedPills(wraps: false)` preserves the prior row path, dimensions, colors and selection behavior; only Add Chart opts into wrapping. The fresh AccessibilityL Add Chart capture shows all four options readable in two rows. Other pill uses were source-compared, not individually recaptured.
- README documents the new functionality. Its existing History/Progress screenshots still accurately depict workout-only history and existing lift/cardio pins; optional nutrition imagery would showcase the feature, but omission is not a confirmed screenshot-rule violation.
- The fresh default day capture is a past day, while the AccessibilityL day capture selected today. The capture helper's visible-row indexing does not ensure a matched past-day pair. Add an explicit past-day capture while fixing T1; no separate layout defect is asserted from this coverage gap.
- `BarDomain` extends its last day by 86,400 seconds (`ProgressPanel.swift:429`), differing from calendar-day addition on DST transition dates. Calendar addition would be more consistent when addressing S2; no separate visible chart defect was established.

## Performance assessment

Food charts group qualifying entries once per reading, then iterate the bounded 7/30/90-day span; goal selection still scans goals per day. History groups food once, rather than rescanning all entries for every date. Full-entry queries and multiple pinned readings can repeat this work on re-render.

The weight trend is quadratic over all weigh-in days before the selected range is cut (`NutritionProgress.swift:119–124`, `NutritionProgressReading.swift:22–26`). An isolated Mac probe of the actual trend function, three iterations each, measured:

| Daily points | Debug | Optimized (`-O`) |
|---|---:|---:|
| 365 | 15.5–15.8 ms | 1.59–1.65 ms |
| 1,825 | 374–403 ms | 30.0–31.6 ms |

Checksums matched; all probe builds/runs exited **0**. Evidence: `/tmp/codex-n10/nutrition-trend-performance-probe.swift` and `nutrition-trend-{debug,optimized}` build/run logs/status files. A rolling window would avoid quadratic growth. This is a performance follow-up, not a demonstrated iPhone/UI regression: these measurements exclude SwiftData materialization and rendering, and do not establish device performance with large histories.

## Verification

Xcode **27.2**, **WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`**, iOS **27.0**. Prepared before runs; fresh `build-for-testing` into `/tmp/codex-n10/dd`, then unchanged binaries for the requested tests. Commands/process evidence: `run.py`, `runner.log`, `runner.pid`, `serial.py`, `serial-runner.log/.pid` in `/tmp/codex-n10/`. Progress reused the existing Orca tab.

- **Build:** exit **0**, `build.log/.status`.
- **Unit plan, serial:** **1,269/1,269 definitions / 1,289 successful executions**, **0 failures/skips**, exit **0**, `unit.xcresult`, `unit-summary.json`, `unit.log/.status`.
- **Requested UI, two workers:** **29/30 passed, 1 failed, 0 skipped**, exit **65**, `ui.xcresult`, `ui-summary.json`, `ui-tests.json`. Progress **10/10**, History **8/8**, TodayFood **7/7**, NutritionProgress **3/4**, warm-up **1/1**. `NutritionProgressUITests.testCaptureDarkAccessibility` failed at `:134`, waiting for the Weight trend page after its card tap; details in `ui-failure.json`.
- **Serial rerun, unchanged binaries:** entire NutritionProgress class plus warm-up **5/5 passed**, **0 failures/skips**, exit **0**, `ui-serial.xcresult`, `ui-serial-summary.json`, `ui-serial.log/.status`. Every originally requested UI case has passing evidence; the initial failure remains preserved.
- **Test-plan consistency:** `python3 scripts/test-plans.py --check` exit **0**, `test-plans.log/.status`. `git diff --check 54d5f80..7e7dd0c` passed.
- **Additional UI probes:** archived `7e7dd0c` under `navigation-probe/`; production app source was unchanged, with two review-only test methods added to that copy's `NutritionProgressUITests.swift`. The navigation probe built successfully and passed **2/2**, exit **0**. The Health consistency probe rebuilt successfully and completed **1 passed / 1 failed** (warm-up / the S1 consistency assertion), exit **65**. Scripts/logs/results are `navigation-run.py`, `navigation-runner.*`, `navigation-*.log/.status`, `navigation-ui.xcresult`, and corresponding `health-page-*` artifacts. The review branch itself remained untouched.
- **Captures:** inspected fresh default trend, AccessibilityL macro panel, default past-day food page, AccessibilityL Add Chart/day page, and both Health-consistency probe screens. Attachments/manifests are in `attachments/`, `serial-attachments/`, `failed-attachments/`, and `health-page-attachments/`. Existing numeric detail lists provide alternatives to hidden chart graphics; human VoiceOver was not tested.
- **Author bundles inspected directly:** `n10-unit` **1,269 definitions / 1,289 executions**, `n10ui` **5/5**, `n10-hp` **45/45**, `n10-today` **7/7**, all passed with no failures/skips. Saved their summaries as `author-*-summary.json`.

Verified: fresh build **exit 0**; Unit **1,269/1,269 definitions / 1,289 executions**, **exit 0**, `/tmp/codex-n10/unit.xcresult`; requested UI cases have passing evidence across `/tmp/codex-n10/ui.xcresult` and the **5/5**, **exit 0**, serial rerun; test-plan check **exit 0**; calendar/aggregation probes and inspected captures. S1 is additionally reproduced by a failing serial UI assertion (**320 vs 412**, exit **65**) in the archived-copy diagnostic bundle; the separate last-entry Undo probe passed.

Not verified: real HealthKit/device behavior, physical-iPhone performance with large datasets, human VoiceOver, runtime Reduce Motion, other pill users individually, a matched past-day default/AccessibilityL pair, or the full UI suite. The Health UI probe uses existing fake-Health launch flags; math/performance probes use minimal data stubs around the actual pure functions. No phone install, server call or key access occurred.

Known flaky: `NutritionProgressUITests.testCaptureDarkAccessibility` failed at the Weight trend navigation wait in parallel, then passed in the complete serial class rerun without changes. Its precise cause is not established; retain both bundles. The separate Health-consistency assertion is a reproduced product defect (S1), not classified as a flake.

Spec: **two P2 and one P3** (S1–S3). Standards: **one P3** (T1), with shared concerns counted once. Total: **two P2 and two P3**, no P1.

Verdict: not clear
