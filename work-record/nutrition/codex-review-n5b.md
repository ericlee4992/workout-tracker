# N5 independent review — round 2

Reviewed by Codex on 2026-11-10. Branch `ericlee4992/nutrition-05-today`, HEAD `e3834686d9ccc81e123fb6da11d284f94673f866`; diff `f39e6e0..e383468`. Scope: the round-1 Burned finding, measured-workout fixture and changed TodayFoodUITests. Separate standards and spec source passes completed. Clean working tree at review start; only this report was written. No commit, push, merge or device install.

## Spec

**Clear — no remaining P1/P2/P3 findings.**

The round-1 P2 is resolved at `WorkoutTracker/Features/Today/TodayFood.swift:90–110`: Burned now appears beside Eaten without a nutrition goal, stacks below it at accessibility sizes, and retains Set your goals. It uses the same `day.burned` statistic as the goal-present layout. Goal, left/over and food calculations are unchanged.

`TodayFoodUITests.testBurnedShowsWithAndWithoutAGoalAndIsNeverAdded` checks the fixture's 320 burned calories in both states and verifies `left + eaten = goal`. This covers the original failure scenario and D71's fixed-budget rule. The no-goal AccessibilityL capture omitted in round 1 is now included.

## Standards

**Clear — no findings.**

The layout uses existing type/color tokens and preserves separate accessibility identifiers for Eaten, Burned and Set your goals. No new animation or persistence/schema behavior is introduced. The measured workout is seeded only through the existing diary fixture gate, which requires the food-sample flag and `-uiTestReset`.

Opened the author's no-goal light/default and dark/AccessibilityL captures in `n5shots3/`: both figures and the invitation are readable; Eaten remains the dominant figure. Also opened the fresh reviewer no-goal light/default and dark/AccessibilityL captures exported to `/tmp/codex-n5/round2/attachments/` (see `manifest.json`): Burned 320, Eaten and the invitation are visible and readable in both. This closes the prior visual-evidence gap.

## Verification

Xcode **27.2 (27B52)**; WT-iPhone27 **47D21838-69A6-4BCB-AE90-B0D9C0AAA70B**, iOS 27.0. Ran `scripts/prepare-test-simulator.sh`, freshly rebuilt into the existing `/tmp/codex-n4/dd` cache, and tested unchanged binaries. Round-2 artifacts: `/tmp/codex-n5/round2/`.

- Build: exit **0**, `build.log` / `build.status`.
- Unit plan, serial: exit **0**, **1,206/1,206 test definitions passed; 1,222 successful executions** including parameterized cases, **0 failures, 0 skips**. `unit.xcresult`, `unit-summary.json`, `unit.log`, `unit.status`. Includes FoodDayTests and the related nutrition suites.
- UI first pass, TodayFoodUITests + warm-up, two workers: **7/8 passed, 1 failed, 0 skips**, exit **65**, `ui.xcresult`, `ui-summary.json`, `ui.log`, `ui.status`. The new Burned regression and all captures/edit/delete cases passed. The existing `testALogFromLogFoodReachesTodayAndSetGoalsOpensTheGoals` failed waiting for the Greek yogurt button after tapping Log food (`TodayFoodUITests.swift:152`); details in `ui-failure.json`.
- Reprepared WT-iPhone27 and reran the same classes serially, unchanged binaries: **8/8 passed** (TodayFoodUITests **7/7**, warm-up **1/1**), **0 failures, 0 skips**, exit **0**. `ui-serial.xcresult`, `ui-serial-summary.json`, `ui-serial.log`, `ui-serial.status`. The parallel failure did not recur. The original run remains recorded as failed.
- `python3 scripts/test-plans.py --check`: exit **0**.
- Author's `n5ui3.xcresult` inspected directly: **7/7 passed**, no failures/skips. This supplements the reviewer's rerun.

Verified: fresh build **exit 0**; Unit **1,206 definitions / 1,222 successful executions**, **exit 0**, `/tmp/codex-n5/round2/unit.xcresult`; TodayFoodUITests **7/7** plus warm-up **1/1**, **exit 0**, `/tmp/codex-n5/round2/ui-serial.xcresult`; test-plan consistency **exit 0**; supplied and fresh no-goal default/AccessibilityL captures inspected. The D71 finding and the missing no-goal AXL evidence are resolved.

Not verified: runtime Reduce Motion, VoiceOver by a person, every appearance/size combination, non-US locale, long-history performance, real CloudKit/Health synchronization, device install or full UI suite. The round-1 adjacent UI classes were not repeated because the user narrowed this UI re-review to TodayFoodUITests; their passing serial evidence remains in `codex-review-n5.md`.

Known flaky: the existing log-to-Today/goals navigation test failed in parallel and passed in the full serial class rerun without code changes. Its precise cause was not established; preserve both bundles and track it with the ticket’s existing UI reliability notes. No other failure or simulator connection error occurred in this round.

Review totals: **Standards 0; Spec 0 findings.**

Verdict: clear
