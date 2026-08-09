# 02 — SwiftData schema & persistent store

**What to build:** The complete milestone-2 schema from SPEC's data-model sketch (as revised 2026-08-08), on a disk-backed ModelContainer the app boots with. Enumerated fully here so later tickets add no schema: Exercise, EquipmentModel, Gym (incl. city?), MachineInstance (incl. archived), WorkoutTemplate/TemplateItem (scalar order, no rest), Workout (startedAt, finishedAt?), ExerciseEntry (freeWeightTag?, scalar order, snapshot UUIDs + display strings), SetRecord (scalar order, completedAt?, weightValue/weightUnit/normalizedKg), GymExerciseMemory (scalar IDs + updatedAt), app-preferences storage (unit preference, drift suppression, global + per-exercise rest overrides, seeded-catalog version, notification-permission marker). Also: Gym.archived, Workout.sourceTemplateID?, Workout.restEndsAt?, snapshot loadType + freeWeightTag, and SetRecord draft optionality (reps/weightValue/normalizedKg optional until completed). Prototype value types reduce to shared enums; screens may keep compiling on temporary in-memory data until ticket 07 rewires them. Later tickets may add fields only with an explicit note here.

**Blocked by:** 01.

**Status:** resolved

- [x] CloudKit rules hold: UUID ids, all relationships optional with explicit inverses, no `@Attribute(.unique)`, no `deny` delete rules; ordering via scalar `order` fields only
- [x] Round-trip test: build object graph → save → tear down container → reopen same on-disk store with a new container → refetch → field-by-field equality (a refetch from the original context does not count)
- [x] Archival delete rule test: deleting a Gym/MachineInstance marks archived rather than cascading into workout history
- [x] App launches on the store; `xcodebuild test` green

---

**Resolution (2026-08-08):** Full schema in `WorkoutTracker/Domain/Models.swift` — Exercise, EquipmentModel, Gym, MachineInstance, WorkoutTemplate/TemplateItem, Workout, ExerciseEntry (snapshot UUIDs + loadType + freeWeightTag + display strings), SetRecord (draft optionality), GymExerciseMemory, plus app preferences as `AppPreferences` (unit pref, drift suppression, global rest defaults, seeded-catalog version, notification marker) and `ExerciseRestOverride` (per-exercise rest, scalar exerciseID). All CloudKit rules hold; delete rules are cascade (workout→entries→sets, template→items) or nullify — never deny. `WorkoutTrackerStore.makeContainer(url:)` builds the on-disk container; the app boots on it (`WorkoutTrackerApp`). `PrototypeModels.swift` reduced to shared String-raw Codable enums (WeightUnit, SetType, LoadType, EquipmentTag — raw values are now stable ids with a `label` for display) + `Sample`-prefixed throwaway structs so the prototype UI keeps compiling on SampleStore until ticket 07. Tests in `WorkoutTrackerTests/SchemaTests.swift`: fresh-container round-trip (field-by-field), archival-by-flag with hard-delete nullify safety net, and compile-time relationship-optionality proof. `xcodebuild test` green on WT-iPhone.

**Field addition (ticket 07, 2026-08-08):** `ExerciseEntry.snapshotCapturedAt: Date?` — when the entry's context snapshot was captured (first set completion). nil = draft entry, equipment editable; non-nil = equipment frozen (D19), permanently — the field is never reset even when the completion is undone. Optional with nil default, CloudKit-safe, additive-only (lightweight migration).

**Field addition (ticket 14, 2026-08-08):** `Workout.restStartedBySetID: UUID?` — the
set whose completion started/replaced the persisted rest timer. This makes the D13
un-completion cancellation rule recoverable across relaunch. Optional scalar with nil default,
CloudKit-safe, additive-only (lightweight migration).

**Field addition (ticket 15, 2026-08-08):** `TemplateItem.targetRepsBySet: [Int?]` —
ordered per-set-slot target reps. `targetReps` remains as the first-slot compatibility value;
the array is authoritative for ticket 15/16 template values. Non-relationship scalar with an
empty default, CloudKit-safe, additive-only (lightweight migration).

**Field addition (review fix, 2026-08-08):** `Workout.restStartedAt: Date?` — when the
current rest timer started. Persisted alongside `restEndsAt` so the timer's *total* duration
(end − start, growing with each +15s) survives relaunch; the progress bar's denominator must
be the total, not the remaining time. Cleared with the rest of the timer state. Optional scalar
with nil default, CloudKit-safe, additive-only (lightweight migration).
