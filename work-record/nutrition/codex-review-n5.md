# N5 independent review — round 1

Codex review, 2026-11-10. Branch `ericlee4992/nutrition-05-today`, HEAD `f39e6e0603a9ba0b6633d5049668d87c7d853a6a`; reviewed `git diff c03bd12..f39e6e0`. Clean checkout at review start. Read the N5 brief/ticket, nutrition spec, D67/D68/D70/D71 and the approved prototype at `design/soft-approved-2026-11-07`. Separate standards and spec source passes were completed. The reviewer ran the build/tests and inspected actual result bundles. Only this report was changed; no commit, push, merge or device install.

## Spec

### P2 — Burned disappears for users without a nutrition goal

`WorkoutTracker/Features/Today/TodayFood.swift:88–101` (`TodayFuelCard.noGoal`).

D71 requires: “Today shows Burned beside Eaten; the goal and ‘left’ stay fixed.” A user who has not configured nutrition goals can finish a measured workout with, for example, 320 active calories. `FoodDayMath.day` calculates `day.burned`, but this layout renders only calories eaten and Set your goals. The measured Burned total is entirely absent. The no-goal requirement removes budget/remaining figures, not workout energy; the ticket's recorded choices do not waive D71.

**Fix:** show Burned beside or below Eaten in the no-goal layout, retaining Set your goals and omitting goal/left figures. Add a no-goal UI case with a measured workout and assert its Burned value. Capture that fixed state at default and AccessibilityL. Both the supplied and freshly generated no-goal screenshots confirm the missing field; the exact 320-calorie scenario follows directly from the unconditional omission in this branch, rather than from an added reviewer UI test.

No other confirmed spec finding. The trained/no-food dashed ring matches the approved prototype: calories determine the ring, training determines the inner mark. No-goal full rings and daily Burned = 0 when nothing was measured are explicit ticket decisions made under the overnight mandate, not additional findings.

## Standards

No separate P1/P2/P3 source finding.

- Domain totals scale per-serving nutrition by servings. Goals are selected with the existing calendar-aware end-of-day rule; a new goal does not apply before its effective local day. Left, over and ring fill exclude Burned. Macro shares use 4/4/9; calories-only data uses the neutral fill. Workout energy prefers the workout total and otherwise sums known cardio segments, preserving nil when no segment has a measurement.
- `DeletedEntry` copies every current FoodEntry field. Restore preserves id, timestamps, source, Health sample id and the saved-food link only while its model is live. Editing uses `EditableNumber` for untouched precision; saved-food nutrition is not changed. The sheet's rendered body uses copied title/serving data; no deleted-model crash was demonstrated in the reviewed flow. The delete toast returns on cancellation and checks its receipt identity before clearing.
- Today groups entries by meal with stable timestamp/creation/id ordering. Its clock refresh and calendar helpers cover local-day changes in source. Future days are excluded before `daysLogged` is called. Set your goals reaches NutritionGoalsView; that screen exposes Personal details when inputs are missing.
- New explicit fuel-bar and delete-toast motion is gated by Reduce Motion. Entry stepper actions introduce no explicit animation. Existing Today title motion was not introduced by N5.
- Diary seeding requires the food-sample flag plus `-uiTestReset`; the over-goal flag only acts within that guarded fixture. Goal back-dating is confined to the fixture invocation.
- README describes the new behavior and unreleased status. No existing gallery image depicts Today, so there is no demonstrated stale Today image in the README.

## Visual and coverage limits

Inspected the supplied `n5shots/N5-light.png` and `N5-dark.png` boards: fuel card, week rows, meal rows, edit sheet and over-goal layouts are readable in the shown default/AccessibilityL states. The no-goal state is captured only at light/default: `TodayFoodUITests.swift:69–80` never captures no-goal AccessibilityL. Complete that evidence with the Burned fix; full visual acceptance is not established for the missing state. The current tests likewise do not exercise every appearance × size combination. Exported fresh reviewer captures to `/tmp/codex-n5/attachments/` with `manifest.json`; opened the no-goal light/default, dark/AXL fuel card and dark/AXL edit-sheet captures. They corroborate the supplied boards and the Burned omission.

Today queries all food entries and scans them for each displayed day. That cost grows with history, but this review has no long-history performance measurement showing a regression. Treat date-bounded querying/grouping as a follow-up optimization, not a demonstrated blocker.

## Verification

