# N2 — Nutrition data model, migration, export/import

Type: change
Status: **approved** (the user, 2026-11-09: "Approve N2's data change" — the stored-format change and the guard's new pin; **My meals included**)
Blocked by: N1
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/nutrition-02-data` off `main`.
Spec: [nutrition → Data rules](../spec.md#data-rules-apply-to-every-ticket). Decisions: D69, D70, D74; D28 (export).

## Goal

The stored data for food, goals and body weight, added so every existing workout, template, gym and machine survives
the update unchanged, and the user's export/import carries the new data.

## Proposed models (in `Domain/Models.swift`, CloudKit-compatible)

- **FoodEntry** — day and time, meal (Breakfast / Lunch / Dinner / Snacks), name, brand, servings, serving
  `(value, unit)` and grams if known, calories, protein, carbs, fat, optional other facts (fibre, sugar, saturated
  fat, sodium, …), source (manual / quick add / saved / recent / barcode / photo / label / describe; no separate `isEstimated` —
  D78),
  barcode, a `.nullify` link to the SavedFood it came from, a Health sample id (N9).
- **SavedFood** — the user's foods: name, brand, barcode, nutrition per serving, serving options, saved or only recent,
  last used. Database hits (N8) are cached here when logged.
- **SavedMeal** + **SavedMealItem** (`.cascade`) — "My meals": a named group of foods logged together. **Included — the
  user, 2026-11-09.**
- **NutritionGoal** — dated: calories, protein, carbs, fat, and the inputs (weight, height, age, sex, activity, goal,
  rate) with which it was calculated, and which numbers were overridden. A past day is judged against the goal in
  force that day (frozen history).
- **BodyWeightEntry** — date, `(value, unit)`, `normalizedKg`, source (app / Health), Health sample id.

## Scope

- Add the models; decide in the ticket between SwiftData's automatic (lightweight, additive) migration and a first
  `VersionedSchema` baseline, following DEVELOPMENT's migration rules. Existing rows are not rewritten.
- `StoreFormatGuardTests`: update the pinned hashes deliberately, with N1's copy in place.
- Export JSON and CSV (D28) and Import: the new models round-trip; an export from today's build still imports.
- Pure domain helpers with unit tests: day totals, per-meal totals, macro calories (4/4/9), serving scaling.

## Acceptance

1. A store from the installed build (build 9/8 format) opens with every row intact and the safety copy made first
   (rehearsal on WT-Backup-01; `compare_stores.py`).
2. Unit tests: model defaults, totals, scaling, frozen entry snapshot after a SavedFood edit/delete.
3. Export → Import round trip including the new data; an old export imports.
4. `xcodebuild build`; Codex clear.

## Verification scope

Persistence + migration → domain unit tests, export/import unit and UI tests (Export, BackupExport), migration
rehearsal. Gate S on the user's phone happens at the release (R).

## Code map

- `WorkoutTracker/Domain/Models.swift`, `ExportCollector.swift`, `ExportJSON.swift`, `ExportCSV.swift`,
  `ExportRecord.swift`, `ExportSnapshot.swift`; `WorkoutTrackerTests/StoreFormatGuardTests.swift`.

## Progress

Branch `ericlee4992/nutrition-02-data` (on `main` `b911247`, N1 merged). **Done so far (2026-11-09, not yet reviewed):**
- Models in `Domain/Nutrition.swift` (FoodEntry, SavedFood with `servingOptionsData`, SavedMeal + SavedMealItem
  `.cascade`, NutritionGoal dated with inputs and override flags, BodyWeightEntry `(value, unit)` + `normalizedKg`);
  enums MealSlot, FoodSource, WeightGoal, ActivityLevel, BiologicalSex, BodyWeightSource; registered in
  `WorkoutTrackerStore.modelTypes`. Nutrition stored per serving; no `isEstimated` (D78). SwiftData's automatic
  (lightweight, additive) migration — no `VersionedSchema`.
- `Domain/NutritionMath.swift`: totals, day/meal totals, 4/4/9 macro calories, servings from grams, goal in force on a day.
- `StoreFormatGuardTests`: `approvedFingerprint` `41b76904…` (user-approved 2026-11-09), `shippedFingerprint` kept for
  builds 1–9; 6 new enums pinned; `servingOptionsData` payload pinned.
- `Fixtures/PreNutrition.store` (shipped format, proven from its own metadata: 21 workouts, 72 sets, 11 cardio, 3
  templates, 3 gyms, 12 machines, 2 presets) + `NutritionMigrationTests` (every row and checksum survives; new tables
  empty; the safety copy sees the change); `NutritionModelTests`. Guard + Schema + migration + model + Legacy suites:
  **31/31, exit 0** (`n2-t2.xcresult`).
- Export v12: JSON carries foodEntries, savedFoods, savedMeals (+items), nutritionGoals, bodyWeights and counts (all
  optional, so v1–v11 files decode); CSV unchanged (sets + cardio). Builds; **not yet tested**.

**Done 2026-11-09 (session 2, `e7b75b0`+):**
- `NutritionExportTests` (4): every nutrition row with all optionals set and none set, counts, order, `savedFoodID`
  links, serving options, items in order; v12 encode → `ExportJSON.decode` equal and no `null`; an empty store; a v11
  file (the five nutrition keys and four counts removed, `schemaVersion` 11) decodes with nutrition absent; the CSV stays
  sets and cardio. **40/40 over 10 iterations, exit 0.** The five tests pinning `schemaVersion == 11` moved to 12.
- **Unit plan 1163/1163, exit 0** (98 s). **Export UI:** warm-up + `ExportUITests` 2/2 passed; `BackupExportUITests`
  skipped by design (runs only with `WT_BACKUP_EXPORT=1`).
- **Simulator migration rehearsal (WT-Floodlight, N2 build, binary hash checked against the derived data):** the sim's
  own `Application Support` backed up (11 files, SHA-256 list); `Fixtures/PreNutrition.store` put there as the only
  `default.store`; container captured; launch → **exactly one** `SafetyCopies/2026-11-09T08-58-39/` whose
  `default.store` is byte-identical to the fixture (manifest `appVersion` "0.1.0 (9)"); the app opened on the fixture's
  unfinished workout (screenshot). `verify_container.py` on the after-capture: exit 0. `compare_stores.py before after`:
  every table and old row present, six new empty tables, preferences unchanged — **exit 1 on one value**: unfinished
  workout Z_PK 19 gained `sensorMaxHeartRateBpm` 185 / `Estimated` 0 (`CardioRecorder.refresh()`, which runs when the
  app resumes an unfinished workout). **Same rehearsal with `main` `b911247`** (scratch build): no safety copy (no
  format change) and the **identical** difference — pre-existing resume behaviour, not the migration.
  `compare_stores.py <main after> <N2 after>`: **exit 0** (only the six new tables added). The sim's own data was put
  back and byte-compared (11/11 identical); the N2 build reinstalled.
- README: a short unreleased note on the v12 JSON (Codex round 1, P3 — AGENTS asks for it when behaviour changes,
  not only screens).

**Verified:** models, math, guard, migration fixture (31/31 earlier, in the Unit plan now); export v12 round trip;
Unit plan 1163/1163; ExportUITests; Simulator migration rehearsal (above).
**Not verified:** a real phone (Gate S at the release R); the build 8/9 TestFlight store itself (the fixture is in the
shipped format, proven from its metadata); Import (none exists; dropped from N2 by the user).
**Known flaky:** none seen.

**Codex round 1** ([report](../codex-review-n2.md), not clear): Spec 0 findings; Standards 1 P3 (README). Fixed: the
README note; also its verification notes — `everyRowAndValueSurvivesTheMigration` renamed
`everyTableKeepsItsRowsAndKeyValuesThroughTheMigration` (it checks counts and key values; row-by-row is the
rehearsal), and the nutrition-rows test now reopens the store in a second container and refetches every new row
(`theMigratedStoreKeepsNutritionDataAcrossAReopen`). `NutritionMigrationTests` **40/40 over 10 iterations, exit 0**
(`n2-migration-r2.xcresult`). Round 2 sent.

**Left:** Codex round 2.

**Import — dropped from N2 (the user, 2026-11-09: "Drop it from N2").** The app has never had an Import; the v12
export carries every nutrition row, so a future Import can restore it. Acceptance 3 is read as "export v12 round-trips
through `ExportJSON.decode`; an old export still decodes". A separate Import ticket only if the user asks.

## Comments
