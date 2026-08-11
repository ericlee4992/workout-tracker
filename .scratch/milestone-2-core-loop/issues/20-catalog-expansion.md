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

- [x] **Every model name must be verifiable from the manufacturer's own product listing.** No
      inventing, no "probably exists", no extrapolating a naming pattern to models not seen.
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
continues at exercise 75 / model 1888.

**Generation:** `scripts/catalog_data.py` (content) + `scripts/generate_seed_catalog.py`
(id allocation, invariants, rendering). `--check` fails if the committed JSON is stale.

**Launch cost** (in-memory store, simulator): catalog decode 6ms; first-launch seed of 1961 rows
270ms (one time); every subsequent launch **0.8ms** via a new fast path in `CatalogSeeder`
(version matches and the seeded row counts match ⇒ nothing to do). Without that fast path the
steady-state reconcile costs ~70ms per launch, so the fast path is ~90× cheaper. Partial stores
still heal: a missing row changes the count and drops through to the full pass.

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

**Known wart:** three version-1 model names could not be verified verbatim by the research
(`Signature Series Shoulder Press`, `Signature Series Lat Pulldown`, `Discovery Series Shoulder
Press`). They keep their v1 names anyway — the UUID is what history is keyed on, and renaming them
would mislabel already-logged sets.

**Follow-on noticed while testing:** with ~1900 models the pickers rely on search to reach a row;
the UI tests now search rather than expecting a row on screen. Ticket 21's grouping work should
assume the lists are long.
