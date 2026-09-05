# 02 — Repair what the camera did to the brand (and the slash)

Status: built — awaiting Codex review
Blocked by: 01

The baseline's dominant failure, in the user's words the misreads they get at the gym: a brand
logo comes back as a corrupted token — `SCYBEX`, `OCYBEX`, `LAMMED STRENGTH`, `YAMMER RENGTH`,
`WUH STRENCTH`, `LieFitness`, `LifeFilness`, `HOISI` — and `manufacturerMatched` needs the exact
token, so preselection is impossible even when the model name read perfectly. Second: a slash
reads as I (`DIP/CHIN` → `DIPICHIN`), gluing two known words into one unknown one.

## What to build

A pure **reading repair** step, owned by the catalog index because it is the index that knows the
vocabulary, applied inside `CatalogMatcher.rank` (so every caller benefits) and exposed for the
create-new brand guess:

- **Brand repair.** A reading token the catalog does not know is compared against every
  manufacturer token of ≥ 4 characters and against each multi-word brand's glued form
  (`lifefitness`, `hammerstrength`): a single stray leading/trailing character is stripped when
  the rest is exactly a brand token (`scybex` → `cybex`); otherwise edit distance ≤ 1 for 4–5
  letters and ≤ 2 for ≥ 6 (`hoisi` → `hoist`, `lammed` → `hammer`, `rength` → `strength`); a glued
  form is split back into its words (`liefitness` → `life fitness`). Refused when the token is a
  known catalog word (`row` is never a brand misread), when it is shorter than 4, or when two
  different brands are equally near (ambiguity is left alone).
- **Slash/glue repair.** An unknown token that splits, at an interior `i`/`l`/`1` or with no
  separator at all, into two known catalog words of ≥ 3 characters becomes those two words
  (`dipichin` → `dip chin`).
- The sheet's echoed text stays the RAW reading; repair changes what is matched, not what the
  user is shown as read.

**Vision vocabulary experiment**, measured not assumed: supplying the catalog's tokens as
`customWords` (which requires `usesLanguageCorrection = true`, the thing the OCR path disabled
because correction rewrote codes like `VSL019BP`). Run the harness both ways; keep it only if
the corpus says so, and record the numbers either way.

## Acceptance criteria

- Unit tests with the exact corruptions above as inputs, plus refusals (a known word, a short
  token, an ambiguous one) and a full-catalog check that repair never changes a token of any
  catalog row's own name (the self-recognition invariant stays intact).
- The harness on the same 41 photos: preselected-right up from 3, wrong preselections still 0,
  create-new agreement not worse than 28/29. Numbers copied here, before and after.
- Existing `CatalogMatcherTests` / OCR tests green; full unit suite green.
- Codex clear.


## Measurements (2026-09-05)

| Run | Top-1 right /12 | Preselected right /12 | Wrong preselect | Create-new /29 |
|---|---|---|---|---|
| Baseline (`reports/baseline-2026-09-05.md`) | 7 | 3 | 0 | 28 |
| + reading repair | 7 | **5** | 0 | 28 |

The two gains are the Assist Dip/Chin plates: `DIPICHIN` → `dip chin`, 45% → 85%, preselected.
`SCYBEX`/`OCYBEX` now read as Cybex (create-new proposes "Cybex" instead of "SCYBEX"); `HOISI`
became Hoist, which correctly demoted Watson's hack squat (61% → 37%, brand conflict) but the
Hoist row itself did not rise — the photo's model code never read. Still not preselected:
- Low Row at 100%: the D33 margin against plain Iso-Lateral Row (a prefix sibling) — a matcher
  rule, not a read problem; candidate for a "contained sibling" exception.
- Tibia at 55%: the plate says TIBIA, the row says Plate Loaded Tibia Dorsi-Flexion. Inherent.
- Wide Pulldown: WIDE lost to rotation (ticket 03, capture-first).

| + Vision vocabulary (custom words, correction ON) | 7 | 5 | 0 | 28 |

**Vocabulary: no measurable gain, kept OFF.** Individual reads improved (`HOISI` → `HOIST`,
`STRENCTH` → `STRENGTH`, `LifeFilness` → `Life Fitness`) but every one of those the repair
already handles, so the totals did not move — and correction also rewrote junk into dictionary
words (`BRACHIT` → `BRIGHT`, `hwea Yealiny` → `we reality`), which is the behaviour that would
eat a user-created model code the vocabulary does not contain. The hook
(`MachineLabelOCR.vocabulary`, nil in the app; `TEST_RUNNER_SCANNER_VOCAB=1` in the harness)
stays so the experiment can be re-run when the corpus grows.

| + prefix-sibling exception in `preselection` | 7 | **6** | 0 | 28 |

**Prefix sibling (added from the rows).** `ISO-LATERAL LOW ROW` read perfectly at 100% and was
never preselected because plain `Iso-Lateral Row` — a strict subset of its name, same maker —
tied it inside the D33 margin. `CatalogMatch` now carries `nameTokens` and `exactlyCovered`, and
`preselection` skips the margin only when the runner-up is a strict-subset sibling of the same
manufacturer, the best row's name was read EXACTLY (no fuzzy claim), and every distinguishing
word has ≥ 3 characters. That last clause came from the existing adversarial test: `Rack & A
Half` vs `Half Rack` differ by the token `a`, and a stray one-letter token is exactly what a
logo reads as, so the first cut of the rule preselected the wrong Sorinex rack. Two tests added;
the Sorinex case is asserted in both.

## Resolution (2026-09-05)

`Domain/MachineLabelRepair.swift` (brand-token repair, glued-brand split, slash/glue split;
every rule refuses known words, short tokens and ambiguity), built once per `CatalogMatchIndex`
and applied inside `CatalogMatcher.rank`; the sheet's create-new guesses read the repaired
plate while the echoed text stays raw. `CatalogMatch.nameTokens` / `exactlyCovered` and the
prefix-sibling exception. `MachineLabelOCR.vocabulary` experiment hook (nil in the app).

Tests: `MachineLabelRepairTests` (11: every corpus corruption, refusals, ambiguity, splits, the
full-catalog "no row's own token is ever repaired" invariant, three through the matcher),
2 in `CatalogMatcherAdversarialTests`. **669 unit green** including the harness.

Final on the 41-photo corpus: **top-1 7/12 (unchanged), preselected right 3 → 6, wrong
preselections 0, create-new 28/29.** Reports: `baseline-2026-09-05.md`,
`after-repair-2026-09-05.md`, `after-ticket-02-2026-09-05.md`. What remains is not a brand
problem: rotated text losing a word (ticket 03), model codes too small to read, a Swedish plate,
and a plate that only says TIBIA.

**Defect caught by the UI suite after the first commit (`197ba91`), whose message wrongly says
the scan class was green — it was red and I read the notification before the log.**
`testCreateNewFromAScanPrefillsTheModelSheet`: the create-new prefill came from the repaired
reading, which was fully normalised, so "Insignia Series Chest Press" arrived as "insignia
series chest press". `repairedText` now rewrites ONLY the words it repaired, each in the case
style of the word it replaces, and leaves every other word exactly as read. Test added
(`untouchedWordsKeepTheirCaseAndPunctuation`). Lesson for the record: a background test run's
"completed (exit code 0)" is the SHELL's exit code, not the test's — read the log's last line.
