## 1. Per-ticket verdict

- **19 — Earned.** Creation uses user UUIDs, immediately selects/logs the exercise, optionally links the seeded model, and D27 merges that link on every later version bump. The merge survives 1→2→3. UI coverage exists.
- **20 — Partially earned.** All 36 v1 UUID/identity pairs match `a4d38b7`; counts are 74/1887/23; generator check passes; Eleiko, Star Trac, Matrix `B`, and Hoist generation traps were respected. Duplicate identities, bad exercise mappings, unverifiable rows, and unsound reconciliation invalidate the accuracy/integrity boxes.
- **21 — Partially earned.** Filtering/grouping is display-only; preference fields are optional; user rows lacking categories remain visible; v3 backfills `equipmentType` from both v1 and v2. Index invalidation is wrong. No other new non-optional persisted field was found.

## 2. Findings by severity

### Critical

- **Same real models have multiple UUIDs, splitting D23 history.** Examples in `SeedCatalog.json`:

  - Hammer `Select Leg Press` `…007` / `Select Seated Leg Press` `…169`
  - Precor `Vitality Series Seated Row` `…011` / `Vitality Seated Row (VSL019BP)` `…239`
  - Precor `Resolute Series Leg Press` `…012` / `Resolute Leg Press (RSL0602)` `…225`
  - Precor `Discovery Series Shoulder Press` `…013` / `Discovery Plate Loaded Shoulder Press (DPL0550)` `…255`
  - Nautilus `Impact Strength Shoulder Press` `…021` / `Impact Shoulder Press` `…376`
  - Nautilus `Impact Strength Leg Press` `…022` / `Impact Seated Leg Press` `…389`
  - Matrix’s documented prefix mapping confirms `Versa Series Chest Press` `…018` / `VS-S13…` `…651`, `Aura Series Seated Row` `…019` / `G3-S31…` `…634`, and `Magnum Smith Machine` `…020` / `MG-PL62…` `…697`.

  The generator rejects only exact `(manufacturer, modelName)` duplicates; it does not reconcile researched aliases to legacy UUIDs.

### Important

- **The count fast path is not D24-safe.** At current version, delete seeded model A and insert arbitrary `isSeeded=true` model X. Counts still equal 1887, so `CatalogSeeder.swift:29` returns; A is never restored. Same-version field corruption also remains. Ticket 20’s “partial stores still heal” claim is false.

- **Exercise mappings are not consistently sane.** BH Fitness `L885 Abdominal Flexor` is linked to `Hanging Knee Raise`, despite the research placing it among abdominal benches. Multiple bodyweight abdominal benches are instead linked to weighted `Abdominal Crunch`. The catalog needed a bodyweight abdominal-flexion exercise with the correct load type.

- **The manufacturer-source checkbox is false.** Ticket 20 requires every name from the manufacturer’s own listing, while its own outcome and source README admit 68 Atlantis rows lack manufacturer corroboration and several brands are dealer-sourced. The “three unverified legacy names” disclosure is also incomplete; e.g. Hammer `Plate-Loaded Seated Row` is absent from the research.

- **`CatalogModelIndex` invalidation is stale.** `GymsView.swift:616` rebuilds only when `models.count` changes. Rename, `equipmentType`, exercise link, exercise rename, or muscle-group changes leave search/group/filter data stale until the view is recreated. It does not rebuild on every body evaluation.

### Minor

- Ticket 19’s resolution overclaims the restricted machine chooser: search is disabled when `choice.linked != nil`, so its create-from-search branch cannot run. Persistent “New Exercise…” creation still satisfies the checked box.
- No test opens an actual pre-ticket-21 on-disk store. The additions are optional and appear lightweight-migration-compatible, but the live upgrade path is not exercised.
- First-launch performance was measured using an in-memory simulator store; the automated test covers only steady-state reconciliation with a loose 250 ms threshold.
- `docs/SPEC.md` now says 1887 models while locked D4 still says “~hundreds” with a stale two-person rationale.
- Build/tests could not run here because Xcode reports no installed simulator runtime; `generate_seed_catalog.py --check` and `git diff --check` pass.

## 3. Install verdict

**No — do not install over the live phone until the duplicate catalog identities and incorrect exercise links are corrected.**
