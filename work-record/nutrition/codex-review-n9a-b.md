# N9a independent review — round 2

Reviewed by Codex on 2026-11-10. Branch `ericlee4992/nutrition-09-weight-health`, HEAD `f1bd299b3bbee75bb9e90a2ca27aab736b4c8ab8`; diff `91e2595..f1bd299`. Clean checkout at review start. Separate standards and spec source passes completed. Only this report changes project content; no commit, push or phone install. Apple Health remains N9b, outside this review.

## Spec

**No remaining P1/P2/P3 findings.**

- **Precision fixed:** `Features/Nutrition/BodyWeightView.swift:145–160,174` now retains an `EditableNumber`, uses its initial text and resolves both Save validation and text/stepper synchronization through it. Unchanged text preserves the exact stored figure; a time-only edit no longer persists the rounded display value. Explicit ± changes retain the documented step and one-decimal rounding. The new regression verifies resolution of `176.456` from its displayed `176.46`; source review confirms the sheet uses that resolver. This is not a separate end-to-end time-only precision UI test.
- **Recalculate fixed:** `Domain/BodyWeightLog.swift:35–42` calls N3's explicit-action path with overrides cleared. The page's button invokes this helper and presents errors through its existing alert. The new domain test covers an overridden goal, the new weight and incomplete details. The UI flow now taps Recalculate, observes the offer disappearing, deletes the newer weight, and observes the offer returning.
- D70's dated-goal behavior remains delegated to NutritionGoalStore. The separate product question about automatic refresh on visiting Nutrition goals is unchanged and is not a review finding.

## Standards

**No findings.** The stored-value fix resolves the shared standards/spec issue. README now describes body-weight history, logging, editing/deletion and recalculation, with unreleased/TestFlight status and pending Apple Health synchronization distinguished. Its “on main” wording is for the intended merged README, not evidence that this branch has already merged.

No schema, unit-selection, layout or motion change was introduced by the fixes. The earlier missing empty/Recalculate/edit-delete capture states remain verification limits, not demonstrated UI defects.

## Verification

Xcode **27.2 (27B52)**; WT-iPhone27 **47D21838-69A6-4BCB-AE90-B0D9C0AAA70B**, iOS 27.0. Ran simulator preparation and fresh build-for-testing into the existing `/tmp/codex-n4/dd` cache; tests used unchanged binaries. Round-2 artifacts are under `/tmp/codex-n9a/round2/`.

- Build: exit **0**, `build.log` / `build.status`.
- Unit plan, serial: **1,211/1,211 definitions passed; 1,227 successful executions**, **0 failures, 0 skips**, exit **0**, `unit.xcresult`, `unit-summary.json`, `unit.log`, `unit.status`. Includes BodyWeightLogTests **5** and NutritionGoalStoreTests.
- UI first pass, BodyWeightUITests + warm-up, two workers: **3/4 passed, 1 failed, 0 skips**, exit **65**, `ui.xcresult`, `ui-summary.json`, `ui.log`, `ui.status`. The updated log/edit/delete/Recalculate flow passed. The dark AccessibilityL capture failed during navigation to `profileBodyWeight`, with the failure tree showing Today/workout-summary content—the same symptom as round 1.
- Reprepared WT-iPhone27 and reran both classes serially, unchanged binaries: **4/4 passed** (BodyWeightUITests **3/3**, warm-up **1/1**), **0 failures, 0 skips**, exit **0**, `ui-serial.xcresult`, `ui-serial-summary.json`, `ui-serial.log`, `ui-serial.status`. The capture failure did not recur. Keep the original failed run in the evidence.
- Exported fresh serial attachments to `attachments/` with `manifest.json`; opened the default/light page and dark/AccessibilityL Log weight sheet. Both are readable; no new visual defect found in those states.
- Test-plan consistency (`python3 scripts/test-plans.py --check`): exit **0**.
- Author evidence inspected directly: `n9u2.xcresult` **5 tests / 50 executions**, and `n9ui3.xcresult` **3/3**, no failures/skips. These supplement the reviewer's reruns.

Verified: fresh build **exit 0**; Unit **1,211 definitions / 1,227 successful executions**, **exit 0**, `/tmp/codex-n9a/round2/unit.xcresult`; BodyWeightUITests **3/3** + warm-up **1/1**, **exit 0**, `/tmp/codex-n9a/round2/ui-serial.xcresult`; test-plan consistency **exit 0**; fresh default/AccessibilityL captures inspected. The recalculation action was exercised in the UI flow and its override/error behavior in domain tests.

Not verified: a distinct time-only precision UI/storage test; incomplete-details alert interaction in UI (domain error and caller wiring checked); empty/Recalculate/edit-delete captures; runtime Reduce Motion, human VoiceOver, non-US locale, every appearance/size combination, phone install or the full UI suite. Adjacent Profile/NutritionGoals UI classes were not repeated in this narrowed round; passing round-1 evidence remains in `codex-review-n9a.md`. Apple Health integration is N9b.

Known flaky: `BodyWeightUITests.testCaptureDarkAccessibility` again failed before reaching Body weight in parallel and passed in the complete serial class rerun without changes. Its precise cause remains unestablished; track this repeated navigation symptom with the ticket’s UI reliability notes. No other failure or simulator connection error occurred in this round.

Review totals: **Standards 0; Spec 0 findings.** All three distinct round-1 findings are resolved within this verification scope.

Verdict: clear
