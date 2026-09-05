# Finish graph and plain numbers

Two asks from the user, 2026-09-04 (evening), from the first real workout on the milestone-9 build
(66:51, 386 active cal, avg 122, max 141). Screenshots: the app's finish sheet beside Apple
Fitness's workout detail for a 2026-08-20 strength session.

## What was asked, verbatim

1. "The heart rate graph at the end of the workout looks messy. It should look clean like the one
   from Apple Fitness. … Just replicate its graph shape."
2. "when it displays total volume it uses the wavy equal sign. Don't use that; just show number. In
   fact there are other places that use this or use the word 'estimated'. Just get rid of any of
   those."

Then: "Run Codex review after for cross-review."

## What the two screenshots show

**Ours:** 15 s buckets drawn as filled bars from 0 BPM to the mean, red gradient, on a 0–150 axis
with four horizontal gridlines, dashed vertical gridlines at 0:00 / 16:40 / 33:20 / 50:00 elapsed,
a dashed average rule with an "avg 122" annotation over the bars, and a ~17-minute gap in the
middle (a sensor outage — the AirPods case, most likely). 268 buckets in ~330 pt means the bars
fuse into a solid red block with a serrated top edge. That is the "messy".

**Apple's:** thin vertical range bars, one per interval, each spanning that interval's LOW to HIGH
bpm and FLOATING — nothing is drawn down to zero. The y range is the series' own (75 at the bottom
right, 159 at the top right, no other axis labels, no horizontal gridlines). Three faint vertical
separators carry clock times (18:29, 18:48, 19:07). Under the plot: "112 BPM AVG" in the accent
colour. No average rule, no annotation.

## What the shape needs that the data does not have

The stored series (`Workout.heartRateSeries`, milestone 9) is the MEAN per 15 s bucket. A range
bar needs the bucket's low and high. Two honest options, and the one taken:

- Draw a tick at the mean. Honest, but it is a dotted line, not Apple's shape.
- **Store low and high per bucket too** (two more `[Int]` on `Workout`, same fold, same export
  rules), and draw them. Workouts finished before this build have only the mean; for those the
  chart draws a bar from the min to the max of the MEANS inside each display slot (see ticket
  01) — a real range of real numbers, narrower than the sample range, never invented.

Display density is a separate problem from storage: a 67-minute workout has 268 buckets and the
plot is ~330 pt wide. Apple's bars are ~2 pt with a gap. So the chart merges adjacent buckets into
at most ~110 display slots (low = min of lows, high = max of highs) — pure logic in Domain, tested.

## Decisions this reopens

Ask 2 removes the two honesty marks the decision log is proudest of: the ≈ on converted weights
(D9/D25, and the CLAUDE.md convention line) and the "(estimated)" on zones from 220−age (D45).
That is the user's call to make and they made it plainly, twice ("just show number", "get rid of
any of those"). It is recorded as **D52**, reopening those decisions deliberately: the DATA keeps
its provenance (`isEstimated`, `zonesFromEstimatedMax`, the per-point `enteredUnits` /
`bestUnit` / `e1rmUnit`, export fields — nothing in a file changes), only the SCREEN stops saying
it. The cost is stated in D52 so nobody rediscovers it as a bug.

## Tickets

| # | Ticket | Touches |
|---|---|---|
| 01 | Apple-shaped heart-rate graph | Domain (fold + display slots), `Workout` (+2 optional arrays, export schema 9), the chart, both callers, a history fixture for screenshots |
| 02 | Remove ≈ and "estimated" from every screen | `Features/` copy + `WeightMath.displayLabel`, tests that asserted the marks, D52, SPEC/CLAUDE lines |

01 first: it is the one with a schema change, so its migration gate and Codex round should not be
mixed with copy edits. Each ticket is Codex-reviewed to "clear" before the next starts.
