# Photograph a machine's name plate to identify it

Written 2026-08-11, at the user's request after milestone 3 merged. Not one of the numbered v1
milestones — a feature that arrived from real gym use, which `docs/STATE.md` says outranks the
backlog.

## The ask, in the user's words

> being able to take a picture of the machine name (when adding machine) and the app either
> automatically finds the machine from the database or creates a new machine if it doesn't exist

## What that means in this app's taxonomy

Adding a machine already creates a `MachineInstance`. What the photo is really identifying is the
**equipment model** — the catalog row (`EquipmentModel`) that names the hardware and links it to
exercises. So:

- **"finds the machine from the database"** → matches the name plate against the 1877 seeded
  catalog models and fills in `Catalog model` on the New Machine sheet.
- **"creates a new machine if it doesn't exist"** → creates a **user-created model**
  (`isSeeded == false`, its own ID space per D4) prefilled with the manufacturer and model text
  the camera read, and attaches it to the machine being added.

The machine instance itself is created by the sheet the user is already in; the scan only fills
in the two fields that are otherwise tedious to type at a gym: the model, and the label.

## Decided up front (user, 2026-08-11)

- **A scan never assigns a catalog identity on its own.** The sheet shows what the camera read
  plus the ranked candidates, preselecting the top one only when the score, the manufacturer and
  the margin over the runner-up all agree; one tap accepts it. → **D33**.
  Rationale: D23 keys history, prefill and PRs on the model UUID, so a confidently-wrong match
  silently splits the user's own history — the exact failure D4 was amended for. OCR on a scuffed,
  angled, back-lit name plate misreads more than it looks like it will.
- **The photo is read and discarded.** No image is persisted, so no schema change, no storage
  growth, nothing new in the export or a future CloudKit sync. → **D34**.
- Unmatched scans produce a **user-space** model, never a row that looks seeded. → **D35**.

## How it works

```
[New Machine sheet] → "Scan label…"
   ↓ camera (or photo library when there is no camera — Simulator, or a photo taken earlier)
[Vision VNRecognizeTextRequest, on device, offline]
   ↓ lines of text + confidence + relative height
[CatalogMatcher — pure, IDF-weighted token scoring against the catalog]
   ↓ ranked candidates
[Result sheet]  ✓ top hit preselected (when unambiguous)  ·  alternatives  ·  "create new"
   ↓
model filled into the New Machine sheet (and the label defaulted, as picking a model already does)
```

### Reading the label (`Features/Gyms/MachineLabelOCR.swift`)

Vision's `VNRecognizeTextRequest`, `.accurate`, language correction **off** — "Insignia",
"Hammer Strength" and "Cybex" are not dictionary words and correction does more harm than good on
them. Each line keeps its confidence and its height as a fraction of the image, because the model
name is almost always the largest text on a name plate and the manufacturer sits above it.

The photo's orientation tag is passed to Vision — a camera image is almost never `.up`, and both
recognition quality and the top-line ordering depend on it. Library photos backed by a `CIImage`
(HEIC, edited) are rendered rather than rejected.

First-party, on-device, offline: no new dependency, and it works in a basement gym with no signal.
It lives in `Features/Gyms` rather than `Domain/` because it orchestrates a platform framework and
speaks `UIImage`; `LabelReading` and the matcher stay in `Domain`, testable without a camera.

### Matching (`Domain/CatalogMatcher.swift`, pure)

1. Normalise both sides: case-fold, strip diacritics and punctuation, collapse whitespace.
2. Weight every token by **IDF across the catalog itself**, computed once when the index is built.
   Single characters are tokens too, **on both sides**: `4 Station` vs `5 Station`, `R-4` vs `R-6`,
   PRIME `2:1` vs `4:1`, Hoist `CMJ-6600-S`, Sorinex `Rack & A Half`. 88 shipped names turn on one.
   Dropping them on the photo side alone silently recreated the bug from the other direction —
   `T-Bar` and `D.Y.` dissolve into lone letters, and plain `Iso-Lateral Row` then explained
   everything that was left.
   "series" and "press" appear in hundreds of rows and say little; "insignia", "sorinex" and
   "vsl019bp" are nearly unique and say almost everything.
