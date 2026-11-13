# N15 — Codex review, round 2

Target: `441f8ff1..a258cd94636358bb9c501df85e1c61b58a74ddf1`, branch
`ericlee4992/nutrition-15-save-any-food`. Clean checkout at start. Reviewed the round-two brief, ticket response
and previous findings. The user's no-new-links/content-matching decision and current-screen design guidance remain
in force. Only this report is changed by the reviewer.

**Final report — 2026-11-13. Three findings resolved; one P2 Weight/serving case remains. Build and Unit checks pass.**

## Standards

No new substantive findings. README now describes saving logged entries, saving individual scan items, and saving
scanned meals to My meals, resolving round-1 #1. Domain/UI separation, explicit saves and stored schema remain
unchanged. No visual re-review is needed for the unchanged UI code and accepted monochrome icon-only bookmarks.

## Spec

1. **P2 — Reconcile gram-based serving quantities with the edited Weight.**
   `WorkoutTracker/Domain/FoodSaving.swift:97–101`. The Weight fix handles `1 cup (150 g)`, but not a portion whose
   unit is itself grams. For Portion `150 g` and an edited Weight of `200`, `food(from:)` saves
   `servingValue = 150`, `servingUnit = "g"`, and `servingGrams = 200`. Both food and meal displays use
   `ServingText.format` (`FoodLog.swift:107–110,243,247`), which omits the separate grams field for a gram-based
   unit, so the saved result still says **150 g**. The displayed serving and stored weight disagree, despite the
   ticket's rule that the edited Weight wins. Normalize gram-based serving values to the authoritative Weight,
   or reconcile the conflicting values before creating the saved copy, while retaining count/volume portions
   such as cups. Extend `theEditedWeightIsSaved` with `150 g` → Weight 200 and assert both saved weight and displayed
   serving for food and meal. This is the remaining case of round-1 #3, established by source tracing; the current
   regression covers only a cup portion with parenthesized grams.

Round-1 #2 is resolved: richer foods and meal ingredients cannot pass `representsAnItem`; the optional nutrition,
brand/barcode and other serving fields are protected, and a linked meal ingredient is not confused with a scan
copy. The regression verifies that saving and un-saving a photo meal leaves the richer meal intact.

Round-1 #4 is resolved: saved state considers every matching food, un-saving clears all saved equivalents without
deleting records, and re-saving deterministically picks the oldest existing copy. The new regression verifies a
mixed saved/unsaved duplicate pair. No additional spec finding.

## Verification

Only WT-Redesign-2 `EB4328A1-87BD-4850-A3B2-A6E604701F1C`; preparation script run before build/tests. Derived data
`/tmp/wt-n15-codex`; round-two logs, exits and results `/tmp/wt-n15-codex-review-r2/`.

- Independent build-for-testing: passed, exit 0 (`build.log`, `build.exit`).
- Independent Unit plan: 1370/1370 passed, exit 0 (`unit.log`, `unit.exit`, `unit.xcresult`), summary inspected.
- Author's `build/results/n15-unit2.xcresult`: directly inspected, 1370/1370 passed.
- Per the round-two brief, inspected rather than repeated UI: the previous independent
  `/tmp/wt-n15-codex-review/ui.xcresult` remains 24/24 passed with recorded exit 0, no failures. This round changes
  Domain logic and README; the UI test diff only removes blank EOF lines. The earlier captures remain applicable.
  The new Domain regressions are the appropriate direct checks for these fixes; the gram-serving case needs one more.
- Test-plan consistency check passed. `git diff --check 441f8ff1..HEAD` reports one new blank EOF line in
  `WorkoutTrackerTests/FoodSavingTests.swift:237` (formatting cleanup only).

Verified: independent build exit 0; Unit 1370/1370, exit 0, `/tmp/wt-n15-codex-review-r2/unit.xcresult`;
          source/caller review; author's 1370-test result and prior 24-test UI result inspected.
Not verified: gram-serving regression above; full TodayTrain area plan (author's
              pending pre-merge check); phone behavior.
Known flaky: none seen in this round; UI was not rerun.

Standards: 0 substantive findings. Spec: 1 remaining P2.

Verdict: not clear
