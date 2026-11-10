# N9a independent review — round 1

Reviewed by Codex on 2026-11-10. Checkout `/Users/ericlee06/orca/workspaces/Health App/UI_design`; branch `ericlee4992/nutrition-09-weight-health`, HEAD `91e2595e085049364ce2bc93144dfe318080b6e1`; diff `d38cf18..91e2595`. Read the brief, N9 split/ticket, D52/D70/D80 and the approved prototype's Log weight sheet. Separate standards and spec source passes completed. Only this report changed project content; no commit, push or installation. Apple Health/N9b is outside this review.

## Spec

### P2 — An unchanged or time-only edit rounds the stored weight

`WorkoutTracker/Features/Nutrition/BodyWeightView.swift:149–156,233–237`.

A new entry accepts `176.456 lb` (or `70.123 kg`), but reopening it uses `FoodNumber.text(initial)`, which rounds to two decimals. Saving without changing Weight—or changing only Time—parses that rounded string and writes `176.46 lb` / `70.12 kg`, also recalculating `normalizedKg` from the altered value. D25/D52 require stored entered values to survive display formatting.

**Fix:** retain the original value for unchanged edit text, using the existing `EditableNumber` pattern or lossless form serialization. Continue rounding to 0.1 only when the user deliberately presses ±. Add a regression through the edit-prefill/time-only-save path with more than two decimal places; the current BodyWeightLog test calls the domain update directly and cannot catch this.

Evidence: a standalone Swift probe using the exact current FoodNumber definitions reproduced both round trips (`/tmp/codex-n9a/precision.swift`, `precision.log`). The subsequent model update is source-traced, not an added app UI test.

### P2 — Recalculate invokes passive refresh semantics instead of the explicit action

`WorkoutTracker/Features/Nutrition/BodyWeightView.swift:104–105`; contract at `WorkoutTracker/Domain/NutritionGoalStore.swift:75–90` and `Features/Nutrition/NutritionGoalsView.swift:51`.

The N3 ticket says Recalculate restores calculated numbers; its existing button clears overrides. N9a calls `NutritionGoalStore.update(in:)` with no change callback. With complete details and manually overridden goals, tapping Recalculate keeps the overrides, advances the goal's recorded weight, and removes the offer without restoring the calculation. Separately, after a goal exists, clear the date of birth through Heart rate settings and log a weight more than 2 kg away: the card still appears, but the passive update returns the old goal without error, so the button silently does nothing.

**Fix:** use the existing explicit recalculation path, e.g. `NutritionGoalStore.update(in: context) { $0.overrides = .none }`, and surface its `detailsIncomplete` error or route to the missing details. Cover both overridden goals and incomplete details by actually tapping the new action. Existing NutritionGoalStoreTests demonstrate the refresh/action distinction; BodyWeightUITests currently asserts only that the Recalculate button appears, never that it works.

This is separate from the recorded product question about whether merely visiting Nutrition goals should automatically refresh a goal. That question is not a finding and remains for the user.

## Standards

### P2 — Entered-value preservation

The precision defect above also violates the project's stored-value convention. Same location, failure and fix; one defect counted on both axes, not another implementation task.

### P3 — README omits the body-weight workflow

`README.md:75–79` (unchanged by this branch).

AGENTS requires the public overview to change on the same branch when behavior changes. The README describes weight within Personal details and nutrition goals, but not the new Profile → Goals & tracking → Body weight page, history, Log/Edit/Delete Weight or recalculation offer.

**Fix:** add a concise unreleased N9a description. Keep TestFlight status accurate and distinguish manual weight logging from Apple Health synchronization, which remains N9b.

## Other assessment and coverage

- `BodyWeightEntry.init` and `set` maintain the value/unit/normalizedKg relationship, and the >2 kg offer compares normalized kilograms for either unit. The sheet preserves the entry's unit when editing rather than converting to the app preference.
- New-entry unit selection matches the recorded decision: latest entry's unit, otherwise the app unit system. Ranges match Personal details (20–360 kg / 50–800 lb). Invalid or out-of-range text disables Save. Valid typed text updates the stepper's numeric state; a deliberate ± uses 0.1 kg / 0.2 lb and rounds to 0.1. Out-of-range steps leave the field unchanged; invalid input can be corrected by typing.
- DatePicker limits selection to now or earlier. The sheet's rendered body uses the captured editing flag rather than reading the entry after deletion. No deleted-model failure was established in the normal delete flow.
- Profile navigation and test-plan registration are wired. Explicit stepper animation is suppressed for Reduce Motion. The new page follows the approved prototype's weight/stepper composition with the app's tokens.
- Inspected the author's `n9att/N9.png`: default/light and AccessibilityL/dark page and new-entry sheet are readable. Empty, Recalculate and editing/deletion visual states are not captured in that board. The current flow test covers threshold visibility, not execution of the offer or the precision scenario.

