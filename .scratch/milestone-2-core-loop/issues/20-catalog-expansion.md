# 20 — Expand the seeded equipment catalog

**What to build:** The shipped catalog is 24 models across 8 manufacturers — labelled a *test
fixture* in ticket 04, with the real content task deferred (D4: "major brands, popular lines",
order of a few hundred models). That deferral is now the binding constraint: the user is about to
walk into a gym and, per D3, gyms and machines are always user-created, so a thin catalog means
typing manufacturer and model by hand for every machine on the floor. Expand it so most commercial
gym equipment is already there.

**Blocked by:** None. Runs against ticket 04's versioned reconciler (D24), so shipping a bigger
catalog is a version bump, not a migration.

**Status:** resolved

## Accuracy is the whole point

This catalog is a list the user *picks from* to describe real machines in front of them. A
plausible-sounding but non-existent model is worse than an absent one: it silently becomes the
identity that history, records, and the same-model-elsewhere layer are keyed on (D23).

- [x] **Every model name must be verifiable from the manufacturer's own product listing —
      restated (codex-review-4): from the manufacturer's own listing *or* an authorised
      dealer's listing carrying the manufacturer's SKU codes.** No inventing, no "probably
      exists", no extrapolating a naming pattern to models not seen. Dealer-sourced brands are
      named in `docs/catalog-sources/README.md`: Atlantis Strength (all 68 rows), Arsenal
      Strength, Impulse Fitness, Panatta, and three Star Trac rows. Six version-1 fixture names
      remain uncorroborated by any source and are listed there row by row; they keep their
      names because the UUID, not the string, is what history is keyed on (D23).
