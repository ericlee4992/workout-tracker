# Claude visual review 01 — cardio, direction B

Reviewer: Claude (T6; Codex implemented). Date: 2026-09-18.
Source: frozen `d0bcb54`. Captures: 21 native PNGs (1206×2622) in
`cardio-implementation/work-record/cardio/screenshots/`, produced by `focused-ui-5`
(7 tests, 0 failures, exit file `0`, verified read-only). I viewed every image. No build,
simulator or product edit by me.

Graded against `ios-design/REVIEW.md` items 1–12 and the B design contract in
`issues/01-implementation.md` (timer is the hero, Pause is the one primary, metric pairs,
route or source row, Pause/End, then Add Exercise/Add Cardio; at AccessibilityL metrics and
controls stack).

All data in the captures is fixture or test-entered. "2.40 mi in 13 s" and the seeded Central
Park route are not measurement, accuracy, GPS or AirPods evidence.

## Verdict

| Gate | State |
|---|---|
| Visual review | **NOT CLEAR** — one Medium of mine (V1) plus the author's three acknowledged defects, all needing recapture |
| Composition against B | Matches the contract at default size for indoor; see A1 for AXL and outdoor |
| Record (item 12) | **Incomplete** — captures are untracked and unlinked; three contract states have no capture (V6) |

## Author-acknowledged defects (not re-investigated, recapture required)

- **A1 — Pause/End below the first viewport** at AccessibilityL (`live-axl`, `outdoor-axl`)
  and on outdoor at default size (`outdoor-default`, `route-default`). This fails item 2: the
  contract puts the primary recording control above the fold. Pinning Pause/End in the
  safe-area inset is the right shape. When recapturing, check the pinned bar does not cover the
  distance row or the last metric, and that the AXL stack (Pause over End) still fits.
- **A2 — "Location unavailable. You can enter distance manually."** shown under a drawn route
  with a GPS distance (`outdoor-default`, `route-default`, `route-axl`). Contradictory on screen;
  fixture-path bug per the author.
- **A3 — route stroke blue** in `route-axl`. `Theme.accent` is `Color.accentColor`
  (`Theme.swift:5`), so the map inherits whatever tint the environment resolves. See V1, which
  looks like the same root cause with a worse symptom.

## Findings

### V1 (Medium) — the saved route is almost invisible in History

`history-route-default` and `history-route-axl`: the polyline renders as a pale, washed-out
grey-green line against the park, nothing like the amber line in the live view. The route is
the only content of that map, and History is where the user goes to see it. Likely the same
`Color.accentColor` resolution issue as A3 (dimmed or overridden tint inside the card). Fix with
the explicit asset colour and verify contrast of the stroke against both the park green and
the street grey; recapture live and History at both sizes.

### V2 (Low, item 6) — amber activity icons are decoration, and inconsistent

The picker rows (`picker-default`, `picker-axl`) and every summary card (`summary-default-1`,
`summary-axl-2`, `mixed-history`, `manual-finish`, `history-route-*`) tint the activity symbol
amber; the live view shows the same symbol in white. Amber is reserved for the bold element
and states. These are inherited button/label tints, not decisions. Set the symbols to the text
or secondary colour, or record a deliberate exception in the ticket's tells.

### V3 (Low, items 4 and 9) — header repeats the hero in a cardio-only workout, and the title truncates at AXL

- `live-axl`, `outdoor-axl`, `controls-axl`, `route-axl`: the nav title truncates to "Indoor…"
  and "Outdoo…" while the full activity name sits directly below. Item 9 asks that nothing the
  wireframe names is truncated; the workout name is the first line of the wireframe.
- In a cardio-first workout the header timer and the hero timer show the same quantity one
  second apart (`outdoor-default` 5:04 over 5:03). At AXL the header figure is nearly hero
  size, so the screen reads as two heroes. The spec requires whole-workout time in the header,
  so this is a judgement: consider demoting the header timer's size at AXL or labelling it.

### V4 (Low, item 3/consistency) — "Lifting" and "Cardio" section headers use different styles in History

