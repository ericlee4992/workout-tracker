# 14 — Time in heart-rate zones in History

Status: in progress (branch `history-14-zone-times`, off ticket 13)

The user (2026-09-11): "In history I also want to be able to see time spent in hr zone, either
when you click the graph or just below the graph." → **just below the graph** — a glance, no
tap (the skill: every screen's job is a glance or a tap; a tap to reveal a number the workout
already holds is a tax).

## What exists

The finish sheet has shown "Time in zones" since milestone 9 — one stacked bar, each zone's share
in its colour, the durations beneath — from `Workout.zoneSeconds`. History's detail showed the
aggregates and the graph but never the zones, although every workout carries them.

## Step 1 — job, state

The History detail exists so the user can read what a past workout was — the job and the bold
element (nothing; it is a record) are unchanged. In the has-heart-rate state the eye lands on
the stat tiles, then the graph; the zones card follows the graph as the receipt's does.

## Built

- `Features/Design/ZoneTimeCard.swift` — the finish sheet's private `zoneCard` lifted out
  unchanged (title, bar, rows; each row now one accessibility element) and used by both.
- `WorkoutDetailView`: a section under the graph, only when any zone has time
  (`historyZoneCard`); cleared row background like the graph card (a card of a group: the bar
  and its rows). Nothing else moves.
- `HeartRateHistoryFixture` gains zone seconds (each 15 s bucket against a 185 max, pure
  `zoneSeconds(of:intervalSeconds:)`), so the seeded hour shows the card in captures and tests.

## Step 4 — tells

Inherited from ticket 06 (History) unchanged; the one addition is a card the receipt already
has, in the receipt's colours (zone colours carry their meaning). Middle dots: none added.
A card in a card: absent — a `Section` row on a cleared background.

## Gate tests

Unit: `HeartRateTests` / `HeartRateSummaryTests` (zones logic, untouched). UI:
`HeartRateSummaryUITests` (the hour-long history test now asserts the card, "Time in zones",
"Zone 2"), `RedesignScreenshotUITests` `test05_historyHeartRate` (+ zones capture) and
`test05_historyHeartRateLargeText` (new: the graph and the card at AXL), `HeartRateUITests`
(the finish sheet's card); then the full suite.

## Verification (2026-09-12)

Unit `HeartRateTests` + `HeartRateSeriesTests` 51/51; UI `HeartRateSummaryUITests` 3/3 (the
hour-long test asserts the card, "Time in zones", "Zone 2"), `HeartRateUITests` 5/5,
`test05_historyHeartRate` + `test05_historyHeartRateLargeText` 2/2 — 10/10. The first AXL capture
stopped with the card half under the tab bar (a half-hidden card is "hittable" — ticket 10's
lesson, again); the test now scrolls until "Zone 3" is on screen, 1/1. Captures
`screenshots/14-05-detail-heart-rate(-zones)(-axl).png`: the card whole at both sizes, three
zones for the seeded hour (32:30 / 15:30 / 10:45 against a 185 max).

## Codex review 14 — response (2026-09-12)

`codex-review-14.md`: ticket 13 round 2 **clear**; ticket 14 clear on items 1, 3, 6, 9, 11, 12
(two peer cards in the List; zone colours mean zones; `ZoneTimeCard` identical to the old card
but for the combined rows; History reads persisted `zoneSeconds`). One P3: the AXL capture test
looped for hittability and then asserted only existence — it now asserts the last row hittable
and clear of the tab bar (a frame check). The fixture's comment claimed five zones; corrected to
the three the series reaches (Codex recomputed the generator: 32:30 / 15:30 / 10:45). Rerun of
`test05_historyHeartRateLargeText`: see below.
