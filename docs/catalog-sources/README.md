# Seeded catalog sources

Provenance for `WorkoutTracker/Resources/SeedCatalog.json` (ticket 20). Each file
is the raw research for a group of manufacturers: the source URLs consulted, the
model names read off them, and a `Confidence` section stating what is complete,
what is thin, and what was deliberately **not** included. A model name that is
not traceable to one of these files does not belong in the catalog (a plausible
but non-existent model silently becomes the identity history is keyed on, D23).

| File | Manufacturers |
|---|---|
| `group1-…` | Life Fitness, Hammer Strength, Precor, Cybex, Nautilus, Star Trac, Body-Solid |
| `group2-…` | Technogym, Matrix, Gym80, Panatta, Watson, Eleiko, BH Fitness |
| `group3-…` | Hoist, Arsenal Strength, PRIME Fitness, Atlantis Strength, Rogue Fitness, Impulse Fitness, Legend Fitness, Sorinex, Titan Fitness |

The JSON is generated from `scripts/catalog_data.py` by
`scripts/generate_seed_catalog.py` (`--check` fails if the committed JSON is
stale). Catalog UUID allocation rules are documented in that script's docstring.

## What "verified" means here

Every seeded model name is read off **either the manufacturer's own listing or
an authorised dealer's listing carrying the manufacturer's SKU codes** — not off
the manufacturer alone. Dealer-sourced brands: **Atlantis Strength** (all 68
models — atlantisstrength.com refused every fetch), **Arsenal Strength**,
**Impulse Fitness**, **Panatta**, and three Star Trac rows (Instinct Circuit,
Instinct Smith Machine, Instinct DAP Functional Trainer). Everything else came
from a manufacturer property.

**Version-1 names that no source corroborates.** The first 24 models shipped as
a hand-written test fixture (ticket 04) and predate this research. Where the
research found the same machine, version 4 merged the two rows and the survivor
took the researched name (see below). These six could not be corroborated and
keep their fixture name — the UUID is what history is keyed on (D23), so
renaming them to a guess would mislabel logged sets:

| id | name | why it is unverified |
|---|---|---|
| …0002 | Life Fitness Signature Series Shoulder Press | Signature Series is discontinued; only 10 Signature names could be verified and no shoulder press is among them |
| …0006 | Hammer Strength Plate-Loaded Seated Row | the plate-loaded line lists Iso-Lateral Row / Low Row / High Row / D.Y. Row, never this string |
| …0008 | Technogym Selection 900 Lat Pulldown | the line has a *Lat Machine* and a *Pulldown*; which one this row meant is unknowable |
| …0010 | Technogym Cable Stations Dual Adjustable Pulley | Technogym's cable products are Kinesis; no such product name was found |
| …0016 | Cybex Bravo Functional Trainer | Bravo is not on the current Cybex/Life Fitness listing |
| …0017 | Matrix Ultra Series Assisted Chin/Dip | the G7 (Ultra) enumeration has no chin/dip; Aura and Versa do |

Three further version-1 names *were* corrected to the researched string, because
the research names the same machine unambiguously: …0003 → `Signature Series
Pulldown`, …0004 → `Signature Series Dual Adjustable Pulley`, …0024 → `Mi7
Functional Training System Mi-7-MB`.

## One machine, one UUID

D23 keys history, records and the same-model-elsewhere layer on the model UUID,
so two rows for one real machine silently split a user's history. Version 2
shipped ten such pairs: a version-1 fixture row and the researched row for the
same machine. Version 4 merged each pair onto the **older** id (the one a
version-1 install may already have logged against), gave it the researched name,
and retired the duplicate's id forever. The mapping lives in `RENAMED_MODELS` in
`scripts/generate_seed_catalog.py`; the generator now rejects near-duplicate
identities (same manufacturer, same name once line words and model codes are
stripped) unless they are listed as adjudicated-distinct with a reason.

A whole-catalog sweep for the same pattern found no others. Two families that
look alike are real: Precor's Glutebuilder sells the same movement plate-loaded
*and* selectorized (the plate-loaded rows were renamed to say so), and PRIME's
PRODIGY racks likewise.

## Traps the research flagged, and what the catalog does about them

- **Eleiko** resells Precor under its "strength machines" category. Only
  genuinely Eleiko items (cable machines, Prestera racks) are seeded under Eleiko.
- **Star Trac**'s strength lines ship as Nautilus today. Only the 8 Star Trac
  branded names actually sighted are seeded; the Nautilus lists were not rebranded.
- **Matrix** `B`-suffix models are an upholstery trim of the same machine —
  collapsed into one entry. **Gym80** `N`-suffix numbers are distinct SKUs — kept.
- **Hoist** RS-1xxx and RS-2xxx are coexisting generations; only RS-1301,
  RS-1502 and RS-1103 were sighted, so the rest of RS-1xxx is not generated.
- **BH Fitness** names both PL150B and PL155B "Seated Triceps"; the model code in
  the display name is what disambiguates them.
- Where a research file records a *line* without enumerating members (Technogym
  Selection Pro, Gym80 80Classics, Panatta HP Line, Eleiko XF 80, Arsenal BRAVO,
  Impulse IF-series, Sorinex Apex/Dark Horse, Titan T-3/X-3, Cybex legacy Eagle /
  VR2 / Plate Loaded, Nautilus ONE, Life Fitness Circuit Series), nothing is
  seeded for it.

## Thin / lower-confidence manufacturers

Worth re-researching before the next expansion:

- **Atlantis Strength** — dealer-sourced only; atlantisstrength.com refused every
  fetch, so there is no manufacturer corroboration for any of its 68 models.
- **Rogue Fitness "Floor Glute"** — the research records the movement but not the
  loading mechanism. It sits in a bodyweight-typed section while linking the
  weighted Glute Kickback; re-check it before the next expansion.
- **Sorinex** (13, rack configurations only) and **Titan Fitness** (1 machine) —
  effectively unresearched beyond what is listed.
- **Star Trac** (8) and **Eleiko** (20) — thin because there is genuinely little
  to find under those brands, not because research fell short.
- **Cybex VR1 / VR3 / Prestige** and **Life Fitness Signature Series** — names are
  exact but the lines are larger than what could be verified. The Signature
  Series gap is the most commercially significant one: those machines are still
  on thousands of gym floors.
- **Arsenal Strength**, **Impulse Fitness**, **Panatta** — authorised-dealer
  sources carrying the manufacturer's own SKU codes; high confidence, but not
  read off the manufacturer's own site.
