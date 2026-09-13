# Codex cross-review 02 — workout name

Review boundary: `57c1ced..7b706e7` (one commit, `7b706e7`). Verdict: **do not merge yet**. The feature's ordinary UI flows work, but a History rename is not explicitly persisted, the change contradicts locked D47 without reopening it, and CSV column 4 has been silently given a different meaning.

## Standards

### High — The change violates locked D47 without deliberately reopening it

`docs/DECISIONS.md:56` says History is editable **only in its numbers**; the sole recorded exception permits correcting `snapshotLoadType`. A workout title is neither a number nor that exception. Nevertheless, the new History alert changes it through `HistoryEditing.rename` (`WorkoutTracker/Features/History/WorkoutDetailView.swift:164`, `WorkoutTracker/Domain/HistoryEditing.swift:267`). `CLAUDE.md:7` requires locked decisions to be reopened deliberately rather than drifted away from. The ticket resolution describes the new behavior, but the issue file is a work record, not the locked decision log. The claim that this is simply “per D47” is wrong: the edit marker follows D47's honesty rule, while permitting the edit contradicts D47's boundary. Reopen D47 explicitly and explain why workout-level naming is safe before shipping this behavior.

### High — The History rename path does not follow the repository's explicit-save pattern

The alert calls `HistoryEditing.rename(workout, to:)` and stops (`WorkoutTracker/Features/History/WorkoutDetailView.swift:167`). That domain function mutates the model but has no context and cannot save (`WorkoutTracker/Domain/HistoryEditing.swift:273`). Every neighboring History mutation in this view immediately invokes its local `save()` helper (`WorkoutTracker/Features/History/WorkoutDetailView.swift:266`, `WorkoutTracker/Features/History/WorkoutDetailView.swift:279`, `WorkoutTracker/Features/History/WorkoutDetailView.swift:289`, `WorkoutTracker/Features/History/WorkoutDetailView.swift:296`, `WorkoutTracker/Features/History/WorkoutDetailView.swift:301`, `WorkoutTracker/Features/History/WorkoutDetailView.swift:307`). This new path alone relies on eventual SwiftData autosave, so termination before autosave can lose both the name and `historyEditedAt`. Call `save()` after an effective rename and add a persistence/reopen test; the current UI test only observes the same live context.

### Medium — The two APIs document a lifecycle boundary that neither enforces

`WorkoutSession.rename` says it names a workout “that is still running” and deliberately does not mark History, but it checks only deletion, not `finishedAt == nil` (`WorkoutTracker/Domain/WorkoutSession.swift:117`). A stale or non-UI caller can therefore rename a logged workout without setting `historyEditedAt`. Conversely, `HistoryEditing.rename` calls its argument “a LOGGED workout” but does not require `finishedAt != nil` (`WorkoutTracker/Domain/HistoryEditing.swift:267`). It can stamp an active workout as a History edit. The current screens normally choose the intended service, but the invariant belongs at the mutation boundary. Refuse the opposite lifecycle state in both APIs and test both refusals.

### Low — Rename normalization is duplicated across the two mutation paths

Whitespace trimming, blank-to-`nil` conversion, equality checking, and assignment are duplicated in `WorkoutSession.rename` (`WorkoutTracker/Domain/WorkoutSession.swift:120`) and `HistoryEditing.rename` (`WorkoutTracker/Domain/HistoryEditing.swift:273`). The paths need different persistence and edit-mark behavior, but not separate definitions of what a stored name means. A small shared normalization/value helper would prevent those semantics from drifting while preserving the distinct operations. This duplication has already made it easier for the two APIs to acquire similarly incomplete lifecycle guards.

## Spec

### High — A History rename is not durably saved

The issue requires a name edited in History and its `historyEditedAt` marker to become stored workout history (`work-record/milestone-9-history-and-summary/issues/02-workout-name.md:13`). The Save button merely mutates the in-memory model (`WorkoutTracker/Features/History/WorkoutDetailView.swift:167`); it never calls the view's explicit persistence helper at `WorkoutTracker/Features/History/WorkoutDetailView.swift:313`. The passing UI test checks the title and marker immediately without leaving or relaunching the app (`WorkoutTrackerUITests/WorkoutNameUITests.swift:50`), so it cannot detect this failure mode. Save the context on this path and verify the name and marker after reopening a persistent store.

