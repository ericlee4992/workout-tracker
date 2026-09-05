# 01 — Plate corpus and the accuracy harness

Status: resolved — baseline measured 2026-09-05 (harness + 41-photo corpus)

## What to build

**Corpus.** `.scratch/scanner-accuracy/corpus/` — photos gitignored, `manifest.json` committed.
One entry per photo: `file`, `source` (URL or "user gym"), `brand`, `model` (as printed on the
plate), `catalogModel` (the catalog row's display name it SHOULD resolve to, or null when the
catalog has no row — then the right answer is "create new"), `notes` (logo-only brand, worn,
glare, angle…). Target 40–60 online photos across the brands the catalog covers, biased toward
worn plates from dealer/resale listings; the user adds gym photos separately.

**Harness.** `WorkoutTrackerTests/ScannerCorpusHarness.swift`: reads the manifest, runs
`MachineLabelOCR.read` (the app's exact Vision configuration) and `CatalogMatcher.rank` against
the shipped catalog index for every photo, and writes
`.scratch/scanner-accuracy/reports/latest.md` with a per-photo row (read text, top candidate and
score, preselected?, right?, would-suggest-create-new?) and totals: top-1 right, preselected
right, **wrong preselections** (the D33 cardinal sin), and create-new agreement. When the corpus
folder holds no photos (CI, a fresh clone) it passes with a note and writes nothing.

## Acceptance criteria

- The harness runs under `-only-testing:WorkoutTrackerTests/ScannerCorpusHarness` and produces
  the report; the full unit suite stays green with and without photos present.
- `manifest.json` has ≥ 40 labelled online photos, every label checked by eye against the image.
- The first report is committed as the baseline, with its numbers copied into this ticket.


## Resolution (2026-09-05)

**Corpus: 41 photos**, all from a used-equipment dealer's galleries (gymequip.eu — real worn
machines photographed on a phone) plus a handful from Bing image search; 12 name a machine the
catalog has, 29 are logo-only frames, model-number serial plates or machines the catalog lacks.
Brands: Cybex, Hammer Strength, Hoist, Life Fitness, Precor. Still missing: Matrix, Technogym,
Nautilus, and anything from the user's own gym. Manifest committed, photos gitignored (verified).

**Harness** (`WorkoutTrackerTests/ScannerCorpusHarness.swift`): ~56 s for 41 photos in the
simulator, writes `reports/latest.md`, passes silently without photos.

### Baseline (`reports/latest.md`, first run)

| Metric | Value |
|---|---|
| Top-1 right (of 12 in catalog) | 7 |
| Preselected right | 3 |
| **Wrong preselections** | **0** |
| Create-new suggested when the row is absent (of 29) | 28 |
| Nothing read at all | 1 |

### What the rows say — the user's complaint, measured

- **Brand logos come back as corrupted brand tokens, and the matcher then treats the brand as
  absent.** Cybex's swoosh reads as a letter: `SCYBEX`, `OCYBEX`, `OLУBЕN`. Hammer Strength's
  badge: `LAMMED / STRENGTH`, `YAMMER / RENGTH`, `WUH / STRENCTH`. Life Fitness's script:
  `LieFitness`, `LifeFiness`, `LifeFilness`, `LiTTes`. Hoist: `HOISI`. `manufacturerMatched` needs
  the exact token, so a Cybex plate read as SCYBEX can NEVER preselect — three of the nine
  "top-1 right, not preselected" cases are this (Low Row read cleanly at 100% but the D33 margin
  failed; Assist Dip/Chin ×2 at 45% because `DIP/CHIN` reads as `DIPICHIN`; Tibia at 55%).
- **Rotated text loses words.** The Wide Pulldown placard at ~45° read `ISO-LATERAL / PULLDOWN`
  without WIDE → top-1 Iso-Lateral Row (67%). Wrong top-1, correctly not preselected.
- **A brand misread hands the row to another brand.** `HOISI` + `HACK SQUAT` → Watson PL Hack
  Squat (61%); the ROC-IT sticker → Nautilus Hack Squat (61%). Both wrong top-1, neither
  preselected — the D33 gate did its job, at the cost of the tap.
- **Serial plates and instruction paragraphs are noise the matcher partly absorbs**: dense
  serial text on Cybex plates scores random rows at 36–49% (Nautilus 5 Station, Rogue Monster
  Cave), all correctly "create new".
- **One near-miss worth a rule:** Ground Base Combo INCLINE (not in catalog) → Ground Base Combo
  TWIST at 78%, and create-new was NOT suggested. Not a wrong preselect, but the top row is a
  sibling the user could tap by mistake.
- The one "nothing read" is a whole-machine shot with a tiny placard — a framing problem the
  capture-first box addresses.

### What this says about the plan

The levers in `spec.md` are the right ones, and the evidence orders them: **brand-token
tolerance first** (a vocabulary for Vision and/or a fuzzy brand match with the swoosh/script
corruptions above as test cases), then the `/`-as-`I` class of symbol confusions, then rotation
(capture-first with a framing box — the user holds the plate square), then the serial-plate /
paragraph junk filter. Precision is already right (0 wrong preselections); the work is recall.
