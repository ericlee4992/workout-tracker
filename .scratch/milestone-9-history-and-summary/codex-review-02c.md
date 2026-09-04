# Codex re-review 02c — workout name

## Standards

**Medium — the source-of-truth inconsistency is not fully closed.** `CLAUDE.md:3-8` makes the milestone specs and ticket record authoritative for cold agent sessions, but `.scratch/milestone-3-export/spec.md:132-134` still presents the JSON format as `schemaVersion: 4` and enumerates changes only through v4, while the current contract is v6. The ticket's test record also still says the CSV “prefers” the typed name (`.scratch/milestone-9-history-and-summary/issues/02-workout-name.md:51-53`), contradicting its corrected contract: column 4 retains template provenance and column 36 carries `workoutTypedName`. The response's claim that every current statement now agrees is false (`.scratch/milestone-9-history-and-summary/issues/02-workout-name.md:90`). No new smell was introduced.

## Spec

**Medium — the same two stale statements leave the round-2 export-contract finding open.** The round-3 prompt requires every current export statement to agree (`.scratch/milestone-9-history-and-summary/codex-review-02c-prompt.md:4`); the JSON example and ticket test record above do not. The other two requested closures are sound: the test is accurately renamed (`WorkoutTrackerTests/WorkoutNameTests.swift:98`), and `ActiveWorkoutView` shows the refusal alert only when `WorkoutSession.rename` returned false, the workout is non-deleted and finished, and the normalized requested name differs from the stored name (`WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift:218`). Therefore an unchanged Save on a finished workout cannot fire the alert falsely. No new runtime defect was introduced. `git diff --check 90616a0..2525711` passed; focused `WorkoutNameTests` and `ExportTests` passed all 34 tests.

Standards — 1 finding (worst: medium); Spec — 1 finding (worst: medium).
