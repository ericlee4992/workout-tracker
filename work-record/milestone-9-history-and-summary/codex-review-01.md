# Codex cross-review 01 — chart equipment axis and History entry point

Review boundary: `05a83c8..18d76ec` (`18d76ec`, one commit).

Verdict: **do not merge yet.** The happy path works, but the new key silently merges two different equipment provenances, and the History entry point can strand the user in a false empty state.

## Standards

### Medium — hard standards violation

- `WorkoutTracker/Features/History/ExerciseProgressView.swift:372` — `availableVariations` implements fallback/order policy in the SwiftUI layer. Its rank tuple at lines 377–381 duplicates `ProgressSeriesMath.defaultVariation`'s preset/tag/UUID tie-break at `WorkoutTracker/Domain/ProgressSeries.swift:120`. `CLAUDE.md:29` requires fallback selection to live in `Domain/`, free of UI imports and unit-tested. The two comparators can drift when another variation axis is added. Move the ranked-variation comparator into `ProgressSeriesMath` and reuse it.

No additional documented-standard breaches or baseline smells found.

## Spec

### High

- `WorkoutTracker/Domain/ProgressSeries.swift:109` and `WorkoutTracker/Domain/ProgressSeries.swift:168` — the nil-tag group is not honest. The ticket says, “A machined set carries a nil tag ... so machine history stays one group” (`work-record/milestone-9-history-and-summary/issues/01-chart-per-equipment-and-history-chart.md:12`), but the key omits equipment provenance and therefore pools machines with entries whose equipment is genuinely unknown, including History's “Add Exercise” rows. D23 (`docs/DECISIONS.md:31`) freezes both machine identity and free-weight tag; collapsing `(machineID != nil, tag == nil)` and `(machineID == nil, tag == nil)` erases that distinction. The acceptance test is false reassurance: `WorkoutTrackerTests/ProgressSeriesTests.swift:222` calls its row “machined” but never gives it a `machineID`, so it proves only that an untagged row survives. “nil tag is its own group” is mechanically met, not semantically met.

- `WorkoutTracker/Features/History/ExerciseProgressView.swift:47` and `WorkoutTracker/Features/History/ExerciseProgressView.swift:180` — History can open into a dead end or false empty state. The ticket requires the button to open “on the variation that session used” (`work-record/milestone-9-history-and-summary/issues/01-chart-per-equipment-and-history-chart.md:20`) and the picker to name variations (`work-record/milestone-9-history-and-summary/issues/01-chart-per-equipment-and-history-chart.md:15`), but `variationPicker` renders only in `.series`. A session variation with one eligible day hides the picker even when other variations have history; an all-warmup variation shows “No sets logged yet” and no route to valid history. The UI test covers only the fixture's two-day dumbbell variation, so the resolution's claim is narrower than the shipped behavior.

### Medium

- `WorkoutTracker/Domain/ProgressSeries.swift:109` and `WorkoutTracker/Domain/ProgressSeries.swift:168` — the ticket/resolution claim that records “already group this way” and the chart was “the one surface” pooling tags (`work-record/milestone-9-history-and-summary/issues/01-chart-per-equipment-and-history-chart.md:9`) is wrong. `RecordsMath.groupKeys` exposes exact-machine, model, tag-specific free-weight, and exercise-wide groups (`WorkoutTracker/Domain/RecordsMath.swift:249`); the chart now implements a hybrid matching none of them. For one preset with Machine A 100, Machine B 110, and Barbell 120, the nil-tag chart claims 110; exact-machine records claim 100 and exercise-wide records claim 120. The chart and records can therefore disagree about the best set for the same preset.

No mechanical test rewrite lost meaning. The two sort orders currently agree. Every new declaration has a caller. No concrete `@State` reuse failure exists in this call path: the selected sheet item cannot change while its modal is covering the detail view, and a later presentation rebuilds the sheet content. `variationName` reads snapshot fields rather than live relationships; its repeated full-table fetch remains a real scaling cost, but it is pre-existing and not a separate regression in this commit. No scope creep found.

Verification: 29 targeted unit tests passed (`ProgressSeriesTests`, `ChartPresetScopingTests`, `DisplayUnitTests`), and `testHistoryOpensTheChartOnThatSessionsVariation` passed. These runs confirm the implemented happy path, not the uncovered cases above.

Summary: Standards — 1 finding (worst: medium, fallback policy duplicated into UI); Spec — 3 findings (worst: high, nil provenance is pooled and History can dead-end on sparse/ineligible variations).
