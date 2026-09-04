# Codex cross-review 05 — Finish summary heart-rate graph

Review boundary: 391191c...1f8f1bf (commit 1f8f1bf). Verdict: **not clear**.

## Standards

### High — The replacement-workout exit violates D44 and contradicts its own “every path” comment

WorkoutHeartRateCoordinator.end says the “finish it and start new” recovery calls it and banks the summary (WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:89-106), but StartWorkoutView.startNew still lets WorkoutSession.startWorkout auto-finish the active workout without access to the coordinator (WorkoutTracker/Features/Start/StartWorkoutView.swift:161-173). After presentation, monitor(for:) merely stops the old monitor and throws its samples away (WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:53-65). A minimized workout replaced through this supported path reaches History without its series, aggregates, or calories, violating D44’s requirement that the HealthKit summary be persisted on Workout. The new coordinator test calls end directly and cannot catch the missing caller.

### High — Basal energy is not refreshed independently of heart-rate samples

ingest copies both energy figures, but refreshLiveness—whose documented purpose includes collecting energy after the last BPM or with no BPM at all—copies only activeEnergyKilocalories (WorkoutTracker/Domain/HeartRateMonitor.swift:194-203, WorkoutTracker/Domain/HeartRateMonitor.swift:219-233). WorkoutHeartRateCoordinator.end then persists the stale cached basal value (WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:95-106). A session with builder energy but no heart-rate samples can therefore retain active energy while losing basal energy, and a late basal update can be omitted. That breaks D44’s persisted-summary rule and can make Total disappear or combine figures captured at different instants.

### Low — Possible Divergent Change in HeartRateSeriesMath (judgement call)

HeartRateSeriesMath owns the bucket fold and point projection, but also the unrelated active-plus-basal calorie calculation (WorkoutTracker/Domain/HeartRateSeries.swift:15-73). Moving total-energy arithmetic to WorkoutSummary or a small energy-domain helper would leave this module with one reason to change. The scalar series representation itself is not a Primitive Obsession finding: T2 and the ticket explicitly require the CloudKit-safe [Int] shape.

## Spec

### Critical — “Finish It & Start New” loses the entire heart-rate summary

The ticket requires the series to be “Written by the finish path” and claims that coordinator end makes “every way out of a workout” take that path (.scratch/milestone-9-history-and-summary/issues/05-finish-summary-heart-rate-graph.md:9-15, .scratch/milestone-9-history-and-summary/issues/05-finish-summary-heart-rate-graph.md:43-46). The replacement flow instead finishes through WorkoutSession.startWorkout or template-drift resolution without calling the coordinator (WorkoutTracker/Features/Start/StartWorkoutView.swift:161-208). When the new workout opens, the coordinator stops the previous monitor without capture (WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:53-65). The old workout is saved with no series, aggregates, active calories, or basal calories. Wire the replacement flow through coordinator capture before finishing and regression-test the real exit, not only a direct call to end.

### High — Total calories can be missing or stale although the builder supplied basal energy

The requirement permits nil basal only “when the builder did not provide it” (.scratch/milestone-9-history-and-summary/issues/05-finish-summary-heart-rate-graph.md:14-15). Basal is copied only when a BPM is ingested, while the periodic/final energy refresh copies active alone (WorkoutTracker/Domain/HeartRateMonitor.swift:194-203, WorkoutTracker/Domain/HeartRateMonitor.swift:219-233). Consequently, no-BPM sessions and updates after the final BPM discard a supplied basal value before end persists the monitor cache. Refresh both halves together at the finish boundary and cover late-energy and energy-without-BPM cases.

### High — “No sample” gaps can contain readings from the discarded source

The stored zero is defined as “a gap with no sample” (.scratch/milestone-9-history-and-summary/issues/05-finish-summary-heart-rate-graph.md:9-13), and the chart footer tells the user that a missing bar means the sensor reported nothing (WorkoutTracker/Features/History/HeartRateSummarySection.swift:78). Instead, one source wins globally by whole-workout sample count and every sample from the other source is discarded (WorkoutTracker/Domain/HeartRateMonitor.swift:143-170, WorkoutTracker/Domain/WorkoutHeartRateCoordinator.swift:98-105). During a source handoff or an outage in the eventual winner, valid readings from the other reporting sensor become zero buckets. A near-half-workout segment can disappear while being labelled “nothing reported”; the source-selection policy must represent handoffs/gaps without making the series and aggregates describe different evidence.

### Medium — The 24-hour cap folds the entire later tail into one 15-second bucket

The resolution promises a series “capped at 24 h of buckets” (.scratch/milestone-9-history-and-summary/issues/05-finish-summary-heart-rate-graph.md:39-42). Although the count is capped, samples remain eligible over the full workout span and their indices are clamped to count - 1 (WorkoutTracker/Domain/HeartRateSeries.swift:35-46). For any span beyond 24 hours, every later sample is therefore averaged into bucket 5,759, corrupting the final retained 15-second mean instead of truncating at the cap horizon. theBucketCountIsCapped supplies no samples and checks only the array length (WorkoutTrackerTests/HeartRateSeriesTests.swift:60-63), so it misses the defect.

### Medium — A partial final bucket overstates workout duration

The requested chart is over elapsed workout time (.scratch/milestone-9-history-and-summary/issues/05-finish-summary-heart-rate-graph.md:17-20), but the chart receives no actual duration. Every rectangle ends at bucketStart + interval, and both its x-domain and accessibility label use series.count * interval (WorkoutTracker/Features/History/HeartRateSummarySection.swift:37-40, WorkoutTracker/Features/History/HeartRateSummarySection.swift:57-58, WorkoutTracker/Features/History/HeartRateSummarySection.swift:83-87). A 31-second workout is drawn and announced as 45 seconds; the last mark and domain need to stop at the real finish duration.

### Low — The canonical data-model sketch omits all three new fields

Schema 8 is correctly recorded, but the canonical Workout sketch still lists only the pre-ticket aggregate fields (docs/SPEC.md:81) and omits heartRateSeries, heartRateSeriesIntervalSeconds, and basalEnergyKilocalories. Update the product source of truth alongside the implemented schema.

## Verified checks

- The ordinary finish, templated-finish, and cancel UI methods call capture before finishedAt is set; the replacement path above does not call capture at all. Nothing new runs at a deadline, and the Live Activity/rest-alarm scheduling logic was not changed (D46).
- The fold handles start, end, ordinary bucket-edge, nonpositive-BPM, duplicate-timestamp, rounded-mean, and end-before-start cases consistently. Zeros are omitted from chart points and accessibility values, an all-zero fold is not persisted, hasHeartRateSeries requires a positive bucket, and both UIs require both active and basal before showing Total.
- Apple’s [typesToCollect documentation](https://developer.apple.com/documentation/healthkit/hkliveworkoutdatasource/typestocollect) lists basalEnergyBurned as a possible automatically collected HKLiveWorkoutDataSource type, so sumQuantity() is the correct statistic shape; the authorization read set includes it. Availability remains optional as the ticket requires.
- The legacy fixture opens with empty/nil new fields. JSON schema 8 and v7 decoding are covered in implementation, docs/SPEC.md, the milestone-3 export spec, and tests; the 37-column CSV is unchanged and its spec explicitly says so.
- git diff --check 391191c...1f8f1bf passes. The full unit suite passed 637/637; the four focused unit suites passed 57/57; HeartRateSummaryUITests passed 2/2 with both screenshot attachments. No source files were modified by this review.

Standards — 3 findings (worst: High); Spec — 6 findings (worst: Critical).
