# Codex cross-review 01c — milestone 9, ticket 01

Review boundary: `75a280f..32cb547`

Verdict: **do not merge yet**. The production ranking is now total, but its regression test does not deterministically detect removal of `loadType`, and the label fallback can itself create a duplicate.

## Standards

### Low — possible Primitive Obsession in the label escalation stages

`WorkoutTracker/Domain/ProgressSeries.swift:317` encodes the disambiguation policy as an integer state machine: `render(... level: Int)`, checks against `level >= 1/2/3`, and a separate `for _ in 0...3` loop at line 334. Those numbers represent named stages—terse, equipment, load type, and gym—and the increment at line 341 can produce an unrendered level 4. This is a judgement-call smell rather than a documented-standard breach. An enum or ordered collection of named stages would make the escalation contract explicit and exhaustive.

No documented-standard violation was found. The ranking and label policy correctly live in the UI-free Domain and have unit coverage, consistent with `CLAUDE.md:29`; the focused `ChartPresetScopingTests` suite built and passed all 19 tests.

## Spec

### Medium — the new ranking test does not deterministically detect the omitted axis

`WorkoutTrackerTests/ProgressSeriesTests.swift:320` compares the result with reversed input, then line 322 only requires the first raw value to sort before the last. With `loadType` removed from the comparator, both calls first pass through a `Dictionary`; reversing insertion does not guarantee reversed dictionary enumeration. Whenever that arbitrary enumeration happens to be `assisted, weighted`, every assertion still passes. The response's claim that the test “pins” the mixed-load-type order (`work-record/milestone-9-history-and-summary/issues/01-chart-per-equipment-and-history-chart.md:105`) is therefore only partially true. Extract and directly test the rank/comparator contract, or otherwise make the mutation fail deterministically.

The production implementation itself closes the round-2 ordering defect: the tuple at `WorkoutTracker/Domain/ProgressSeries.swift:161` now includes day count plus every field of `ProgressVariationKey`—preset presence/id, `loadType`, and equipment—so distinct keys cannot compare equal.

### Medium — ordinal fallback can introduce a duplicate label and never recheck it

`WorkoutTracker/Domain/ProgressSeries.swift:343` numbers only labels that are already repeated, but it never checks the generated ` (n)` strings against untouched rows. A concrete valid input has two distinct weighted machines both named `X` with nil gyms, plus a third variation whose user-supplied preset name is `X · Weighted (2)`. The first two escalate together to `X · Weighted`; line 350 changes the second to `X · Weighted (2)`, which is now exactly the third row's unchanged label. Equal non-nil gyms behave the same way. With three initially identical rows, the generated `(2)` and `(3)` labels can each collide with untouched user-provided names.

Thus names containing the separator and ordinal syntax defeat the asserted “NO two the same” contract (`WorkoutTracker/Domain/ProgressSeries.swift:306`) and the response's “finally an ordinal” guarantee (`work-record/milestone-9-history-and-summary/issues/01-chart-per-equipment-and-history-chart.md:110`). The escalation loop does detect collisions created by raising only some rows, but the ordinal step sits after that loop and has no final uniqueness pass. Allocate suffixes against the complete set of original and already-assigned labels, and test both three-way collisions and occupied ordinal suffixes.

No scope creep was found.

Verification: `xcodebuild test ... -only-testing:WorkoutTrackerTests/ChartPresetScopingTests` succeeded with 19 tests in one suite and zero failures.

Standards — 1 finding (worst: low); Spec — 2 findings (worst: medium).