- [x] Where a line is known but individual model names are not, seed the *line* only — do not
      fabricate members. (In practice: nothing was seeded for such lines — see the "not
      enumerated" list in `docs/catalog-sources/README.md`.)
- [x] Record where each manufacturer's data came from, so the next expansion can be audited.
      The three research files live in `docs/catalog-sources/` with a README indexing them.

## Scope

- [x] Target ~15–20 manufacturers covering commercial gyms worldwide — **23 shipped**: Life
      Fitness, Hammer Strength, Precor, Cybex, Nautilus, Star Trac, Body-Solid, Technogym, Matrix,
      Gym80, Panatta, Watson, Eleiko, BH Fitness, Hoist, Arsenal Strength, PRIME Fitness, Atlantis
      Strength, Rogue Fitness, Impulse Fitness, Legend Fitness, Sorinex, Titan Fitness.
      (Jerai was not researched and is not seeded.)
- [x] Selectorized, plate-loaded, cable/functional, and Smith/rack where the manufacturer names a
      distinct model
- [x] Each model links to ≥1 seeded exercise; multi-exercise stations link to several
- [x] Add seeded exercises where a model needs one that doesn't exist yet, with correct
      `loadType`, `equipmentTypeTags`, `muscleGroup`

## Integrity constraints (D24)

- [x] **Never renumber or reuse an existing catalog UUID** — the 24 shipped models and 12 shipped
      exercises keep their exact ids and names; `version1CatalogIDsAreUnchanged` pins all 36
- [x] New entries get fresh, stable, deterministic UUIDs in the existing `5EED…` scheme
      (dense sequences; allocation is sticky — see `scripts/generate_seed_catalog.py`)
- [x] Bump `version` (1 → 2); the reconciler inserts the new rows into an existing store without
      duplicating, without touching user-created rows, and without disturbing history
- [x] Test: seed at old version → upgrade → new models present, old ids unchanged, user rows intact
      (`upgradeFromVersion1CatalogAddsModelsAndKeepsUserData`, including a user exercise linked to a
      seeded model, D27)

## Acceptance

- [x] Catalog is materially larger and every entry traceable to a real product listing
- [x] `xcodebuild test` green (unit + UI): 182 unit tests, 8 UI tests
- [x] App launch time is not visibly degraded by catalog size

## Outcome

**Final counts:** catalog version 2 — **74 exercises**, **1887 equipment models**, **23
manufacturers** (from 12 / 24 / 8). Exercise ids 1–74, model ids 1–1887; the next expansion
continues at exercise 75 / model 1888. *(Version 4 makes this 76 exercises and 1877 models —
ten duplicate identities merged, ten model ids retired; next free exercise index 77, model
index 1888.)*

**Generation:** `scripts/catalog_data.py` (content) + `scripts/generate_seed_catalog.py`
(id allocation, invariants, rendering). `--check` fails if the committed JSON is stale.

**Launch cost** (in-memory store, simulator): catalog decode 6ms; first-launch seed of 1961 rows
270ms (one time); every subsequent launch **0.8ms** via a new fast path in `CatalogSeeder`
(version matches and the seeded row counts match ⇒ nothing to do). Without that fast path the
steady-state reconcile costs ~70ms per launch, so the fast path is ~90× cheaper. Partial stores
still heal: a missing row changes the count and drops through to the full pass.
*Corrected by codex-review-4: the count check was not sound and "partial stores still heal" was
false for any store that lost one seeded row and gained another. See the resolution note for what
replaced it and what it now costs.*

**Thin / lower-confidence manufacturers** (re-research before the next expansion):
- **Atlantis Strength** (68 models) — dealer-sourced only; atlantisstrength.com blocked every fetch.
- **Titan Fitness** (1) and **Sorinex** (13, racks only) — essentially unresearched.
- **Star Trac** (8) and **Eleiko** (20) — thin because little exists under those brands. Star Trac's
  strength lines ship as Nautilus today and were deliberately *not* reconstructed by rebranding the
  Nautilus lists; Eleiko's "strength machines" are resold Precor and were not filed under Eleiko.
- **Cybex VR1/VR3/Prestige** and **Life Fitness Signature Series** — names exact, lines incomplete.
  The Signature Series gap is the most commercially significant one.
- **Arsenal Strength**, **Impulse Fitness**, **Panatta** — authorised-dealer sources carrying the
  manufacturer's own SKU codes.

**Known wart (superseded by the codex-review-4 note below):** three version-1 model names could
not be verified verbatim by the research (`Signature Series Shoulder Press`, `Signature Series Lat
Pulldown`, `Discovery Series Shoulder Press`). The real list is six, not three, and two of those
three turned out to be fixable — see the resolution note.

**Follow-on noticed while testing:** with ~1900 models the pickers rely on search to reach a row;
the UI tests now search rather than expecting a row on screen. Ticket 21's grouping work should
assume the lists are long.


## Resolution note (codex-review-4, 2026-08-10)

Catalog **version 4**: 76 exercises, **1877** models (1887 − 10), 23 manufacturers.

**Ten duplicate identities merged.** Version 2 kept all 24 version-1 fixture rows *and* added the
researched row for the same machine, so one real machine had two UUIDs — and D23 keys history,
records and the same-model-elsewhere layer on that UUID, so picking one today and the other
tomorrow splits the user's own history. Each pair was merged onto the **older** id (the one a
version-1 install has already logged against); the survivor took the researched name (an
allowlisted field, D24) and the duplicate's id is retired forever, never reissued:

| surviving id | version-1 name | name now | retired id |
|---|---|---|---|
| …0007 | Hammer Strength Select Leg Press | Select Seated Leg Press | …0169 |
| …0011 | Precor Vitality Series Seated Row | Vitality Seated Row (VSL019BP) | …0239 |
| …0012 | Precor Resolute Series Leg Press | Resolute Leg Press (RSL0602) | …0225 |
| …0013 | Precor Discovery Series Shoulder Press | Discovery Plate Loaded Shoulder Press (DPL0550) | …0255 |
| …0018 | Matrix Versa Series Chest Press | VS-S13 Converging Chest Press | …0651 |
| …0019 | Matrix Aura Series Seated Row | G3-S31 Seated Row | …0634 |
| …0020 | Matrix Magnum Smith Machine | MG-PL62 Smith Machine | …0697 |
| …0021 | Nautilus Impact Strength Shoulder Press | **Impact Shoulder Press** | …0376 |
| …0022 | Nautilus Impact Strength Leg Press | Impact Seated Leg Press | …0389 |
| …0023 | Hoist ROC-IT Lat Pulldown | Lat Pulldown RS-2201 | …1404 |

