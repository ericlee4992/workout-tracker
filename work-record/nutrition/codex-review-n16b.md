# N16 — independent Codex review, round 2

Reviewed 2026-11-20. Claude implemented; Codex independently reviewed `8ea159df..9b87bc23de22d39c4120a5ae819f78b4e098fbaa` on `ericlee4992/today-pick-day`, following `codex-review-n16b-prompt.md` and the round-one rules. Only this report was edited by the reviewer.

## Findings and resolution of round one

No new actionable findings in the fix diff.

1. **Round-one P2 #1 resolved — failed-scan recovery uses the scan's day.** `WorkoutTracker/Features/Today/TodayView.swift:345–347`: both Retake and Manual Add set `logDay = scan.pickedDay` before dismissing the pending card and presenting the next flow. That explicitly replaces an intervening visit's stale day; nil also clears a previous past-day value for scans initiated without a pick. The queue's ordinary retry continues retaining its original `pickedDay`. The new `TodayPickDayUITests.testAFailedScansManualAddGoesToItsDay` reproduces the intervening Today → Log food visit, then verifies the manual entry lands on the scan's day and not today. Retake has the same corrected assignment; there is no dedicated UI regression that completes a retake after that intervening visit.

2. **Round-one P2 #2 resolved — label creation/recency are now independent of photo time.** `WorkoutTracker/Domain/TodayDayPick.swift:108–113` and `WorkoutTracker/Features/Food/Scan/FoodScanFlow.swift:1125–1127`: `labelTimes` supplies a single current timestamp for creation and a separate eating timestamp. The actual view caller passes these to `FoodScan.logLabel` as `at:` and `loggedAt:` respectively. Traced both save-to-My-foods branches: entry creation and new saved-food creation/recency receive now, while the entry's eating time receives the picked day's meal time. The new parameterized regression exercises Save to My foods on and off and verifies stored entry timestamps plus saved-food recency. It also asserts the no-pick timestamp pair.

The unpicked library-label correction does **not** require a new product decision: D83(9)'s observable eating date and meal rule stay intact. Correcting creation and recency metadata to now is consistent with their meaning and D92's separation of timestamps. It neither changes the stored format nor rewrites existing rows. The updated comment accurately describes the caller.

## Verification

Reviewer environment: WT-Redesign-2 (`EB4328A1-87BD-4850-A3B2-A6E604701F1C`), Xcode 27.2, derived data `/tmp/wt-n16-codex`. Ran `scripts/prepare-test-simulator.sh` first. Rebuilt the changed app/test source before any `test-without-building` run. No competing author build/test was running.

- `xcodebuild build-for-testing` — **exit 0**, `/tmp/n16b-codex-build.log`.
- Unit plan narrowed to `TodayDayPickTests`, `FoodScanTests`, and `FoodLogTests`, serial — **51/51 passed, 0 failed, 0 skipped, exit 0**, `/tmp/n16b-codex-unit.xcresult`, `/tmp/n16b-codex-unit.log`. Read the completed xcresult summary; the new parameterized test runs both save choices.
- Required UI classes `TodayPickDayUITests` (7) and `ScanFoodUITests` (15), TodayTrain plan with two parallel simulator workers — **22/22 passed, 0 failed, 0 skipped, exit 0**, `/tmp/n16b-codex-ui.xcresult`, `/tmp/n16b-codex-ui.log`. Independently reran both classes because the fixes change UI behavior/test code; read the completed xcresult summary. The new failed-scan Manual Add regression and the existing label-flow test passed.
- `git diff --check 8ea159df..HEAD` and `python3 scripts/test-plans.py --check` — **exit 0**.

Author's evidence independently inspected using `xcresulttool get test-results summary`:

| Result bundle | Passed / total | Failed / skipped | Result |
| --- | --- | --- | --- |
| `build/results/n16b-unit.xcresult` | 1345 / 1345 | 0 / 0 | Passed |
| `build/results/n16b-ui.xcresult` | 22 / 22 | 0 / 0 | Passed |

The author's corresponding logs end with `TEST SUCCEEDED`; the ticket records exit 0 for both. Reviewer runs above have independently observed process exit codes. Round-one broad review and verification remain applicable to the unchanged code; this round checks the fixes, their callers, and affected flows.

Verified: reviewer build-for-testing exit 0; affected unit suites 51/51, exit 0 (`/tmp/n16b-codex-unit.xcresult`); TodayPickDayUITests + ScanFoodUITests 22/22, exit 0 (`/tmp/n16b-codex-ui.xcresult`); diff whitespace and test-plan checks exit 0. Author's Unit 1345/1345 and UI 22/22 result bundles inspected. HEAD remained `9b87bc23de22d39c4120a5ae819f78b4e098fbaa` through completion.

Not verified: physical-device Health/camera/library behavior, live network requests, VoiceOver by a person, a real hour-away/midnight transition, and the dedicated Retake-after-intervening-visit UI sequence noted above. The old-library-label timestamp assertions run at the helper/domain boundary; its actual UI caller was inspected and the existing label UI flow was rerun. No model/schema change, migration, phone installation, account, backup, deployment, or desktop-control action was performed.

Known flaky: none seen in the reviewer runs; no rerun was needed.

Verdict: clear
