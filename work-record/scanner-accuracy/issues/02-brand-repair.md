# 02 — Repair what the camera did to the brand (and the slash)

Status: resolved — Codex clear after 4 rounds (codex-review-02..02d)
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

- **Brand repair** *(amended after codex-review-02/02b — the first wording let prose manufacture
  brands)*. Only a line that is nothing but one brand, tokens in order — or the same brand over
  two consecutive lines — is repaired: a stray LEADING character before an exact brand token is
  stripped (`scybex` → `cybex`); otherwise an edit repair of one letter, or two for a token of
  ≥ 7 letters or one corroborated by the brand's other word (`hoisi` → `hoist`, `strencth` →
  `strength`); a glued script logo is split back (`liefitness` → `life fitness`). Refused when
  the token is a known catalog word, shorter than 4, an ENGLISH WORD (spell checker; without a
  dictionary no edit repair, glued repair or split at all), is longer than the brand token, or when
  two brands fit; and a line with a digit in any unknown token is a code line that NO path — strip,
  edit, glued — turns into a brand, Gym80 included. Accepted cost: `LAMMED`, `YAMMER` (words to the
  checker), trailing junk (`CYBEXS`) and digit misreads (`CYB3X`, `GYM8O`) stay as read.
- **Slash repair** *(amended)*. An unknown, non-word token that splits at an interior `i`/`l`/`1`
  into two known words that sit together in ONE catalog row's name becomes those words
  (`dipichin` → `dip chin`). No separator-less split (`dipchin` stays).
- **No prefix-sibling exception** to the D33 margin: tried twice, leaked twice, removed.
- The sheet's echoed text stays the RAW reading; repair changes what is matched, not what the
  user is shown as read.

**Vision vocabulary experiment**, measured not assumed: supplying the catalog's tokens as
`customWords` (which requires `usesLanguageCorrection = true`, the thing the OCR path disabled
because correction rewrote codes like `VSL019BP`). Run the harness both ways; keep it only if
the corpus says so, and record the numbers either way.

## Acceptance criteria

- Unit tests with the exact corruptions above as inputs, plus refusals (a known word, a short
  token, an ambiguous one, an English word, a digit-bearing code, prose, wrong order, real
  compounds) and a full-catalog check that repair never changes any catalog row's own line.
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

## Resolution (2026-09-05) — SUPERSEDED by the rebuild below; kept as the record of the first cut

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


## Codex review 02 — response (2026-09-05)

`codex-review-02.md`: **not clear** — 1 critical, 2 high, 2 medium, 1 low (spec), 2 standards.
All real; the critical and both highs were design holes, not slips, so the repair was rebuilt:

- **Brand repair manufactured brands from prose (critical).** `MOIST CHEST PRESS RS-2301` became a
  Hoist plate and preselected; `PRICE FITNESS` → PRIME Fitness; `START TRACK` → Star Trac;
  `RECORD` → Precor. Three rules now, each closing one of those: (1) a brand is repaired ONLY on a
  line that is nothing but that brand, tokens in order — a logo reads as a lone word on its own
  line, prose never does (`MOIST CHEST PRESS` untouched); (2) an edit repair is refused when the
  misread token is an English word — UIKit's spell checker injected into Domain as a closure
  (`MachineLabelDictionary`), and with NO dictionary no edit repair is made at all (`PRICE`,
  `MOIST`, `START`, `RECORD`, `METRIC` untouched); (3) a token is never shortened to a brand
  (`START` ≠ `star`, `HAMMERS` ≠ `hammer`), only a LEADING stray character is stripped, and two
  edits need a long token or a corroborating second word of the same brand. Cost, measured and
  accepted: `LAMMED` and `YAMMER` are English words to the checker, so those two badges stay as
  read; both are brand-only photos with nothing to preselect.
- **Furniture words unlocked the prefix sibling (high).** `Impact Lat Pull Down` + a lone `FIXED`
  preselected the Fixed row; an instruction saying "seated" preselected Seated Leg Curl. A
  distinguishing word must now be read on a NAME LINE: a line made only of the row's own words
  AND carrying at least two of its name words (`CatalogMatch.nameLineTokens`). Test with Codex's
  three constructions (Nautilus, Life Fitness, Eleiko) plus the positive case.
- **Separator-less split mangled compounds (high).** `AIRLIFT`, `FACEPLATE`, `COUNTERWEIGHT`… A
  split now needs the slash-confusion character AND both halves in ONE catalog row's name
  (`CatalogMatchIndex` precomputes the pairs). Test: Codex's 13 compounds all untouched.
- **Vocabulary hook (medium ×2).** Deleted from production and the harness; the result stays
  recorded here and in the OCR comment. The `SCANNER_VOCAB` env-name mismatch dies with it.
- **Punctuation inside a repaired word (medium).** Repair now works on alphanumeric runs and
  copies every other character through verbatim, so double spaces, tabs, hyphens and slashes
  survive; `HOISI-RS-2403` is a code line, not a brand line, and is left alone. Test.
