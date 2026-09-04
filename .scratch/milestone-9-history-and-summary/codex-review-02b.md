# Codex re-review 02b — workout name

Review boundary: `7b706e7..90616a0` (three commits, substantive fix `90616a0`). Verdict: **do not close yet**. The runtime fixes are sound, but the export contract remains contradictory in the repository's source-of-truth documents, and the Active UI silently treats a lifecycle refusal as success.

## Standards

### Medium — The repository no longer has one coherent source of truth for export

`CLAUDE.md:3-8` says repository documents are the source of truth for cold agent sessions. The authoritative milestone-3 table and implementation now correctly define schema v6 with 36 CSV columns, preserving column 4 as template provenance and appending `workoutTypedName` (`.scratch/milestone-3-export/spec.md:69`, `.scratch/milestone-3-export/spec.md:101`, `WorkoutTracker/Domain/ExportCSV.swift:48`). However, `docs/SPEC.md:94-95` still promises 35 columns and JSON schema v5; `WorkoutTracker/Domain/ExportCSV.swift:20` says the header has 34 columns; and `WorkoutTracker/Domain/ExportSnapshot.swift:35-38` still claims the typed name replaces column 4. The ticket's original resolution also still says “CSV gains no column” (`.scratch/milestone-9-history-and-summary/issues/02-workout-name.md:43`), even though the later response contradicts it. Update every current-contract statement; if the original resolution is intentionally preserved as history, mark it explicitly superseded.

The other round-1 Standards findings are closed. D50 deliberately and narrowly reopens D47 (`docs/DECISIONS.md:59`); the History alert explicitly saves each effective mutation (`WorkoutTracker/Features/History/WorkoutDetailView.swift:167`); both lifecycle boundaries are enforced in Domain (`WorkoutTracker/Domain/WorkoutSession.swift:126`, `WorkoutTracker/Domain/HistoryEditing.swift:279`); and `Workout.normalizedName` owns normalization (`WorkoutTracker/Domain/Models.swift:281`). No new baseline code smell was found.

## Spec

### Medium — The CSV fix is only partially closed because its documented contract still disagrees with itself

Round 2 specifically requires every CSV field count and spec to agree on 36 (`.scratch/milestone-9-history-and-summary/codex-review-02b-prompt.md:9`). Runtime output is correct: compared with the pre-ticket export at `57c1ced`, columns 1–35 are functionally unchanged for every workout, column 4 again emits only `sourceTemplateName`, and `workoutTypedName` is appended as column 36 (`WorkoutTracker/Domain/ExportCSV.swift:90`, `WorkoutTracker/Domain/ExportCSV.swift:131`). The header/count test and milestone-3 table agree (`WorkoutTrackerTests/ExportTests.swift:220`, `.scratch/milestone-3-export/spec.md:64`). But `docs/SPEC.md:94-95`, `WorkoutTracker/Domain/ExportCSV.swift:20`, and `WorkoutTracker/Domain/ExportSnapshot.swift:35-38` retain three different obsolete contracts. Even the new test name still says the CSV “prefers” the typed name although its assertions correctly prove the opposite (`WorkoutTrackerTests/WorkoutNameTests.swift:98`). The response's claim that the header and spec were corrected is therefore incomplete.

### Low — ActiveWorkoutView discards a refused rename as though Save succeeded

The new guard correctly makes `WorkoutSession.rename` return `false` for a finished workout (`WorkoutTracker/Domain/WorkoutSession.swift:126`). The Active alert ignores that result and closes normally (`WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift:210`). The ordinary Finish path synchronously clears the presented Active workout in `RootView`, so this is limited to a stale/racing view rather than the normal flow; nevertheless, that is exactly the state the guard was added to defend. If the model becomes finished before Save executes, the user's text is silently discarded with no indication that the operation was refused. Consume the result and dismiss/redirect or report failure explicitly; add coverage for the caller behavior, not only the Domain refusal.

All other round-1 Spec findings are closed. The History action saves after every effective rename, and `aHistoryRenameIsOnDiskAfterSave` releases the first context, opens the same store through a new container, and observes both name and edit mark (`WorkoutTrackerTests/WorkoutNameTests.swift:190`). D50 clearly distinguishes authored name from captured provenance and makes the running/logged boundary explicit (`docs/DECISIONS.md:59`). Both crossed lifecycle cases are tested (`WorkoutTrackerTests/WorkoutNameTests.swift:165`, `WorkoutTrackerTests/WorkoutNameTests.swift:176`). JSON tests now cover a present name round-trip and a v5-shaped object with the key absent (`WorkoutTrackerTests/WorkoutNameTests.swift:130`). No scope creep was introduced.

## Verification

- `git diff --check 7b706e7..90616a0` passed.
- Focused `WorkoutNameTests`, `ExportTests`, `ExportFidelityTests`, and `LegacyStoreMigrationTests` passed: 56 tests in 4 suites, zero failures.
- The boundary diff against the pre-ticket CSV implementation confirms the first 35 emitted fields retain their v5 expressions and only column 36 is appended.

Standards — 1 finding (worst: medium); Spec — 2 findings (worst: medium).