3. Score each catalog row by the weighted share of its **model-name** tokens the reading covers,
   allowing an edit distance of 1 (short tokens) or 2 (long tokens) so `Insigma`, `lnsignia` and
   `INSIGNIA` all land on the same row. One recognised word may serve as evidence for exactly one
   catalog word, and two words the catalog both knows are never treated as a misreading of each
   other — "adduction" is not "abduction", it is the next machine along.
4. Bonus when the row's manufacturer appears in the reading; small credit for explaining the
   reading's own distinctive tokens (only small — name plates are full of "MAX 300 LB",
   "READ MANUAL BEFORE USE" and serial numbers that no model name will ever explain).
5. Return the top candidates above a floor, each with a 0–1 score the UI shows as a percentage.

**Preselection needs three things at once**, because the first cross-review found four ways to be
confidently wrong with only a score (`codex-review.md`):

1. score ≥ **0.85**;
2. the plate **names this row's manufacturer and no other known one** — an unknown, contradicting,
   or second brand cannot be waved through (a plate reading `NEWCO PENDULUM SQUAT` scored 0.97
   against *Nautilus* Pendulum Squat before this; a plate naming two brands is a photo of two
   machines);
3. the runner-up is at least **0.08** behind — a near-tie is an ambiguity to show, not a coin flip
   to resolve. Two machines in one photograph, or a short catalog name contained in a longer one,
   both produce ties.

**Create-new leads** — the action, not just the wording — when the score is below 0.35, when the
plate names a different known brand, or when the best candidate explains less than 80% of what the
plate said. That last rule is what catches hardware the catalog does not carry but whose *name* it
does: `NEWCO PENDULUM SQUAT` matches Nautilus's pendulum squat word for word, and the only thing
saying otherwise is the word NEWCO that nothing explains. Weak candidates stay listed below,
labelled as weak.

Scoring is `0.60 × name coverage + 0.30 × how much of the plate the row explains + 0.10 ×
manufacturer named`, times 0.6 when the plate names a different known manufacturer. Words the
catalog has never seen count as maximally distinctive rather than free — otherwise an unlisted
brand costs a row nothing.

### Creating a model from the reading

When nothing matches, the reading is parsed into a manufacturer guess (a known catalog
manufacturer found in the text wins, in its canonical spelling; otherwise the top line) and a
model-name guess (the largest remaining line, junk lines dropped — load ratings, warnings, serial
numbers). Both are editable before saving: the app proposes, the user decides.

### What this costs, stated plainly

Requiring the brand means a plate whose brand strip is worn, cropped, or simply absent — many
machines put the badge on the frame, not the plate — **never** preselects, even when the right row
is first at 0.90. The candidates are still listed and one tap picks the right one, so the cost is a
tap; the alternative cost is a wrong UUID in the user's history. Measured against the shipped
catalog by the round-2 review: a clean reading of brand + model name preselects correctly for
**95%** of rows, and a model name alone for **0%**, by design.

## Explicitly not in this feature

- Recognising the *machine* (which of the three chest presses this is) — that is the user's label.
- Reading weight stacks, plate counts or QR/serial codes.
- Scanning from the logging flow (Add by Machine). Same core will serve it later if wanted.
- Storing or exporting photos (D34).
- Any network call. Nothing leaves the phone.

## Tickets

```
01 label-reading-core  — Vision reader + pure matcher + model-name guessing, unit-tested
└── 02 scan-ui         — "Scan label…" in the New Machine sheet, capture, results, create-new
    └── 03 verification — XCUITest through a fixture image, docs, decisions D33–D35
```
