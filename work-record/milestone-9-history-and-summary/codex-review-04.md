# Codex cross-review 04 — Dumbbell exercises and history move

Review boundary: `4fe1d33..94a0652` (one commit, `94a0652`). Verdict: **do not merge or install over the live store**. The catalog additions and ordinary migration path work, but the change creates structurally orphaned preset history, cannot recover history that arrives after the global v5 gate, and contradicts the repository's frozen-history decisions without reopening them.

## Standards

### Critical — The migration contradicts three locked history decisions without reopening them

`DumbbellHistoryMove` rewrites the live exercise relationship and the permanently frozen snapshot exercise UUID/name while deliberately leaving `historyEditedAt` nil (`WorkoutTracker/Domain/DumbbellHistoryMove.swift:7-21`, `WorkoutTracker/Domain/DumbbellHistoryMove.swift:51-53`). D19 says the context freezes permanently, D23 says historical queries retain frozen snapshot identity, and D47 expressly says an edit must never change frozen exercise identity/name and every permitted edit is marked (`docs/DECISIONS.md:27`, `docs/DECISIONS.md:31`, `docs/DECISIONS.md:56`). The user-approved ticket can justify reopening those rules, but the commit does not amend `DECISIONS.md`; a global Settings note is neither the required recorded reopening nor a marker on the affected workouts. That violates `CLAUDE.md:3-8`.

### High — Preserving a source-owned preset creates an impossible cross-exercise snapshot

The migration changes the entry to the target exercise but intentionally preserves `preset`, `snapshotPresetID`, and `snapshotPresetName` (`WorkoutTracker/Domain/DumbbellHistoryMove.swift:19-21`, `WorkoutTracker/Domain/DumbbellHistoryMove.swift:51-53`). D37 says a preset belongs to one exercise, while D36 makes its UUID part of records, chart, and prefill identity (`docs/DECISIONS.md:44-45`). Export therefore emits a Dumbbell Bench Press entry with a preset whose exported owner is still Bench Press (`WorkoutTracker/Domain/ExportCollector.swift:112-120`, `WorkoutTracker/Domain/ExportCollector.swift:280-301`). A future preset created for the dumbbell exercise receives another UUID, so future work cannot join the migrated variation. No preset-bearing migration test covers this.

### High — Settings does not read the canonical preferences row

The seeder writes its audit record to `AppPreferences.canonical(in:)`, but Settings reads `allPreferences.first` twice (`WorkoutTracker/Features/Settings/AppSettingsSection.swift:58-59`). The model explicitly permits duplicate CloudKit-compatible rows and defines deterministic canonical selection (`WorkoutTracker/Domain/Models.swift:694-709`). With duplicates, Settings can hide the actual migration record or display a stale one, defeating the visibility safeguard for a snapshot rewrite.

### High — The only migration audit record is dropped from the backup

The two provenance fields are persisted at `WorkoutTracker/Domain/Models.swift:619-623`, but `ExportSnapshot.Preferences` has no corresponding fields and `ExportCollector.preferences` omits them (`WorkoutTracker/Domain/ExportSnapshot.swift:87-107`, `WorkoutTracker/Domain/ExportCollector.swift:392-403`). Meanwhile, the export contains the rewritten target identity and a nil `historyEditedAt`. Even if D19/D23/D47 were properly amended, dropping the only fact that explains the rewrite violates the complete-backup/historical-fidelity rules in D28/D30.

### Low — Possible Mysterious Name / overbroad contract in `switchExercise`

`switchExercise(of:to:)` accepts any exercise, clears machine and preset, and guesses the first non-machine tag (`WorkoutTracker/Domain/WorkoutSession.swift:404-422`), although its only intended operation is switching a mapped source to its dumbbell counterpart. The name and signature promise a general exercise switch that the implementation cannot safely provide. Restrict it to a verified counterpart or name the narrower operation.

## Spec

### Critical — Migrated preset history is stranded from all future dumbbell work

The ticket says to leave presets attached because a grip “travels” (`work-record/milestone-9-history-and-summary/issues/04-dumbbell-exercises.md:24-25`), but the implementation preserves the old preset object/UUID while changing its entry to another exercise (`WorkoutTracker/Domain/DumbbellHistoryMove.swift:51-53`). The target exercise cannot offer that source-owned preset, and a same-named target preset has a different UUID. Since records, charts, and prefill key on the preset UUID, migrated rows occupy a permanent historical island. The export is internally inconsistent as well: target exercise identity beside a preset definition owned by the source exercise.

