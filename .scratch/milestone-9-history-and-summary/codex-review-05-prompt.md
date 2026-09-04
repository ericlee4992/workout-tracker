Cross-review (T6) of milestone 9, ticket 05, on branch
milestone-9-history-and-summary. Review boundary: 391191c..1f8f1bf (one commit,
1f8f1bf). Read .scratch/milestone-9-history-and-summary/spec.md and
issues/05-finish-summary-heart-rate-graph.md, and docs/DECISIONS.md D9, D25,
D44, D45, D46, T2.

## What was built

Domain/HeartRateSeries.swift (bucket fold, points, total energy);
Workout.heartRateSeries / heartRateSeriesIntervalSeconds /
basalEnergyKilocalories; HeartRateProviding.basalEnergyKilocalories (defaulted
nil) read from HKLiveWorkoutBuilder, composited, and supplied by the fixture;
WorkoutSummaryBuilder.capture(samples:basal:now:) writes the series;
WorkoutHeartRateCoordinator.end passes dominantSamples; WorkoutSummary gains
the three fields + totalEnergyKilocalories/hasHeartRateSeries;
Features/History/HeartRateSummarySection.swift (Swift Charts, RectangleMarks);
WorkoutFinishedSheet 2x2 tile grid + section; WorkoutDetailView heart-rate
section + chart; export schema 8. HeartRateSeriesTests (10), migration gate,
HeartRateSummaryUITests (2).

## Specific things to attack

1. **The fold.** Bucket index arithmetic at the boundaries (a sample exactly
   at start, exactly at end, exactly on a bucket edge); rounding of means;
   samples with bpm <= 0; duplicate timestamps; a series longer than the
   cap; an end before start. Does `capture` compute the end from `now` and is
   that the right instant on every exit path (finish, templated finish,
   cancel, the start-new recovery) -- in particular, is capture ever called
   AFTER finishedAt is set, or long after the last sample?
2. **Dominant-source samples.** The aggregates use the dominant source; the
   series now does too. Is there any path where they diverge (source changes
   mid-workout)? Is a series from one source honest when the other source
   was reporting during a gap?
3. **Missing is not zero (D44).** Every place a 0 bucket could be read as
   0 BPM: the chart, the accessibility label, the export, the summary's
   hasHeartRateSeries. Is a series of all zeros written (it should not be)?
4. **Total calories (D9/D25).** Shown only when both halves exist -- verify
   in the sheet, in History, and that no path sums active + 0. Is basal from
   HKLiveWorkoutBuilder the right statistic (sum over the session), and does
   the authorization set include it without breaking the existing grant?
   What does the fixture claim and is it labelled?
5. **The chart.** RectangleMark from elapsed to elapsed+interval: is the last
   bucket's span right when the workout ended mid-bucket? Is the y-domain
   honest when maxBpm is nil? Does the x-domain formula hold for a 1-bucket
   series? Anything that renders an empty chart?
6. **Migration and export.** Three new optional/defaulted fields on Workout:
   fixture opens? Schema 8 asserted everywhere (docs/SPEC.md, milestone-3
   spec, tests)? Does the CSV remain unchanged, and is that documented?
7. **D46.** Confirm nothing here runs at a deadline or touches the Live
   Activity / alarm paths.
8. **Absence of a caller / false claims.** Is every new identifier used? Is
   every claim in the resolution and commit message true?

Report by severity with file:line, do not soften. Write to
.scratch/milestone-9-history-and-summary/codex-review-05.md
