# N15 — Codex review, round 3

Target: `a258cd94..e572db5afef30cc2387bdcbeb8948afd64ed8a8e`, branch
`ericlee4992/nutrition-15-save-any-food`. Clean checkout at start. Reviewed the round-three brief, ticket response,
previous findings and changed code. Current-screen design guidance and the user's no-new-links/content-matching
choice remain in force. Only this report is changed by the reviewer.

**Final report — 2026-11-13. All previous findings resolved; no new findings. Independent build and Unit checks pass.**

## Standards

No findings. Domain/UI separation, explicit persistence boundaries and the existing stored schema are preserved.
No visual changes this round; the accepted monochrome, icon-only bookmark and prior captures remain applicable.
Diff whitespace and test-plan consistency checks pass.

## Spec

No findings. Round-2 #1 is resolved: for `g`, `gram` and `grams` portions, an explicit Weight now supplies both the
serving value and its grams. A `150 g` portion with Weight 200 consequently saves and displays as `200 g`.
Count/volume portions retain their quantity and unit while their associated grams follow Weight; when Weight is
absent, the parsed portion weight remains the fallback. Calories and macros are preserved as the item's values.

The extended `theEditedWeightIsSaved` regression verifies the gram portion's stored fields and food display, plus
the persisted meal item's `servingText`. The same conversion feeds item matching and both food/meal creation, so
the corrected serving is used consistently. The previous richer-content, duplicate saved-state and README fixes
remain intact. All previous review findings are resolved.

## Verification

Only WT-Redesign-2 `EB4328A1-87BD-4850-A3B2-A6E604701F1C`; preparation script before build/tests. Derived data
`/tmp/wt-n15-codex`; round-three logs, exits and results `/tmp/wt-n15-codex-review-r3/`.

- Independent build-for-testing: passed, exit 0 (`build.log`, `build.exit`).
- Independent Unit plan: 1370/1370 passed, exit 0 (`unit.log`, `unit.exit`, `unit.xcresult`), summary inspected;
  no failures or skips.
- Author's `build/results/n15-unit3.xcresult`: summary inspected, 1370/1370 passed, no failures or skips.
- UI inspected rather than rerun, per the round-three brief: previous independent
  `/tmp/wt-n15-codex-review/ui.xcresult` is 24/24 passed, no failures or skips; recorded exit 0. This round changes
  only the Domain conversion and its unit regression, with no UI source/test behavior or layout changes.
- `git diff --check a258cd94..HEAD` and `python3 scripts/test-plans.py --check`: passed.

Verified: independent build exit 0; Unit 1370/1370, exit 0, `/tmp/wt-n15-codex-review-r3/unit.xcresult`;
          source/caller review; current author Unit and prior independent UI results inspected.
Not verified: full TodayTrain area plan (author's pending pre-merge check);
              phone behavior.
Known flaky: none seen in this round; UI was not rerun.

Standards: 0 findings. Spec: 0 findings. Review clearance covers the code at the target commit; the ticket's full
TodayTrain area-plan check remains a separate pre-merge step, and no device installation or release was performed.

Verdict: clear
