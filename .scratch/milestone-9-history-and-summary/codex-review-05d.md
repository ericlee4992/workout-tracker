# Codex cross-review 05d — Finish summary heart-rate graph

Review boundary: `3add329...4748203` (commit `4748203`). Verdict: **not clear**.

## Standards

### High — The “bounded” summary is still selected using out-of-workout samples

`WorkoutHeartRateCoordinator.end` obtains `monitor.summarySamples` first and only then filters that result to the workout interval (WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:119-130). But `summarySamples` chooses the dominant source from the monitor's entire sample history and evaluates handoffs before that bound is applied (WorkoutTracker/Domain/HeartRateMonitor.swift:143-175, WorkoutTracker/Domain/WorkoutVitals.swift:52-89). On a late bank, post-finish readings are absent from the final array but can still decide which source is dominant or whether another source qualifies as a terminal run. Vitals and series consequently consume the same array, but it can be the wrong in-workout evidence, still violating D44's persisted-at-finish truthfulness.

For example, six AirPods readings during a 50-second workout followed by many Watch readings before a late bank make Watch dominant. The six valid AirPods readings form a leading span shorter than 60 seconds and are rejected by the terminal-run rule; the subsequent date filter removes every post-finish Watch reading, leaving no summary at all. The new regression uses `.fixture` for both its pre- and post-finish readings, so it cannot expose cross-source selection poisoning (WorkoutTrackerTests/HeartRateSeriesTests.swift:264-282). Bound the monitor's raw samples first, then choose the dominant source and merge handoffs from that bounded input.

### Low — Possible Speculative Generality in the now-unused unbounded vitals property

The fix removed the only production use of `HeartRateMonitor.vitals`; it is now referenced only by tests (WorkoutTracker/Domain/HeartRateMonitor.swift:161-163). Keeping an unbounded summary API beside the new bounded finish path invites the old defect to be reintroduced. Remove it, or replace it with an API that accepts the workout bounds. This is a judgement call rather than a documented-standard violation.

## Spec

### High — Samples outside the workout still influence which workout samples are persisted

The ticket states that samples outside the workout are ignored and that the series uses the same readings as the aggregates (.scratch/milestone-9-history-and-summary/issues/05-finish-summary-heart-rate-graph.md:39-46). Although the final array is date-filtered, its source selection and handoff qualification have already examined all monitor samples (WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:119-130, WorkoutTracker/Domain/HeartRateMonitor.swift:151-175). A post-finish source can therefore become dominant and cause valid in-workout readings from the actual workout source to be discarded before the bound is applied. The one-source regression cannot catch this (WorkoutTrackerTests/HeartRateSeriesTests.swift:264-282). Apply `[startedAt, end]` to raw samples before any dominant-source or handoff logic.

## Verified checks

- The direct coordinator filter is inclusive at both `startedAt` and `end`, and both vitals and series receive precisely its output. When the workout is still active, `finishedAt` is nil and one captured `Date()` supplies the ordinary finish boundary (WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:107-130).
- The remaining failure is ordering: source selection precedes the bound. Once selected, vitals and series no longer diverge from each other.
- Terminal handoffs now require a total span longer than 60 seconds and no internal gap longer than 60 seconds. Two lone readings 61 seconds apart are rejected, gaps exactly at the threshold remain continuous, and the continuous 70-second regression is retained (WorkoutTracker/Domain/WorkoutVitals.swift:70-89, WorkoutTrackerTests/HeartRateSeriesTests.swift:229-259).
- `HeartRateSeriesTests` and `CodexReviewRegressionTests` passed 29/29. `git diff --check 3add329...4748203` passes. No source files were modified by this review.

Standards — 2 findings (worst: High); Spec — 1 finding (worst: High).
