# N15 — Codex review, round 1

Target: `ec0e3a96..dead49d2972e9ef3c66ab382fb08a36951d2a035`, branch
`ericlee4992/nutrition-15-save-any-food`. Clean checkout at start. Reviewed the N15 ticket, D81/D82/D83/D87,
AGENTS, and the project's SwiftUI/SwiftData/ios-design guidance. The user's choice of content matching without
new photo-item/meal link fields is respected; none of these findings requires a schema change.

**Checkpoint: independent UI verification still running.**

## Standards

1. **P3 — Document the new save paths in the public overview.** `README.md:71–84` describes opened log entries and
   scanned meals as editable/deletable but does not describe their new bookmarks, saving individual scan items,
   or saving a scanned meal to My meals. AGENTS requires updating README on the same branch when product behavior
   changes. Add these paths and destinations; the existing generic bookmark sentence does not explain them.

All eight supplied captures were opened. The new controls fit at Default and AccessibilityL, the bookmark is
separate from Save, and its filled state does not rely on color. No new visual blocker or schema/concurrency finding.

## Spec

2. **P2 — Compare the complete content before deleting a matching meal.**
   `WorkoutTracker/Domain/FoodSaving.swift:135–139` (used by `:101–104`, deletion at `:112–113`). Matching ignores
   brand, barcode, fiber, sugar, saturated fat and sodium. A meal created through My meals can contain an ingredient
   with all these facts; a photo estimate with the same meal/ingredient names, portion and headline macros is then
   incorrectly treated as that meal. Its bookmark appears filled, and un-saving deletes the original reusable meal
   and its richer ingredient snapshots. Logged entries survive, but the distinct saved meal is lost. Content
   matching is the accepted design; incomplete equality is not. Compare the full relevant ingredient snapshot, or
   restrict matching to candidates representable by the scan item's content. Apply the same rule to the food matcher
   at `:128–132`. Add a regression with equal headline macros and different extra nutrition/brand facts.

3. **P2 — Preserve the edited Weight rather than overriding it from Portion.**
   `WorkoutTracker/Domain/FoodSaving.swift:89` prefers `serving.grams` to `item.grams`. Open an item whose Portion is
   `1 cup (150 g)`, change its separate Weight field to `200`, and bookmark it: `ScanItemEditor.current` correctly
   contains 200 g, but the saved food still contains 150 g. The same conversion is used for saved meals and content
   matching, so a weight-only edit can still appear already saved. Honor the explicit Weight field, or reconcile
   conflicting portion/weight inputs before saving, instead of silently discarding the edit. Cover both item and
   meal saving with this conflicting-value case.

4. **P2 — Do not let an unsaved duplicate hide an existing saved copy.**
   `WorkoutTracker/Domain/FoodSaving.swift:56–65`. Two identical Manual Add/label entries can each create their own
   linked SavedFood through the entry path. Un-save one, leaving the other saved. A photo item with matching content
   resolves the first fetched copy without considering saved state; if it is the unsaved one, the bookmark is empty
   even though the same item remains in Saved foods, and tapping it re-saves the redundant copy. Resolve content
   matches with explicit, deterministic saved-state semantics (including un-saving when multiple exact matches
   exist), rather than an arbitrary first row. Test one saved and one unsaved equivalent copy.

## Other checks and coverage

- Entry-based bookmarks retain a link and do not duplicate on repeated toggles. A real linked food is bookmarked
  rather than overwritten, as D87 requires. The first copy of an unlinked entry uses its staged per-serving values.
  Cancel preserving an explicit bookmark is the recorded immediate-action design, separate from committing edits.
- The `ScanItemEditor.current` extraction preserves previous write-back behavior and item identity. The task keys
  cover the edited content fields; the conversion issue is #3, not a missing task dependency.
- `isCachedLookup` keeps logged foods (`lastUsedAt`), user-created foods and saved foods visible; it additionally
  hides abandoned, unlogged saved copies. Logged snapshots and the existing delete rules are unchanged. No stored
  model changes were found.
- The new tests prove the common entry/item/meal save flows and basic toggle behavior, but do not cover #2–4.
  The planned TodayTrain area plan is appropriate before merge because list eligibility is shared with Log food
  and Create meal. Add the targeted regressions above; a full UI-suite escalation is not needed.

## Verification

Only WT-Redesign-2 `EB4328A1-87BD-4850-A3B2-A6E604701F1C`; preparation script run first. Derived data
`/tmp/wt-n15-codex`; logs, exits and result bundles `/tmp/wt-n15-codex-review/`.

- Independent build-for-testing passed, exit 0 (`build.log`, `build.exit`).
- Independent Unit plan: 1366/1366 passed, exit 0 (`unit.log`, `unit.exit`, `unit.xcresult`), summary inspected.
- Independent UI running: TodayTrain plan narrowed to TodayFoodUITests and ScanFoodUITests (24 tests),
  two workers on the designated destination; exec session 29223 (`ui.log`, `ui.exit`, `ui.xcresult`).
- Author xcresult summaries inspected directly: `n15-unit.xcresult` 1366/1366 passed;
  `n15-ui3.xcresult` 4/4 passed.
- Test-plan consistency check passed. Diff whitespace check reports added blank EOF lines in the two UI-test files.

Verified: independent build exit 0; Unit 1366/1366, exit 0, `/tmp/wt-n15-codex-review/unit.xcresult`;
          source/caller review; all eight supplied captures; author's xcresult summaries.
Not verified: independent UI completion; regressions for #2–4; full TodayTrain area plan; phone behavior.
Known flaky: none seen in this round yet.

Standards: 1 finding, worst P3. Spec: 3 findings, worst P2.

Verdict: not clear
