# Codex cross-review 2 — milestone 8 tickets 01 and 04

Review boundary: `e15f9e5..8e7f438` (`b1019c8`, `e009e46`, `8e7f438`).

Verdict: **do not merge or install this over the live store.** The superset implementation can preserve a rest between members and silently loses template grouping through three ordinary paths. The charts can confidently plot the wrong history and do not work for plain bodyweight exercises.

## Standards

### Critical

- **Hard violation — the previous-review fix contradicts locked D47.** `WorkoutTracker/Domain/HistoryEditing.swift:142-158` directly mutates `ExerciseEntry.snapshotLoadType`. D47 says history is editable “only [in] its numbers” and explicitly freezes load type (`docs/DECISIONS.md:56`); D23 makes that snapshot historical truth (`docs/DECISIONS.md:31`). The repair is user-directed rather than a live-catalog re-resolution, and ticket 03's original proposal allowed editing a frozen field explicitly, but the recorded decision does not. Amend D47 deliberately before shipping this capability. `b1019c8` moved the contradiction; it did not resolve it.

### High

- **Hard violation — bodyweight charts contradict D20.** `WorkoutTracker/Domain/ProgressSeries.swift:91-98` stores `best.normalizedKg`, normally nil for plain bodyweight, while `WorkoutTracker/Features/History/ExerciseProgressView.swift:100-113` labels the axis “Reps (kg)” and plots that nil instead of reps. The single-session value at `:136-139` is consequently `—`. D20 requires plain-bodyweight progression to be most reps.

- **Hard violation — D48 does not actually stop an existing rest.** `WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift:450-455` returns before touching the timer when a non-last member completes. Complete B1 (starts rest), then complete A2 before it expires: B1's standard or heart-rate rest remains scheduled between A2 and B2. D48 says there is no rest there.

- **Hard violation / absence of a caller — orphan group IDs persist.** `WorkoutTracker/Domain/Supersets.swift:124-129` defines `pruneOrphanGroups`, but no production code calls it. Active deletion at `WorkoutTracker/Domain/WorkoutSession.swift:270-277` and history pruning at `WorkoutTracker/Domain/HistoryEditing.swift:161-165` can leave a singleton ID that export and template capture preserve. The test at `WorkoutTrackerTests/SupersetTests.swift:168-176` proves only that a helper works when manually invoked—the exact absence-of-a-caller failure the prompt warned about.

### Judgement call

- **Possible Duplicated Code / Feature Envy.** `WorkoutTracker/Features/History/ExerciseProgressView.swift:160-177` and `WorkoutTracker/Domain/HistoryEditing.swift:181-195` independently walk `SetRecord -> ExerciseEntry` and rebuild the same `RecordSetInput` field list. A Domain mapper would prevent the two consumers from drifting.

## Spec

### Critical

- **Charts do not use the same historical grouping/classification as records.** Ticket 01 requires load-type-correct series from the shared records rules (`issues/01-progress-charts.md:14-20,30-31`), while D23/D36 require snapshot load type and preset-scoped records. `WorkoutTracker/Features/Exercises/ExercisesView.swift:130-133` passes the live exercise load type; `WorkoutTracker/Features/History/ExerciseProgressView.swift:160-178` then mixes every snapshot load type and every preset for that exercise, including completed sets in unfinished workouts. `WorkoutTracker/Domain/ProgressSeries.swift:79-98` does not filter to its `loadType`; `outranks` therefore compares mixed types using each candidate's direction. A load-type correction can relabel old weighted sets as assistance, and narrow/wide-grip best sets and e1RM are pooled contrary to D36. The resolution's “cannot drift from the records screen” claim is false.

- **Template grouping is silently lost, so ticket 04's round-trip claim is false.** `WorkoutTracker/Domain/TemplateDrift.swift:4-24,147-159,178-206` has no grouping field: grouping-only drift never prompts, and an `updateTemplate`/`updateBoth` rebuild drops all group IDs. `WorkoutTracker/Features/Start/TemplateEditorSheet.swift:128-150` also omits IDs when loading and saving, so any ordinary template edit ungroups it. Finally, the complete JSON backup omits grouping from template items (`WorkoutTracker/Domain/ExportSnapshot.swift:172-181`; `WorkoutTracker/Domain/ExportCollector.swift:225-238`). The direct save/start path preserves one template's grouping and the production start code generates a fresh ID, but update, drift, and backup do not. This is template data loss in exactly the path the ticket called load-bearing.

### High

- **Rest lifecycle is incomplete, not just the B1/A2 case.** Deleting the timer's source set or last superset member does not clear `Workout.restStartedBySetID` (`WorkoutTracker/Domain/WorkoutSession.swift:270-277,463-470`). A heart-rate rest can no longer resolve its source at `WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift:291-300`, so it sits until the stale cap/notification fires; a standard rest also remains. Grouping entries while a rest is already running likewise never re-evaluates it. Minimize persistence and the existing skip/+15 controls still hold, but D43 does not make these stale rests correct.