- **Stale counts (low), dead `Brand.name`/`brands`/`Equatable` (standards low).** Removed with the
  rewrite; counts below are from the tip.
- Also from the rewrite: a multi-word brand set over two consecutive lines (`HAMMER` / `STRENCTH`)
  is repaired as one brand line — the corpus's actual shape.

Codex's other numbers: it enumerated 130 same-maker strict-subset pairs passing the ≥3-char rule
and 62 that tie inside the margin under an exact reading. With the name-line clause, an exact
reading of the LONGER row's name is exactly the case that should preselect it; the exposure was
the shorter plate plus a stray word, which the clause closes.

**After the rebuild** (`reports/after-ticket-02b-2026-09-05.md`): top-1 **8**/12 (up one — the
corroborated split), preselected right **6**/12, wrong preselections **0**, create-new 28/29.
**674 unit green** (harness included; 15 repair tests, 3 sibling tests), ScanMachineLabel UI 2/2
— all read from the log's `** TEST SUCCEEDED **`.


## Codex review 02b — response (2026-09-05)

`codex-review-02b.md`: **not clear** — 1 high, 4 medium, 1 low (spec); 1 medium, 1 low
(standards). All addressed:

- **The prefix-sibling exception (high) is REMOVED.** Codex's second-round constructions
  (`FIXED PULL`, `SEATED LEG`, `FITNESS RACK` as a stray second line) beat the name-line rule, and
  a genuine `SEATED` on its own line was wrongly blocked. Layout is not provenance; two cuts leaked
  two ways. D33's rule stands — a near-tie is an ambiguity the user's tap resolves — and the
  matcher comment says why. Cost: preselected-right **6 → 5** (the Low Row tie). The three tests
  are replaced by one pinning the tie as unpreselected and Codex's constructions as unpreselected.
  This also removes the per-entry `Set(entry.tokens)` allocation in the hot path (standards medium).
- **Digit-bearing tokens (medium).** A token with a digit is a code, never a misread logo:
  `CYB3X`, `PR1ME`, `PREC0R`, `MATR1X` stay as read (Gym80's own digits excepted). Tests.
- **Ticket not amended (medium).** "What to build" and the acceptance criteria now state the
  rules as built, including the accepted costs (`LAMMED`/`YAMMER` are words; trailing junk stays).
- **Split still mangled `MIDLAND`/`ROWLAND` (medium).** The dictionary refusal applies to splits
  too. Tests.
- **Two-line pass lost punctuation (medium).** Both lines now go through the same run-splicing
  as a single line: `HAMMER-` / `(STRENCTH)` → `HAMMER-` / `(STRENGTH)`. Test.
- **Ticket-03 draft in the repair commit (low).** Acknowledged; it stays where it is (docs only)
  and future ticket drafts go in their own commits.
- **Dead `brandTokens` (standards low).** Removed.

Final on the corpus (`reports/after-ticket-02c-2026-09-05.md`): **top-1 8/12, preselected right
5/12 (from 3), wrong preselections 0, create-new 28/29.**


## Codex review 02c — response (2026-09-05)

`codex-review-02c.md`: 1 medium, 2 low. All closed:
- **Digit refusal bypassed by the strip and glued paths; Gym80 exempt (medium).** The rule now
  sits at the top of `repairedBrandLine`: a digit in any unknown token makes the line a code line
  and no path repairs it — `1CYBEX`, `0CYBEX`, `LIFEFITN3SS`, `GYM8O` added to the test, all stay.
  The ticket's wording drops the Gym80 exception.
- **Source comments described rejected rules (low).** Header, `isDictionaryWord` doc and the
  inline examples now cite `HAMMER STRENCTH`, name `LAMMED`/`YAMMER` as accepted costs, and say
  that without a dictionary only the strip remains.
- **Stale Resolution (low).** Marked SUPERSEDED; the current result is this section:

### Resolution, current (2026-09-05, after three Codex rounds)

`Domain/MachineLabelRepair.swift`: brand-line-only repair (single line, or the same brand over
two consecutive lines), leading-character strip, dictionary- and digit-refused edit repairs,
glued-brand split, corroborated slash split; only repaired runs are rewritten. Built once per
`CatalogMatchIndex` with `isDictionaryWord` (UIKit's checker via `Features/Gyms/
MachineLabelDictionary.swift`; the sheet, the harness and the repair tests all supply it);
applied in `CatalogMatcher.rank`; the sheet's create-new guesses read the repaired plate, the
echoed text stays raw. No prefix-sibling exception; no vocabulary hook. Tests: 15 repair, 1
sibling-tie pin, corpus harness. **Corpus: top-1 8/12, preselected right 5/12 (from 3), wrong
preselections 0, create-new 28/29.**


## Codex review 02d (2026-09-05)

`codex-review-02d.md`: **clear.**
