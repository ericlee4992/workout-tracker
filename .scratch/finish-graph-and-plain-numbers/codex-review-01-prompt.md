Cross-review (T6) of the finish-graph work, ticket 01, on branch
finish-graph-and-plain-numbers. Review boundary: af0a52a..32dad6f (one commit,
32dad6f). Read .scratch/finish-graph-and-plain-numbers/spec.md and
issues/01-apple-shaped-heart-rate-graph.md, and docs/DECISIONS.md D9, D25,
D44, T2. The user's two screenshots are described in spec.md; the app's own
screenshot of the result is the `history-heart-rate-hour` attachment (run
WorkoutTrackerUITests/HeartRateSummaryUITests if you want it).

## What was built

Domain/HeartRateSeries.swift: `fold` (mean + low + high per bucket, `series`
now delegates), `displaySlots` (merge to <=110 bars, gaps omitted, mean-only
fallback, mismatched range ignored, last slot clamped to duration),
`range(of:)`. Workout.heartRateSeriesLow/High (defaulted []),
WorkoutSummary carries them, WorkoutSummaryBuilder.capture writes all three
from one fold, export schema 9 (JSON only, omitted when empty).
Features/History/HeartRateSummarySection.swift rewritten (RectangleMark low..high
inset 30%, ±0.5 bpm ink, y domain = drawn range + pad, two y labels, three
clock-time x ticks, "N BPM AVG" caption; new `low`/`high`/`startedAt`
parameters, both callers updated). Domain/HeartRateHistoryFixture.swift +
`-uiTestHeartRateHistory` wiring in WorkoutTrackerApp. Tests: +5 unit in
HeartRateSeriesTests, capture/export tests extended, migration gate extended,
three schemaVersion assertions moved to 9, one new UI test with screenshot.

## Specific things to attack

1. **The fold.** Low/high initialisation (the first sample of a bucket must
   SET the low, not min against 0), samples with bpm <= 0, the cap horizon
   — do low/high obey exactly the same admission rule as the mean? Is
   `low <= mean <= high` guaranteed for every non-gap bucket, and 0/0/0 for
   every gap?
2. **Display slots.** Off-by-one in `perSlot`/`slotCount` for counts just
   above and just below a multiple of maxSlots; a slot whose only non-gap
   bucket has a range array entry of 0 with a mean > 0 (should not happen —
   is it handled?); `endSeconds` clamping when durationSeconds < startSeconds
   (a corrupt duration); a series longer than maxSlots × perSlot. Is the
   "range of MEANS" fallback for v8 data honest, and is it documented where
   the user would see it (SPEC)?
3. **The chart.** y domain when the range is a single value (low == high
   everywhere); the ±0.5 ink vs the axis labels at exact low/high — does a
   label ever sit off the bar it labels? The 30% inset when a slot is 15 s
   and the plot is narrow; the third clock label at ⅔ overflowing the
   trailing edge; `formatted(date:.omitted, time:.shortened)` on a 24-hour
   locale; the accessibility label still truthful.
4. **Migration and export (D44, T2).** Two new arrays on Workout: fixture
   opens? Are they CloudKit-safe scalars? Schema 9 asserted everywhere it
   was asserted for 8 (grep)? Does `ExportCollector` omit them exactly when
   the mean is omitted, and could low/high be present with the mean absent
   (or lengths disagree) on any write path? Restore is not implemented, but
   is the file self-consistent?
5. **The fixture.** It is seeded only under the argument — confirm it cannot
   reach a real store; confirm the generator is deterministic and its
   invariants (low <= mean <= high, gap = 0/0/0) hold for every index; is
   `maxHeartRate` = max(high) consistent with what `capture` would have
   written from real samples?
6. **Absence of a caller / false claims.** Is every new identifier used
   (`Folded.empty`, `hasSamples`, `range(of:)`, `defaultMaxSlots`,
   `heartRateAverageCaption`)? Is every claim in the resolution and commit
   message true, including the test counts?
7. **D46.** Confirm nothing here runs at a deadline or touches the Live
   Activity / alarm paths.

Report by severity with file:line, do not soften. Do not modify source
files. Write to .scratch/finish-graph-and-plain-numbers/codex-review-01.md
