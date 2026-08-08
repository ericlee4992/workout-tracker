# 02 — SwiftData schema & persistent store

**What to build:** The complete milestone-2 schema from SPEC's data-model sketch (as revised 2026-08-08), on a disk-backed ModelContainer the app boots with. Enumerated fully here so later tickets add no schema: Exercise, EquipmentModel, Gym (incl. city?), MachineInstance (incl. archived), WorkoutTemplate/TemplateItem (scalar order, no rest), Workout (startedAt, finishedAt?), ExerciseEntry (freeWeightTag?, scalar order, snapshot UUIDs + display strings), SetRecord (scalar order, completedAt?, weightValue/weightUnit/normalizedKg), GymExerciseMemory (scalar IDs + updatedAt), app-preferences storage (unit preference, drift suppression, global + per-exercise rest overrides, seeded-catalog version, notification-permission marker). Also: Gym.archived, Workout.sourceTemplateID?, Workout.restEndsAt?, snapshot loadType + freeWeightTag, and SetRecord draft optionality (reps/weightValue/normalizedKg optional until completed). Prototype value types reduce to shared enums; screens may keep compiling on temporary in-memory data until ticket 07 rewires them. Later tickets may add fields only with an explicit note here.

**Blocked by:** 01.

**Status:** ready-for-agent

- [ ] CloudKit rules hold: UUID ids, all relationships optional with explicit inverses, no `@Attribute(.unique)`, no `deny` delete rules; ordering via scalar `order` fields only
- [ ] Round-trip test: build object graph → save → tear down container → reopen same on-disk store with a new container → refetch → field-by-field equality (a refetch from the original context does not count)
- [ ] Archival delete rule test: deleting a Gym/MachineInstance marks archived rather than cascading into workout history
- [ ] App launches on the store; `xcodebuild test` green
