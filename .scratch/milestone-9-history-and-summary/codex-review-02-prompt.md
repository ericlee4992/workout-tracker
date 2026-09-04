Cross-review (T6) of milestone 9, ticket 02, on branch
milestone-9-history-and-summary. Review boundary: 57c1ced..7b706e7 (one commit,
7b706e7). Read .scratch/milestone-9-history-and-summary/spec.md and
issues/02-workout-name.md for intent, docs/DECISIONS.md for D23, D28-D32
(export), D47, and .scratch/milestone-3-export/spec.md for the export format.

## What was built

Workout.name (optional). HistoryRendering.title(name:templateName:exercises:)
and Workout.derivedTitle. WorkoutSession.rename (live, unmarked) and
HistoryEditing.rename (logged, marked via historyEditedAt). A principal-item
title button + alert on ActiveWorkoutView; a Name row + alert on
WorkoutDetailView. Export schema v6: JSON workouts[].name; CSV workoutName
column now prefers the typed name. Tests: WorkoutNameTests (7), a migration
gate test, two UI tests.

## Specific things to attack

1. **The CSV column reuse.** workoutName previously meant sourceTemplateName.
   A consumer of a v1-v5 CSV reading column 4 now gets a different value for a
   named workout. Is that an honest evolution of the column or a silent format
   change that should have been a new column? Does the export spec say what
   it now says? Is anything downstream (import? the export tests' fixtures)
   assuming column 4 == template name?
2. **D47 boundary.** Is every rename of a LOGGED workout marked? Can the live
   path (WorkoutSession.rename) be reached for a workout that is already
   finished -- e.g. via the finished sheet, a resumed/minimised workout that
   finished elsewhere, or a stale Workout reference in ActiveWorkoutView after
   finish? Conversely, can HistoryEditing.rename mark a workout that has not
   finished?
3. **Snapshot honesty.** Is the name ever derived from LIVE rows anywhere?
   derivedTitle uses snapshotExercises -- confirm. Does naming a workout from a
   template alter sourceTemplateName, template drift detection (D18), or the
   save-as-template flow?
4. **Migration.** New optional field on Workout. Does the fixture open, and
   would the real store? Is  reachable from CloudKit-compatibility
   constraints (T2)?
5. **The alert UI.** A SwiftUI alert with a TextField: known quirks with
   stale @State text between presentations, the placeholder not showing when
   text is non-empty, Save with unchanged text. Does the workout screen's
   title button survive workout deletion (isDeleted guards)?
6. **Absence of a caller / declared but unused.** Is derivedTitle used? Is
   every identifier used by a test? Anything in this commit nothing reaches?
7. **Export round-trip.** Does the JSON decoder tolerate a v5 file (no name)?
   Does the fidelity test cover name both present and absent?

Report by severity with file:line, say plainly if a claim in the ticket or
commit message is wrong, do not soften. Write to
.scratch/milestone-9-history-and-summary/codex-review-02.md
