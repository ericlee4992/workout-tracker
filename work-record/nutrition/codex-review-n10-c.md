# N10 independent review — round 3

Reviewed by Codex on 2026-11-11. Clean checkout on `ericlee4992/nutrition-10-progress`, HEAD
`9aa3f48e8edff11e32c2d505a63824edfc87b3ff`; reviewed `01d6cd7..9aa3f48`. Read AGENTS, current STATE, the round-3 brief,
ticket's round-2 note and previous review, applying the established spec/decisions and SwiftUI/SwiftData/design guidance.
Separate standards and spec passes completed. Only this report changes the checkout. No commit, push, merge, deployment
or phone installation.

## Spec

No P1/P2/P3 findings. **R2-S1 is fixed.**

- `Domain/NutritionProgress.swift:52–57,121–125`: individual weigh-ins retain their persisted entry UUID in
  `WeightPoint.entryID`. Equal timestamps sort by UUID, making their order independent of query/input order. Daily
  averages and trend points retain their date-based identity.
- `Features/Progress/NutritionProgressReading.swift:40` passes that UUID into `ProgressReading.Point.key`.
  `ProgressPanel.swift:10–21` uses the explicit key when present, with a deterministic date-string fallback.
- `ProgressPanel.swift:379–383` preserves the key during the line chart's value/sign conversion. The Body weight
  detail's `ForEach` consumes the same identified reading points. The stored UUID remains independent of value and
  measurement-time edits; removing another entry does not alter it.
- Checked lift, cardio, training, nutrition food and weight-trend constructors and their consumers. None depends on
  the previous `Date` ID type. Their fallback remains date-derived; chart x-values still use `Date`. Pin serialization
  and SwiftData models are unchanged.
- `weighInsAtTheSameTimeKeepTheirOwnIdentity` passed in the fresh Unit run. It checks distinct IDs for app/Health
  entries sharing one timestamp, reversed input, a value edit, deletion, and the daily trend's aggregate fallback.
  Timestamp-edit stability and preservation through the private chart mapping were additionally source-checked.

The round-2 refresh advisory is addressed: `DayFoodView.swift:100–103` now includes `now` in the task key, so the
foreground, clock and time-zone updates supplied by `refreshingNow` can restart today's Health read. The `isToday`
guard still excludes past days. The existing current-day Health UI regression passed with and without a goal.

## Standards

No P1/P2/P3 findings or additional baseline-smell findings. Measurement identity now comes from the stored element,
as required by the SwiftUI data-flow guidance; it is not generated during rendering or derived from an editable field.

The new Body weight captures close the row-readability gap noted in round 2. Inspected the fresh light Default and
dark AccessibilityL renders, plus the author's `n10att4/bodyweight.png`: complete visible rows show the date, time,
weight and unit without truncation. AccessibilityL wraps the timestamp onto two lines. The captures have different
scroll offsets, so they establish readability of the rows rather than a matched whole-screen composition comparison.
Also inspected fresh lifting/cardio panels, the AccessibilityL cardio pace chart and the AccessibilityL training-volume
chart. No new visual defect was found in those captures.

## Verification

Xcode **27.2**, WT-iPhone27 **`47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`**, iOS **27.0**. Prepared the simulator first,
built fresh into `/tmp/codex-n10-r3/dd`, ran Unit serially, then the five requested UI classes with **two workers**.
App/test sources remained unchanged. Evidence root: **`/tmp/codex-n10-r3/`**; reproducible commands and process records:
`run.py`, `runner.pid`, `runner.log`, `tested-head.txt`, and `*.command.json`.

| Check | Result | Evidence under the root above |
|---|---|---|
| Simulator preparation | exit **0** | `prepare.log/.status` |
| Build-for-testing | exit **0** | `build.log/.status` |
| Unit plan | **1,273/1,273**, no failures/skips, exit **0** | `unit.xcresult`, `unit-summary.json`, `unit.log/.status` |
| Requested UI | **22/22**, no failures/skips, exit **0** | `ui.xcresult`, `ui-summary.json`, `ui-tests.json`, `ui.log/.status` |
| Test-plan consistency | exit **0** | `test-plans.log/.status` |
| Diff whitespace check | exit **0** | `diff-check.log/.status` |

UI breakdown: `AAAWarmUpUITests` **1/1**, `NutritionProgressUITests` **5/5**, `FloodlightProgressUITests` **10/10**,
`ProgressChartUITests` **2/2**, `ProgressChartTooltipUITests` **4/4**. No failures required a serial rerun. This includes
chart creation, options/reordering/removal/relaunch, training charts, empty progress, variation navigation, as-entered
tooltips, food-day editing/Undo, today's Health Burned and the expanded nutrition captures.

Exported captures and manifests are in `attachments/` (NutritionProgress) and `progress-attachments/` (FloodlightProgress).
The inspected Body weight pair is `attachments/D8017A4E-782E-4810-B1F6-D86C54A86F04.png` (light Default) and
`attachments/4BBAE513-96F7-42E5-A8AA-FB723459DCCE.png` (dark AccessibilityL). Additional inspected files are
`progress-attachments/5F5949CF-9E48-4F69-A8B4-8E0990D0594B.png`,
`progress-attachments/5E2A72C9-8A13-4B62-9A18-B7D71300D00D.png`, and
`progress-attachments/F1956015-A1D8-4672-9AD7-5FE3ED90BB5C.png`.

Directly inspected the author's supplied `n10r3-unit.xcresult` (**1,273 passed**) and `n10r3-ui.xcresult` (**22 passed**),
both with no failures/skips. Saved summaries as `author-n10r3-unit-summary.json` and `author-n10r3-ui-summary.json`.
The reviewer results above have independently captured shell exit codes; clearance does not rely on the author's summary.

Spec: **0 findings**. Standards: **0 findings**. R2-S1 and the refresh advisory are resolved.

Verified: fresh build exit **0**; Unit **1,273/1,273**, exit **0**, `/tmp/codex-n10-r3/unit.xcresult`; requested UI
**22/22**, exit **0**, `/tmp/codex-n10-r3/ui.xcresult`; consistency/diff checks exit **0**; fresh default/AccessibilityL
Body weight captures and selected adjacent Progress captures inspected.

Not verified: real HealthKit/device behavior; foreground/time-zone refresh with changing Health energy in a dedicated
runtime probe; same-timestamp row reconciliation via an additional UI edit/delete scenario (covered at the reading
level by the unit regression and source tracing); physical-device performance with large histories; human VoiceOver;
runtime Reduce Motion; the full UI suite. No phone installation.

Known flaky: none observed this round. The round-2 dark nutrition capture/navigation failure did not recur. The separate
TodayFood navigation flake recorded in round 2 is outside this round's requested UI scope; its prior evidence remains
in `codex-review-n10-b.md`.

Verdict: clear
