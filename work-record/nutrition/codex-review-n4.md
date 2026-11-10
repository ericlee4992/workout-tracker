# N4 independent review — round 1

Reviewed 2026-11-10 by Codex, independently of Claude's implementation. Branch `ericlee4992/nutrition-04-log-food`, HEAD `e85d549443e4a76a09722385db6ff0d474195584`; diff `git diff e471c11..HEAD`. The checkout was clean at the start. During verification, the author advanced HEAD to `29abf9ff676760f80a9b11563549735d43720c35` with documentation only (STATE, N4 and N5 tickets); I inspected that delta. App/test source remains identical to the tested `e85d549`. I changed only this report and made no commit or push. Standards and spec received separate source-review passes; build/test evidence below was inspected directly by the reviewer.

## Spec

### P2 — A canceled toast timer clears the next log's Undo

`WorkoutTracker/Features/Food/LogFoodView.swift:98–102`.

D69 and N4 acceptance 1 require one-tap logging with Undo. Log A, then log B before A's five-second timer expires. The task ID changes and SwiftUI cancels A's task. `try? await Task.sleep` swallows cancellation, so A immediately executes `receipt = nil` against the shared state, erasing B's receipt. B is saved but loses its expected Undo window. The existing UI test performs only one log and cannot catch this; the unit test of two receipts does not exercise the timer.

Fix: return on cancellation, capture the receipt identity, and clear only that same receipt after the delay. Add a UI regression that logs twice quickly and undoes only the second; check expiry and logging again after expiry too. A standalone Swift reproduction of this cancellation body produced `Receipt after canceled old timer: nil` (`/tmp/codex-n4/toast-cancellation.swift`, `.log`); this is a concurrency reproduction, not an extra app UI test.

### P2 — An unrelated food edit rewrites stored serving and nutrition values

`WorkoutTracker/Domain/FoodLog.swift:20–24,61–64`; consumers `WorkoutTracker/Features/Food/AddFoodView.swift:26–27,106–114,175–184`.

The nutrition spec requires serving amounts to “keep the entered `(value, unit)`.” `FoodNumber.text` rounds to two decimals and is also used as the edit-field serializer. Add a food with `1/3 cup`, edit only its name, and save: the form reparses `0.33 cup`, replacing the original quantity. A smaller value such as `0.004 g` formats as `0 g`, which reparses as value **1**, unit **“0 g”**, with grams lost. Nutrition, grams and servings-per-container also round when the user never changes those fields.

Fix: separate rounded display formatting from lossless edit formatting, or retain original values for untouched fields. Test the actual edit-prefill/save path with fractions, small decimal amounts and optional nutrition. Running the exact parser/formatter definitions extracted from this HEAD reproduced both cases (`/tmp/codex-n4/parsing.swift`, `.log`). Existing entries remain snapshots; the corruption affects the saved food and future logs.

### P2 — Invalid numeric servings are accepted as units, and division can produce infinity

`WorkoutTracker/Domain/FoodLog.swift:53–57,68–77`; validation consumers `WorkoutTracker/Features/Food/AddFoodView.swift:31–35` and `WorkoutTracker/Features/Food/SelectedFoodView.swift:195–197`.

N4's serving validation currently treats a failed numeric prefix as a unit-only entry. `1/0 cup` succeeds as `(1, "1/0 cup")`, `-2 g` succeeds as `(1, "-2 g")`, and `0/2 cup` succeeds with value zero. The fraction branch validates its operands but not the quotient: finite very large/small decimal operands produce `Double.infinity`, which can be saved and cannot be encoded by the JSON exporter. The extracted-code probe reproduced the nonfinite result and `EncodingError.invalidValue`.

Fix: distinguish a genuine unit-only string from an invalid numeric amount; require positive, finite results after division. Preserve digit-bearing unit suffixes (`2 x 50 g` already round-trips correctly), and propagate invalid nonblank servings through both Add food and Manual Add validation. Do not let a newly rejected optional Manual Add serving silently become the default serving. Cover invalid fractions, zero/negative input, scientific notation policy and overflow.

