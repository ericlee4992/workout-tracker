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

**Field addition (ticket 17, 2026-08-09):** `AppPreferences.selectedGymID: UUID?` — the gym the
Start screen is set to, remembered across launches (D1). Scalar id rather than a relationship, so
an archived or deleted gym degrades to "No gym" instead of resurrecting; nil is itself a real
remembered choice. Optional with nil default, CloudKit-safe, additive-only (lightweight migration).

**Field additions (ticket 21, 2026-08-10):** `EquipmentModel.equipmentType: EquipmentCategory?`
— selectorized / plate-loaded / cable / rack-or-Smith / bodyweight station. Ticket 21 allowed
deriving this from the linked exercises' `equipmentTypeTags` and it does not work: those tags
describe the *movement*, and a chest press exists as a selectorized stack, a plate-loaded lever and
a Smith variant that all link to the same exercise (1147 of 1887 seeded models derive the single
tag `machine`). So it is an explicit, seeded field, sourced from the section headings the ticket-20
research was transcribed under (`TYPE(...)` markers in `scripts/catalog_data.py`); nil means "not
established", never "guessed", and those rows browse under "Uncategorized". Allowlisted for
reconciliation (D24) — catalog version 3 carries the values onto stores seeded at version 2.

Also `AppPreferences.modelBrowseGrouping: CatalogGrouping?`, `modelBrowseMuscleGroup: String?`,
`modelBrowseEquipmentType: EquipmentCategory?`, `machineBrowseGrouping: MachineGrouping?`,
`exerciseBrowseMuscleGroup: String?`, `exerciseBrowseEquipmentTag: EquipmentTag?` — the remembered
grouping mode and active filters per browsing surface. Display state only (D23): nothing logged
reads them. All optional with nil defaults (nil = the screen's default / "All"): a non-optional
enum column has no value to migrate into on an existing store and fails to materialise. CloudKit-
safe, additive-only (lightweight migration).

**Field addition (ticket 17 post-review, 2026-08-09):** `Workout.sourceTemplateName: String?` and
`Workout.snapshotGymName: String?` — the template name and gym name captured when the workout
starts. History titles and subtitles read these snapshots instead of the live `WorkoutTemplate`
/`Gym` rows (D23), so renaming or deleting a template no longer retitles finished workouts and
renaming a gym no longer rewrites old rows. Optional scalars with nil defaults, CloudKit-safe,
additive-only (lightweight migration); workouts logged before this addition simply fall through
to the exercise-derived title and the entry-level gym snapshot.

**Field addition (codex-review-4, 2026-08-10):** `AppPreferences.seededCatalogFingerprint:
String?` — a hash of the catalog content last reconciled (every fixed UUID plus every allowlisted
mutable field, D24). `seededCatalogVersion` alone cannot distinguish "same catalog" from "same
version number, edited content", and the launch fast path used to trust a *row count*, which
survives one seeded row being deleted and another inserted. The fingerprint plus an id-set check
is what makes the fast path safe to skip work on. Optional with a nil default (nil = "unknown",
costing one full reconcile), CloudKit-safe, additive-only (lightweight migration).
