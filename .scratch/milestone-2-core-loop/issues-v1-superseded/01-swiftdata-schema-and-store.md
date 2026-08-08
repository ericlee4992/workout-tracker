# 01 — SwiftData schema & persistent store

**What to build:** The app boots on a real SwiftData store instead of in-memory sample data. All entities from the SPEC data-model sketch exist as SwiftData models (Exercise, EquipmentModel, Gym, MachineInstance, WorkoutTemplate/TemplateItem, Workout, ExerciseEntry with context snapshot fields, SetRecord, GymExerciseMemory), following the CloudKit-compatibility rules: UUID ids, optional relationships, no unique constraints.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] App launches with a SwiftData ModelContainer; prototype value types in `Domain/PrototypeModels.swift` are removed or reduced to enums shared with the schema (WeightUnit, SetType, LoadType, EquipmentTag)
- [ ] SetRecord stores weight as entered (`weightValue`, `weightUnit`) plus `normalizedKg`
- [ ] ExerciseEntry carries denormalized snapshot fields (gym name, machine label, manufacturer+model)
- [ ] A save-then-fetch round-trip test passes in a test target (create workout → quit context → refetch → identical values)
- [ ] No `@Attribute(.unique)` anywhere; all relationships optional