…0021 is the user's own machine: it keeps its id and every set logged against it, and simply
reads "Nautilus Impact Shoulder Press" from now on.

**The sweep found one pair the review did not** (Hoist …0023 / …1404 — the version-1 row named the
*line*, the researched row the movement plus the SKU). The whole 1877 were swept by normalising the
manufacturer, stripping line words and SKU codes, and comparing the remaining movement words:
30 candidate pairs, adjudicated one by one against `docs/catalog-sources/`, of which 10 were true
duplicates. Beyond the duplicates it found **three ambiguous twins** — Precor sells Glutebuilder
Hip Thrust Elite / Pendulum Kickback / Kneeling Glute Isolator both plate-loaded *and* selectorized
under the same display name, so the plate-loaded rows were renamed `Glutebuilder Plate Loaded …`
rather than merged. Everything else the sweep raised (Watson's 45°/seated/vertical variants,
Cybex Eagle NX vs VR1/VR3, PRIME's plate-loaded vs selectorized PRODIGY racks, BH's M/PL/L lines,
Panatta's line codes) is genuinely distinct product.

**It cannot recur silently.** `scripts/generate_seed_catalog.py` now fails generation on
*near*-duplicate identities, not just identical names: within a manufacturer, rows whose names
agree once line words ("Series", "Strength") and model codes are removed, or that differ by a
single weak token ("Seated", "Converging", "Plate Loaded"). Anything flagged must be merged
(`RENAMED_MODELS`) or listed with a reason (`ADJUDICATED_DISTINCT`) — run against the version-3
catalog it flags 13 unresolved pairs, i.e. exactly the defect. `bundledCatalogHasNoNearDuplicate
Identities` enforces the same rule over the shipped JSON from the test suite, with no allowlist.

**Renaming is now a declared operation.** Ids are allocated by a sticky `manufacturer + modelName`
key, so a rename silently orphaned an id. `RENAMED_MODELS` re-points the key, asserts the surviving
id, and retires the loser's index so it can never be handed to a future machine.

**Names corrected, disclosure widened.** The "three unverifiable v1 names" was wrong in both
directions. `Discovery Series Shoulder Press` was not unverifiable — it is DPL0550, now merged.
`Signature Series Lat Pulldown` → `Signature Series Pulldown` and `Signature Series Cable Motion
Dual Adjustable Pulley` → `Signature Series Dual Adjustable Pulley` are both in the research's
verified list, and `Mi7 Functional Trainer` → `Mi7 Functional Training System Mi-7-MB`. Six names
really are uncorroborated (…0002, …0006, …0008, …0010, …0016, …0017) and are now listed row by row
with the reason in `docs/catalog-sources/README.md`. The "every name from the manufacturer's own
listing" checkbox above is restated to what is actually true.

**Wrong exercise links fixed (D20).** `L885 Abdominal Flexor` linked `Hanging Knee Raise` although
the research files it among BH's abdominal benches. More seriously, bodyweight benches were linked
to *weighted* machine exercises, so their records were computed under the wrong load-type rules —
weight×reps volume and a Brzycki e1RM for a movement with no external load. Two exercises were
added — **Bench Crunch** and **Hyperextension**, both `bodyweightPlus` — and every bodyweight-typed
station relinked: 9 ab benches and 12 hyperextension benches / Roman chairs. A catalog-wide audit
found exactly one bodyweight-typed row still linking a weighted exercise (Rogue `Floor Glute`,
whose mechanism the research never established); it is flagged in the sources README and asserted
as the single exception in `bodyweightStationsLinkBodyweightExercises`.

**Reconciler integrity.** The count fast path was replaced (details in ticket 21's note, since the
mechanism is shared) — the launch check is now content-sensitive and the "partial stores still
heal" claim above holds for the delete-one-insert-one case it did not cover.

**Suite:** 214 unit tests, 9 UI tests, green.