No scope-creep finding. Today's totals and entry edit/delete are explicitly assigned to N5; their absence is not an N4 defect.

## Standards

### P2 — Stored-value preservation is also a standards failure

`WorkoutTracker/Domain/FoodLog.swift:23`. The edit-roundtrip issue detailed in Spec above also violates the project's entered-value preservation rule. Same scenario and fix; this is one defect counted on both review axes, not a second implementation task.

### P2 — Food screens do not honor Reduce Motion

`WorkoutTracker/Features/Food/LogFoodView.swift:189,253,328`; also `SelectedFoodView.swift:116` and `CreateMealView.swift:151,171`.

The iOS design review checklist, item 10, requires motion to be suppressed or replaced with a crossfade under Reduce Motion. These new screens unconditionally animate tab scrolling, reordered rows, numeric changes and a moving toast. There is no `accessibilityReduceMotion` gate in the Food views or a global ancestor override that supplies one.

Fix: read the setting and gate movement, including explicit `withAnimation` calls and the toast transition; use no animation or opacity when enabled. Verify the affected actions with Reduce Motion enabled. This finding is based on source tracing; runtime Reduce Motion was not exercised.

### P3 — Public README and screenshots omit N4

`README.md:64` (unchanged by this branch); `WorkoutTracker/Features/Food/LogFoodView.swift:4–7` introduces the undocumented flows.

AGENTS requires README and screenshots on the same branch when behavior or visible screens change. The README still says “food logging still being built” and has no unreleased description or screenshots of the completed manual logging, My foods, Saved foods and My meals flows.

Fix: document the implemented N4 behavior and representative screenshots, keeping its unreleased/TestFlight status accurate and N5's totals/editing visibly pending.

## Storage, behavior and visual assessment

- `createdByUser = false` and optional `servingsPerContainer` are additive and satisfy the project's CloudKit constraints. Existing relationship delete rules are unchanged. The shipped-format fingerprint stays pinned separately from the approved development format.
- Keeping export version 12 is reasonable: it is unreleased, and both added `SavedFoodRow` fields are optional, so earlier v12 data can decode without them. Reinterpreting `isSaved` is likewise limited to unreleased nutrition data; it does not reinterpret any shipped nutrition rows.
- Logging snapshots values into entries. Meal logging uses each item's frozen snapshot, not the current linked food. Manual Add creates no SavedFood and blank names use `.quickAdd`. Receipt-based domain Undo removes exactly its entries and restores last-used metadata. The UI timer issue above prevents the two-log interaction from meeting that contract reliably.
- `FoodSampleFixture.isEnabled` delegates to `WorkoutTrackerStore.fixtureIsEnabled`, which requires both its flag and `-uiTestReset`; it cannot seed the ordinary store from its own flag alone.
- Inspected the author's `ui2shots/N4-wired-light-default.png` and `N4-wired-dark-axl.png` boards, plus full-size dark/AXL Log food toast and Selected food captures. The D67 Soft tokens supersede the older Floodlight palette in the design skill. Default/AXL composition, stacked form fields and scrolling tab choices match the approved structure in the inspected states. The capture tests do not scroll Selected food to show all its lower content or expand Other nutrition facts at AXL, so those states are not visually cleared.
- The concurrent documentation commit `29abf9f` records the user's approval of the new strings and N5 deferrals, plus **Delete Food…** for My foods. It explicitly schedules Delete Food after this review and for round 2. That new behavior is not implemented or verified in this round; it needs implementation and review before final N4 clearance.

## Verification

Reviewer environment: Xcode **27.2 (27B52)**, WT-iPhone27 **47D21838-69A6-4BCB-AE90-B0D9C0AAA70B**, iOS 27.0. Ran `scripts/prepare-test-simulator.sh` first. Fresh `build-for-testing`, then unchanged binaries via `test-without-building`. Unit serial; UI two workers. Derived data `/tmp/codex-n4/dd`.

