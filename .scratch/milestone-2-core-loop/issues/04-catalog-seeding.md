# 04 — Versioned catalog seeding

**What to build:** Seeding as versioned, idempotent reconciliation (D24). A bundled catalog fixture (JSON in the app bundle, carrying a version number and fixed catalog UUIDs) defines seeded exercises (name, loadType, tags) and equipment models (manufacturer, model, exercise links). On every launch, reconcile: insert missing seeded rows by catalog UUID, update seeded metadata/links when the bundled version is newer, never duplicate, never modify user-created rows or break historical references. Exercises tab reads from the store.

**Blocked by:** 02.

**Status:** ready-for-agent

- [ ] Test fixture: the 12 prototype exercises with correct load types/tags + ≥20 equipment models across ≥6 manufacturers, each linked to ≥1 exercise; ≥1 multi-exercise station. (The few-hundred-model production catalog per D4 is the separate parallel content task — not this ticket's gate)
- [ ] Mutable seeded fields allowlisted (name, links, metadata); seeded rows not editable in-app (D24) — reconciliation test proves user edits impossible/preserved
- [ ] Tests: empty store seeds fully; identical rerun changes nothing (row counts stable); partial store (delete some rows, rerun) heals; v1→v2 fixture adds/updates without duplicating; user-created rows untouched by rerun
- [ ] Exercises tab lists seeded exercises from the store with load-type badges
