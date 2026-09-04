# 04 — Dumbbell movements as their own exercises

Status: ready-for-agent
Blocked by: 03
Covers the catalog half of user ask **4**.

## What to build

**A. Catalog rows** (bump `SeedCatalog.json` version, D24), each tagged `dumbbell`, `weighted`,
correct muscle group: Dumbbell Bench Press, Dumbbell Incline Press, Dumbbell Decline Press,
Dumbbell Shoulder Press, Dumbbell Row, Dumbbell Romanian Deadlift, Dumbbell Lunge, Bulgarian Split
Squat, Dumbbell Shrug, Dumbbell Floor Press, Dumbbell Hip Thrust, Dumbbell Fly, Dumbbell Lateral
Raise, Dumbbell Goblet Squat. The user was shown this list and asked to prune; treat it as
approved unless a comment below says otherwise.

**B. A one-time history move.** The user has real sets logged under a barbell-named exercise
(e.g. Bench Press) with `freeWeightTag == .dumbbell`. Those must land under the new dumbbell
exercise. This is a MIGRATION, not a rename: D23 forbids reinterpreting a snapshot silently, so
it must:
- run once, keyed on the catalog version bump, and be idempotent;
- rewrite BOTH the relationship and the snapshot (`snapshotExerciseID`, `snapshotExerciseName`)
  on affected entries — and only entries whose snapshot tag is `.dumbbell` and whose snapshot
  exercise has a mapped dumbbell counterpart;
- record what it did (`Workout.historyEditedAt`? No — the user did not edit; use a migration log
  line in the seeder and a count surfaced once in Settings), so the move is visible, not silent;
- leave presets attached (a grip preset is a property of the movement and travels — D37).

**C. The equipment sheet** should stop offering Dumbbell under an exercise whose counterpart
exists, and instead offer "Log as Dumbbell Bench Press instead" — otherwise the split re-grows.

## Acceptance criteria

- `LegacyStoreMigrationTests` opens the fixture AND a test proves the move: a fixture entry under
  Bench Press + dumbbell tag ends under Dumbbell Bench Press with records/chart following it.
- The move never touches barbell-tagged or machined entries; a test pins it.
- Running the seeder twice moves nothing the second time.
- The mapping table (barbell exercise → dumbbell exercise) is data in `Domain/`, unit-tested for
  no duplicate targets.
- **Before installing:** a fresh export of the real history is on iCloud Drive.
