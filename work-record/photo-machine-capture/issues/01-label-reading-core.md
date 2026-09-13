# 01 — Label reading core: OCR, matcher, model-name guessing

Status: resolved
Blocked by: —

All the logic, none of the UI. The matcher is pure and gets the hard tests; the Vision wrapper is
thin enough to trust once an end-to-end test proves it reads a rendered label.

## Files

- `WorkoutTracker/Domain/MachineLabelText.swift` — `LabelReading` (lines + confidence + relative
  height), normalisation, tokenisation, and the manufacturer/model-name guess. Pure.
- `WorkoutTracker/Domain/CatalogMatcher.swift` — `CatalogMatchIndex` (built once from the catalog,
  carries IDF weights) and the ranking. Pure.
- `WorkoutTracker/Domain/MachineLabelOCR.swift` — `VNRecognizeTextRequest` wrapper returning a
  `LabelReading`. Imports Vision; imports no UI.
- `WorkoutTrackerTests/CatalogMatcherTests.swift`, `WorkoutTrackerTests/MachineLabelOCRTests.swift`

## Acceptance criteria

- [x] Matching is **pure and deterministic**: same reading + same index → same ranking, ties broken
      totally (score, then name, then id).
- [x] Real catalog rows are found from realistic readings: all-caps plates, the manufacturer on its
      own line, line order scrambled, and single-character OCR errors (`Insigma`, `lnsignia`,
      `HAMIER STRENGTH`).
- [x] Junk on the plate does not sink the match: `MAX 300 LB`, `READ MANUAL BEFORE USE`, serial
      numbers, and duplicated warning text.
- [x] A plate for hardware the catalog does not have scores **below the create-new floor** — a
      confident wrong answer is worse than no answer (D33/D4).
- [x] Two different models from the same manufacturer (Insignia Chest Press vs. Insignia Shoulder
      Press) rank in the right order; the loser still appears as an alternative.
- [x] IDF weighting is real: a reading of only common words ("SERIES PRESS") matches nothing
      confidently.
- [x] Index build over the full 1877-row seeded catalog, plus a ranking, completes fast enough to
      run inline on a tap (assert a loose bound; the point is catching an accidental O(n²)).
- [x] The manufacturer guess returns the catalog's **canonical spelling** when the plate names a
      known manufacturer, and the model guess drops junk lines.
- [x] `MachineLabelOCR` reads a label rendered in the test itself (Core Graphics → `CGImage`) and
      the matcher picks the right catalog row from it — the one test that proves the whole chain.
- [x] No UI import in `Domain/`; no network call anywhere.

## Resolution (2026-08-11)

`Domain/MachineLabelText.swift` (reading value type, normalisation, junk-line and name guessing),
`Domain/CatalogMatcher.swift` (IDF-weighted index + ranking), `Domain/MachineLabelOCR.swift`
(Vision). Tests: `CatalogMatcherTests` (21 cases) and `MachineLabelOCRTests`, which renders a name
plate with Core Graphics and runs the whole chain — pixels → Vision → matcher → catalog row.

Two things worth knowing:

- **Coverage is measured over the model name, not the whole row.** Counting manufacturer tokens
  in the denominator let "Insignia Series Row" score 86% on a plate that plainly said Chest Press,
  purely because it shared "Life Fitness Insignia Series". Name-only coverage plus a separate
  brand bonus puts the right row at 100% and its stablemates at 75–79%.
- **The confident bar is 0.85, above that stablemate band** — deliberately, so a misread of the one
  distinguishing word cannot preselect a sibling. `onlyTheRightRowClearsTheConfidentBarAmongItsStablemates`
  locks that in against the real 1877-row catalog.

## Codex cross-review round 1 (2026-08-11)

`codex-review.md` — verdict "do not merge", four **critical** ways to preselect a confidently
wrong catalog UUID, all reproduced against the shipped 1877-row catalog and all fixed here:

1. `NEWCO PENDULUM SQUAT` scored **0.97** against *Nautilus* Pendulum Squat — words the catalog
   has never seen weighed nothing. Unseen words now count as maximally distinctive, a plate that
   names a *different* known brand costs the row 40%, and preselection requires the row's own
   manufacturer to be named.
2. `NAUTILUS 5 STATION` tied 4/5/9 Station at 1.00 — the tokenizer dropped single characters.
   Catalog tokens now keep everything (`R-4` vs `R-6`, PRIME `2:1` vs `4:1`); only the *photo*
   side drops lone letters. A test asserts no two shipped rows share a matcher identity.
3. A short generic row (`Back Extension`) tied the longer specific one it is contained in, and a
   photo of two machines tied both. Explanation of the plate's own evidence now carries 30% of the
   score, and preselection needs 0.08 of daylight over the runner-up.
4. One recognised word could be evidence for two catalog words — "abduction" fuzzy-covering
   "adduction". Fuzzy assignment is now one-to-one, and two words the catalog both knows are never
   treated as a misreading of each other.

Also fixed: non-deterministic scores from summing an unordered `Set` of floats (findings 7),
and the brand guess searching the whole photo instead of the brand line (finding 9).
`CatalogMatcherAdversarialTests` replays every case above against the real catalog.

## Codex cross-review round 2 (2026-08-11)

`codex-review-2.md` — verdict "do not merge" again, and right again. The round-1 gate held (no
NEWCO/MATRIX/Atlantis preselection), but the round-1 *fix* had recreated the identity bug from the
other side: dropping lone letters on the photo side dissolved `T-Bar`, `D.Y.`, `CMJ-6600-S` and
`Rack & A Half`, so four clean readings of shipped rows preselected the wrong UUID. Both sides now
tokenize identically.

Also fixed here: junk detection matched substrings, so `min` inside `Abdominal` and `rev` inside
`Reverse` classified **73 shipped model names** as plate furniture (now token-boundary matching);
`manufacturerConflicts` allowed a *second* known brand through D33's "and no other known one"
clause; create-new did not lead for hardware the catalog lacks but whose name it has (now gated on
how much of the plate the best row explains); and fuzzy matching could consume a word a later token
would have matched exactly (exact matches are now reserved in a first pass).

The invariant that would have caught all of it, and now guards it:
`everySampledCatalogRowRecognisesItself` reads each sampled row's own canonical name back through
the photo-side tokenizer and requires it to rank itself first and preselect nothing else.