`mixed-history`: "Lifting" is a white headline row; "Cardio" is the grey section-header style.
They are peers and should look like peers. The receipt (`manual-finish`) already renders both
in the same grey style.

### V5 (Low, item 9) — Add Exercise / Add by Machine stay side by side at AXL

`controls-axl`, `route-axl`: both labels wrap to two lines with the icon stranded on the first
line, directly under the correctly stacked Pause/End. This row pre-dates cardio, but the new
screen makes the contrast obvious. Stack it at accessibility sizes or record it as accepted.

### V6 (Medium for the record, item 12) — contract states with no capture

The design contract names states that no image shows, at either size:

- **Paused** ("Resume leads"): no capture of the Resume primary or the "Paused" label.
- **Lifting focus with cardio running**: the new banner row ("Indoor Run … Recording") added
  in this commit has never been captured.
- **Distance editor** and the picker's **"ends the current cardio segment"** note.

Also, the `screenshots/` folder is untracked and the ticket does not link it. Commit the
captures with the ticket update so the evidence is part of the record.

### V7 (Low, copy/format — judgement)

- `manual-finish`: the receipt subtitle wraps as "1 exercise · 1 set · 1" / "cardio activity",
  orphaning the count from its noun at default size.
- History header duration ("29s", "5 min") and the cardio card ("0:13", "5:07") use different
  formats for nearly the same quantity on one screen.
- `live-default`: "Average pace 0:05 /mi" beside "Current pace: 11:45 /mi". Here it is test
  data, but the same contradiction appears for a real user who enters a machine distance while
  a sensor keeps reporting pace. Consider hiding current pace while an entered distance is in
  force, or labelling its source.

## Checklist results

| # | Item | Result |
|---|---|---|
| 1 | Bold element | Pass. Pause is the only accent fill on the live screen; Start Lifting on Start; View in History on the receipt. Ring and selected tab are state uses |
| 2 | Placement | **Fail at AXL and outdoor default** (A1). Pass for indoor default: every wireframe block is in the first viewport, in order |
| 3 | Grouping | Pass. Summary card holds a group; live metrics are an ungrouped peer grid as the contract specifies; no card in a card. V4 is a consistency note |
| 4 | Figures | Pass with V3 judgement. One hero (segment timer); metrics are stat size; labels smaller than figures |
| 5 | Type | Pass. No `.system(size:)`, no Light weights in `Features/Cardio/` |
| 6 | Colour | **Findings** V1, V2, A3. Heart rate red is a meaning use |
| 7 | Controls | Pass. One primary; Pause and End are equal size; End Cardio is not destructive-primary; segmented picker native; 44 pt rows. V5 noted |
| 8 | Lists, sheets, tab bar | Pass. Picker keeps Cancel; receipt keeps Done; tabs only navigate |
| 9 | Dynamic Type | Metrics and Pause/End stack correctly, same fixture and state as default. **Findings** V3 truncation, V5, A1 |
| 10 | Motion | Pass. No animation added in `Features/Cardio/` |
| 11 | Copy | "Start Empty Workout" became "Start Lifting" with the identifier preserved, recorded in the spec. New strings are covered by the spec's flow. Pass |
| 12 | Record | **Incomplete** (V6) |

## What works

The indoor default live screen delivers B as drawn: timer leads, one amber Pause, paired
metrics, honest source row ("Entered distance", "GPS"), and both Add actions reachable. The
picker is one tap per activity with grouped Gym/Outdoors lists. The receipt and History keep
one workout with separate Lifting and Cardio sections, omit heart-rate tiles when no sensor
ran (`manual-finish`), and offer no template for a cardio-only workout. AXL stacks metrics to
one column without truncating any figure.

## Required before visual clearance

1. Fix A1, A2, A3 and V1; recapture live, route and History route at both sizes.
2. Add captures for the paused state, lifting focus with the cardio banner, the distance
   editor and the segment-ending picker note, at both sizes.
3. Resolve or record V2–V5 and V7 in the ticket's tells.
4. Commit the captures and link them from the ticket.
