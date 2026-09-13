# Codex cross-review 05c — Finish summary heart-rate graph

Review boundary: `70c654a...3add329` (commit `3add329`). Verdict: **not clear**.

## Standards

### High — A late bank still lets the aggregates extend past `finishedAt`

Passing `workout.finishedAt` as `capture`'s `now` correctly truncates the series, but the coordinator separately supplies `monitor.vitals`, which was already computed from every unbounded `summarySample` (WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:107-126, WorkoutTracker/Domain/HeartRateMonitor.swift:161-175). On the supported late-bank safety-net path, readings collected after the workout finished can therefore change average heart rate, maximum heart rate, and zone time while the series drops those same readings. That violates D44's persisted-at-finish truthfulness and the code's own invariant that aggregates and series describe the same evidence.

The new late-bank regression supplies only pre-finish samples and asserts only the series length, so it cannot detect the divergence (WorkoutTrackerTests/HeartRateSeriesTests.swift:253-267). Filter the summary samples once to the workout's `[startedAt, finishedAt]` boundary and derive both vitals and series from that collection.

### Medium — The “sustained run” gate does not establish sustained reporting

The terminal-handoff rule accepts any secondary-source collection whose first and last timestamps are more than 60 seconds apart (WorkoutTracker/Domain/WorkoutVitals.swift:70-84). Two isolated readings 61 seconds apart therefore qualify even though their own gap exceeds the threshold that this module defines as “the sensor was not reporting”; both can alter average and maximum heart rate. The dense-run regression and the one-sample-stray regression leave this minimum qualifying case uncovered (WorkoutTrackerTests/HeartRateSeriesTests.swift:229-250).

This is also a possible **Mysterious Name** judgement call: `run` and the comments' “kept reporting”/“sustained” language imply continuity that an endpoint-span check does not prove. Either require continuity or sufficient sample-count evidence, or name and document the weaker two-endpoint policy explicitly.

## Spec

### High — The series and aggregates no longer use the same workout-bounded readings

The ticket says samples outside the workout are ignored and that the series uses the same readings as the aggregates (work-record/milestone-9-history-and-summary/issues/05-finish-summary-heart-rate-graph.md:39-46). `finishedAt` is passed only to the series fold; `monitor.vitals` still folds every summary sample without a workout start/end filter (WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:107-126, WorkoutTracker/Domain/HeartRateMonitor.swift:161-175, WorkoutTracker/Domain/WorkoutSummary.swift:166-192). Thus a post-finish reading received before the delayed safety-net bank is absent from the chart but present in its average, maximum, and possibly zone totals. The new regression checks only bucket count with samples that all precede `finishedAt` (WorkoutTrackerTests/HeartRateSeriesTests.swift:253-267).

## Verified checks

- Drift replacement now calls `end(workout)` while `replacementWorkout` strongly holds the still-active model, before `TemplateDriftService.resolve` finishes it (WorkoutTracker/Features/Start/StartWorkoutView.swift:208-222). `end` mutates the model first, and `resolve`'s explicit context saves persist the capture (WorkoutTracker/Domain/TemplateDrift.swift:144-205). The coordinator guard prevents a second capture when `startNew` runs.
- `workout.finishedAt ?? .now` gives the series the recorded end on a late bank; the remaining defect is that the aggregates do not share that bound.
- A dense leading or trailing secondary-source handoff is retained, while the single late-reading regression remains excluded. Two actual readings 61 seconds apart do not make the intervening chart buckets nonzero and cannot replace the count-dominant source, so the weaker threshold is not a separate ticket-Spec failure; it remains the Standards/test-coverage issue above.
- The artificial cap horizon is now exclusive, including equality, while an uncapped workout's true end remains inclusive (WorkoutTracker/Domain/HeartRateSeries.swift:40-54). Its equality regression passes.
- The standalone `StartWorkoutView` preview now supplies `WorkoutHeartRateCoordinator` (WorkoutTracker/Features/Start/StartWorkoutView.swift:360-367).
- `HeartRateSeriesTests` and `CodexReviewRegressionTests` passed 29/29. `git diff --check 70c654a...3add329` passes. No source files were modified by this review.

Standards — 2 findings (worst: High); Spec — 1 finding (worst: High).
