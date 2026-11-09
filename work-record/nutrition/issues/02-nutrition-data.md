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

**Left:** export round-trip unit test (encode v12 → decode equal; a v11 file still decodes); Unit plan; the Simulator
migration rehearsal (a store in the shipped format in the app's real location → launch → one safety copy →
`compare_stores.py` exit 0); README if needed; Codex review.
**Question for the user (morning):** the ticket's "Import" — the app has no Import (JSON can't be restored in the
app). Build one (replace or merge, its screens) or drop it from N2? Not built; nothing else depends on it.

## Comments
