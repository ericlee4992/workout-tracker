# 01 — Progress charts (milestone 4, brought here)

Status: open
Blocked by: 02, 03 — a chart of mis-typed or un-correctable data is a confident picture of the
wrong thing.
Covers user ask **1**.

## What to build

Swift Charts. No third-party dependencies (SPEC).

- **Per-exercise progression** over time: best set, estimated 1RM where the load type allows one,
  and volume.
- **Normalized axes, as-entered tooltips.** This is the milestone-4 line from the original plan and
  it is D9/D25 restated: plot in `normalizedKg` so a session logged in lb and one in kg sit on one
  axis, but show the user the number they actually typed, marked `≈` if converted.
- **Respect `loadType`.** Assisted is *lower is better* — its progression line goes DOWN as the
  user gets stronger. A chart that draws it as decline is worse than no chart. Label the axis so
  the direction is unmistakable.
- **Exclude warmups** from volume and PR series, as `RecordsMath` already does.
- **Empty and thin states.** One data point is not a trend; say so rather than drawing a line
  between two dots and implying a slope.

## Acceptance criteria

- A per-exercise chart renders from real history with no crash on: zero sets, one set, one
  session, and mixed units.
- Assisted exercises are drawn and labelled so that improvement reads as improvement.
- Warmups are excluded from volume/PR series; a test pins it.
- Chart series derive from the same `RecordsMath` helpers as the records screen — not a second,
  parallel implementation that can disagree with it.
- Unit tests for the series-building logic (pure, `Domain/`, no UI import).
- UI test renders the chart screen and screenshots it (the user prefers seeing the UI).

## Notes

Series-building is pure logic and belongs in `Domain/`, testable without a view. If it stays in the
view it cannot be proven, and "the chart looked right on my machine" is what this project's
process exists to refuse.
