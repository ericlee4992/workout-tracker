Cross-review (T6) of milestone 9, ticket 04, on branch
milestone-9-history-and-summary. Review boundary: 4fe1d33..94a0652 (one commit,
94a0652). Read .scratch/milestone-9-history-and-summary/spec.md and
issues/04-dumbbell-exercises.md, and docs/DECISIONS.md D7, D19, D23, D24,
D36, D37, D47.

This ticket REWRITES SNAPSHOTS on the user's only copy of their training
history. It is the highest-risk change in the milestone. Attack it as such.

## What was built

scripts/generate_seed_catalog.py: CATALOG_VERSION 5, fourteen dumbbell rows
(SeedCatalog.json regenerated). Domain/DumbbellCounterparts.swift (UUID
mapping). Domain/DumbbellHistoryMove.swift (the move). CatalogSeeder.reconcile
runs it once on the version crossing and records sets/date on AppPreferences
(two new optional fields); AppSettingsSection shows the record.
WorkoutSession.switchExercise + a generalised split(exercise:).
MachinePickerSheet offers the counterpart instead of the Dumbbell tag.
DumbbellExercisesTests (10), a migration-gate test, one UI test.

## Specific things to attack

1. **What the move touches.** Enumerate every field on ExerciseEntry and
   SetRecord and say for each whether the move should change it and whether
   it does. Is leaving snapshotPresetID/Name pointing at a Bench Press preset
   under a Dumbbell Bench Press entry honest, and what does the chart's
   variation picker / records do with it? Is the D23 argument in the file
   header actually sound, or is this a D47-class edit that should be marked?
2. **What the move must NOT touch, and whether it can.** Running workouts,
   barbell-tagged, machined (machineID set AND tag nil), unmapped movements,
   entries whose snapshot was never captured, deleted rows, entries whose
   `exercise` relationship is nil but snapshot says Bench Press (a deleted
   user exercise?). Is the qualifying predicate exactly right?
3. **Once-only.** previousVersion < 5 && catalog.version >= 5 -- trace the
   fast path in reconcile: can a store at version 4 with a matching
   fingerprint skip the full pass and never move? Can the move run before
   the dumbbell rows exist in the store (order of reconcileExercises vs the
   move)? A CloudKit-merged store with prefs at 5 but unmoved entries?
   Two AppPreferences rows?
4. **Idempotency claim.** "A moved entry points at an exercise with no
   counterpart" -- verify no target is also a source, and that a re-run after
   a later catalog bump (6) does not re-trigger.
5. **switchExercise.** The draft branch rewrites provisional snapshot fields
   and clears drafts/bars; the frozen branch calls split(exercise:). Does
   split with a NEW exercise carry anything over that belongs to the old one
   (preset, bar, prefilled values, superset group)? Renumbering? Is the
   tag chosen (`first { $0 != .machine }`) right for every counterpart?
6. **The counterpart row in the sheet.** Fetches by id on every render; fine?
   What if the counterpart exercise is missing from the store (partial
   store) -- does the plain Dumbbell tag come back, and is that acceptable?
7. **Catalog generator.** Ids sticky, LEGACY ids intact, --check passes;
   any existing test asserting exercise counts or specific ids?
8. **Export.** Do moved entries export under the new exercise id AND name,
   and does the export say nothing false about them?
9. **The Settings record.** Two optional fields on AppPreferences: migration
   gate passes? Is the note shown to a user who had nothing moved? Wording.
10. **Absence of a caller / false claims** in the ticket resolution or the
    commit message.

Report by severity with file:line, do not soften. Write to
.scratch/milestone-9-history-and-summary/codex-review-04.md
