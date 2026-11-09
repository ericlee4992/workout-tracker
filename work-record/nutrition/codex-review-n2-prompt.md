# Codex review — nutrition N2 (nutrition data model, migration, export)

You are the independent reviewer; Claude implemented. Read AGENTS.md first. Checkout
`/Users/ericlee06/orca/workspaces/Health App/UI_design`, branch `ericlee4992/nutrition-02-data` (off `main`
`b911247`, N1 merged). Review `git diff b911247..HEAD`.

Read first: `work-record/nutrition/issues/02-nutrition-data.md` (approved 2026-11-09 incl. My meals; Progress: the
choices made while building, evidence; **Import dropped from N2 by the user** — the app has no Import, so acceptance 3
is the v12 round trip through `ExportJSON.decode` plus old files still decoding), `work-record/nutrition/spec.md` →
Data rules, decisions D69, D70, D74, D78 (no `isEstimated`), D28/D29/D31 (export), DEVELOPMENT → migration and *When a
backup is required*, AGENTS → code and data conventions (CloudKit-compatible SwiftData, delete rules, `(value, unit)`
+ `normalizedKg`), and N1's ticket (`issues/01-safety-copy.md`) — N1's safety copy is what protects this format change.

This is the first stored-format change testers will receive (release R). Check in particular:
1. **Models** (`Domain/Nutrition.swift`, registration in `Domain/Models.swift`): CloudKit compatibility (a default on
   every attribute, optional relationships, inverses, no `.unique`); delete rules — SavedFood → entries / meal items
   `.nullify` (history survives), SavedMeal → items `.cascade`; entries and meal items as frozen snapshots of the food;
   stored enum raw values; `servingOptionsData` (a bad payload reads as none); BodyWeightEntry keeps `(value, unit)` and
   `normalizedKg` in step; NutritionGoal dated, no `updatedAt` (a change makes a new goal — is that consistent with
   D70 and the spec?). Anything N3–N9 will need that is missing now and would force a second format change.
2. **Migration:** SwiftData's automatic lightweight migration, no `VersionedSchema` — is that sound under DEVELOPMENT's
   rules for a purely additive change? Does N1's `SafetyCopies.storeNeedsCopy` fire for the shipped-format store
   (tested in `NutritionMigrationTests`)? `StoreFormatGuardTests`: the new `approvedFingerprint`, `shippedFingerprint`
   kept for builds 1–9, the six enums and the `servingOptionsData` payload pinned. Is `Fixtures/PreNutrition.store`
   really in the shipped format (the ticket says it is proven from its own metadata — check)?
3. **NutritionMath** (`Domain/NutritionMath.swift`): totals, day/meal totals by the local day, 4/4/9 macro calories,
   servings from grams, the goal in force on a day (frozen history; the day boundary; two goals on one day).
4. **Export v12** (`ExportCollector.swift`, `ExportSnapshot.swift`): every new field exported, nothing derived, dates
   via `ExportDateFormat`, deterministic order with a total tie-break, counts, all new keys optional so v1–v11 decode,
   `savedFoodID` when the food was deleted, `servingOptions` empty vs absent, CSV unchanged. The five tests that pinned
   `schemaVersion == 11` now pin 12.
5. **Tests:** `NutritionModelTests`, `NutritionMigrationTests`, `NutritionExportTests`, the guard — gaps, and whether a
   test would catch the failure it is named for.

**The rehearsal's one difference.** `compare_stores.py` before → after on the N2 build exited 1 on one value:
unfinished workout Z_PK 19 gained `sensorMaxHeartRateBpm` 185 (`CardioRecorder.refresh()` on resuming the fixture's
unfinished workout). The same rehearsal with `main` `b911247` gave the identical difference, and `compare_stores.py
<main after> <N2 after>` exited 0. Judge whether that attribution holds (and note that DEVELOPMENT calls
`compare_stores.py` a same-schema tool; N2 adds tables only, no columns to existing tables).

Per AGENTS' reviewer rule: build; run the Unit plan (`-testPlan Unit`) or at least `NutritionModelTests`,
`NutritionMigrationTests`, `NutritionExportTests`, `StoreFormatGuardTests`, `SchemaTests`, `ExportTests`,
`ExportFidelityTests`, `SafetyCopyTests`; as round 1, the UI classes `AAAWarmUpUITests` and `ExportUITests` serially.
Repeat the Simulator migration rehearsal on WT-iPhone27 if you can (ticket's Progress has the steps: back up that
simulator's own `Application Support` first, put `WorkoutTrackerTests/Fixtures/PreNutrition.store` there as the only
`default.store`, capture, launch the N2 build → exactly one `SafetyCopies/` copy, terminate, capture,
`scripts/container-tools/compare_stores.py`; put the simulator's own data back and byte-compare). Inspect Claude's
evidence in
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/f473a23d-3eaa-41a2-9817-2ebe24bda24e/scratchpad/`
(`n2-export.xcresult`, `n2-unit.xcresult`, `n2-exportui.xcresult`, `rehearsal/` — `compare.txt`,
`compare-main.txt`, `compare-main-vs-n2.txt`, `after-launch.png`).

Run on **WT-iPhone27** `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B` (`scripts/prepare-test-simulator.sh <id>` first), paths
under `/tmp/codex-n2/`. Show progress in the existing Orca tab "Test progress (Claude r2)"
`term_ac1339dc-202d-4c10-bab3-b528de726cbd` once it is back at its prompt — do not open a new terminal. Do not modify
files other than the report; do not commit or push.

Write `work-record/nutrition/codex-review-n2.md`: findings P1/P2/P3 with file:line, failure scenario and fix; a
Verified / Not verified / Known flaky block; end with exactly `Verdict: clear` or `Verdict: not clear`.
