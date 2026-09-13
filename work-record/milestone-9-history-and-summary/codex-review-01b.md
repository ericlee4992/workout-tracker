# Codex cross-review 01b — milestone 9, ticket 01

Review boundary: `18d76ec..75a280f`  
Verdict: **do not merge yet**. The round-1 grouping and empty-state defects are closed, but the fix's ordering contract is still false and its naming rule can make distinct picker choices indistinguishable.

## Standards

### Medium — `rankedVariations` is not a total, deterministic ordering

`WorkoutTracker/Domain/ProgressSeries.swift:158` builds the entire tie-break tuple from day count, preset presence, equipment, and preset id. It omits `loadType`, even though `ProgressVariationKey` includes `loadType` and the surrounding documentation explicitly says D47 can leave one exercise with history under two load types (`WorkoutTracker/Domain/ProgressSeries.swift:101`). Two distinct keys with equal day counts, equipment, and preset therefore compare equal. Because the source is a dictionary, their order can vary rather than remaining stable across launches.

This contradicts the function's “fully ordered” contract at `WorkoutTracker/Domain/ProgressSeries.swift:143` and the response's claim at `work-record/milestone-9-history-and-summary/issues/01-chart-per-equipment-and-history-chart.md:92`. It also leaves the test named `rankedVariationsIsTotalAndStable` incomplete: every input in `WorkoutTrackerTests/ProgressSeriesTests.swift:291` is weighted, so the omitted axis is never exercised. Add a stable load-type discriminator to the domain rank and pin a same-days/same-equipment/same-preset mixed-load-type case.

The round-1 standards finding about duplicated ranking is otherwise closed: the comparator now has one domain owner, `defaultVariation` takes its first result, and the view consumes that result without re-sorting (`WorkoutTracker/Domain/ProgressSeries.swift:152`, `WorkoutTracker/Domain/ProgressSeries.swift:167`, `WorkoutTracker/Features/History/ExerciseProgressView.swift:388`).

## Spec

### Medium — the promised stable tie-break still allows distinct variations to compare equal

`WorkoutTracker/Domain/ProgressSeries.swift:158` does not include `loadType` in its rank. D47 expressly permits one exercise's frozen history to contain multiple load types (`docs/decisions.md:56`), and load type is part of the variation key (`WorkoutTracker/Domain/ProgressSeries.swift:115`). Consequently two distinct variations can tie on every compared field and inherit dictionary order, violating the ticket response's claim that the order is “fully ordered” and stable (`work-record/milestone-9-history-and-summary/issues/01-chart-per-equipment-and-history-chart.md:92`). The current “total and stable” test uses only `.weighted` records (`WorkoutTrackerTests/ProgressSeriesTests.swift:291`) and cannot establish the claim.

### Medium — two distinct picker rows can have exactly the same rendered label

`WorkoutTracker/Features/History/ExerciseProgressView.swift:408` suppresses the equipment text for `.unrecorded` whenever a preset exists, then displays only that preset name. User preset names are not constrained against equipment labels. For example, a one-day `.unrecorded` variation whose snapshot preset is named “Dumbbell” and a one-day `.freeWeight(.dumbbell)` variation with no preset both render as `Dumbbell · 1 day` at `WorkoutTracker/Features/History/ExerciseProgressView.swift:192`, despite having different keys and different series. Exact machines can likewise collide when their frozen display labels match. This breaks the ticket requirement that the picker name the variation (`work-record/milestone-9-history-and-summary/issues/01-chart-per-equipment-and-history-chart.md:15`) and makes the response's new naming rule at line 95 ambiguous. Preserve a visible discriminator for every axis, or disambiguate colliding display names before constructing the picker rows, and add a collision test.

The other round-1 spec findings are closed. `ProgressEquipment` is total over both optional provenance fields and deliberately gives a machine precedence (`WorkoutTracker/Domain/ProgressSeries.swift:84`), matching `RecordsMath.groupKeys` (`WorkoutTracker/Domain/RecordsMath.swift:249`). Normal app entry creation and equipment changes already clear the tag when a machine is present (`WorkoutTracker/Domain/WorkoutSession.swift:166`, `WorkoutTracker/Domain/WorkoutSession.swift:317`), while the precedence also handles anomalous legacy inputs consistently. Series filtering now uses that exact derived equipment plus load type and preset (`WorkoutTracker/Domain/ProgressSeries.swift:177`), so exact-machine, free-weight-tag, and unrecorded sets no longer pool.

The sparse-history dead end is also closed for reachable chart flows: the current variation is appended with zero eligible days when necessary (`WorkoutTracker/Features/History/ExerciseProgressView.swift:388`), and the picker remains available above the empty state whenever another variation exists. A genuinely entry-less stale initial key would display a named `nothing eligible` row and offer the other variations; no in-sheet delete or live-refresh path was found that can create that stale state. The warmup fixture changes only the chart-history fixture (`WorkoutTracker/Domain/ChartFixture.swift:64`); the two positional accesses in `ProgressChartTooltipUITests` were updated to the new ordering (`WorkoutTrackerUITests/ProgressChartTooltipUITests.swift:123`, `WorkoutTrackerUITests/ProgressChartTooltipUITests.swift:152`), while the other History row indexing tests do not launch that fixture.

Verification: `git diff --check 18d76ec..75a280f` passed, and a Debug iPhone-simulator build completed successfully. Focused unit tests could not be independently executed because the simulator test service terminated with Mach error `-308`; after rebooting the simulator, the retry stalled waiting for the test runner and was stopped without any test case starting. This is a verification limitation, not an observed product-test failure.

Standards — 1 finding (worst: medium); Spec — 2 findings (worst: medium).
