# Cross-review request — exercise presets (D36–D38)

Work written by Claude; you are the independent check T6 requires. Adversarial, terse, no praise.
Do not change code.

## Read first

`CLAUDE.md`, `docs/STATE.md`, `docs/SPEC.md`, `docs/DECISIONS.md` (**D36–D38 new**; D19, D21, D23,
D24, D27 are the ones this can violate), then `.scratch/exercise-presets/spec.md` and `issues/`.

The change is **uncommitted** on branch `exercise-presets`; `git status --short` lists it. Modified:
`Domain/Models.swift`, `Domain/RecordsMath.swift`, `Domain/PreviousPerformance.swift`,
`Domain/WorkoutSession.swift`, `Domain/HistoryRendering.swift`, `Domain/Export*.swift`,
`Features/Exercises/ExercisesView.swift`, `Features/Gyms/GymsView.swift`,
`Features/ActiveWorkout/ExerciseEntryCard.swift`. New: `Domain/ExercisePresets.swift`,
`Features/Exercises/ExercisePresetsSheet.swift`, `WorkoutTrackerTests/ExercisePresetTests.swift`,
`WorkoutTrackerUITests/ExercisePresetUITests.swift`.

## What matters here

A preset changes which sets are **comparable**. Wrong boundaries corrupt the user's history exactly
as a wrong machine UUID does (D23) — quietly, and only visible months later in a PR table.

1. **Migration.** There is a live store on the user's phone with real training data. Every new
   field is optional/defaulted and one new model type is added — does that actually migrate
   lightweightly under SwiftData, or is there a case that fails to open the store? What happens to
   existing entries (`snapshotPresetID == nil`) in records, prefill, layers and export?
2. **Grouping.** `RecordGroupKey` now carries the preset in all four cases. Any path that still
   groups without it, or that mixes preset and non-preset sets? Is `nil` handled consistently as
   its own group everywhere (records, all three layers, prefill, the record surface)? Does volume
   (D21) still count everything, as intended?
3. **The freeze rule.** `choosePreset` mirrors `chooseEquipment`. Compare them line by line: does
   the split move drafts, renumber, seed a set, and preserve the entry order the same way? What
   happens when preset *and* equipment are both switched, in either order? Does `chooseEquipment`
   carrying `entry.preset` across a machine change produce a preset belonging to a different
   exercise?
4. **Defaults.** `MachineInstance.defaultPresetID` is a scalar resolved against the exercise being
   logged. Deleted preset, preset moved to another exercise, multi-exercise machine, machine whose
   model changed — any way to attach a variation the user did not choose?
5. **Export.** Columns appended and `schemaVersion` 2. Is the draft/frozen rule right? Does
   anything about presets fail to leave the phone (D30)?
6. **Catalog reconciliation.** Presets hang off seeded exercises. Confirm D24's reconciler cannot
   delete or orphan them, including when a seeded exercise is dropped from a future catalog.
7. **Tests.** What do they claim that they do not prove? The UI test asserts a second card appears
   after switching — does that actually prove the split, or could it pass for another reason?

## Output

`.scratch/exercise-presets/codex-review.md`: findings by severity, file/line, the decision each
violates, and the smallest fix. Say plainly what is fine.