Xcode **27.2 (27B52)**; WT-iPhone27 **47D21838-69A6-4BCB-AE90-B0D9C0AAA70B**, iOS 27.0. Prepared the simulator with `scripts/prepare-test-simulator.sh`; freshly rebuilt app and test bundles in the existing `/tmp/codex-n4/dd` cache. N5 logs/status/result artifacts are under `/tmp/codex-n5/`. Unit serial; named UI classes with two workers.

- Build: exit **0**, `build.log` / `build.status`.
- Unit plan: exit **0**, **1,206/1,206 definitions passed; 1,222 successful executions** including parameterized cases, **0 failures and 0 skips**. `unit.xcresult`, `unit-summary.json`, `unit.log`, `unit.status`.
- UI first pass, five named classes selected from Full (not the full suite): **26/30 passed, 4 failed, 0 skipped**, exit **65**, `ui.xcresult`, `ui-summary.json`, `ui.log`, `ui.status`. `TodayFoodUITests` **6/6**, `TodayUpNextUITests` **9/9**, warm-up **1/1** passed. Food flows were **3/5** and nutrition goals **7/9**.
- Parallel failures: `LogFoodFlowUITests.testAddFoodMakesOneOfMyFoodsAndTheBookmarkSavesIt` (waiting for the meal chip at line 21); `testManualAddLogsCaloriesAloneAndAMealIsCreatedLoggedAndDeleted` (“2 servings,” line 148); `NutritionGoalsUITests.testClearingTheBirthDateInTheZonesSheetLeavesNothingToEdit` (Personal details summary, line 122); `testPersonalDetailsMakeAGoalAndATypedNumberStaysUntilRecalculate` (Save enabled, line 36). Detailed records: `failure-1.json` through `failure-4.json`.
- Initial serial attempt: exit **65**, `ui-serial.xcresult`; no test methods ran. The result contains one runner-error record: **Invalid connectionUUID specified** while preparing WT-iPhone27. The simulator was found shut down; reran `scripts/prepare-test-simulator.sh`, which booted it successfully.
- Serial retry with unchanged binaries: warm-up + entire LogFoodFlowUITests + entire NutritionGoalsUITests, **15/15 passed, 0 failures, 0 skips**, exit **0**, `ui-serial2.xcresult`, `ui-serial2-summary.json`, `ui-serial2.log`, `ui-serial2.status`. All four parallel failures passed. Every one of the 30 requested UI cases has passing evidence; the original parallel run is still a failed run.
- Test-plan consistency: `python3 scripts/test-plans.py --check`, exit **0**.
- Author bundles inspected directly: `n5u.xcresult` **6 tests / 60 executions** passed; `n5ui.xcresult` **6/6**; `n5unit.xcresult` **1,206 definitions / 1,222 executions**, no failures; `n5reg.xcresult` **23/24** with one failure; `n5reg2.xcresult` **5/5** for the subsequent food-flow rerun. These corroborate the ticket and do not replace reviewer verification.

Verified: fresh build **exit 0**; Unit **1,206 definitions / 1,222 successful executions**, **exit 0**, `/tmp/codex-n5/unit.xcresult`; new Today food flows/captures **6/6** and Today up-next **9/9** in `/tmp/codex-n5/ui.xcresult`; serial food/goals/warm-up **15/15**, **exit 0**, `/tmp/codex-n5/ui-serial2.xcresult`; test-plan consistency **exit 0**; supplied and fresh captures inspected as described above.

Not verified: no-goal AccessibilityL; every appearance/size combination; runtime Reduce Motion; VoiceOver by a person; long-history performance; real CloudKit/Health synchronization; device migration/install; full UI suite. Specific new unit coverage is limited: cardio fallback/known zero, a non-current time zone/DST boundary in FoodDay, and restore after deleting the linked food are primarily source-inspected here, not individually exercised by new N5 tests. Existing NutritionModel/goal-store/calendar tests provide related coverage. No speculative deleted-sheet failure is counted as a finding.

Known flaky: the four named parallel failures did not reproduce in the complete serial class rerun; their precise causes were not established. The two food-flow failures were also observed in earlier N4/N5 evidence. Preserve both runs and track them in the ticket rather than attributing them to N5 product code. Separately, the first serial attempt hit the simulator connection error above; boot preparation resolved it.

Review totals: **Spec 1 P2; Standards 0 findings.** N5 needs the no-goal Burned fix and its verification before independent clearance.

Verdict: not clear
