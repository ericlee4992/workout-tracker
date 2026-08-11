# 21 — Browse and categorize machines

**What to build:** Once ticket 20 lands, a flat alphabetical list of several hundred models is
unusable — both when picking a model while adding a machine, and when scanning your own gym's
machines. Add categorization and filtering.

**Blocked by:** 20 (the categories only matter at scale). Can be built against the current catalog
and will scale with it.

**Status:** resolved

## Where it applies

- [x] **Model picker** (adding/editing a machine): group by manufacturer, and filter by exercise /
      body area and by equipment type (selectorized, plate-loaded, Smith/rack). Search must
      match manufacturer *and* model, so "hammer incline" finds the right row.
- [x] **Gym detail** (your own machines): group by exercise or body area, so a 30-machine gym is
      scannable. Keep the flat A–Z as an option — a small gym doesn't need grouping.
- [x] **Exercises tab**: filter by body area / equipment type, since ticket 20 grows this list too.

## Data

- [x] Exercises already carry `muscleGroup` in the seed schema — use it rather than inventing a
      parallel taxonomy, and make sure ticket 20 populates it for every seeded exercise.
- [x] Equipment type is derivable from the linked exercises' `equipmentTypeTags`; if that proves
      too indirect for grouping, add an explicit field to the model schema and note it in ticket 02.
      **It is not derivable** — see Outcome; an explicit `EquipmentModel.equipmentType` was added
      and noted in ticket 02.
- [x] Whatever the user picks (grouping mode, active filters) should persist between visits — this
      is a per-user preference, not per-session state.

## Constraints

- [x] Grouping and filtering are **display concerns only** — they must not change what gets logged,
      how snapshots are captured, or how records group (D23). No filter state may leak into a
      logged entry.
- [x] User-created models and exercises appear alongside seeded ones in every grouping, clearly
      marked (D24), and are never filtered out by a category they lack — put them in an
      "Uncategorized" group rather than hiding them.

## Acceptance

- [x] Picking a model in a several-hundred-model catalog takes seconds, not scrolling
- [x] Unit tests for the grouping/filtering logic (pure, in `Domain/`)
- [x] `xcodebuild test` green (unit + UI): 206 unit tests, 9 UI tests

## Outcome

**Equipment type is an explicit field, not derived.** The ticket's fallback was needed: a model's
loading mechanism is a property of the *machine*, and the linked exercises' `equipmentTypeTags`
describe the *movement*. 1147 of 1887 seeded models derive exactly one tag (`machine`), which
cannot separate a selectorized chest press from a plate-loaded one from a Smith variant — the split
the user actually wants. So `EquipmentModel.equipmentType: EquipmentCategory?` was added (schema +
seed JSON + generator, noted in ticket 02), with catalog **version 3** carrying the values onto
already-seeded stores through the D24 allowlist.

