# Codex cross-review 04b — Dumbbell reclassification, round 2

Review boundary: `94a0652...23e004c` (fix commit `23e004c`). Verdict: **not clear yet**. The round-one critical correctness failures are substantially repaired: D51 now explicitly licenses the narrow snapshot rewrite, late-arriving history is handled on both seeder paths, presets are re-homed, provenance survives export, Settings reads the canonical row, and valid supersets remain contiguous. Three edge cases remain, two of which are defects introduced by the round-one fixes.

## Standards

### High — Preset re-homing duplicates the repository's canonical name logic and gets a weaker answer

`DumbbellHistoryMove.preset` compares raw names with case/diacritic-insensitive `String.compare`, then creates a preset with the raw incoming name (`WorkoutTracker/Domain/DumbbellHistoryMove.swift:95-103`). That duplicates, but does not preserve, `ExercisePresets`' domain rule: its comparator also trims outer whitespace and collapses repeated spaces (`WorkoutTracker/Domain/ExercisePresets.swift:24-40`, `WorkoutTracker/Domain/ExercisePresets.swift:54-59`). A target preset named `"Wide grip"` and a migrated source preset named `"WIDE   GRIP"` therefore become separate UUIDs even though the rest of the app treats those names as one visible variation, splitting D36 records/chart/prefill and failing D51's same-named re-home. This is a concrete D36/D51 breach and a possible Duplicated Code smell. Reuse one canonical matcher, clean names before creation, and add outer/repeated-whitespace coverage.

### Medium — D51's cheap every-launch premise is not met

The count gate checks only whether any entry snapshot uses one of the ten mapped source UUIDs (`WorkoutTracker/Domain/DumbbellHistoryMove.swift:45-49`). An ordinary barbell Bench Press, a running workout, or an uncaptured/ineligible entry keeps that count positive forever; the migration then fetches target rows and materializes every entry for all ten common source exercises before filtering them in Swift (`WorkoutTracker/Domain/DumbbellHistoryMove.swift:51-66`). The predicate does compile and execute as a persistent query, but it does not gate the normal no-op case described by D51. Tighten the persisted candidate condition to the migration qualifiers and add a large no-op store containing permanent barbell source history.

## Spec

### High — Whitespace-equivalent target presets can still be duplicated

The round-two prompt expressly asks whether re-homing can duplicate an existing target preset under `ExercisePresets.cleanedName` rules (`.scratch/milestone-9-history-and-summary/codex-review-04b-prompt.md:10-15`). It can: raw `String.compare` ignores case and diacritics but not leading/trailing or repeated whitespace, while the app's preset duplicate rule normalizes all of those (`WorkoutTracker/Domain/DumbbellHistoryMove.swift:94-103`; `WorkoutTracker/Domain/ExercisePresets.swift:24-40`, `WorkoutTracker/Domain/ExercisePresets.swift:54-59`). The resulting second UUID reintroduces the record island D51 was written to eliminate. The existing test covers case only, not whitespace (`WorkoutTrackerTests/DumbbellExercisesTests.swift:228-253`).

### Medium — The count query does not cheaply identify eligible history

D51 requires the every-launch reclassification to be gated by one cheap count, and the re-review specifically asks whether its predicate is correct and cheap (`docs/DECISIONS.md:60`; `.scratch/milestone-9-history-and-summary/codex-review-04b-prompt.md:16-20`). `sourceIDs.contains(snapshotExerciseID)` is SQL-translatable—the focused migration tests execute it successfully—but it counts all source-exercise entries rather than eligible frozen, finished, dumbbell-tagged rows (`WorkoutTracker/Domain/DumbbellHistoryMove.swift:45-57`). Once a user has any permanent barbell Bench Press history, every launch takes the slow path and materializes all mapped-source history. This preserves correctness but misses the specified common-case cost.

### Medium — Copying a stale singleton group defeats the orphan repair

The shared split now copies `entry.supersetGroupID` before calling `pruneOrphanGroups` (`WorkoutTracker/Domain/WorkoutSession.swift:443-473`). That is correct for a valid adjacent group and fixes both counterpart and ordinary equipment splits. For a stale one-member group, however, the copy creates a two-entry run first; pruning therefore sees a valid-looking group and cannot remove it. A standalone exercise becomes a two-member "superset" consisting of its old and continuation entries, changing badges and rest behavior contrary to D48's rule that a group of one is not a superset (`WorkoutTracker/Domain/Supersets.swift:48-55`, `WorkoutTracker/Domain/Supersets.swift:114-119`). Validate/prune the source membership before carrying its ID and add a singleton-source split regression test.

## Round-one closure audit

- **Decision boundary:** D51 expressly reopens D19/D23/D47 for this catalog-driven operation and matches the implemented fields and scope. D19, D23, and D47 point back to it. No additional frozen-history mutation was found.
- **Preset movement:** relationship and `snapshotPresetID` both move; a nil live preset falls back to `snapshotPresetName`; `snapshotPresetName` remains frozen; the source preset is not mutated. Preferring the live preset's current name is correct when that preset was renamed: the UUID is the variation identity, while the old snapshot name remains historical display. The non-deleted target list supplied to `nextOrder` is otherwise correct. Whitespace-equivalence is the remaining High finding.
- **Every launch:** the fast path invokes the move before returning, and the full path reconciles exercises before invoking it, so a fresh store has target rows before migration. Moved target IDs are disjoint from sources. After the first check, a true no-op does not mutate preferences or trigger `save`; the remaining issue is query/materialization churn when ineligible source rows exist.
- **Provenance/export:** every actually moved row receives both provenance fields. The collector exports them independently of its frozen/live context branch; JSON schema 7 includes row and preference provenance; CSV appends `reclassifiedFrom` at column 37. Header/row tests, `docs/SPEC.md`, and `.scratch/milestone-3-export/spec.md` consistently say 37.
- **Supersets:** valid adjacent groups survive both counterpart and ordinary equipment splits, and the regression test covers the counterpart case. The stale-singleton ordering defect above is not covered.
- **Counterpart UI:** a mapped exercise never falls back to the bare Dumbbell tag. When the target row is absent, the List contains a named, disabled button using `Pair.targetName` plus a warning icon. The existing UI test covers the normal enabled row and passed; there is no missing-target UI fixture/test.
- **Other round-one findings:** canonical Settings selection, zero-result `checkedAt`, per-row History disclosure, exported preference audit fields, and the narrowed `switchToDumbbellCounterpart` contract are closed. No other introduced defect was found.

## Verification

- `git diff --check 94a0652...23e004c` passed.
- 73 focused unit tests across `DumbbellExercisesTests`, `ExportFidelityTests`, `ExportTests`, `LegacyStoreMigrationTests`, and `WorkoutNameTests` passed.
- `DumbbellCounterpartUITests` passed 1/1 on the `WT-iPhone` simulator.
- No source files were modified by this review.

Standards — 2 findings (worst: High); Spec — 3 findings (worst: High).
