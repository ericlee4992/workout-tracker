# 03 — Finish summary: status ring, tiles, zone bar, chart card

Status: built 2026-09-10 on `ui-redesign-03` — Codex rounds 1–3 answered, awaiting round 4

Spec: `.scratch/ui-redesign/spec.md` ticket 03, on the chosen Ink / Amber system.

## What changed

- `WorkoutFinishedSheet.swift`: the receipt opens on an 84 pt status ring — full amber with a
  tick for a saved workout, empty grey with a tray for a discarded one — beside "Workout saved"
  (`stat` font) and the unchanged summary line (`finishedSummary`). View in History is a
  `.primary` button, Save as Template `.secondary`. Every figure is a `StatTile` (Codex's
  component) in a two-column grid: time, active/total calories, average and max heart rate,
  total volume — the last two were plain rows before (new ids `summaryMaxHR`, `summaryVolume`);
  the four existing ids and their combined "title, value unit" labels are unchanged. "Time in
  zones" is a card with a stacked bar (each zone's share of the workout in its colour) over the
  per-zone durations. Exercise lines are cards with the set count and best set in amber. List
  rows cleared, `SurfaceBackground` behind. No new copy.
- `Features/Design/ZoneColors.swift`: `HeartRateZone.color`, shared by the live bar (which lost
  its private switch), the zone bar and, later, History.
- `HeartRateSummarySection.swift` (shared with History detail): the section's content is a
  card; bars are an amber→red gradient; the time gridlines use `Hairline`; the average caption
  `Danger`. Shape, axes, ids unchanged (Apple-Fitness shape, D-finish-graph).

## Acceptance criteria

- Screenshots `03-finish-summary` (and the heart-rate fixture's `finish-heart-rate`) reviewed
  by the user.
- Gates green: HeartRate, HeartRateSummary, CoreLoop finish tests; unit suite; full UI suite
  before merge; Codex clear.

## Verification (2026-09-10)

`HeartRateSummaryUITests` 3/3, `HeartRateUITests` 5/5, CoreLoop's two finish tests, the
`RedesignScreenshotUITests` finish flow — green. One test changed: the receipt test now scrolls
to the heart-rate chart (a lazy `List` does not materialise a row below the fold; the tiles are
above it now). `StatTile` was tightened (symbol + label on one line) so the chart's top edge is
in the first screen. Screenshots: `screenshots/03/` — sent to the user.

## Codex review 03 — response (2026-09-10)

`codex-review-03.md`: one P2, one P3; D44/D52/copy/History/shared-tile checks clear.

- **P2, zone bar widths could overflow the card** (per-segment `max(4, share − 2)` ignored the
  gaps and the minimums' cost). The arithmetic is now `Domain/ZoneBarLayout.widths(values:width:gap:minimum:)`,
  pure: widths sum to width − gaps, every visible zone keeps a 4 pt minimum, and the minimums are
  paid by the largest segments; an unaffordable minimum collapses to an even split.
  `ZoneBarLayoutTests` pins one zone, proportional shares, `[3599, 1]`, `[3595, 1, 1, 1, 1, 1]`
  (Codex's cases), the unaffordable case, and empty/degenerate inputs.
- **P3, the receipt test's scroll stopped at the chart's top edge.** It now scrolls until the
  average caption UNDER the chart is hittable (bounded), so the `finish-heart-rate` shot holds the
  whole chart; then it scrolls back until View in History is hittable before tapping it.
- Also taken: assertions for `summaryMaxHR` and `summaryVolume` in that test; `StatTile` labels
  may wrap to two lines (AXL); a new `test03_finishSummaryLargeText` captures the receipt at
  `UICTContentSizeCategoryAccessibilityL` (`redesign-03-finish-summary-axl`).
- Noted for ticket 06: the chart card's 16 pt inset differs from History's stock grouped rows
  until History is restyled.

## Codex review 03b — response (2026-09-10)

`codex-review-03b.md`: one P2, one P3; the round-1 chart finding closed.

- **P2, zero width returned an empty array and the card's subscript would trap.**
  `ZoneBarLayout.widths` now returns one width per value ALWAYS — zeros when width ≤ 0, zeros when
  the gaps alone exceed the width — and the card guards the subscript anyway
  (`index < widths.count ? widths[index] : 0`). Tests: `[10]` at 0 → `[0]`, negative width, six
  zones at width 5 → six zeros, and a 2,000-case sweep pinning cardinality and `0 ≤ w ≤ width`.
  The unaffordable-minimum test's diagnostic now says what it means (4 shared four ways).
- **P3, the AXL capture showed only the first tile row.** `test03_finishSummaryLargeText` now
  scrolls (bounded) until `summaryVolume` — the last tile — is hittable and captures again
  (`03-finish-summary-axl-2.png`): all six tiles at AccessibilityL, the BPM values included.

## Codex review 03c — response (2026-09-10)

`codex-review-03c.md`: the round-2 P2 closed (Codex re-ran the helper on the sweep's 2,000
cases); one P3 — the AXL values still truncated ("126 B…").

- **P3, BPM values truncated at AccessibilityL.** The tile grid is now ONE column at
  accessibility sizes (`dynamicTypeSize.isAccessibilitySize`), two otherwise; the recapture
  (`03-finish-summary-axl-2.png`) shows "126 BPM" and "151 BPM" whole. While there: the chart's
  three clock labels collided at that size, so only the first is labelled at accessibility
  sizes (the separators stay). Both flows re-run green.
