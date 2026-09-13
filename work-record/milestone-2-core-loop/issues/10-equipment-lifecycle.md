# 10 — Equipment lifecycle & model correction

**What to build:** Rename, archive, and model-correction flows with historical honesty. Renaming a gym/machine/model changes future displays only (history reads snapshots). Deleting archives: hidden from pickers, history intact. Correcting a machine's model triggers the locked prompt (D10): "apply to past workouts too, or future only?" — future-only leaves old snapshots untouched; apply-to-past rewrites the snapshot model UUID+strings on that machine's past entries.

**Blocked by:** 09.

**Status:** resolved

- [x] Tests, each asserting both the history display AND the snapshot IDs: gym rename, machine rename, model rename, machine archive, gym archive
- [x] Future-only correction: old entries keep the old model UUID in snapshots (and thus stay in the old model's history layer)
- [x] Apply-to-past correction: chosen scope's snapshots rewritten; entries on other machines of the old model untouched
- [x] Archived machines/gyms excluded from pickers and from GymExerciseMemory resolution
- [x] Rename applies only to user-created models/exercises; seeded rows are read-only (D24)

## Comments

Resolved 2026-08-08. `Domain/EquipmentLifecycle.swift` centralizes persisted rename,
archive, remembered-machine resolution, and model-correction operations. Ordinary gym,
machine, model, and exercise renames affect live rows only; history continues rendering
the UUIDs and display strings captured at log time. Model correction is the sole explicit
historical rewrite: future-only changes the live machine while apply-to-past rewrites
snapshot model UUID/name for entries whose snapshot machine UUID matches that exact
machine, leaving other machines on the former model untouched. Memory resolution rejects
archived gyms, archived machines, and mismatched gym links without deleting scalar memory.
Gym detail now exposes rename/archive actions, user-model rename, and a correction sheet
with both D10 scopes; active-workout pickers also reject archived gyms. ExercisesView routes
custom-exercise rename through the same read-only guard. Eight focused tests in
`EquipmentLifecycleTests.swift` cover snapshot IDs and rendered labels for every lifecycle
case, both correction scopes, memory filtering, and seeded-row rejection.
