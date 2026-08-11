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