**How 1887 models were classified without guessing:** `scripts/catalog_data.py` was already
organised under the section headings the ticket-20 research was transcribed from ("Insignia Series
(selectorized)", "Plate-loaded, Iso-Lateral", "Racks & rigs", …). Those headings became `TYPE(...)`
markers — one line per section, applying to the entries below it — plus a third tuple element for
the 165 entries whose section default is wrong (a Smith machine inside a selectorized line, a
functional trainer inside a rack line). Shipped: 893 selectorized, 571 plate-loaded, 216
rack/Smith/bench, 163 cable, 40 bodyweight stations, and **4 honest nils** (Gym80 4401/4402/4403,
Rogue Air Rhino) that browse under "Uncategorized" rather than being invented into a group.

**Surfaces**
- *Model picker*: grouped by manufacturer / body area / equipment type / flat A–Z, filtered by body
  area and equipment type, searched over "manufacturer + model" with multi-token, order-independent,
  punctuation-insensitive matching ("hammer incline", "iso lateral"). Active filters show as a
  summary row with a one-tap Clear, so a remembered filter can never silently hide the catalog.
- *Gym detail*: machines grouped by exercise or body area, A–Z still the default.
- *Exercises tab*: body-area and equipment-type filters, and rows now show their body area.
- The mid-workout exercise pickers picked up the same multi-token search.

**Performance:** `CatalogModelIndex` converts the SwiftData rows to value types once per screen
appearance (*rebuilt only when the model count changes — wrong, corrected below*); every keystroke then filters and groups
plain structs against a precomputed normalised search string. No debounce was needed — filtering
and grouping 2000 rows five times over is asserted under 1s in
`filteringTheWholeCatalogIsFastEnoughToTypeAgainst` and runs in a few ms in practice.

**Display-only (D23):** all of it lives in `Domain/CatalogBrowsing.swift` as pure functions over
value types, and the remembered state lives in `AppPreferences`. Nothing in the logging, snapshot
or records path reads a grouping mode or a filter.


## Resolution note (codex-review-4, 2026-08-10)

**Index invalidation was count-sensitive, not content-sensitive.** `ModelPickerView` rebuilt
`CatalogModelIndex` on `models.count`, so a rename, an `equipmentType` change, an exercise-link
change or a muscle-group edit left search, grouping and the filter menus stale until the view was
recreated — and version 4 renames 13 seeded models, which is exactly a count-preserving change.
Rebuilding on every body evaluation was not an option either: this screen re-evaluates per
keystroke and a rebuild reads ~1900 SwiftData rows. Invalidation is now driven by *which entities a
store save touched* (`ModelContext.didSave` → `CatalogIndexInvalidation.touchesCatalog`), so every
edit to an `EquipmentModel` or an `Exercise` rebuilds and nothing else does — a logged set or a
saved browsing preference does not. A save whose payload cannot be read is treated as a change: a
missed rebuild shows stale rows, a spare one costs milliseconds. Tested in
`catalogIndexInvalidatesOnCatalogEntitiesOnly` and
`rebuildingTheIndexPicksUpARenameThatKeepsTheCount`.

**The reconciler's launch fast path was not D24-safe.** It skipped all work when the catalog
version matched *and* the seeded row counts matched. Delete one seeded row and insert any other
`isSeeded` row — a partially restored backup, a half-finished sync — and the counts still match, so
the deleted machine was never restored; ticket 20's "partial stores still heal" was false for that
case, and same-version content changes were invisible too. Replaced with two content-sensitive
conditions:

1. **`AppPreferences.seededCatalogFingerprint`** (new optional field, noted in ticket 02): an
   FNV-1a hash over the catalog version, every fixed UUID and every allowlisted mutable field.
   Equal fingerprint ⇒ the content is what was last applied; unequal at the *same* version now
   drives a rewrite rather than being ignored. FNV-1a rather than `Hasher` because the value is
   persisted and Swift's hasher is seeded per process.
2. **An id-set check**: the number of seeded rows *and* the number of seeded rows carrying an id
   the catalog does not define — four aggregate queries, no rows materialised. Zero foreign rows
   at the right total means every catalog row is present.

Measured in a Debug simulator (`reconcileIsCheapOnceSeeded`, which now prints the number):
**9.3 ms per launch**, against 0.2 ms for the old count-only check and 60–100 ms for the full
per-field diff — the fingerprint is ~2.7 ms and the four queries ~6 ms. Fetching the ids themselves
would have cost ~85 ms, because `propertiesToFetch` still materialises the objects. Residual, and
documented in the code: a store holding two copies of one seeded row *and* missing another still
passes; nothing in the app can produce that, and it would take a CloudKit merge (no unique
constraints, T2). `countPreservingCorruptionStillHeals` is the regression test — it deletes a
seeded model, inserts an impostor to keep the count, and proves the deleted row comes back (and
that the impostor is *not* deleted: D24 never removes a seeded row a historical reference may
point at).

**Not fixed, still true (from the review's minor findings):** no test opens a real pre-ticket-21
*on-disk* store — every seeding and migration test uses an in-memory container, so the live
lightweight-migration path is exercised only by running the app. The same applies to the launch
numbers above: they are in-memory simulator measurements, not device measurements. The new fields
are all optional scalars with nil defaults (additive-only), which is the case lightweight migration
handles, but "should migrate" is not "was seen to migrate". Worth a real on-disk fixture store
committed to the test bundle before the next schema-touching ticket.

**Suite after these fixes:** 214 unit tests, 9 UI tests, green.
