# 01 — Preset schema and records core

Status: resolved
Blocked by: —

## Files

- `WorkoutTracker/Domain/Models.swift` — `ExercisePreset`; `Exercise.presets`;
  `ExerciseEntry.preset` + `snapshotPresetID`/`snapshotPresetName`;
  `MachineInstance.defaultPresetID`; registered in `WorkoutTrackerStore.modelTypes`.
- `WorkoutTracker/Domain/ExercisePresets.swift` — naming and ordering rules (pure).
- `WorkoutTracker/Domain/RecordsMath.swift` — `presetID` on `RecordSetInput`, preset in every
  `RecordGroupKey`.
- `WorkoutTracker/Domain/PreviousPerformance.swift` — layers, prefill and record summaries filter
  by preset.
- `WorkoutTracker/Domain/WorkoutSession.swift` — snapshot capture, `usualPreset`, `choosePreset`.

## Acceptance criteria

- [x] Every new field is optional or defaulted, so the store already on the user's phone migrates
      lightweightly. Sets logged before presets keep `nil` — honestly "no preset recorded".
- [x] A preset is captured into the D23 snapshot at first completion and never rewritten; renaming
      a preset afterwards does not retitle logged sets.
- [x] Switching preset on a frozen entry splits it (D19), moving draft rows and leaving completed
      sets behind — the same rule and the same shape as `chooseEquipment`.
- [x] Records, previous performance and prefill never cross presets (D36).
- [x] A machine's usual preset preselects a new entry, and a stale one degrades to none.
- [x] Presets attached to a **seeded** exercise survive a catalog version bump (D24/D27).
- [x] No UI import in `Domain/`.

## Resolution (2026-08-12)

`ExercisePresetTests` covers the lot, including the catalog-bump survival case that D27 taught us
to check. The one design note worth keeping: `MachineInstance.defaultPresetID` is a scalar id
resolved against the exercise being logged, not a relationship — a default pointing at another
exercise's preset must degrade to "none chosen" rather than attach a variation from a different
movement.
