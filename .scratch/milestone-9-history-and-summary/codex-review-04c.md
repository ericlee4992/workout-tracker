# Codex cross-review 04c — Dumbbell reclassification, round 3

Review boundary: `23e004c...2207bd7` (fix commit `2207bd7`). Verdict: **not clear**. Canonical preset deduplication and both superset cases are closed, and the response is correct that SwiftData cannot persistently compare the optional enum tag. The focused suite nevertheless found an order-dependent preset-label regression, and the projected gate faults excluded rows before checking the property it deliberately fetched.

## Standards

### High — Unsorted migration order makes the target preset label nondeterministic and leaves the focused suite red

The candidate fetch has no sort order, so the snapshot-only `"  WIDE   GRIP "` entry can be processed before entries carrying the live `"Wide grip"` preset (`WorkoutTracker/Domain/DumbbellHistoryMove.swift:56-70`, `WorkoutTracker/Domain/DumbbellHistoryMove.swift:88-90`). `cleanedName` trims only the outer whitespace, so that first row creates a user-visible target preset named `"WIDE   GRIP"` (`WorkoutTracker/Domain/DumbbellHistoryMove.swift:109-120`). Identical logical stores can therefore choose different target labels from unspecified fetch order, and the new assertion fails at `WorkoutTrackerTests/DumbbellExercisesTests.swift:253`—twice in independent focused-suite runs here. This violates the tested-Domain/local-test gate in `CLAUDE.md:29` and `CLAUDE.md:85-89`. Give live preset names deterministic precedence over snapshot-only fallbacks, with an explicit tie-break, and exercise more than one insertion/fetch order.

### Medium — The partial projection faults barbell rows before inspecting their fetched tag

`propertiesToFetch` asks only for `snapshotFreeWeightTag` and `snapshotExerciseID`, but the loop accesses the nonfetched `workout` relationship, `workout.finishedAt`, and `snapshotCapturedAt` before checking the fetched tag (`WorkoutTracker/Domain/DumbbellHistoryMove.swift:63-76`). SwiftData faults nonfetched properties on access, so every permanent finished barbell source row can incur extra storage reads before rejection, defeating the projection's purpose and D51's cheap every-launch boundary (`docs/DECISIONS.md:60`). Check `snapshotFreeWeightTag == .dumbbell` first; only actual candidates should fault the remaining state.

## Spec

### Medium — Canonical deduplication is fixed, but the chosen canonical label depends on fetch order

The round-three prompt asks whether preset deduplication/cleaning is fully closed (`.scratch/milestone-9-history-and-summary/codex-review-04c-prompt.md:5-7`). The move now correctly uses `ExercisePresets.isDuplicate`, so it does not create a second UUID the app would refuse. However, whichever equivalent row arrives first supplies the newly created target's spelling. In the focused run, the unsorted snapshot-only row won and produced `"WIDE   GRIP"` rather than the current live preset's `"Wide grip"` (`WorkoutTracker/Domain/DumbbellHistoryMove.swift:70`, `WorkoutTracker/Domain/DumbbellHistoryMove.swift:89-90`, `WorkoutTracker/Domain/DumbbellHistoryMove.swift:116-119`). That contradicts the response's promised/tested result (`.scratch/milestone-9-history-and-summary/issues/04-dumbbell-exercises.md:132-134`) and failed `WorkoutTrackerTests/DumbbellExercisesTests.swift:253`. Prefer live relationship names deterministically, then use snapshot names only as fallbacks.

### Medium — The accepted platform ceiling is cheaper than the code currently realizes

The response's enum claim is correct: minimal SwiftData probes on the current SDK rejected both captured optional and nonoptional enum values with `unsupportedPredicate`. Mutating a partially fetched model is also safe: SwiftData faults nonfetched attributes on access, and a separate projected-fetch probe persisted a mutation through a fresh context; this matches [Apple's `propertiesToFetch` documentation](https://developer.apple.com/documentation/swiftdata/fetchdescriptor/propertiestofetch). A projected two-column scan of finished source history is therefore a reasonable platform-limited ceiling under D51 and does not itself require amending D51.

The implementation still misses that ceiling. It fetches all target exercises before inspecting candidate tags, then faults `workout` and `snapshotCapturedAt` on every barbell candidate before reaching the fetched tag (`WorkoutTracker/Domain/DumbbellHistoryMove.swift:63-76`). Filter the projected entries by tag first, return if none remain, and only then fetch targets and fault the fields required for actual moves. The new barbell-history test proves correctness, not the claimed query behavior (`WorkoutTrackerTests/DumbbellExercisesTests.swift:379-395`).

## Closed checks

- `ExercisePresets.isDuplicate` now supplies the same case/diacritic/spacing equivalence used by the app, and creation applies `cleanedName`; the remaining preset issue is label precedence, not duplicate identity.
- `Supersets.isGrouped` carries the ID for a genuine adjacent run and rejects a stale singleton; `pruneOrphanGroups` still runs unconditionally after insertion (`WorkoutTracker/Domain/WorkoutSession.swift:443-475`). Both the valid-group and singleton tests pass.
- `git diff --check 23e004c...2207bd7` passes. In two runs of `DumbbellExercisesTests`, 17/18 tests passed and `aPresetIsReHomedOntoTheCounterpartAndShared` failed at line 253 with `homed.name == "WIDE   GRIP"`; the attempted method-only filter selected zero Swift Testing tests and is not counted.
- No source files were modified by this review.

Standards — 2 findings (worst: High); Spec — 2 findings (worst: Medium).
