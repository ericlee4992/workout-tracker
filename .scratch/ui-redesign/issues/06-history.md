# 06 — History: cards, the calendar, the detail, the progress chart

Status: in review — gates green, screenshots sent; Codex round 1 and the full suite pending

Spec: `.scratch/ui-redesign/spec.md` ticket 06, on the chosen Ink / Amber system.

## What changed

- `HistoryView.swift`: rows → cards led by a day tile (day number in `stat`, weekday in
  `label`; the month is the section header, now `label` uppercase); title, gym, stats line and
  unit badge unchanged. The row is a `Button` that appends to the same `path` the calendar and
  the receipt use — a `NavigationLink` in a `List` draws its chevron outside the label, so the
  card could not own its row; the chevron is drawn inside the card instead. `historyWorkoutRow`
  stays on the row, swipe-delete (still confirming) in `Theme.danger`. Empty state →
  `EmptyState("No workouts yet")` with the existing "Finished workouts show up here." under it.
- `HistoryCalendarSheet.swift`: each month a card; a workout day is an accent disc with
  `onAccent` text (the fill IS the mark — the green check is gone; the accessibility labels are
  unchanged), today a ring, a marked today an accent disc with a ring, a future workout day a
  dimmed disc. **Deviation from the plan**: the today ring is `Theme.secondary`, not
  `Theme.hairline` — Hairline is white at 7 %, invisible as a 2 pt ring on a card. 40 pt
  `Button`s and `calendarDay.*` ids untouched, the non-button empty day too.
- `WorkoutDetailView.swift`: the name/gym/duration rows and every set row sit on `Theme.card`;
  each exercise's header is a `MuscleIcon` + name (`cardTitle`) + equipment, the chart button an
  accent disc, the load type a `Chip` (still the same `Menu`, same ids). **The icon's colour is
  the live exercise's muscle group** — the snapshot has no muscle group (D23 snapshots display
  strings), the neutral icon when the exercise is gone; noted for Codex. Set lines: marker in a
  `fill` disc, the value semibold monospaced; strings untouched. Heart-rate aggregates → the
  receipt's `StatTile`s (new ids `historyAverageHR`, `historyMaxHR`, `historyActiveCalories`,
  `historyTotalCalories`; the Section keeps `historyHeartRateSection`) — WITHOUT a header of its
  own: the chart card under it is titled "Heart rate" (it was two "Heart rate" headers in a row
  before), and the receipt lays its tiles out headerless too; the chart card was restyled in
  ticket 03. The load-type chip sits beside the equipment line, under the name, so the name
  keeps one line. "Add Exercise…" `.secondary`; the edited mark on the background.
- `ExerciseProgressView.swift`: accent `LineMark` (catmullRom) over an accent→clear
  `AreaMark` under the same points, accent `PointMark`s, `Hairline` grid, `secondary` axis
  labels; the manual `chartOverlay` drag and the row insets untouched (the tooltip test's
  normalized drag); rows on `Theme.card`; "Since first session" in `stat`, accent when ≥ 0;
  empty state → `EmptyState` with both existing strings (`progressEmpty` on the container).
- No new copy. `ContentUnavailableView` no longer used on these screens.

## Acceptance criteria

- Screenshots `05-history`, `05-calendar`, `05-detail`, `05-chart`, `05-detail-heart-rate`,
  `08-empty-history` reviewed by the user.
- Gates green: `HistoryCalendarUITests`, `ProgressChartUITests`, `ProgressChartTooltipUITests`,
  `HistoryEditingUITests`, `HeartRateSummaryUITests`; unit suite; full UI suite before merge;
  Codex clear.

## Verification (2026-09-10)

Gates on `ui-redesign-06`: `HistoryCalendarUITests` 3/3, `ProgressChartUITests` 2/2,
`ProgressChartTooltipUITests` 2/2, `HistoryEditingUITests` 4/4, `HeartRateSummaryUITests` 2/2,
`RedesignScreenshotUITests` test05_history + test05_historyHeartRate + test08_emptyStates — 16/16;
HistoryEditing + HeartRateSummary + the two history captures re-run after the header/chip
tidy-up, 7/7. Screenshots `screenshots/06/` — sent to the user. Full suite: see STATE.
