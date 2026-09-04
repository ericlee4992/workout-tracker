# 05 — Finish summary with a heart-rate graph, in History too

Status: ready-for-agent
Blocked by: 04
Covers user ask **6**.

## What to build

**A. Persist a heart-rate series per workout.** `Workout.heartRateSeries: [Int]` at a fixed
cadence (`heartRateSeriesIntervalSeconds`, 15 s), starting at `startedAt`; a gap with no sample
stores 0 and renders as a gap, never as 0 BPM. CloudKit-safe scalars only (T2), same shape as
`zoneSeconds`. Written by the finish path from the samples the monitor already accumulates for
zone time — assert the WRITE happens (this repo's most-shipped defect is a field nothing sets).
Also persist `basalEnergyKilocalories` from `HKLiveWorkoutBuilder` so **total calories** =
active + basal can be shown; nil when the builder did not provide it.

**B. The finish sheet** becomes the card layout in the user's Apple Fitness screenshot: a 2×2
stats block (Workout time, Active calories, Total calories, Avg. heart rate), then time in zones as
today, then a **Heart Rate** section with a Swift Charts bar/line series over elapsed time, y-axis
from the recorded max, average annotated. No effort rating (user's call).

**C. `WorkoutDetailView`** shows the same heart-rate section for any workout that has a series;
workouts logged before this ticket show what they have today (aggregates), never an empty chart.

## Acceptance criteria

- `LegacyStoreMigrationTests` opens the fixture with the two new fields.
- A unit test proves the series is written on finish from a fixture provider, with the right
  length for the duration and 0 for gaps.
- A test proves total calories is nil (row hidden), not 0, when basal is missing.
- UI tests under `-uiTestHeartRate`: the finish sheet shows the chart; a History detail for that
  workout shows it too; a fixture workout WITHOUT a series shows no chart section. Screenshots.
- The Live Activity and alarm paths are untouched — the series is read at finish, nothing runs at a
  deadline (D46).
