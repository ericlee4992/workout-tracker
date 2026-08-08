# 15 — Templates: CRUD, startup & machine resolution

**What to build:** Persisted templates (name, ordered exercises via scalar order, target set counts with optional target reps — no weights, no rest in v1). Create/edit/delete template UI; "save as template" offered when finishing a from-scratch workout. Starting a template creates a workout whose entries resolve each exercise to the last-used machine at the current gym via GymExerciseMemory (deterministic pick per ticket 07's upsert rule); no memory at this gym, or no gym → machineless entry. Target sets materialize as uncompleted set rows.

**Blocked by:** 07 (memory upsert behavior; ticket 08's UI is not required). Internal order: CRUD first, then startup/resolution.

**Status:** ready-for-agent

- [ ] Template CRUD survives relaunch; ordering stable via scalar order
- [ ] Resolution test: same template started at gym A vs gym B resolves to each gym's remembered machines; unknown-at-B exercise starts machineless
- [ ] No-gym start works; all entries machineless
- [ ] Save-as-template captures exercise list + set counts from the finished workout
- [ ] Started-from-template workouts record provenance via Workout.sourceTemplateID (for ticket 16's drift detection)
- [ ] Target-rep capture: per set slot, from the workout's completed sets in order; target set count = completed set count
