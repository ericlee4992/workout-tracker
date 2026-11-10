# N4 independent review — round 2

Reviewed by Codex on 2026-11-10. Branch `ericlee4992/nutrition-04-log-food`, HEAD `23adb0e388d299bf10451bc497bde4193388ec58`; diff `29abf9f..23adb0e`. The working tree was clean before review. Scope: the round-1 fixes and newly authorized Delete Food, as specified in `codex-review-n4b-prompt.md`. Separate standards and spec source passes were completed; the reviewer built and ran the tests below and inspected the actual results. No implementation edits, commit, push, merge or device install.

## Spec

No remaining P1/P2/P3 findings in the reviewed diff.

- **Toast timer resolved:** `WorkoutTracker/Features/Food/LogFoodView.swift:99–105` returns on cancellation and verifies receipt identity before clearing. The new rapid-log regression exercises a second log, Undo of only that log, expiration, and a fresh Undo afterward.
- **Unchanged values preserved:** `WorkoutTracker/Domain/FoodLog.swift:47–58,142–157` retains the original numeric/serving value when edit text is unchanged. `AddFoodView.swift:27–39,116–140` uses those wrappers for serving, grams, servings per container, calories and all optional nutrition. Rounded display text is no longer silently written over untouched stored values. The regression includes a fractional serving and non-rounded nutrition.
- **Serving validation resolved:** `FoodLog.swift:16–27,74–103,120–137` validates plain numeric text and positive finite serving quantities, including division results and the documented upper bound. `SelectedFoodView.swift:217–222` prevents invalid nonblank Manual Add servings from silently becoming a default. The deliberate `1e3 g` interpretation as value 1 with unit `e3 g` is recorded in the ticket; scalar `1e3` is rejected.
- **Delete Food implemented:** `SelectedFoodView.swift:26–44,96–121` exposes deletion only for My foods and hides content/toolbars before deleting the model. `FoodLog.swift:373–378,409–412` preserves entry/meal snapshots via existing nullifying links and skips deleted models during Undo. The domain test checks preservation and Undo after deletion; the UI flow checks removal from both My foods and Saved foods. `LogFoodView.swift:107–115` dismisses the selected page and drops that food's outstanding toast.

Today's totals and entry edit/delete remain explicitly assigned to N5. No new scope-creep finding.

## Standards

No remaining P1/P2/P3 findings in the reviewed diff.

- **Reduce Motion:** traced the setting through explicit animations in LogFoodView, SelectedFoodView and CreateMealView, plus MacroSummary. Movement is suppressed; toast/numeric/symbol transitions select opacity. This clears the source finding; runtime Reduce Motion remains outside the exercised evidence.
- **README:** describes N4, its unreleased status and N5 deferrals, and includes `docs/readme/log-food.png`. Opened the image; it uses sample data and matches the feature. The “on main” wording describes the intended merged README; this review does not claim the branch has already merged.
- **Test plans:** food classes are mapped to TodayTrain, NutritionGoalsUITests to ProfileAI. `python3 scripts/test-plans.py --check` exits 0.
- **Captures:** the new expanded Other nutrition facts captures show all four facts legibly at light/default and dark/AccessibilityL. No additional visual defect found in those states.

No unrelated modernization or structural change is needed for this ticket's clearance.

## Verification

Xcode **27.2 (27B52)**; WT-iPhone27 **47D21838-69A6-4BCB-AE90-B0D9C0AAA70B**, iOS 27.0. Ran `scripts/prepare-test-simulator.sh` before testing and rebuilt into `/tmp/codex-n4/dd`. All round-2 logs/status/result bundles are under `/tmp/codex-n4/round2/`.

- Fresh `build-for-testing`: exit **0**, `build.log` / `build.status`.
- Unit plan, serial: exit **0**, **1,200/1,200 test definitions passed; 1,216 successful executions** including parameterized cases; **0 failures, 0 skips**. `unit.xcresult`, `unit-summary.json`, `unit.log`, `unit.status`. Includes FoodLogTests **16**, export, schema guard and migration coverage.
- UI, named classes within TodayTrain, two workers: exit **0**, **11/11 passed**, **0 failures, 0 skips**. `AAAWarmUpUITests` **1/1**, `LogFoodUITests` **5/5**, `LogFoodFlowUITests` **5/5**. Includes rapid-log Undo, expiry/fresh Undo, Delete Food, meal creation/logging/deletion and the README capture. `ui.xcresult`, `ui-summary.json`, `ui.log`, `ui.status`. No serial rerun was needed.
- Exported fresh UI attachments to `attachments/` with `manifest.json`; opened the reviewer’s expanded Selected food captures at light/default and dark/AccessibilityL. All four lower nutrition facts are readable in both. The new toolbar remains reachable. Test-plan consistency check: exit **0**.
- Author evidence independently inspected: `unit3.xcresult` **16 tests / 160 executions**, no failures/skips; `ui4.xcresult` **9/9**, no failures/skips. Inspected the expanded Selected food captures in the author's `ui4shots/` and the committed README screenshot. These supplement the reviewer's reruns.

Verified: build **exit 0**; Unit **1,200/1,200 definitions / 1,216 executions**, **exit 0**, `/tmp/codex-n4/round2/unit.xcresult`; named UI classes **11/11**, **exit 0**, `/tmp/codex-n4/round2/ui.xcresult`; test-plan mapping **exit 0**; fresh default/AXL expanded-facts captures and committed README image inspected. Round-1 findings are resolved within this scope.

Not verified: runtime Reduce Motion, VoiceOver by a person, non-US locale, real CloudKit synchronization, device migration/install, or the full UI suite. Today's totals and logged-entry editing/deletion belong to N5. No schema changes were introduced in this round. The prior backup waiver remains honored.

Known flaky: **none observed in this round**. Round 1’s parallel warm-up/Add food/meal-flow failures passed serially then, and all passed in this round’s parallel run. The historical clone keyboard/idle-signal stalls remain recorded in the N4 ticket; they did not cause a failure here.

Review totals: **Standards 0 findings; Spec 0 findings**.

Verdict: clear