### Critical — A global version gate permanently misses late-arriving eligible history

The ticket requires affected history to land under the new exercise and calls the move idempotent (`work-record/milestone-9-history-and-summary/issues/04-dumbbell-exercises.md:17-25`). Once canonical preferences say v5, the fast path returns before the move (`WorkoutTracker/Domain/CatalogSeeder.swift:39-42`), and the migration condition can never become true again (`WorkoutTracker/Domain/CatalogSeeder.swift:54-60`). Thus an old Bench Press+dumbbell entry merged after the crossing—or selected alongside a newer v5 `AppPreferences` duplicate—remains unmoved forever. The entry-level transformation is already idempotent because targets are disjoint from sources, so the global gate creates incompleteness without providing the claimed safety.

### High — Frozen counterpart switching can sever a superset

For a frozen entry, `split` inserts a new entry immediately after the old one but does not carry or repair `supersetGroupID` (`WorkoutTracker/Domain/WorkoutSession.swift:438-476`). If the old entry is followed by another member of the same adjacent D48 group, the new ungrouped entry interrupts that run and changes its rest behavior. The ticket requires completed sets to remain and drafts to move; it does not authorize changing the workout's superset structure. The frozen-switch test contains no superset (`WorkoutTrackerTests/DumbbellExercisesTests.swift:218-238`).

### Medium — Duplicate preferences can make the required Settings disclosure disappear

The required count is written to the canonical row, but the UI reads an unsorted first row (`WorkoutTracker/Features/Settings/AppSettingsSection.swift:58-59`). With two preference rows, the user may see no “History update” despite a completed rewrite, contrary to the ticket's “visible, not silent” requirement (`work-record/milestone-9-history-and-summary/issues/04-dumbbell-exercises.md:21-24`).

### Medium — A zero-result migration is indistinguishable from one that never ran

The model documents nil as either “moved nothing” or “has not run,” and the seeder writes no date or zero count unless at least one completed set moved (`WorkoutTracker/Domain/Models.swift:619-623`, `WorkoutTracker/Domain/CatalogSeeder.swift:55-59`). The fresh-store test locks in that ambiguity (`WorkoutTrackerTests/DumbbellExercisesTests.swift:187-193`). This does not “record what it did”; Settings cannot distinguish a successful zero-result crossing from a migration that was skipped or failed.

### Medium — A missing counterpart row restores the forbidden Dumbbell tag

`dumbbellCounterpart` suppresses fetch failures and returns nil when the target row is absent (`WorkoutTracker/Features/ActiveWorkout/MachinePickerSheet.swift:129-137`). That sends the `.dumbbell` iteration through the ordinary tag branch (`WorkoutTracker/Features/ActiveWorkout/MachinePickerSheet.swift:49-80`), reopening exactly the representation the ticket says must stop being offered (`work-record/milestone-9-history-and-summary/issues/04-dumbbell-exercises.md:26-28`). The normal launch reconciler should heal a partial store, but the fallback is unsafe for a transiently missing row or fetch failure.

### Medium — Export drops the provenance that is supposed to make the rewrite non-silent

Moved entries correctly export with the target snapshot ID/name, but neither JSON preferences nor the workout carries the migration fact (`WorkoutTracker/Domain/ExportSnapshot.swift:87-107`, `WorkoutTracker/Domain/ExportCollector.swift:392-403`). Because `historyEditedAt` remains nil, an exported backup presents the target identity without the only audit record explaining that it was rewritten. That is distinct from the preset-owner inconsistency and fails the ticket's “record what it did” safeguard (`work-record/milestone-9-history-and-summary/issues/04-dumbbell-exercises.md:21-24`).

## Mutation audit

Only three `ExerciseEntry` properties are assigned by the move. The complete field audit is:

| `ExerciseEntry` field | Should the move change it? | Does it? |
|---|---|---|
| `id` | No | No |
| `order` | No | No |
| `freeWeightTag` | No; live tag remains dumbbell | No |
| `supersetGroupID` | No | No |
| `workout` | No | No |
| `exercise` | Yes, to the mapped target | Yes |
| `machine` | No | No |
| `preset` | Ticket says no, but that is unsafe per the preset findings | No |
| `sets` | No | No |
| `snapshotCapturedAt` | No | No |
| `snapshotExerciseID` | Yes, to the mapped target | Yes |
| `snapshotMachineID` | No | No |
| `snapshotModelID` | No | No |
| `snapshotGymID` | No | No |
| `snapshotLoadType` | No; mapping tests require equal catalog load types | No |
| `snapshotFreeWeightTag` | No; it remains the evidence that qualifies the move | No |
| `snapshotExerciseName` | Yes, to the mapped target name | Yes |
| `snapshotMachineLabel` | No | No |
| `snapshotModelName` | No | No |
| `snapshotGymName` | No | No |
| `snapshotPresetID` | Ticket says no, but that strands the variation | No |
| `snapshotPresetName` | Ticket says no, but it remains attached to the source-owned UUID | No |

