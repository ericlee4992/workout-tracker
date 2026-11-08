# S3 independent review — Round 2

Reviewed 2026-11-07 by Codex; implementation by Claude.

## Scope

Reviewed `git diff 3d059d8..1f887b7` on `ericlee4992/soft-03-workout`. HEAD is
`a3fa32d7efa23f3cc0781572f518f33faac159c0`; the only commit after the fix adds the Round 2 brief.
The fix changes only `WorkoutTrackerUITests/FloodlightFinishUITests.swift`; app and unit-test code are unchanged.
Read the full updated brief, current state, ticket, earlier report, and the corrected helper. Only this new report
was written in the repository during Round 2; the Round 1 report remains as requested. No commit or push.

## Standards

No new source findings. The helper retains its assertions for View in History, best count, best/previous values,
equipment/bar information, and exercise reachability. The four-swipe upper bound is preserved.

## Spec and closure

The accepted Round 1 failure was in the test: after checking View in History, it unconditionally swiped down four
times, even when no upward scroll had been needed. That could dismiss the finish sheet before checking its bests.
At `FloodlightFinishUITests.swift:50–54`, the fix counts actual upward swipes and reverses only that count. In the
zero-scroll case it now performs zero downward swipes. There are no product-behavior changes in this corrective
diff. All eight finish variants passed independently with the fix, including both previously failing cases.
The known failure is closed within the requested scope.

## Independent evidence

Xcode 27.2 (27B52), iOS 27.0 simulator WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`.
Round 2 logs/results: `/tmp/codex-s3/round2/`. Reused `/tmp/codex-s3/DerivedData`, rebuilding the changed test bundle.

- `build-for-testing`: **exit 0**, `TEST BUILD SUCCEEDED`; xcresult status `succeeded`, **0 errors, 0 warnings**
  in this incremental build. Evidence: `build.log`, `build.xcresult`, `build-summary.json`.
- Serial UI run: **exit 0**, `TEST EXECUTE SUCCEEDED`; **9 passed, 0 failed, 0 skipped** — the requested
  `CardioUITests/testSavedDistanceEditorKeepsEnteredUnitsAndUntouchedMeasurements` warm-up **1/1**, followed by
  `FloodlightFinishUITests` **8/8**, with `-parallel-testing-enabled NO -collect-test-diagnostics never`.
  Evidence: `ui.log`, `ui.xcresult`, `ui-legacy.json`. No retry was needed for this fixed-code run. The modern
  `xcresulttool get test-results summary` hit an XCResultDataViews database error; `get object --legacy` succeeded
  and directly confirmed 9 tests, 0 failures, 0 skips, action status `succeeded`, and no failure summaries.
- Exported and inspected the fresh light/dark, default/AccessibilityL finish captures. The receipt's paired
  exercise/set, calorie and heart-rate figures fit; the bests → receipt → actions order and subsequent exercise
  section are visible across the captures. Best-count, previous-best and bar-weight spoken-label assertions pass.
  The AX bar-best screenshots are scrolled far enough that the top of that best row is partly under the navigation
  bar; they are not evidence of the entire row being visible simultaneously. No new product-layout defect was
  established by that capture position. Evidence: `captures/manifest.json`, original PNGs, inspected contact
  sheets `captures/review-light.png` and `captures/review-dark.png`.
- `git diff --check 3d059d8..1f887b7`: **exit 0**.

For clarity, the interrupted Round 1 report's UI checkpoint is stale: its requested run actually finished with
**exit 65, 9 passed, 2 failed, 0 skipped** (`/tmp/codex-s3/ui.xcresult`). The failures were
`testCaptureBarBestLightDefault` and `testCaptureReceiptDarkAccessibility`, both reporting zero best elements.
Both TemplateDetail tests and the cardio warm-up passed. The independent Round 1 build passed (exit 0), and the
seven due-next/comparison unit tests passed (exit 0, no failures/skips). Those unchanged-code results remain valid;
they were not rerun in this test-only correction. No frame decoding was resumed after the user's interruption.

The full combined Phase 1 capture/core-flow run remains deferred. This is targeted S3 re-review, not a device
installation or full release acceptance; actual VoiceOver traversal and hardware behavior are not claimed.

Standards: **0 new findings**. Spec: **0 new findings**. The Round 1 scrolling failure is closed; the deferred
combined Phase 1 verification remains a separate merge gate.

Verdict: clear
