# 01 — Apple-shaped heart-rate graph

Status: built — awaiting Codex review
Added 2026-09-04 from the user's screenshot pair (see spec.md).

## What to build

Redraw `HeartRateSummarySection` (shared by the finish sheet and History detail) as Apple
Fitness draws it, and give it the data that shape needs.

**Data.** `HeartRateSeriesMath.fold(from:start:end:intervalSeconds:)` returns mean, low and high
per bucket (0 in all three = gap, exactly as today's `series`). `Workout` gains
`heartRateSeriesLow: [Int]` and `heartRateSeriesHigh: [Int]`, defaulted empty, written by
`WorkoutSummaryBuilder.capture` beside the mean; `WorkoutSummary` carries them; export schema 9
adds `heartRateSeriesLow` / `heartRateSeriesHigh` (JSON only, omitted when empty, like the mean).
The CSV is unchanged. Older workouts have only the mean and must still draw.

**Display slots.** `HeartRateSeriesMath.displaySlots(mean:low:high:intervalSeconds:
durationSeconds:maxSlots:)` merges adjacent buckets so at most `maxSlots` bars are drawn: each
slot spans its buckets' elapsed seconds, low = min of the non-gap lows, high = max of the non-gap
highs; when low/high are absent the means stand in for both. A slot with no non-gap bucket is not
returned (a gap stays a gap). A series with `<= maxSlots` buckets is returned bucket-for-bucket.

**Chart.**
- One `RectangleMark` per slot from `low` to `high`, inset within its slot so bars have air
  between them; a flat slot (low == high) still shows as a short tick, never vanishes.
- Nothing drawn from zero. Y domain is the series' own low…high with a little headroom; the axis
  shows exactly two labels, the high at the top right and the low at the bottom right, no
  horizontal gridlines.
- X axis: three faint vertical separators at the start and at thirds, labelled with CLOCK time
  (`startedAt` + elapsed, `HH:mm`), like the reference. `startedAt` is a new parameter.
- Under the plot, leading: "122 BPM AVG" in the bar colour, when an average exists. The dashed
  average rule and its annotation go.
- Solid accent (no gradient). Height ~160.

**Seeing it.** A `-uiTestHeartRateHistory` launch argument seeds ONE finished 60-minute workout
with a synthetic series (mean/low/high, a few gaps, a plausible strength shape) so the graph can
be screenshotted at real density; the simulator's fixture sensor yields two buckets in a 20 s
test and cannot show the shape. A UI test opens it from History and attaches the screenshot.

## Acceptance criteria

- `HeartRateSeriesTests`: fold gives low ≤ mean ≤ high per bucket, gaps are 0 in all three;
  `displaySlots` merges to the cap, keeps gaps, passes short series through, and falls back to
  means; capture writes all three arrays; export round-trips schema 9 and a v8 file still
  decodes with low/high nil.
- `LegacyStoreMigrationTests`: the new fields arrive empty on the phone-shaped fixture.
- The chart for a mean-only workout (v8 data) still draws.
- Screenshots: the finish sheet after the fixture sensor, and the seeded 60-minute workout in
  History — the second is the one to compare with the reference.
- Unit suite green in full; the UI classes that touch the sheet, History detail and heart rate
  green (HeartRateSummary, HeartRate, CoreLoop, HistoryEditing).
- Codex clear.


## Resolution (2026-09-04)

**Data.** `HeartRateSeriesMath.fold` returns `Folded { mean, low, high }` — one pass, same
boundaries and cap as `series`, which is now `fold(...).mean`. `Workout.heartRateSeriesLow` /
`heartRateSeriesHigh` (defaulted `[]`, lightweight migration, same shape as the mean array);
`capture` writes all three from the one fold; `WorkoutSummary` carries them; export **schema 9**
adds the two arrays (JSON only, omitted when empty; a v8 file decodes with them nil). CSV
unchanged. `LegacyStoreMigrationTests` opens the phone-shaped fixture and sees both empty.

**Display.** `HeartRateSeriesMath.displaySlots` merges adjacent buckets to at most 110 bars
(`defaultMaxSlots`): low = min of non-gap lows, high = max of non-gap highs, an all-gap slot is
omitted (a hole), a short series passes through bucket-for-bucket, the last slot ends at the
workout's end, and a workout with no range arrays (pre-v9) draws from the range of its means — a
mismatched-length range is ignored rather than trusted. `range(of:)` gives the axis.

**Chart** (`HeartRateSummarySection`, shared by finish sheet and History): one `RectangleMark` per
slot from low to high, inset 30% each side, ±0.5 bpm of ink so a flat slot is a tick; y domain =
drawn range plus headroom (never from 0); y-axis = exactly two labels at the drawn low and high,
no gridlines; x-axis = three faint separators at 0 / ⅓ / ⅔ labelled with clock time (locale
short time, so 24-hour phones read "18:29"); "122 BPM AVG" under the plot in the bar colour. The
dashed average rule, its annotation, the gradient and the 0–150 axis are gone. `startedAt` is a
new parameter, both callers pass `summary.date`.

**Seeing it.** `-uiTestHeartRateHistory` (`Domain/HeartRateHistoryFixture.swift`) seeds one
60-minute workout two days ago with a deterministic 240-bucket mean/low/high series (effort/rest
phases, one 75 s outage). `testAnHourLongWorkoutDrawsTheAppleShapedChartInHistory` opens it and
attaches `history-heart-rate-hour` — that screenshot beside the Apple Fitness reference: thin
floating bars, 150 top-right / 102 bottom-right, 6:29 PM / 6:49 PM / 7:09 PM, "122 BPM AVG".

**Tests.** +5 unit (fold low/high; slots merge/gaps/range; short series ends at the workout's end;
means stand in, mismatched range ignored; the fixture is well-formed, deterministic and seeds once)
plus the capture and export tests extended and the three `schemaVersion == 8` assertions moved to
9. **649 unit green.** UI: HeartRateSummary (3, one new) + HeartRate (5) + CoreLoop (9) +
HistoryEditing (2) — **19/19 green**, run 2026-09-04 in two pieces.


## Codex review 01 — response (2026-09-04)

`codex-review-01.md`: 1 high, 2 medium (spec), 1 medium (standards). All four real, all fixed:

- **Fixture flag alone seeded a real store (high).** True: only `-uiTestReset` selects the
  throwaway container, and `isEnabled` checked its own flag only. Now `isEnabled(arguments:)`
  requires both, pure and tested — and **`ChartFixture` had the identical hole since milestone 8**,
  fixed the same way in the same commit (outside the boundary, but the same defect one file over).
- **Export could carry a lone or mismatched range (medium).** `HeartRateSeriesMath.exportableRange`
  returns the pair only when both arrays match the mean's length; `ExportCollector` writes both or
  neither. Test: a `[95]` low beside a two-bucket mean exports no range at all.
- **Corrupt duration left a slot past the plot that still set the axis (medium).** A positive
  `durationSeconds` is now a horizon: slots starting at or past it are dropped, every kept slot ends
  within it; non-positive means no horizon. Test: `[120, 190]` with duration 10 draws one slot and
  the axis tops at 125.
- **STATE and SPEC still said schema 8 (medium, standards).** Both now say 9 and what 9 adds.

**652 unit green** (+3 regressions). UI: HeartRateSummary + ProgressChart + ProgressChartTooltip
(the fixture-driven classes, 9 tests) re-run green; HistoryCalendar (the fourth class on the chart
fixture) run separately, see below.
