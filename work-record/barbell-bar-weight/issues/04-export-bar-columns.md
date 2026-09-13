# 04 — Export the bar (CSV 31 columns, JSON schemaVersion 3)

Status: resolved
Blocked by: 02

The export is the only backup that exists (D28–D32). A field the app stores and the backup drops
is a field that disappears the first time the phone does.

## Files

- `WorkoutTracker/Domain/ExportSnapshot.swift` — `SetRow.barWeight` / `barWeightKg`, version 3
- `WorkoutTracker/Domain/ExportCollector.swift`, `ExportCSV.swift`
- `work-record/milestone-3-export/spec.md` — column list and JSON sample
- `WorkoutTrackerTests/ExportTests.swift`, `ExportFidelityTests.swift`

## What to build

- `SetRow.barWeight: Double?` (as entered, in the row's `unit`) and `barWeightKg: Double?`
  (normalized). Both nil for a total-entry set, and omitted from the JSON rather than emitted as
  `null`, like every other nil.
- `ExportSnapshot.currentSchemaVersion` 2 → 3, with the same note the version-2 comment carries:
  what changed, and that a version-2 reader was not wrong about anything it already understood.
- CSV: `barWeight`, `barWeightKg` **appended** after `presetName` (29 → 31). Appending is safe,
  inserting is not — a consumer reading the first 29 columns of an older export still reads them
  correctly.
- Update `work-record/milestone-3-export/spec.md`: the column table, the count, and the JSON sample.

## Acceptance criteria

- [ ] D29 applies to the bar: `barWeight` is as entered and `barWeightKg` is
      `barWeight × 0.45359237` for an lb row and equal for a kg row. No `≈` anywhere.
- [ ] A bar-mode set exports `weight` = the **total**, not the plates — the same number the app
      shows and the records count.
- [ ] A total-entry set exports both bar columns empty (CSV) / absent (JSON).
- [ ] `decode(encode(x)) == x` still holds for a snapshot exercising a bar-mode set.
- [ ] The CSV header matches the 31 columns in the updated spec exactly, in order.
- [ ] `ExportFidelityTests` covers a store containing both a bar-mode and a total-entry set.
- [x] Numbers still serialize locale-independently under a comma-decimal locale.

## Resolution (2026-08-22)

`SetRow.barWeight`/`barWeightKg`, `currentSchemaVersion` 3, two appended CSV columns, and the
collector normalizing the bar through the row's own unit. `work-record/milestone-3-export/spec.md`
gained rows 28–31 — its table had never been updated for presets, so columns 28/29 are documented
here for the first time along with 30/31.

Coverage: `theExportCarriesTheBarWithoutMovingTheWeight` in `ExportFidelityTests` logs a bar set
and a total-entry set in one workout and asserts `weight` is 135 for the bar row (the total, not
the plates) while the total-entry row's bar columns come back **empty rather than zero** — an
exported `0` would read as a weightless bar rather than as "no bar".
