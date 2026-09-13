# 06 — History: cards, the calendar, the detail, the progress chart

Status: resolved — Codex clear after 3 rounds (codex-review-06, 06b, 06c); unit 707/707; full UI suite 58/58 on `0d3614a`; merged to main 2026-09-11

Spec: `work-record/ui-redesign/spec.md` ticket 06, on the chosen Ink / Amber system.

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
- `ExerciseProgressView.swift`: accent `LineMark` (**monotone**, see the Codex response) over an accent→clear
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

Gates on `ui-redesign-06`: `HistoryCalendarUITests` 2/2, `ProgressChartUITests` 2/2,
`ProgressChartTooltipUITests` 4/4, `HistoryEditingUITests` 2/2, `HeartRateSummaryUITests` 3/3,
`RedesignScreenshotUITests` test05_history + test05_historyHeartRate + test08_emptyStates — 16/16;
HistoryEditing + HeartRateSummary + the two history captures re-run after the header/chip
tidy-up, 7/7. After the Codex round-1 fixes: HistoryCalendar, ProgressChart, Tooltip,
HistoryEditing + test05_history + test05_historyLargeText 12/12; after the AXL layout fix:
HistoryEditing + the two captures 4/4. Screenshots `screenshots/06/` — sent to the user.
Full suite: see STATE.

## Codex review 06 — response (2026-09-10)

`codex-review-06.md`: two P2s, one P3, one verification ask; everything else clear.

- **P2, Catmull-Rom can invent extrema** (a hump between equal neighbours; on an assisted
  series that reads as an improvement nobody logged). Both marks are back on `.monotone` — a
  documented deviation from the plan's "catmullRom": the chart must never be more confident than
  the data (D9/D25).
- **P2, the future-workout day was 2:1 against the card; the marked-today ring 1.6:1 against
  amber.** A future workout day is now a hollow accent ring with full-contrast numerals
  (`Theme.text`), distinct from a past workout (filled disc) and from today (grey ring). Every
  ring is now drawn 2 pt OUTSIDE the disc, so its neighbours are the card and a gap, never the
  amber interior; the marked-today ring is `Theme.secondary` like the plain today ring.
- **P3, the name/gym/duration section was not on `Theme.card`** — the modifier had not landed
  (an unasserted replace); it is there now, with the hairline separator.
- **Verification ask, AccessibilityL**: `test05_historyLargeText` captures the list and a
  detail at AccessibilityL (`05-history-axl`, `05-detail-axl`). The first capture showed exactly
  the risk: "Seated Che…" in the row, "equip-ment" / "Weight ed" in the header. Now, at
  accessibility sizes, the day tile sits ABOVE the row's text (`AnyLayout`, title may wrap to
  three lines) and the equipment line and chip stack; the chip never breaks mid-word
  (`fixedSize`). The day tile is minimum-sized, not fixed, so it grows with its text.
  Recaptured: every string whole.
- Also: the icon comment says glyph AND colour follow the live exercise; the gate counts above
  corrected to what the result bundle says (16 tests: 2+2+4+2+3+3).

## Codex review 06b — response (2026-09-11)

`codex-review-06b.md`: the round-1 P2s and P3 closed (contrast re-derived from the assets:
future-day numerals 15.6:1, accent ring 9.8:1, grey rings 8.8:1); one new P3.

- **P3, a ring painted 2 pt outside the cell overlaps its neighbour on a 375 pt phone** (the
  seven columns have no horizontal spacing: 44.4 pt each, a 48 pt ring). Rings are back INSIDE
  the 40 pt cell (`strokeBorder`, no negative padding); under a ring the disc is inset 4 pt, so
  the 2 pt gap of card between amber and ring is kept and nothing is painted beyond the cell.
  `HistoryCalendarUITests` 2/2 + the calendar capture re-run.

## Codex review 06c — response (2026-09-11)

`codex-review-06c.md`: **clear** — the ring is confined to the cell (≈ 4.4 pt between
neighbours at 375 pt), the inset disc keeps its 2 pt card gap and the verified contrast. Codex
notes a marked-today AccessibilityL capture would be the only way to PROVE two-digit numerals fit
the 32 pt inset disc; the text frame is unchanged from before the redesign, and no fixture puts
a workout on today — left as noted, not built.
