# Codex cross-review — scanner accuracy ticket 02, round 3

Boundary: `bf77d4d..c87ae80` (one commit, `c87ae80`).

Verdict: **not clear**. The sibling exception, split-word false positives, two-line punctuation loss, hot-path allocation, and dead state are closed, but the new digit refusal has two bypasses and the current documentation remains internally contradictory.

## Standards

Clear. No hard violation of `CLAUDE.md` or introduced Fowler-baseline smell was found. The changed production logic remains pure in `WorkoutTracker/Domain/`; the per-entry/per-line provenance allocation and unused `brandTokens` are gone; and `spliced(_:replacements:)` consolidates reconstruction rather than duplicating it. `git diff --check bf77d4d...c87ae80` passes.

## Spec

### Medium

1. **Digit-bearing brand refusal is only partial.** `.scratch/scanner-accuracy/issues/02-brand-repair.md:18-30,174-175`; `WorkoutTracker/Domain/MachineLabelRepair.swift:159-183,208-231`; `WorkoutTrackerTests/MachineLabelRepairTests.swift:65-83`.

   The amended ticket categorically says a brand repair is refused when the token carries a digit, and the response says such a token is a code, never a misread logo. The implementation checks digits only inside `if distance > 0` in the token-for-token path, and it exempts any brand token that itself contains a digit. Two other paths bypass the check entirely:

   - `1CYBEX` takes the leading-character strip's distance-zero path and becomes `cybex`.
   - `LIFEFITN3SS` goes through `repairedGluedBrand` and becomes `life fitness`.

   A near miss of `Gym80`, such as `GYM8O`, is also edit-repaired despite the governing ticket's unconditional wording. I compiled the domain implementation with a temporary driver and reproduced all three outputs. The added tests cover ordinary substitution and trailing-code shapes (`CYB3X`, `PR1ME`, `PREC0R`, `HAMNER1`, `MATR1X`) but not leading-strip, glued-brand, or Gym80 paths. Move the digit refusal ahead of every brand-repair path, or amend the ticket to state the narrower rule and its exceptions.

### Low

2. **Current source documentation contradicts the amended ticket and executable behavior.** `WorkoutTracker/Domain/MachineLabelRepair.swift:46-52,154-156,187-190,218-221`; `WorkoutTrackerTests/MachineLabelRepairTests.swift:35-42`; `.scratch/scanner-accuracy/issues/02-brand-repair.md:25-29`.

   The accepted-cost list truthfully says `LAMMED` and `YAMMER` remain as read, and the tests agree. The source nevertheless calls `LAMMED` a non-word, documents `LAMMED STRENGTH → HAMMER STRENGTH`, and cites `RENGTH` beside `YAMMER` as a corroborated repair; the dictionary gate prevents all of those in the app. The same comment says a glued split remains available without a dictionary, while `repairedGluedBrand` requires one. These comments now describe rules the amended ticket explicitly rejected.

3. **The ticket's canonical Resolution is stale and conflicts with its later response.** `.scratch/scanner-accuracy/issues/02-brand-repair.md:90-98,141-146,167-184`.

   The Resolution still says `CatalogMatch.nameTokens` / `exactlyCovered`, the prefix-sibling exception, and the production vocabulary hook are part of the built result. The current code has removed all three, and the later review responses say so. Keeping the historical account is useful, but it should be marked superseded rather than presented as the ticket's current resolution.

### Verified closures and claims

- The sibling exception is removed from `CatalogMatch`, `score`, and preselection. Grep finds none of `nameLineTokens`, `exactlyCovered`, `isPrefixSibling`, `lineTokenSets`, or `exactNameTokens`; only the explanatory matcher comment and single pinning test remain. The three two-word furniture constructions and the real Low Row tie are unpreselected.
- `split` now refuses English words and refuses all splits when no dictionary is supplied. `MIDLAND` and `ROWLAND` remain intact in the app-backed tests.
- Both halves of the two-line pass use the shared run splicer. The exact `HAMMER-` / `(STRENCTH)` construction passes as `HAMMER-` / `(STRENGTH)`.
- The ticket is now amended to match the deliberate `LAMMED`, `YAMMER`, trailing-junk, and separatorless-split costs; those costs are stated truthfully. `brandTokens` is gone.
- Source contains exactly 672 `@Test` declarations, including 15 repair tests. I independently ran the full `WorkoutTrackerTests` target and both `ScanMachineLabelUITests`; both commands exited 0. The harness rerun reproduced the committed 41-photo totals: top-1 8/12, preselected-right 5/12, wrong preselections 0, create-new 28/29.

Summary: Standards has 0 findings. Spec has 3 findings; worst is Medium because digit-bearing codes still reach two brand-repair paths.