### High — CSV column 4 is a silent breaking format change and loses template provenance

At the review base, the export contract defined column 4 as `Workout.sourceTemplateName` (`work-record/milestone-3-export/spec.md:69` at `57c1ced`). The implementation now emits `workout.name ?? workout.sourceTemplateName` in that same unversioned position (`WorkoutTracker/Domain/ExportCSV.swift:89`). For a named workout started from a template, an existing v1-v5 consumer now receives the user's title where it previously received template provenance, and CSV no longer exports that provenance anywhere. This directly collapses two meanings the ticket itself says must remain distinct (`work-record/milestone-9-history-and-summary/issues/02-workout-name.md:17`). Updating the spec to describe the new output does not make existing files or consumers forward-compatible. The source comment's claim that the column meaning is unchanged is false, and it contradicts the append-only compatibility rationale immediately above the header (`WorkoutTracker/Domain/ExportCSV.swift:20`). Preserve column 4 as `sourceTemplateName` and append a new typed-name column (or introduce an explicit, genuinely versioned CSV format).

### Medium — Logged-versus-running rename semantics are not guaranteed by the implementation

Acceptance requires renaming in History to mark the workout and renaming during the workout not to mark it (`work-record/milestone-9-history-and-summary/issues/02-workout-name.md:25`). Those semantics currently depend entirely on every caller selecting the right API. `WorkoutSession.rename` accepts a finished workout without marking it (`WorkoutTracker/Domain/WorkoutSession.swift:120`), while `HistoryEditing.rename` accepts an unfinished one and marks it (`WorkoutTracker/Domain/HistoryEditing.swift:273`). The tests cover only the matching service/state combinations (`WorkoutTrackerTests/WorkoutNameTests.swift:42`, `WorkoutTrackerTests/WorkoutNameTests.swift:85`). Add state guards and adversarial tests for the two crossed combinations.

### Low — JSON compatibility and fidelity are only partially proved

The schema shape is compatible in code: `ExportSnapshot.Workout.name` defaults to `nil`, so an older JSON object with no `name` can decode (`WorkoutTracker/Domain/ExportSnapshot.swift:206`). But the new workout-name export test stops after collection and CSV rendering (`WorkoutTrackerTests/WorkoutNameTests.swift:98`); it never encodes or decodes JSON. Existing round-trip fixtures contain only absent names and have had their schema number changed to 6, rather than exercising a real v5 payload. Consequently, no test proves a present name survives JSON encode/decode, and no explicit v5 fixture proves the missing field is accepted. Add both cases to the fidelity suite.

## Confirmed behavior and verification

- Title precedence is correct: a trimmed typed name wins, then the snapshotted template name, then snapshotted exercises (`WorkoutTracker/Domain/HistoryRendering.swift:88`). `Workout.derivedTitle` is reached by both rename alerts and uses `snapshotExercises`, never live exercise relationships (`WorkoutTracker/Domain/HistoryRendering.swift:153`, `WorkoutTracker/Domain/HistoryRendering.swift:171`).
- Starting from a template leaves `Workout.name` empty and retains `sourceTemplateName`; naming does not enter template-drift comparison or change the explicit save-as-template name flow (`WorkoutTracker/Domain/WorkoutTemplates.swift:108`).
- The optional scalar is compatible with the repository's CloudKit schema constraints, and the legacy-store migration test passed.
- Both alerts refresh their state on presentation, unchanged saves are no-ops, and the active/history controls guard deleted workouts. `workoutNameField` and `saveWorkoutName` are present in both alerts but are not queried by the UI tests, which use the first text field and the visible “Save” label (`WorkoutTrackerUITests/WorkoutNameUITests.swift:79`); they are redundant test selectors, not unreachable production code.
- `git diff --check 57c1ced..7b706e7` passed. The focused model/export/migration run passed 52 tests across `WorkoutNameTests`, `LegacyStoreMigrationTests`, `ExportTests`, and `ExportFidelityTests`. `WorkoutNameUITests` passed 2/2.

Standards — 4 findings (worst: high); Spec — 4 findings (worst: high).