- **The chart's confidence gate and tooltips are incomplete.** Ticket 01 says not to imply a slope between two dots and requires as-entered tooltips (`issues/01-progress-charts.md:14-16,21-22`). `WorkoutTracker/Domain/ProgressSeries.swift:107-112` promotes two sessions to `.series`; `WorkoutTracker/Features/History/ExerciseProgressView.swift:81-90` draws the line and `:62-69` reports percentage change. Multi-point charts have no selection, annotation, or tooltip at all; as-entered text exists only for the single-point state (`:123-140`). One point is correctly prevented from drawing a line in the view.

- **“Session” confidence is actually calendar-day confidence.** `WorkoutTracker/Domain/ProgressSeries.swift:80-84` groups by `startOfDay(completedAt)`. Two workouts on one day collapse into one “session,” while one workout spanning midnight becomes two and can acquire a line. The empty/thin-state claims at `issues/01-progress-charts.md:26-27,62-64` are therefore false for real session boundaries.

- **Core superset UI requirements are absent.** Ticket 04 requires cycling, reordering, and History representation (`issues/04-supersets.md:19-24,28`). `Supersets.nextMember` (`WorkoutTracker/Domain/Supersets.swift:88-96`) has no production caller; Active Workout renders a plain `ForEach` with no reorder control (`WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift:80-89`); and History shows no grouping (`WorkoutTracker/Features/History/WorkoutDetailView.swift:34-83`). The resolution's three-member claim is also false: once B is grouped, `WorkoutTracker/Features/ActiveWorkout/ExerciseEntryCard.swift:298-309` replaces “Superset with next” with “Break superset,” so B cannot add C.

### Medium

- **The claimed load-bearing invariant test is vacuous.** `WorkoutTrackerTests/SupersetTests.swift:49-71` computes records/volume from one synthetic `[RecordSetInput]`, changes unrelated model rows, then evaluates the same array. It never derives inputs through production code before/after grouping and never exercises `PerformanceHistory`/Previous Performance. Production `RecordGroupKey` and Previous Performance currently ignore `supersetGroupID`, so D48's records/PR/volume invariant holds by inspection—but the test does not pin it, contrary to `issues/04-supersets.md:57-59`.

- **`b1019c8` did not “Fix every finding,” and the resolution's “532 unit tests green” claim is false at the reviewed commit.** The prior review's catalog-audit finding remains explicitly undone at `issues/02-load-type-editable.md:100-104`, and the historical retype fix introduced the unrecorded D47 exception above. An isolated run of exact `8e7f438` executed all 532 tests and failed two. The new `eachStartGetsItsOwnGroupIdentity` test (`WorkoutTrackerTests/SupersetTests.swift:245-259`) starts a second workout without completing the first; `WorkoutSession.startWorkout` finishes and deletes that empty first workout (`WorkoutTracker/Domain/WorkoutSession.swift:71-80,130-158`), so the assertion reads a deleted graph and fails instead of proving ID remapping. `HeartRateMonitorTests.samplesArriveAndBecomeTheCurrentReading` also failed its immediate freshness assertion (`WorkoutTrackerTests/HeartRateMonitorTests.swift:90-103`), apparently as a timing-sensitive pre-existing failure rather than a change in this boundary. The other prior-review fixes—invalid-weight validation, bar provenance, shared deletion volume, destructive confirmations, D24's explicit amendment, and both export integrity markers—do hold. The amended D24 is honest and matches `CatalogSeeder`/export behavior.

## Export and migration verification

- CSV column 35 is genuinely appended (`WorkoutTracker/Domain/ExportCSV.swift:22-48,116-124`), and the three v5 export additions are optional, so v4 JSON omission is compatible with synthesized decoding. Workout grouping exports; **template** grouping does not.
- The SwiftData additions are optional, which is the lightweight shape expected to migrate. The repository fixture is from `5239ef2`, not the newer installed store (`WorkoutTrackerTests/LegacyStoreMigrationTests.swift:12-15`; `docs/STATE.md` records this known debt), so even a green fixture is not exact proof for the real phone.
- Independent verification used an isolated archive of exact `8e7f438`, avoiding unrelated concurrent worktree changes. `xcodebuild test -only-testing:WorkoutTrackerTests` executed 532 tests in 54 suites and failed the two tests described above. `LegacyStoreMigrationTests` passed, so the bundled old fixture does open; that still does not prove the newer real-phone store. The UI suite was not rerun, so its green claim was not independently verified.

Summary: Standards — 5 findings (worst: the unrecorded D47 contradiction); Spec — 8 findings (worst: wrong historical chart classification and three template-grouping data-loss paths).
