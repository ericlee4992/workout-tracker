# 02 — Managing presets, and a machine's usual one

Status: resolved
Blocked by: 01

## Files

- `WorkoutTracker/Features/Exercises/ExercisePresetsSheet.swift` — add, rename, reorder, delete;
  suggestions for common names.
- `WorkoutTracker/Features/Exercises/ExercisesView.swift` — "Presets…" in the row menu.
- `WorkoutTracker/Features/Gyms/GymsView.swift` — the machine's usual preset (D38).

## Acceptance criteria

- [x] Presets are offered on **seeded** exercises too — they are user data hanging off a catalog
      row, unlike renaming, which D24 reserves.
- [x] Duplicate names (case- and space-insensitive) are refused, with the reason shown.
- [x] The consequence is stated where the decision is made: the footer says records are kept per
      preset, and the rename alert says logged sets keep the old name.
- [x] The machine's preset picker appears only when the model serves exactly one exercise — a
      cable station serving five movements has no single list to offer.
- [x] Identifiers: `preset.<name>`, `newPresetName`, `addPreset`, `presetSuggestion.<name>`,
      `machinePresetPicker`, `noPresets`.
