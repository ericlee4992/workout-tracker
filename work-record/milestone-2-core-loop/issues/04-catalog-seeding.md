# 04 — Versioned catalog seeding

**What to build:** Seeding as versioned, idempotent reconciliation (D24). A bundled catalog fixture (JSON in the app bundle, carrying a version number and fixed catalog UUIDs) defines seeded exercises (name, loadType, tags) and equipment models (manufacturer, model, exercise links). On every launch, reconcile: insert missing seeded rows by catalog UUID, update seeded metadata/links when the bundled version is newer, never duplicate, never modify user-created rows or break historical references. Exercises tab reads from the store.

**Blocked by:** 02.

**Status:** resolved

- [x] Test fixture: the 12 prototype exercises with correct load types/tags + ≥20 equipment models across ≥6 manufacturers, each linked to ≥1 exercise; ≥1 multi-exercise station. (The few-hundred-model production catalog per D4 is the separate parallel content task — not this ticket's gate)
- [x] Mutable seeded fields allowlisted (name, links, metadata); seeded rows not editable in-app (D24) — reconciliation test proves user edits impossible/preserved
- [x] Tests: empty store seeds fully; identical rerun changes nothing (row counts stable); partial store (delete some rows, rerun) heals; v1→v2 fixture adds/updates without duplicating; user-created rows untouched by rerun
- [x] Exercises tab lists seeded exercises from the store with load-type badges

---

**Comment (2026-08-08, agent):** Resolved. `WorkoutTracker/Resources/SeedCatalog.json` (version 1) ships in the app bundle via the synchronized folder — verified present at the built product's bundle root, no pbxproj changes. Fixture: the 12 prototype exercises (fixed `5EED0001-…` catalog UUIDs, load types/tags matching SampleStore) + 24 equipment models across 8 manufacturers (fixed `5EED0002-…` UUIDs), every model linked to ≥1 exercise, 6 multi-exercise stations (cable pulley stations ×4, assisted chin/dip, Smith machine). `Domain/SeedCatalog.swift` decodes it; `Domain/CatalogSeeder.reconcile(_:in:)` runs at every launch from `WorkoutTrackerApp.init`: inserts missing seeded rows by catalog UUID at any version (heals partial stores), rewrites allowlisted fields (name, links, metadata) only when the bundled version exceeds `AppPreferences.seededCatalogVersion`, never deletes catalog rows, never touches `isSeeded == false` rows, saves only on real changes. ExercisesView now `@Query`s seeded exercises from the store (load-type badges via the shared `ExerciseRow`, generalized to render both Sample and SwiftData exercises); the rest of the prototype UI stays on SampleStore until ticket 07. Tests: `WorkoutTrackerTests/SeedingTests.swift` — 6 tests (fixture content bar; empty-store seed; identical rerun stable; partial-store heal; v1→v2 upgrade incl. tampered-seeded-row restore and stale-catalog no-downgrade; user rows untouched). Full suite: 22 tests green on WT-iPhone.
