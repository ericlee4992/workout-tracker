# Cardio and mixed workouts — accepted implementation scope

User authorization: 2026-09-18, direction B plus optional devices/manual fallback; explicitly
requires indoor distance and pace with supported connected devices including AirPods Pro 3.
Also retains approved outdoor runs/rides with GPS and one saved mixed workout.

## User flow

- Start Lifting enters the existing log (preserve startEmptyWorkout test identifier).
  Start Cardio sits beside Start Lifting (stacked at accessibility sizes) and offers Apple-style Indoor Walk, Indoor Run, Indoor Cycle, Elliptical, Rowing,
  Stair Stepper, Outdoor Walk, Outdoor Run and Outdoor Cycle.
- One ongoing workout, Lifting / Cardio focus switch (B), Add Exercise and Add Cardio available
  mid-workout. A focus switch changes the view; it does not silently end recording.
- Starting a cardio activity creates a segment and ends any preceding unfinished cardio
  segment at the same boundary. Explain this consequence in the picker when relevant.
- Cardio offers Pause / Resume and End Cardio. End Cardio saves the segment and keeps the
  workout open. Finish ends the workout and its unfinished segment. Cancel deletes all of it.
  Starting cardio clears an outstanding lifting rest timer/alarm.
- Timer is cardio active time (pauses excluded). The workout header is whole-workout elapsed
  time. A paused segment survives restart; an interrupted running segment recovers paused at
  its last persisted checkpoint, never pretending to have tracked while the app was dead.
- Cardio works without wearable data. Missing HR/calories/distance/pace are absent or a dash,
  never fake zero measurements. Device loss does not discard or end the workout.

## Measurement contract

- HealthKit uses the selected activity/location, collects supported distance types and
  observes live builder statistics. Actual data arrival establishes metric capability;
  merely connecting audio or receiving HR does not prove distance availability.
- Indoor walking/running additionally support Core Motion pedometer distance/pace, clearly
  labeled Phone motion. HealthKit distance takes precedence when supplied for the same span;
  overlapping estimates are never added. Alternatives share a sensor-session epoch across
  pauses; source timestamps select a fresh fallback and late cumulative totals remain usable. No running-speed assumption for indoor walking.
- The live view shows average pace (or cycling speed) from active duration / recorded distance.
  Fresh current pace/speed is additional, so batched distance does not mean no usable pace.
  Current pace is derived from fresh
  measured movement only; stale/zero/unavailable speed has no current pace. Cycling shows speed.
- Indoor bike/rower/elliptical/stepper distance uses real supported sensor data when supplied
  or entered machine distance. Never derive distance from heart rate or pretend every device
  supports every metric. AirPods indoor delivery is a real-device acceptance gate, not proven
  by synthetic input or Apple's first-party Fitness behavior. See research note.
- Manual distance retains entered value/unit; normalized meters support math. Explicit manual
  correction overrides displayed automatic distance while preserving the automatic evidence.
- Outdoor GPS requests location on use; respects denied/reduced-accuracy/stale/poor fixes.
  Route and distance persist, pause gaps are not connected, and the app continues with the
  screen locked using supported background location. Route access is local, no backend.
- Sequential activity-specific HealthKit sessions sit inside one app workout; preserve the
  whole workout's HR samples/summary and add only non-overlapping energy intervals.
  No arbitrary strength/cardio HKWorkoutActivity mixture or duplicate energy streams.

## Persistence, History and export

- Separate cardio segments belong to Workout; weight×reps SetRecord semantics stay intact.
  Additive CloudKit-compatible schema (UUIDs, optional relationships, defaults).
- Cardio-only finish saves meaningful recorded duration even with zero strength sets.
- History and receipt keep one workout, with lifting/cardio sections, each segment's duration,
  distance/source/pace, available HR/energy and outdoor route. Shared session metrics retain
  their accepted time/volume, calories, HR order. No cardio fabricated as strength volume/PR.
- In-flight HR samples and energy totals checkpoint locally and resume without replacing earlier
  data. App-owned sessions retain the workout across minimise; cross-workout sensor teardown
  completes before the next session starts. Finished summaries clear transient checkpoints.
- Existing lifting templates continue to save lifting only; cardio-only workouts do not offer
  an empty lifting template. History delete cascades cardio; export retains every segment,
  manual and measured distance provenance, active intervals and route data.
- JSON version increments; CSV appends cardio columns/rows without reusing old meanings.
  Reopen/export tests cover these paths. Verify a current pre-cardio store migration as well
  as the historical fixture before any phone install. Installation is not requested yet.

## Design and verification

B: header / Lifting–Cardio focus / current activity / segment timer (hero) / measured metric
pairs / sensor details (no live map) / one primary Pause / secondary End Cardio, pinned within the safe area. At AccessibilityL,
metrics and controls stack. Existing colours, SF Symbols and tab navigation remain.
Real normal/AccessibilityL captures, targeted domain/service/export/migration tests, Debug
build and full local UI suite gate merge, followed by independent Claude code/visual review.
Real phone sensor/GPS validation is tracked distinctly from simulator evidence.

## Presentation amendment — 2026-09-18

User confirmed indoor distance works with AirPods Pro 3. Suppress the HealthKit estimate
caption without changing saved source evidence; retain manual and other source labels.
Outdoor maps appear only after workout Finish, in Summary and History, including when a
cardio segment has ended while the encompassing workout remains open. Route recording is unchanged.
