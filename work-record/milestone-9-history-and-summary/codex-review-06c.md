# Codex re-review 06c — Per-metric unit provenance

Review boundary: `11bf70b...cb3773f`. Verdict: **not clear**.

## Standards

### Low — The regression test constructs an impossible stored-weight tuple

`WorkoutTrackerTests/ProgressSeriesTests.swift:33-34` creates a row with `weightValue == 198.4`, `weightUnit == .lb`, but leaves `normalizedKg == 90` from the helper's original kg fixture. Under D25 and the repository's atomic normalization rule, 198.4 lb normalizes to 89.992726208 kg. Build the tuple through `WeightMath.normalizedKg(value:unit:)` (or a helper that sets all three fields together) so the provenance test does not depend on store state the app cannot produce.

**Standards — 1 finding (worst: Low).**

## Spec

Clear. `enteredUnits` is derived after variation and `RecordsMath.isEligible` filtering, so warmups, unfinished rows, invalid/missing loads, and other variations cannot mark Volume; for a weighted chart it contains exactly the sets whose loads feed `totalVolumeKg` (`WorkoutTracker/Domain/ProgressSeries.swift:226-275`, `WorkoutTracker/Domain/RecordsMath.swift:88-106`). `e1rmUnit` comes from the exact `bestE1RM` winner after its weighted, eligible, 1...12-rep gate (`WorkoutTracker/Domain/RecordsMath.swift:189-223`). Best Set uses `bestUnit`, Volume uses every contributor's unit for both the axis and selected value, and e1RM uses its winning unit for the axis while its selected estimate remains `≈`-marked (`WorkoutTracker/Features/History/ExerciseProgressView.swift:242-260`, `WorkoutTracker/Features/History/ExerciseProgressView.swift:276-305`). Each comparison is against `displayUnit`, so same-unit kg and lb stay unmarked where exact, while cross-unit and mixed-unit values are marked.

The focused `ProgressSeriesTests` suite passed 12/12, and `git diff --check 11bf70b...cb3773f` passes. No source files were modified by this review.

**Spec — 0 findings (clear).**
