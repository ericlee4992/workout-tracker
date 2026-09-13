# Codex cross-review — exercise presets (D36–D38)

Verdict: **do not merge or install over the live store yet.** JSON drops preset-owned user data; previous-performance snapshots cross preset boundaries; changing presets can retain another preset's auto-prefill.

Fixed point: `HEAD` (`5239ef2e8bf53638e57e0276dec40dcf83e29e2c`), reviewing the uncommitted preset worktree. No code changed.

## Spec

### Critical

1. **JSON is not a complete backup of presets.**
   - **File/line:** `WorkoutTracker/Domain/ExportSnapshot.swift:30–40, 94–112`; `WorkoutTracker/Domain/ExportCollector.swift:35–45, 79–81, 175–186`
   - **Failure:** There is no exported `ExercisePreset` collection, `Machine` omits `defaultPresetID`, and the collector never fetches presets. Only presets used by entries leave the phone, reduced to snapshot/live ID + name. Unused presets, order, exercise ownership, and every machine's usual preset disappear. A preset on an otherwise-unreferenced seeded exercise also fails to make that exercise referenced.
   - **Violates:** D28, D30; spec lines 54–55; JSON is the complete backup.
   - **Smallest fix:** Add JSON preset rows `(id, name, order, exerciseID)`, `Machine.defaultPresetID`, a preset count, collector coverage, and preset-owner exercise IDs to D28 reference collection. Add unused/deleted/draft/frozen/default round trips. CSV's appended entry columns are fine.

### High

2. **Two of the three previous-performance snapshot layers mix presets.**
   - **File/line:** `WorkoutTracker/Domain/PreviousPerformance.swift:168–200`
   - **Failure:** `thisEquipment` uses `layerOneMatch` and filters `snapshotPresetID`; `sameModelElsewhere` and `anyEquipment` do not. A narrow-grip sheet can show the latest wide-grip or pre-preset (`nil`) session even though the record block below it is correctly narrow-only.
   - **Violates:** D36, D23; spec lines 32–37; issue 01 line 26.
   - **Smallest fix:** Capture `currentPresetID(for:)` once in `layers(for:in:)` and require equality in both closures. Test all three layers for wide, narrow, and `nil`.

3. **Preset switching can keep another preset's auto-prefilled values.**
   - **File/line:** `WorkoutTracker/Domain/WorkoutSession.swift:323–365`; `WorkoutTracker/Features/ActiveWorkout/ExerciseEntryCard.swift:347–349, 605–638`
   - **Failure:** Prefill is persisted into draft sets. A draft preset change edits the entry but leaves those values in place, and `prefillTaskID` omits the preset so no lookup reruns. A frozen split moves all drafts, including values auto-filled for the old preset. Even a rerun with no candidate only changes `PREVIOUS` to `—`; it does not clear the stored inputs. Narrow grip can therefore arrive seeded with wide-grip numbers.
   - **Violates:** D36; D19's draft-move rule does not authorize carrying a false comparison across contexts.
   - **Smallest fix:** Include the effective preset ID in `prefillTaskID`; track auto-prefill provenance and, on preset/equipment context change, clear/recompute only untouched auto-filled drafts while preserving user-edited drafts. Test draft switch and frozen split both with and without history for the destination preset.

### Medium

4. **The domain accepts a preset owned by another exercise.**
   - **File/line:** `WorkoutTracker/Domain/WorkoutSession.swift:323–340`
   - **Failure:** `choosePreset` assigns any `ExercisePreset`; only the current UI happens to pass rows from `entry.exercise`. A Leg Press preset can be attached to a Seated Row entry through the service, then snapshotted and grouped as if valid. `chooseEquipment` will carry that invalid preset onward.
   - **Violates:** D37; D23.
   - **Smallest fix:** Resolve/validate the candidate against the entry exercise in the service and reject or degrade foreign values to `nil`; apply the same validation before `chooseEquipment` carries a preset. Test draft and frozen paths.

5. **The previous-performance surface does not identify the selected preset where it names the machine.**
   - **File/line:** `WorkoutTracker/Features/ActiveWorkout/PreviousPerformanceSheet.swift:147–179`
   - **Failure:** The layer-one header says `This equipment — <machine>` but not the current preset. With no matching history, nothing on the sheet says whether the empty record table is Wide, Narrow, or None. Historical snapshot rows do append their own preset, which is not a substitute for naming the current query.
   - **Violates:** spec line 79; issue 03 line 19; D36.
   - **Smallest fix:** Append the draft/frozen current preset name (or `No preset`) to the layer header wherever it prints the current machine; test the empty-history case.

6. **The live-store migration path is not tested.**
   - **File/line:** `WorkoutTracker/Domain/Models.swift:34–38, 64–73, 159–163, 312–340, 603–619`; `WorkoutTrackerTests/ExercisePresetTests.swift:56–60, 230–255`
   - **Failure:** The shape is eligible for inferred lightweight migration: new attributes and relationships are optional, and the new entity has no old rows. Existing entries should materialize `snapshotPresetID/name == nil`. But every preset test creates the new schema from scratch; none opens a store made by the pre-preset schema. The checked migration acceptance criterion is evidence-free for the only store that matters. Apple's inferred-migration rules cover adding attributes, relationships, and entities: [Migrating your data model automatically](https://developer.apple.com/documentation/coredata/migrating-your-data-model-automatically).
   - **Violates:** issue 01 lines 20–21; T1's migration risk mitigation.
   - **Smallest fix:** Commit a fixture store generated by the `HEAD` app/schema, open it with the new container, and assert old workouts/entries/sets remain queryable, preset fields are `nil`, records/prefill stay in the `nil` group, and export succeeds.

