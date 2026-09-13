# 09 — History rendering from snapshots

**What to build:** History and workout detail read persisted finished workouts, rendering equipment from **snapshot display strings** (never live relationships). Sets show as entered with W/F markers. The workout summary's unit badge derives from actual sets: kg, lb, or Mixed. The whole-view convert toggle renders every weight in the chosen unit with converted values ≈-marked, using ticket 03's formatting.

**Blocked by:** 07.

**Status:** resolved

- [x] History lists only finished workouts (finishedAt != nil), grouped by month, newest first; only completed sets render (Finish already deleted drafts)
- [x] Free-weight entries render their snapshot tag (e.g. "Barbell") as the equipment label
- [x] Detail shows snapshot equipment labels; a unit test proves rendering never touches the live MachineInstance/EquipmentModel relationship
- [x] Unit badge test: all-kg workout → kg; all-lb → lb; mixed → Mixed
- [x] Convert toggle: original units by default; toggled view marks conversions with ≈; storage unchanged

## Comments

2026-08-08 — Resolved. HistoryView now runs on a SwiftData `@Query` over finished workouts
(`finishedAt != nil`, newest `startedAt` first), grouped by month, keeping the milestone-1 visual
design; the row headline is the gym name (workouts have no name field), with stats
`exercises · completed sets · duration` (startedAt→finishedAt) and a per-workout unit badge
derived from the actual completed sets — kg, lb, or Mixed — never the gym default. Badge logic is
pure Domain (`Domain/HistoryRendering.swift`): `WorkoutUnitBadge.derive(fromUnits:)` /
`derive(fromCompleted:)` (drafts excluded), plus `ExerciseEntry.snapshotEquipmentLabel`
("machine label · manufacturer model", free-weight tag label, or "No equipment") and
`Workout.durationMinutes`/`completedSets`. WorkoutDetailView renders exercise + equipment from
snapshot display strings ONLY (D23) and completed sets as entered with W/F markers; a toolbar
menu (As entered / kg / lb) is the whole-view convert toggle — converted values render ≈-marked
via `WeightMath.displayLabel` (D9/D25), storage untouched. Sample-data teardown: deleted
`SampleData/SampleStore.swift` and all dead prototype types (SampleWorkout/WorkoutEntry/
LoggedSet/SampleGym/SampleExercise/SampleEquipmentModel/Machine/PerformanceLayer);
`Domain/PrototypeModels.swift` shrank to the shared enums + `Format` and was renamed
`Domain/SharedEnums.swift`. The Start screen's sample templates (last SampleStore dependency,
ticket 15) moved to `SampleData/SampleTemplates.swift` as `SampleWorkoutTemplate.samples`.
RootView lost its `@StateObject SampleStore`; PROTO_SCREEN keeps only the gyms/exercises deep
links (history/detail depended on sample data). Tests:
`WorkoutTrackerTests/HistoryRenderingTests.swift` — badge derivation (all-kg/all-lb/mixed/empty +
draft exclusion), snapshot label shapes (machine and free-weight), a disk-backed reopen test
renaming the live machine/model/exercise after logging and proving the rendered snapshot strings
are unchanged, and convert-toggle formatting (`60 kg` plain; `≈132.28 lb` / `≈61.23 kg`).
Full suite: 89 tests green on WT-iPhone; plain `xcodebuild build` green.
