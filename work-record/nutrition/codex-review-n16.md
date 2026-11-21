# N16 — independent Codex review, round 1

Reviewed 2026-11-20. Claude implemented; Codex reviewed. Product diff: `cb364043..8ea159dfb2e11ee16a6b6222dd9c6e21c9cff77a` on `ericlee4992/today-pick-day`. During review HEAD advanced to `3bf89cab70ec8225f44ea863cd1bae8f57963e5b`; that additional commit changes only `docs/STATE.md`, with no app/test changes. Only this report was edited by the reviewer.

## Findings

1. **P2 — Failed-scan recovery can log to an unrelated visit's day.** `WorkoutTracker/Features/Today/TodayView.swift:343–345` (consumers at `:117–120`, assignments at `:112–113`). The card's Retake and Manual Add closures present a flow without setting `logDay`. That value belongs to the most recent Log food/camera pill tap, not necessarily this scan or the day currently shown. Concrete sequence: select Tuesday, scan a photo that returns No food found; return to today, open and close Log food (sets `logDay = nil`); select Tuesday again and choose Manual Add on its failed card. The manual entry goes to today. Retake has the same stale value, and a later visit to another past day can instead send recovery to that unrelated day. The queue's ordinary Try again correctly retains `pickedDay`; these two recovery actions bypass it. **Fix:** explicitly snapshot the recovery destination from the failed scan's `pickedDay` before presenting either flow (and deliberately resolve the no-pick case), rather than inheriting the last visit's `logDay`. Add a regression covering a failed past-day scan, an intervening visit that changes `logDay`, and both recovery routes; assert only the intended day's totals change. This is a source-confirmed path; the existing six N16 UI tests do not exercise failed-scan recovery.

2. **P2 — A picked-day label scan still backdates creation and recency to the library photo.** `WorkoutTracker/Features/Food/Scan/FoodScanFlow.swift:1124–1125`, with the value supplied at `:1044` and the inaccurate contract at `:1057`. Pick Tuesday, import a label photo taken weeks earlier, and log it with Save to My foods enabled. `loggedAt` correctly becomes Tuesday's meal time, but `at: eatenAt` remains the photo's old date. `FoodScan.logLabel` passes that date to both `createFood` and `FoodLog.log`, so the entry's `createdAt` and the food's `createdAt`/`lastUsedAt` are weeks old. The newly logged food is pushed down or out of Recently logged. With Save to My foods off, the entry's `createdAt` is still backdated. D92 and the ticket explicitly require creation/recency to stay now. **Fix:** use a fresh current timestamp as `at:` and supply the eating timestamp separately as `loggedAt:` (picked-day meal time, otherwise the existing photo timestamp). Correct the comment and test the caller's old-library-photo case with saving both on and off. The new domain test passes `at: now` directly, so it cannot catch this incorrectly wired caller.

## Scope checked

- Read the brief, ticket/user decisions, repository guidance, nutrition specification, D70/D74/D77/D82/D83/D92, and the applicable SwiftUI/SwiftData review references.
- Traced food and meal +, selected food/meal, online results, Manual Add, Estimate, camera/library photo, label, barcode, Undo and failed-scan recovery. Fresh pill/camera visits explicitly replace `logDay`; changing the pick does not itself mutate an already-open visit's snapshot. Ordinary queue retry preserves its day.
- Reviewed the week window's lower/upper bounds, current-week caller in StartWorkoutView, prior-week counts, goal lookup, historical workout-only Burned, Up next suppression, Resume, scan visibility/removal, background reset, midnight/week rollover and Reduce Motion for the new selection/week transitions.
- Inspected HealthNutritionSync: desired writes fetch all food entries and use each entry's `loggedAt`; reconciliation handles edits/deletes. No device Health verification was performed.
- Inspected the real light Default and dark AccessibilityL contact sheets under `work-record/nutrition/captures/16/`. The day marks differ by shape, accessibility selection traits are supplied, rows wrap at AccessibilityL, and chevrons have 44-point targets. These captures cover This week and Last week, not every locale/date-range header or text size.
- Confirmed no model/schema/export format changes in the net diff. No migration or Gate S is needed for this change. README describes the intended feature and correctly says it is not yet in TestFlight; its all-paths implication remains subject to findings 1–2.

## Verification

Reviewer build/tests are on WT-Redesign-2 (`EB4328A1-87BD-4850-A3B2-A6E604701F1C`), Xcode 27.2, derived data `/tmp/wt-n16-codex`. Ran `scripts/prepare-test-simulator.sh` first. Source remained unchanged throughout the build/test sequence.

- `xcodebuild build-for-testing` — exit 0, `/tmp/n16-codex-build.log`.
- `git diff --check cb364043..HEAD` — exit 0.
- `python3 scripts/test-plans.py --check` — exit 0.
- `xcodebuild test-without-building -testPlan Unit -parallel-testing-enabled NO` — **1344/1344 passed, 0 failed, 0 skipped, exit 0**. `/tmp/n16-codex-unit.xcresult`, `/tmp/n16-codex-unit.log`; read the actual xcresult summary.
- Standalone Swift probe using the unchanged `TodayDayPick.swift` implementation — **6 assertions passed, exit 0**: Monday-first week start/movement, year rollover, spring and fall DST meal times, and a cross-year week title. Reproduction: `swift /tmp/n16-codex-calendar.swift`.
- `xcodebuild test-without-building -testPlan TodayTrain -only-testing:WorkoutTrackerUITests/TodayPickDayUITests -parallel-testing-enabled NO` — **6/6 passed, 0 failed, 0 skipped, exit 0**. `/tmp/n16-codex-ui.xcresult`, `/tmp/n16-codex-ui.log`; read the actual xcresult summary. Includes the real Default/AccessibilityL capture tests and the `todayWeek` swipe.

Author's evidence independently inspected with `xcresulttool get test-results summary`:

| Run | Passed / total | Failed / skipped | Result |
| --- | --- | --- | --- |
| `build/results/n16-unitplan.xcresult` | 1344 / 1344 | 0 / 0 | Passed |
| `build/results/n16-todaytrain.xcresult` | 86 / 86 | 0 / 0 | Passed |
| `build/results/n16-unit.xcresult` | 65 / 65 | 0 / 0 | Passed |
| `build/results/n16-ui.xcresult` | 6 / 6 | 0 / 0 | Passed |

`build/n16-exits.txt` records Unit and TodayTrain exit 0. Counts above are the xcresult summary's test counts; parameterized test executions can make per-device counts larger. No clearance is implied by the author's passing tests: neither finding's sequence is covered by the new tests.

Verified: reviewer build-for-testing exit 0; Unit 1344/1344, exit 0 (`/tmp/n16-codex-unit.xcresult`); TodayPickDayUITests 6/6, exit 0 (`/tmp/n16-codex-ui.xcresult`); calendar probe 6 assertions, exit 0; diff whitespace and test-plan checks exit 0. Author's completed Unit/TodayTrain/focused results inspected as above.

Not verified: on-device Health writes, physical camera/library integration, VoiceOver by a person, live signed-in network requests, real background-hour/midnight transitions, and runtime reproduction of the two source-confirmed findings. No app/test changes or phone/account/backup/deployment/desktop actions were made. Follow-up regression tests are required for both fixes; the current passing tests do not clear those paths.

Known flaky: none seen in the reviewer runs.

Verdict: not clear
