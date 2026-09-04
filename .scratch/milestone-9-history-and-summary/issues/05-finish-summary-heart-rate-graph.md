# 05 — Finish summary with a heart-rate graph, in History too

Status: resolved — awaiting Codex review
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


## Resolution (2026-09-04)

**A. The series.** `Domain/HeartRateSeries.swift` — pure: samples folded into 15 s buckets from
`startedAt` to the finish instant, each bucket the rounded mean bpm, 0 where none arrived (a gap,
never 0 BPM); samples outside the workout ignored; capped at 24 h of buckets. `Workout` gains
`heartRateSeries: [Int]`, `heartRateSeriesIntervalSeconds: Int?` (stored, not assumed) and
`basalEnergyKilocalories: Double?`. **The write:** `WorkoutSummaryBuilder.capture` folds the
monitor's DOMINANT-source samples (the same readings the aggregates use) and writes series +
interval + basal; `WorkoutHeartRateCoordinator.end` passes them, so every way out of a workout
takes the path. Tested end to end through the coordinator, not just the fold. `HeartRateProviding`
gains `basalEnergyKilocalories` (defaulted nil); HealthKit reads `basalEnergyBurned` alongside
active; the composite takes the max; the fixture supplies a labelled figure.

**B. The finish sheet.** "Workout details" opens with a 2×2 tile block — Workout time, Active
calories, Total calories, Avg. heart rate — each tile OMITTED when its fact is missing (D44), and
Total shown only when both halves exist (D9/D25). Max HR, volume and time-in-zones follow as
before. Then a **Heart rate** section: `HeartRateSummarySection` (shared) draws each bucket as a
`RectangleMark` spanning its 15 s, the average as a dashed rule, y from the recorded max. (A
`BarMark` on a quantitative axis drew axes and no bars — caught by the screenshot, not the test,
which is why the screenshot is in the acceptance criteria.)

**C. History detail.** A "Heart rate" section (avg / max / active / total) for any workout with
aggregates, and the same chart when a series exists. Pre-existing workouts show aggregates and no
chart — asserted on the chart fixture.

**Export** schema **8**: `heartRateSeries`, `heartRateSeriesIntervalSeconds`,
`basalEnergyKilocalories` on the workout, JSON only (arrays do not belong in the set ledger, as with
`zoneSeconds`). v7 payloads decode with the fields absent.

**Tests.** `HeartRateSeriesTests` (10): bucket means, gaps, length rounding up, end inclusive /
outside ignored, points skip gaps, cap; total needs both halves; capture writes series+basal and the
summary sees them; no samples → empty series, hidden total; **coordinator end writes the series**;
JSON round-trip and v7 decode. Migration gate: fields arrive empty/nil, no chart claimed.
`HeartRateSummaryUITests` (2): finish → chart + Total tile → View in History → section + chart; chart
fixture → no section, no chart. **637 unit green; UI: summary (2), heart rate (5), history editing
(2) green.** Screenshots `finish-heart-rate`, `history-heart-rate`.

**Untouched, deliberately:** the Live Activity and the rest alarm — the series is read once at
finish; nothing runs at a deadline (D46).


## Codex review 05 — response (2026-09-04)

`codex-review-05.md`: 1 critical, 4 high, 2 medium, 2 low. All acted on.

- **"Finish it & start new" lost the whole heart-rate summary (critical / high).** True, and older
  than this ticket — aggregates and calories were already lost on that path; the coordinator's own
  comment claiming it was covered was false. Two fixes: `StartWorkoutView.startNew` calls
  `heartRateCoordinator.end(active)` before `startWorkout` auto-finishes it (the coordinator is
  now in the TabView's environment, not only the workout cover's), and `monitor(for:)` banks the
  previous workout before discarding its monitor, as a net. Tested through the replacement path.
- **Basal not refreshed with active (high ×2).** `refreshLiveness` refreshes both; `end` calls a
  new `refreshEnergy()` at the finish boundary before capture. Test: energy arriving after the last
  bpm, both halves persisted.
- **Dominant-source gaps (high).** `summarySamples` — used by BOTH aggregates and series — is the
  dominant sensor's samples plus the other sensor's samples strictly inside a dominant outage
  longer than `maxAttributedGap` (60 s). A first cut filled anything >15 s from a dominant sample
  and broke the codex-review-2 #6 regression (one late Watch reading joined the summary); the
  outage rule keeps that guarantee and honours the handoff case. Tested both.
- **Cap folded the tail (medium).** Truncates at the horizon; tested with samples beyond it.
- **Partial last bucket overstated duration (medium).** The section takes `durationSeconds`; the
  last rectangle, the x-domain and the accessibility label stop there.
- **SPEC sketch (low)** updated; **total-energy helper (low)** moved to `WorkoutSummary`.

**640 unit green (+3).** UI: summary (2), heart rate (5), core loop (9) ran green after the
RootView/Start changes; the later outage-rule change is Domain-only with a single fixture source.
