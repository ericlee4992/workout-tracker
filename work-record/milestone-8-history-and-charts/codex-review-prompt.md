Cross-review (T6) of milestone 8, tickets 02 and 03, on branch
milestone-8-history-and-charts. Review boundary: 39737ae..e15f9e5 (commits
3443f94 and e15f9e5). Read work-record/milestone-8-history-and-charts/spec.md and
issues/02-*.md and issues/03-*.md for intent, and docs/DECISIONS.md for D23,
D24, D25, D45, D46 and the NEW D47.

This is the highest-risk pair in the milestone: it can silently rewrite or
destroy the user's only copy of their real training history, which lives on one
phone. Attack it accordingly.

## What was built

Ticket 02 — the user could not FIX A WRONG LOAD TYPE. loadType was set only at
creation. Added Exercise.loadTypeUserOverridden (optional Bool) plus a guard in
CatalogSeeder.reconcileExercises so a hand-corrected type is not overwritten at
the next catalog version bump, and EditExerciseLoadTypeSheet reachable by
long-press on ANY exercise including seeded ones.

Ticket 03 — Domain/HistoryEditing.swift, EditLoggedSetSheet, delete paths in
WorkoutDetailView, Workout.historyEditedAt, and D47.

## Specific things to attack

1. **D23/D47 boundary.** Can any path reach a frozen snapshot field? Editing a
   set must never re-resolve exercise/machine/gym/loadType to today's values.
2. **D25 atomicity.** Does weightValue/weightUnit/normalizedKg ever drift apart
   through the edit path? What about a nil weight on a bodyweight set?
3. **Records after an edit or delete.** Does a deleted PR set stop being the PR?
   Is anything cached that would keep it alive? Does volume recompute?
4. **The seeder guard.** Is loadTypeUserOverridden checked everywhere it must
   be? Does it wrongly freeze OTHER allowlisted fields (name, tags, muscle
   group) that D24 still owns?
5. **Orphans and cascades.** deleteSet + pruneIfEmpty — can an entry survive
   with no sets, or a set survive with no entry? Does deleting a workout leave
   anything behind? Check export (ExportCollector/CSV/JSON) too.
6. **isLoggable parity.** EditLoggedSetSheet's Save-enabled rule must not be
   able to enable on input the store then refuses, and vice versa.
7. **Migration.** Two new optional fields. Does LegacyStoreMigrationTests still
   open the fixture, and would the user's REAL store migrate?
8. **The absence-of-a-caller class.** This repo has shipped that bug twice: a
   field carried, a view rendering it, and nothing ever setting it. Is
   historyEditedAt actually set on every mutating path? Is anything else
   declared but never called?

Report findings by severity with file:line, say plainly if a claim in the
tickets or commit messages is wrong, and do not soften. Write the review to
work-record/milestone-8-history-and-charts/codex-review.md