## Verification

Xcode **27.2 (27B52)**, WT-iPhone27 **47D21838-69A6-4BCB-AE90-B0D9C0AAA70B**, iOS 27.0. Prepared the simulator, freshly rebuilt into the existing `/tmp/codex-n4/dd` cache, and tested unchanged binaries. Review logs/status/results are under `/tmp/codex-n9a/`.

- Fresh build-for-testing: exit **0**, `build.log` / `build.status`.
- Unit plan, serial: **1,209/1,209 definitions passed; 1,225 successful executions**, **0 failures, 0 skips**, exit **0**, `unit.xcresult`, `unit-summary.json`, `unit.log`, `unit.status`. Includes BodyWeightLogTests and NutritionGoalStoreTests.
- UI first pass, four named classes within ProfileAI, two workers: **22/23 passed, 1 failed, 0 skips**, exit **65**, `ui.xcresult`, `ui-summary.json`, `ui.log`, `ui.status`. FloodlightProfileUITests **10/10**, NutritionGoalsUITests **9/9**, warm-up **1/1**, BodyWeightUITests **2/3**. The dark AccessibilityL capture failed at `BodyWeightUITests.swift:31` before reaching Body weight: `profileBodyWeight` was absent and the failure tree showed Today/workout-summary content (`ui-failure.json`).
- Reprepared the simulator and reran warm-up + the entire BodyWeightUITests class serially, unchanged binaries: **4/4 passed, 0 failures, 0 skips**, exit **0**, `ui-serial.xcresult`, `ui-serial-summary.json`, `ui-serial.log`, `ui-serial.status`. The failed capture passed, as did the log/edit/delete flow. All 23 requested cases have passing evidence; the initial parallel run remains failed.
- Exported fresh serial captures to `/tmp/codex-n9a/attachments/` with `manifest.json`. Opened the light/default body-weight page and dark/AXL new-entry sheet; both are readable and agree with the supplied board. This does not cover the missing Recalculate, empty or edit/delete capture states.
- Test-plan consistency (`python3 scripts/test-plans.py --check`): exit **0**.
- Author bundles inspected directly: `n9u` **3 tests / 30 executions** passed; `n9ui` **2 passed / 1 failed**, followed by `n9ui2` **1/1**; `n9unit` **1,209 definitions / 1,225 executions** passed; `n9reg` **23/23** passed. These corroborate the ticket and do not replace the reviewer runs.

Verified: fresh build **exit 0**; Unit **1,209 definitions / 1,225 successful executions**, **exit 0**, `/tmp/codex-n9a/unit.xcresult`; Profile **10/10** and Nutrition goals **9/9** in `/tmp/codex-n9a/ui.xcresult`; BodyWeight **3/3** plus warm-up **1/1**, **exit 0**, `/tmp/codex-n9a/ui-serial.xcresult`; test-plan consistency **exit 0**; supplied/fresh captures and the exact formatter/parser probe inspected.

Not verified: the fix scenarios above in end-to-end UI, empty/Recalculate/edit-delete captures, cross-unit editing with a differing app preference in UI, runtime Reduce Motion, VoiceOver by a person, non-US locale, the full UI suite, or device installation. Apple Health permissions, deduplication and synchronization belong to N9b and are not acceptance gaps for N9a.

Known flaky: `BodyWeightUITests.testCaptureDarkAccessibility` failed during navigation in parallel and passed in the full serial class rerun without code changes. Its precise cause was not established; preserve both result bundles and track it with the existing UI reliability notes. No other failure or simulator connection error occurred in this review.

Review totals: **Spec 2 P2; Standards 1 P2 and 1 P3**, with precision shared across axes: **three distinct findings**. N9a is not ready for independent clearance.

Verdict: not clear