Every `SetRecord` stays attached to the same entry and is untouched directly, which is correct for a reclassification: `id`, `order`, `type`, `reps`, `weightValue`, `weightUnit`, `normalizedKg`, `completedAt`, `barWeightValue`, `barNormalizedKg`, `prefilledAt`, and `entry` all should remain unchanged and do remain unchanged (`WorkoutTracker/Domain/Models.swift:483-555`; the move's only writes are `DumbbellHistoryMove.swift:51-53`). `Workout.historyEditedAt` also remains unchanged, but that is the unrecorded locked-decision conflict above.

## Edge-case and integration trace

- **Qualification:** running workouts fail `finishedAt != nil`; barbell rows and machined rows with nil snapshot tag fail the exact `.dumbbell` check; unmapped IDs fail counterpart lookup; uncaptured snapshots fail `snapshotCapturedAt`; deleted entries/workouts are guarded. An entry with a nil live `exercise` but a mapped Bench Press snapshot *is* moved and relinked, appropriately using D23's frozen identity; a genuinely user-created/deleted exercise has a different, unmapped UUID. The main test covers barbell, machined, running, and unmapped rows, but not uncaptured, deleted, or nil-relationship rows (`WorkoutTrackerTests/DumbbellExercisesTests.swift:88-121`).
- **Seeder order and fast path:** a v4 store cannot take the no-update fast path because `catalog.version > previousVersion`; `reconcileExercises` runs before the move, so target rows exist; a 0→5 fresh store runs over no history. A 5→6 bump does not retrigger because `previousVersion < 5` is false, while a direct second run is harmless because no target is also a source. The unrecoverable v5/late-merge and duplicate-preferences cases remain the Critical finding.
- **Draft switch:** it updates live/provisional exercise identity, clears machine, chooses `.dumbbell` for every actual counterpart, drops the old preset, clears bars and inherited prefill, and preserves user-entered draft values, order, workout, sets, and superset membership. **Frozen switch:** completed rows remain on the old entry; draft rows move in relative order; bars and inherited prefill clear; touched values/type/unit remain; both entries' set order is repaired. The missing superset handling is the High finding. All shipped targets have exactly one `[.dumbbell]` tag, so `first { $0 != .machine }` happens to choose correctly for every counterpart despite the general API smell.
- **Counterpart lookup:** it performs one small ID fetch per body recomputation, which is not a material performance problem. Missing/error fallback is the Medium correctness problem above.
- **Catalog:** all 14 approved rows are present; existing exercise IDs/names 1–76 and the 12 legacy IDs remain unchanged; mapping sources and targets are unique and disjoint; version is 5. `python3 scripts/generate_seed_catalog.py --check` passed. Existing count assertions are lower-bound or catalog-derived; no stale exact-count test was found.
- **Records/chart/export:** the target exercise ID/name and unchanged set numbers flow through records and chart inputs. Preset-bearing history does not remain comparable to future target work, and export loses both coherent preset ownership and the migration audit record, as reported above.
- **Settings/schema/callers:** both new model fields are optional and the legacy fixture opens with nil values. All introduced production declarations have callers. The “no way back” commit title is false for late-arriving history in the damaging direction: the system has no recovery path once preferences are at v5. No unrelated scope expansion was found.
- **Manual gate:** the required fresh iCloud Drive export before installation is external state and cannot be proven from this repository; it remains a hard pre-install prerequisite.

## Verification

`git diff --check 4fe1d33...94a0652` passed. The 50 focused tests in `DumbbellExercisesTests`, `LegacyStoreMigrationTests`, `SeedingTests`, and `ExportFidelityTests` passed. `DumbbellCounterpartUITests` passed 1/1 after a clean rebuild. An initial incremental UI run used a stale compiled test body (its diagnostics and line map did not match the reviewed source) and failed before reaching the counterpart sheet; the clean build is the relevant result.

Standards — 5 findings (worst: critical); Spec — 7 findings (worst: critical).
