Cross-review (T6) of the scanner-accuracy work, ticket 02, on branch scanner-accuracy.
Review boundary: 419a04a..5ffa3cc (two commits: 197ba91 the feature, 5ffa3cc a fix whose message
corrects a false "UI green" claim in the first — review the fix and that correction too).
Read work-record/scanner-accuracy/spec.md, issues/01-corpus-and-harness.md (the baseline and
its analysis), issues/02-brand-repair.md, and docs/DECISIONS.md D33–D35.

## What was built

Domain/MachineLabelRepair.swift — a pure reading-repair step built once per
CatalogMatchIndex (`index.repair`, `index.repaired(_:)`) and applied inside
CatalogMatcher.rank: brand-token repair (strip one stray char around an exact brand token;
edit distance ≤1 for 4–5 chars, ≤2 for ≥6; glued multi-word brands split back), and a
slash/glue split of an unknown token into two known catalog words. Every rule refuses
known catalog words, short tokens, and ambiguity (two brands equally near / two ways to
cut). repairedText rewrites only the repaired words, styled like the word replaced.
CatalogMatch gains nameTokens/exactlyCovered; CatalogMatcher.preselection skips the D33
margin for a prefix sibling (same maker, strict subset, exact coverage, every
distinguishing word ≥3 chars). ScanMachineLabelSheet.present feeds the REPAIRED reading to
the create-new guesses and keeps the raw reading as the echoed text.
MachineLabelOCR.vocabulary — an experiment hook (nil in the app; set by the harness under
TEST_RUNNER_SCANNER_VOCAB=1): customWords + language correction. Measured: no gain, off.
Tests: MachineLabelRepairTests (12), 2 in CatalogMatcherAdversarialTests.
Corpus: preselected right 3 → 6 of 12, wrong preselections 0 both before and after,
top-1 7, create-new 28/29 (reports/baseline-2026-09-05.md → after-ticket-02-2026-09-05.md).

## Specific things to attack

1. **Can repair manufacture a WRONG brand?** This is the D33 risk in its purest form: a
   repaired token is trusted as if read. Hunt for real catalog model-name tokens or
   plausible plate words within the tolerances of some brand token (the 4–5 char / ≤1
   edit band especially: e.g. is any brand token one edit from a common English or
   equipment word that is NOT in the catalog vocabulary — "hoist" vs "moist"/"joist",
   "cybex" vs …, "matrix", "rogue" vs "rouge", "keiser" vs "kaiser", "nautilus",
   "precor" vs "precut"?). The refusal only covers words the CATALOG knows. Grade the
   exposure with the actual manufacturer list (SeedCatalog.json) — enumerate brand tokens
   of 4–6 chars and say which are one edit from a word a plate could carry.
2. **The stray-character strip**: `dropFirst`/`dropLast` around an exact brand token —
   what about a token that is a brand token plus a legitimate letter (a model code that
   embeds a brand? "hoists"? plural/possessive?). Is anything in the catalog's own
   vocabulary caught (the invariant test says no — check the test is actually strong).
3. **The glued split**: `isKnown` covers every catalog token including single letters
   and numbers — with minimumSplitHalfLength 3 that is bounded, but check for a
   catalog-word pair that a REAL unknown word (a genuine new model name) would split into,
   corrupting a create-new name. The "exactly one way to cut" rule — is it actually
   exact-one, or first-found?
4. **Prefix-sibling exception**: is exactlyCovered computed correctly (exact pass only,
   fuzzy contributions excluded, tokens consumed once)? Same-manufacturer check uses the
   display string — fine? Any pair of catalog rows (grep the catalog) where the
   distinguishing tokens are ≥3 chars but are plate FURNITURE words (e.g. a row named
   "X Series" vs "X" where "series" is on every plate) that would now preselect the longer
   row over a plate that only names the shorter machine? The runner-up only ties when
   scores are within 0.08 — enumerate real strict-subset pairs in SeedCatalog and reason.
5. **repairedText styling**: words with mixed punctuation (`ISO-LATERAL` → tokens
   `iso`,`lateral` — if either were repaired, the hyphen is lost; acceptable?), and a
   word whose tokens repair to MORE words — does the create-new model-name guess still
   pick the right line by heightFraction?
6. **The sheet**: Results.reading raw, guesses repaired — verify `present` on every path
   (live settle, still photo, fixture) and that `consider`'s settle key (rank's top row)
   benefits from repair without changing the stabilizer's contract.
7. **Harness + reports**: are the three committed reports consistent with the ticket's
   table; does the harness still pass silently with no photos; is the vocabulary hook
   truly nil on every app path (grep) and is `nonisolated(unsafe)` justified?
8. **Absence of a caller / false claims**: every new identifier used? Every claim in both
   commit messages and the ticket true, including test counts?

Report by severity with file:line, do not soften. Do not modify source files. Write to
work-record/scanner-accuracy/codex-review-02.md
