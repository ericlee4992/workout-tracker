# 03 — Choosing the preset while logging

Status: resolved
Blocked by: 02

## Files

- `WorkoutTracker/Features/ActiveWorkout/ExerciseEntryCard.swift` — the chip row.
- `WorkoutTracker/Domain/HistoryRendering.swift` — the preset in the snapshot equipment label.

## Acceptance criteria

- [x] Chips, not a menu: switched one-handed mid-workout, and seeing the alternatives is the point
      — the user is choosing which record table the set belongs to.
- [x] A "None" chip exists. The user did something the presets do not describe, and filing it under
      a variation they did not perform would be the same lie as the wrong machine.
- [x] The selection shows the live pick while drafting and the frozen snapshot once a set is
      logged; switching after that splits the entry (the service owns the rule, not the view).
- [x] History and the previous-performance sheet name the preset wherever they name the machine.
- [x] Identifiers: `presetChip.<name>`, `presetChip.None`.
