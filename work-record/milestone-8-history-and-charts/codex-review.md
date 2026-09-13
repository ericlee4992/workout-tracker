# Codex cross-review — milestone 8 tickets 02 and 03

Review boundary: `39737ae..e15f9e5` (`3443f94`, `e15f9e5`).

Verdict: **do not merge or install over the live store.** The change can persist invalid weights, corrupt bar provenance, and lose both new integrity markers from the JSON backup. More fundamentally, the two “resolved” tickets still provide no way to repair the historical wrong-load-type case that ticket 02 explicitly delegates to ticket 03.

Targeted verification passed 22 tests in `LegacyStoreMigrationTests`, `HistoryEditingTests`, and `LoadTypeOverrideTests`, including opening the legacy fixture. Those tests do not exercise the failures below.

## Standards

### Critical

- **Hard violation — the backup drops the only durable seeder guard.** `WorkoutTracker/Domain/Models.swift:38` adds the marker protecting a corrected seeded load type, but `WorkoutTracker/Domain/ExportCollector.swift:66` can omit an overridden seeded exercise entirely and `WorkoutTracker/Domain/ExportCollector.swift:202` never serializes the flag even when the exercise is included. A restore followed by reconciliation can silently revert the correction and flip future record direction. This violates `docs/SPEC.md` (“JSON — the object graph and the complete backup”) and D24’s reconciliation-integrity rule. Ticket 02’s “survives” claim is false for the backup story.

### High

- **Hard violation — D24 was contradicted, not reopened.** `WorkoutTracker/Features/Exercises/ExercisesView.swift:79` and `WorkoutTracker/Features/Exercises/EditExerciseLoadTypeSheet.swift:98` deliberately make seeded rows user-editable, while locked D24 says seeded rows are not user-editable. The ticket claims D24 reserves only naming, but `docs/DECISIONS.md:32` was not amended; only D47 was added. Reopen D24 explicitly or do not ship the exception.

- **Hard violation — bar provenance is torn apart.** `WorkoutTracker/Domain/HistoryEditing.swift:53` edits a bar-mode set’s total and unit but leaves `barWeightValue` and `barNormalizedKg` untouched (`WorkoutTracker/Domain/Models.swift:453`). A unit edit can therefore relabel a 45 lb bar as 45 kg while exporting its old 20.41 kg normalization; a total edit can make total weight lower than the bar. This violates `CLAUDE.md`’s stored-weight triple and D25 atomicity. `WorkoutTracker/Domain/ExportCollector.swift:348` faithfully exports the corruption.

- **Hard violation / absence of a caller — deletion impact is calculated but not shown.** D47 requires workout deletion to name sets, exercises, and volume. `WorkoutTracker/Domain/HistoryEditing.swift:99` carries `volumeKg`, but `WorkoutTracker/Features/History/WorkoutDetailView.swift:90` never renders it. Ticket 03’s resolution claim is false. The dead calculation at `WorkoutTracker/Domain/HistoryEditing.swift:110` also counts assisted and bodyweight-plus loads, contrary to `CLAUDE.md` and `docs/SPEC.md` (“weighted exercises only”). Reuse `RecordsMath.totalVolumeKg`.

- **Hard violation — the edit marker is absent from the complete backup.** `WorkoutTracker/Domain/Models.swift:269` adds D47’s honesty marker, but `WorkoutTracker/Domain/ExportSnapshot.swift:175` and `WorkoutTracker/Domain/ExportCollector.swift:238` omit `historyEditedAt`. A JSON backup loses the fact that history was altered, violating D47 and the complete-backup rule.

No additional baseline-only smell survives the documented standards; duplicated volume logic is subsumed by the hard volume-rule breach.

## Spec

### Critical

- **The pair does not solve its central historical-repair case.** Ticket 02 says correcting an exercise “does NOT repair sets already logged wrong — that needs ticket 03” and requires the sheet to point there (`issues/02-load-type-editable.md:32`, `:51`). Ticket 03 calls correcting a set logged on the wrong exercise legitimate (`issues/03-edit-history.md:16`), but D47 narrows edits to numbers and freezes snapshot load type. `WorkoutTracker/Domain/HistoryEditing.swift:29` exposes only reps, weight, unit, and set type; `WorkoutTracker/Features/History/EditLoggedSetSheet.swift:27` has no exercise/load-type control; and `WorkoutTracker/Features/Exercises/EditExerciseLoadTypeSheet.swift:45` merely says history stays frozen. Historical sets ranked under the wrong load type remain irreparable. Both tickets’ “resolved” status is false, and their specifications contradict each other.

- **Invalid weights can be written into finished history.** `WorkoutTracker/Features/History/EditLoggedSetSheet.swift:79` parses raw `Double`, and `WorkoutTracker/Domain/HistoryEditing.swift:49` asks only whether the value is non-nil. Neither uses `WorkoutSession.weightValue(from:)`, `WeightMath.isValidInput`, or `StoredWeight`. Pasted negative, NaN, or infinite loads are accepted, normalized, and can poison records or make JSON encoding fail. Ticket 03’s resolution says `apply` “refuses an edit that would not be loggable (A1).” That claim is false.

- **Bar-mode edits violate D25.** `WorkoutTracker/Domain/HistoryEditing.swift:53` updates the main weight triple but leaves bar value/normalization stale. Changing units relabels the bar while `WorkoutTracker/Domain/ExportCollector.swift:348` retains its old normalization. The resolution’s D25-compliance claim is false.

### High

- **Individual historical-set deletion does not confirm.** The destructive swipe calls deletion immediately at `WorkoutTracker/Features/History/WorkoutDetailView.swift:39`. Ticket 03’s risk section says the phone holds the only copy and to “make the destructive paths confirm” (`issues/03-edit-history.md:42`). Only whole-workout deletion confirms.

- **The deletion confirmation does not meet D47.** `WorkoutTracker/Features/History/WorkoutDetailView.swift:90` never displays `impact.volumeKg`; it only says volume will be recalculated. The unused computation at `WorkoutTracker/Domain/HistoryEditing.swift:110` is also wrong for non-weighted load types. The resolution’s claim that `impact` makes the confirmation name what deletion destroys is false.

### Medium

- **Export reflects edited set values and physical deletions, but drops both new user-authored facts.** `loadTypeUserOverridden` is absent from `WorkoutTracker/Domain/ExportSnapshot.swift:131`, and `historyEditedAt` is absent from `WorkoutTracker/Domain/ExportSnapshot.swift:175`. JSON therefore cannot preserve the seeder override or D47 edit mark.

- **The required catalog audit was not done.** Ticket 02 explicitly requires bodyweight additions and an assisted/supported audit (`issues/02-load-type-editable.md:43`); its own resolution admits no catalog changes were made (`issues/02-load-type-editable.md:80`). Calling the ticket resolved is false.

No scope creep found. Snapshot non-drift, seeder-guard field scope, cascade/orphan pruning, derived-query freshness after edit/delete, nil-bodyweight normalization, and legacy-store opening look correct.

Summary: Standards — 5 findings (worst: critical backup loss of the seeder guard); Spec — 7 findings (worst: critical absence of the promised historical load-type repair, plus invalid/stale weight persistence).
