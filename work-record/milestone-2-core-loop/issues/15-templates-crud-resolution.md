# 15 — Templates: CRUD, startup & machine resolution

**What to build:** Persisted templates (name, ordered exercises via scalar order, target set counts with optional target reps — no weights, no rest in v1). Create/edit/delete template UI; "save as template" offered when finishing a from-scratch workout. Starting a template creates a workout whose entries resolve each exercise to the last-used machine at the current gym via GymExerciseMemory (deterministic pick per ticket 07's upsert rule); no memory at this gym, or no gym → machineless entry. Target sets materialize as uncompleted set rows.

**Blocked by:** 07 (memory upsert behavior; ticket 08's UI is not required). Internal order: CRUD first, then startup/resolution.

**Status:** resolved

- [x] Template CRUD survives relaunch; ordering stable via scalar order
- [x] Resolution test: same template started at gym A vs gym B resolves to each gym's remembered machines; unknown-at-B exercise starts machineless
- [x] No-gym start works; all entries machineless
- [x] Save-as-template captures exercise list + set counts from the finished workout
- [x] Started-from-template workouts record provenance via Workout.sourceTemplateID (for ticket 16's drift detection)
- [x] Target-rep capture: per set slot, from the workout's completed sets in order; target set count = completed set count

**Review fix (2026-08-08).** Template start no longer pre-writes target reps into
`SetRecord.reps`. The ticket asks only that "target sets materialize as uncompleted set rows";
writing the planned reps in as well was actively harmful:

- it collided with ticket 11 — the row was not dirty, so same-machine prefill silently replaced
  the target with historical values anyway; and
- one tap on the completion circle logged a *planned* rep count as *performed*, fabricating
  history. That is the exact inverse of this app's thesis, so a stored target was never an
  acceptable way to make the target visible.

`WorkoutTemplateService.start` now materializes genuinely empty drafts (reps, weight and
`completedAt` all nil) and the template keeps sole ownership of its targets. Prefill fills rows
from real history as designed. If targets should ever be visible in the active workout they must
be non-destructive (placeholder/hint text), never a stored value.

Also fixed here: the save-as-template offer (defect 6). `ActiveWorkoutView` used to finish the
workout and *then* call `saveAsTemplate`, which throws `noExercises` when nothing was completed
— leaving the workout finished, no template, and an `assertionFailure` in debug. The offer is
now gated on `WorkoutTemplateService.canSaveAsTemplate(_:)` (the same predicate `saveAsTemplate`
enforces, so the two cannot drift), capture happens *before* finishing so a failure leaves the
workout untouched, and any failure surfaces as a "Couldn't Save Template" alert instead of an
assertion. Finishing a from-scratch workout with nothing completed just finishes.

Tests: `startedTemplateRowsAreEmptyUncompletedDrafts` (rows have `reps == nil` and
`completedAt == nil`; template still holds the targets), `saveAsTemplateIsOfferedOnlyWhenItCanSucceed`.
