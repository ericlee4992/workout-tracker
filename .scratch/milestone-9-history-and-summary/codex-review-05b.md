# Codex cross-review 05b — Finish summary heart-rate graph

Review boundary: `1f8f1bf...70c654a` (commit `70c654a`). Verdict: **not clear**.

## Standards

### High — The template-drift replacement path still violates D44

The ordinary replacement path is fixed: `startNew` calls `end(active)` while the old workout is still active, and the following workout-start save persists the captured summary (WorkoutTracker/Features/Start/StartWorkoutView.swift:164-182). The drift-resolution path has a different order. `TemplateDriftService.resolve` finishes and saves the old workout first, then `resolveReplacementDrift` clears its strong state references and calls `startNew` (WorkoutTracker/Domain/TemplateDrift.swift:193-205, WorkoutTracker/Features/Start/StartWorkoutView.swift:208-217). At that point `resumableWorkout()` cannot return the finished row, so the explicit `end` is skipped.

The later `monitor(for:)` safety net is not an adequate finish boundary. It depends on a `weak` `currentWorkout` surviving until the new full-screen cover asks for a monitor; if that reference has gone nil, the fallback merely stops the old monitor and discards its samples (WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:26-29, WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:62-74). If it does survive, capture uses the later wall-clock `now`, despite the workout already having `finishedAt`, and runs after both explicit saves with no subsequent `ModelContext.save` (WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:107-130, WorkoutTracker/Domain/WorkoutSummary.swift:163-188). That can extend the series past the recorded finish and leaves persistence to autosave. Bank the summary before drift resolution finishes the workout, while the caller still holds it strongly.

The replacement regression test does not exercise this order: it retains `first` strongly, never finishes it before switching monitors, and never reopens storage to prove durability (WorkoutTrackerTests/HeartRateSeriesTests.swift:195-209). Calling `end` twice does not double-capture in the fixed ordinary path because the first call clears `monitor` and `workoutID` and the second call fails the guard.

### High — Sustained terminal sensor handoffs are still represented as missing data

D44's missing-versus-recorded contract is still false when the globally dominant sensor stops for good. `summarySamples` admits secondary samples only strictly between two dominant readings separated by more than 60 seconds (WorkoutTracker/Domain/WorkoutVitals.swift:42-70). If AirPods own the longer prefix, then stop while Watch continues reporting for a substantial but shorter tail, every valid Watch reading after the final AirPods reading is discarded and the chart calls that whole interval a gap. The same issue applies to a substantial leading segment before the eventual dominant source begins.

The strict interior rule is correct for bounded outages: it avoids overlapping endpoint samples, treats exactly 60 seconds consistently with the existing staleness threshold, and preserves codex-review-2 #6's isolated late-Watch regression. It is not sufficient for a sustained leading or trailing run. The new test covers one bounded interior outage and one trailing stray, but not a continuing terminal handoff (WorkoutTrackerTests/HeartRateSeriesTests.swift:171-192).

### Medium — The cap still folds a sample exactly at its truncation boundary

For a workout longer than 24 hours, the retained horizon is the end-exclusive boundary after bucket 5,759. A sample exactly at that horizon belongs to the first omitted bucket, but `offset <= horizon` admits it and `min(count - 1, Int(offset / interval))` folds it into the preceding retained bucket (WorkoutTracker/Domain/HeartRateSeries.swift:37-50). The cap regression checks `horizon - 5` and `horizon + 100`, skipping equality (WorkoutTrackerTests/HeartRateSeriesTests.swift:60-69). Preserve end-inclusive behavior for an uncapped workout's true end, but make the artificial cap boundary exclusive when the cap bites and add the equality case.

### Low — The standalone StartWorkoutView preview now lacks its required environment value

`StartWorkoutView` gained a non-optional `WorkoutHeartRateCoordinator` environment dependency (WorkoutTracker/Features/Start/StartWorkoutView.swift:4-9), but its direct preview still supplies only a model container (WorkoutTracker/Features/Start/StartWorkoutView.swift:355-362). Rendering that preview will fail because no coordinator is present. The production `TabView` injection is correctly above every tab, and the full-screen cover retains its explicit coordinator injection (WorkoutTracker/App/RootView.swift:37-70); the preview needs the same dependency.

## Spec

### Critical — Template-drift “Finish It & Start New” still does not durably write the summary

The ticket requires the heart-rate series to be written by the finish path and says every way out of a workout takes coordinator `end` (.scratch/milestone-9-history-and-summary/issues/05-finish-summary-heart-rate-graph.md:9-15, .scratch/milestone-9-history-and-summary/issues/05-finish-summary-heart-rate-graph.md:43-46). Ordinary replacement now does. Template-drift replacement still finishes and saves before `startNew`, which then sees no active workout and cannot call `end` (WorkoutTracker/Features/Start/StartWorkoutView.swift:164-182, WorkoutTracker/Features/Start/StartWorkoutView.swift:208-217, WorkoutTracker/Domain/TemplateDrift.swift:193-205).

Capture is deferred until presentation of the next workout and relies on the old workout surviving through a weak reference. If it does not, the summary is lost; if it does, the write happens after the finish and new-workout saves, is not explicitly persisted, and uses the wrong end instant (WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:26-29, WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:62-74, WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:107-130). The new test proves only a direct in-memory monitor switch, not the real drift flow or a durable write (WorkoutTrackerTests/HeartRateSeriesTests.swift:195-209).

### High — A real terminal source handoff is still rendered as “sensor reported nothing”

The stored zero is defined as a gap with no sample, but the merge accepts secondary readings only inside a bounded dominant-source outage (WorkoutTracker/Domain/WorkoutVitals.swift:42-70). When the dominant source stops permanently and the other sensor continues reporting, or a secondary source reports a sustained leading segment, those readings are dropped merely because there is no dominant sample on the far side. The chart then displays false gaps contrary to the ticket's meaning for zero (.scratch/milestone-9-history-and-summary/issues/05-finish-summary-heart-rate-graph.md:9-13). A sustained-run rule can retain genuine terminal handoffs while continuing to reject the single late reading covered by codex-review-2 #6.

## Verified checks

- The ordinary replacement path now captures before the workout-start save; the coordinator's identity guard prevents double capture. The `TabView` environment reaches the Start tab and all other tabs, and the cover's explicit injection remains present.
- `refreshEnergy()` copies active and basal energy as a pair, and `end` invokes it immediately before capture. The late-energy regression test covers both fields and total calories (WorkoutTrackerTests/HeartRateSeriesTests.swift:212-226).
- Samples strictly inside a bounded dominant gap longer than 60 seconds are consistently used for both aggregates and the series; an exactly-60-second gap and the isolated trailing-sample regression remain excluded.
- Samples beyond the cap horizon are now truncated rather than collapsed into the final bucket. The exact-horizon defect above remains.
- `durationSeconds` bounds the last rectangle, x-domain, and accessibility duration. For a duration shorter than one interval, `xEnd` is the real positive duration rather than the full interval (WorkoutTracker/Features/History/HeartRateSummarySection.swift:12-20, WorkoutTracker/Features/History/HeartRateSummarySection.swift:37-58, WorkoutTracker/Features/History/HeartRateSummarySection.swift:82-89).
- The total-energy helper moved out of `HeartRateSeriesMath`, and the canonical model sketch now includes all three new fields. No D46 deadline paths changed.
- `git diff --check 1f8f1bf...70c654a` passes. The focused `HeartRateSeriesTests` passed 13/13, and the full unit suite passed 640/640. No source files were modified by this review.

Standards — 4 findings (worst: High); Spec — 2 findings (worst: Critical).