- Build: exit **0**, `** TEST BUILD SUCCEEDED **`, `/tmp/codex-n4/build.log` and `.status`.
- Unit plan: exit **0**, **1,197/1,197 definitions passed**, **1,213 successful executions** including parameterized cases; **0 failures, 0 skips**. `/tmp/codex-n4/unit.xcresult`, `unit.log`, `unit.status`, `unit-summary.json`. Includes FoodLogTests, NutritionExportTests, NutritionMigrationTests, StoreFormatGuardTests and legacy migration coverage.
- UI first pass: **15/18 passed, 3 failed, 0 skipped**, exit **65**, `/tmp/codex-n4/ui.xcresult` (`ui.log`, `ui.status`, `ui-summary.json`). `LogFoodUITests` **4/4** and `TodayUpNextUITests` **9/9** passed. Failures: warm-up did not see the tab bar; Add food failed waiting for `logFoodMeal.lunch` before entering its form; the combined Manual Add/meal flow failed its “2 servings” assertion after the second +.
- Serial rerun, unchanged binaries: `AAAWarmUpUITests` + entire `LogFoodFlowUITests`, **5/5 passed, 0 failed, 0 skipped**, exit **0**, `/tmp/codex-n4/ui-serial.xcresult` (`ui-serial.log`, `ui-serial.status`, `ui-serial-summary.json`). All 18 requested tests therefore have passing evidence; the original parallel run remains a failed run.
- Exported reviewer captures and failure attachments to `/tmp/codex-n4/attachments/` with `manifest.json`. Opened fresh light/default Log food and dark/AXL scrolled Selected meal captures; no additional visual defect found in those states.
- `python3 scripts/test-plans.py --check`: exit **1**. New `LogFoodUITests` and `LogFoodFlowUITests` have no area-plan mapping; register them in `scripts/test-plans.py:AREAS` and regenerate the plans. `NutritionGoalsUITests` is also unmapped, already present before N4. Named-class execution below does not repair that area-plan omission. This is a tooling result, separate from the source findings.
- Author evidence inspected directly: `unit2.xcresult` has 1,197 definitions / 1,213 executions, no failures/skips; `ui3.xcresult` has **8/8 passed**, no failures/skips. These corroborate the ticket but do not replace the reviewer's runs.
- Scratch parser probes confirmed comma decimals; FoodNumber accepts `1e3` as 1000, accepts finite `1e308`, rejects `1e309` and negatives. `2 x 50 g` and `1 jar (250 g)` preserve their parsed representation. Failure cases are detailed above.

Verified: fresh build exit 0; Unit **1,213 successful executions / 1,197 definitions, 0 failures, 0 skips**, exit 0, `unit.xcresult`; Log food captures **4/4** and Today **9/9** in `ui.xcresult`; warm-up + food flows **5/5**, exit 0, `ui-serial.xcresult`. All result paths are under `/tmp/codex-n4/`. Parser/formatter and cancellation probes reproduced the findings; supplied and fresh captures inspected as itemized above.

Not verified: device migration rehearsal or install (explicitly waived/not requested); real CloudKit synchronization; an intermediate N3 nutrition store with pre-existing SavedFood rows (the migration fixture is the shipped pre-nutrition format); full UI suite; light/AXL and dark/default combinations; lower/expanded Selected food at AXL; VoiceOver by a person; runtime Reduce Motion; rapid-log timer behavior in the actual app. No product files/tests were edited to add regression probes. Today's totals and entry edit/delete remain N5.

Known flaky: the three parallel UI failures listed above all passed in the serial rerun without changes. Their precise causes were not established; do not count them as reproduced product defects. Preserve both result bundles and track them with N4's existing UI-stall record. The author's reported clone keyboard/event-loop idle stall is recorded in the ticket; it is not itself proof of an app hang.

Source-review totals: **Spec 3 P2 findings; Standards 2 P2 and 1 P3**, with the precision defect shared across axes. No P1 identified. Test-plan mapping also needs correction. N4 is not ready for independent clearance.

Verdict: not clear