7. **The tests claim substantially more than they prove.**
   - **File/line:** `WorkoutTrackerTests/ExercisePresetTests.swift:104–119, 137–158, 183–224, 226–288`; `WorkoutTrackerTests/ExportFidelityTests.swift:316–345`; `WorkoutTrackerUITests/ExercisePresetUITests.swift:44–68`; issue 01 lines 20–28; issue 04 lines 19–21.
   - **Failure:**
     - `recordsDoNotCrossPresets` checks named presets at the machine key only: not `nil`, model, exercise, free-weight, the three performance layers, or the record surface.
     - The split test has no pre-existing draft rows, so it does not prove drafts move with identity/order/values.
     - The stale-default test covers a foreign ID, not a deleted preset or model/exercise change.
     - The catalog test bumps a catalog that still contains the exercise; it does not exercise a future catalog dropping it.
     - Export tests cover one frozen used preset, not live drafts, unused presets, ordering/ownership, deleted presets, or machine defaults.
     - The UI test counts two `staticTexts` named `Seated Row`. That can establish two accessibility nodes, not that the completed row stayed in the old entry and drafts moved to the new one. It never logs the narrow card; Finish deletes it, and History only proves the original Wide snapshot.
   - **Violates:** T6; the cited ticket acceptance/resolution claims.
   - **Smallest fix:** Add adversarial tests for the omitted boundaries. In UI, give cards stable entry IDs, assert Wide remains selected on the old card and Narrow on the new card, log the second card, then verify both snapshot labels in History/export.

### Low

8. **The machine preset picker is rendered twice.**
   - **File/line:** `WorkoutTracker/Features/Gyms/GymsView.swift:454–488`
   - **Failure:** Two identical sections share one binding and the same `machinePresetPicker` accessibility identifier. The UI test's `firstMatch` hides it.
   - **Violates:** D38's one log-time default control; issue 02's identifier contract.
   - **Smallest fix:** Delete either duplicate block.

## Standards

1. **Hard — fallback selection lives in a SwiftUI view without a unit test.**
   - **File/line:** `WorkoutTracker/Features/Gyms/GymsView.swift:576–591`
   - **Violation:** `CLAUDE.md` requires pure fallback selection in `Domain/`, unit-tested. This movement-label change is unrelated to presets but is in the reviewed worktree.
   - **Smallest fix:** Move one-vs-many exercise/name selection to a pure Domain helper and test it; keep fetching and state assignment in the view.

2. **Judgement — duplicated split algorithm.**
   - **File/line:** `WorkoutTracker/Domain/WorkoutSession.swift:273–312, 332–366`
   - **Smell:** `chooseEquipment` and `choosePreset` duplicate entry insertion, renumbering, draft migration, empty-row seeding, save, and return. The duplication already enabled the prefill invariant to be missed twice.
   - **Smallest fix:** Extract one private split primitive parameterized by validated new context.

3. **Judgement — dead/speculative helpers and state.**
   - **File/line:** `WorkoutTracker/Domain/ExercisePresets.swift:48–52`; `WorkoutTracker/Features/Gyms/GymsView.swift:300`
   - **Smell:** `renumbered(_:)` is used only by its test while production reimplements it; `GymEditorSheet.defaultPresetID` is never read.
   - **Smallest fix:** Use the helper in production or delete it and its test; delete the stray gym state.

## Fine

- `RecordGroupKey` carries `preset: UUID?` in all four cases. `nil` is a distinct key; record summaries, `completedValues`, and the domain prefill match use snapshot preset IDs. `RecordsMath.totalVolumeKg` ignores grouping and still counts all eligible sets (D21/D36).
- Snapshot capture freezes preset ID + name. History and frozen export read those fields; draft export reads the live preset. Renaming/deleting a preset cannot retitle a frozen set. CSV columns are appended at 28–29 and schema version is 2.
- Apart from auto-prefill provenance and foreign-candidate validation, `choosePreset` mirrors `chooseEquipment`: it inserts after the source, renumbers entries/sets, moves drafts, leaves completed sets, and seeds a draft if needed. With a valid same-exercise preset, preset→equipment and equipment→preset preserve the intended final context; equipment changes do not replace a deliberate preset with the new machine's default.
- `usualPreset` resolves the scalar only inside the exercise being logged. Deleted IDs, another exercise's ID, multi-exercise-machine ambiguity, and a model changed to another exercise degrade to no preset rather than attaching a foreign variation.
- `CatalogSeeder` never deletes seeded exercises omitted by a later catalog and does not overwrite `Exercise.presets`; presets remain attached even if a future catalog removes the exercise or a model link. The existing test covers field reconciliation, not the omitted-row branch.
- Domain files remain free of UI imports; new persistent relationships are optional, UUID identity is retained, and no unique constraint was added.

## Verification

- `git diff --check`: clean for the reviewed paths.
- Independent build/test rerun: not completed. The host's CoreSimulator service reported no available simulator runtimes; `xcodebuild` stopped in asset-catalog compilation before yielding a useful app/test result. The claimed `315 unit + 13 UI` run was not independently reproduced here.

Spec axis: 8 findings (worst: incomplete JSON backup). Standards axis: 1 hard violation, 2 judgement-call smell groups (worst: fallback logic outside Domain).
