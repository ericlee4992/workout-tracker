# Claude visual review 02 — cardio, direction B (final captures)

Reviewer: Claude (T6; Codex implemented). Date: 2026-09-18.
Product source `03ada3d`; test source `306acf4`; evidence commit `3e05c89` (no product or
test paths changed after `306acf4`, verified by diff). Captures: 29 native PNGs in
`cardio-implementation/work-record/cardio/screenshots/final/`, produced by `focused-ui-6`
(7 tests, 0 failures, exit file `0`, verified read-only). I viewed all 29. No build, simulator
or product edit by me.

Graded against `claude-visual-01.md` (A1–A3, V1–V7) and `ios-design/REVIEW.md` items 1–12.
All data shown is fixture or test-entered; the Central Park route is seeded. None of it is
measurement, GPS or AirPods evidence.

## Verdict

| Gate | State |
|---|---|
| **Visual review** | **CLEAR** — no blocking finding; four Low notes (W1–W4) to record in the ticket |
| Code review | Clear at `03ada3d` (`claude-review-03.md`) |
| Full local UI suite (`full-ui-2`, 79) | **RUNNING** under PID 64009 per author; not assessed |
| Merge clearance | **NOT GIVEN** until the full suite's actual exit code and counts are in |
| Real-device acceptance | **OUTSTANDING** — AirPods treadmill distance, background GPS; Watch cardio not claimed |

## Visual-01 items

| Item | Result | Evidence |
|---|---|---|
| A1 Pause/End below the fold | **Fixed.** Pinned in the bottom inset, first viewport at both sizes, stacked at AccessibilityL | `live-*`, `outdoor-*`, `paused-*`, `controls-*`, `route-*` |
| A2 "Location unavailable" under a drawn route | **Fixed.** Message gone; source row reads "GPS 0.67 km" | `route-default`, `route-axl` |
| A3 blue route stroke | **Fixed.** Amber at both sizes | `route-axl` |
| V1 route invisible in History | **Fixed.** Solid amber line, legible on park green and street grey | `history-route-default`, `history-route-axl` |
| V2 decorative amber icons | **Fixed.** Neutral in picker rows and summary cards | `picker-*`, `replace-picker-*`, `summary-*`, `mixed-history`, `manual-finish` |
| V3 title truncation / header timer | **Recorded exception** in the ticket. Still visible at AccessibilityL ("Indoor…", "Outdoo…"). The paused pair now shows why the header timer exists: 0:30 workout over 0:28 paused segment |
| V4 Lifting/Cardio header styles | **Recorded exception.** Unchanged in `mixed-history` |
| V5 Add buttons at AccessibilityL | **Fixed.** Stacked full-width | `controls-axl`, `route-axl`, `lifting-banner-axl` |
| V6 missing states | **Fixed.** Paused, lifting banner, editor and replacement picker each captured at both sizes; captures committed with a gallery |
| V7 contradictory pace under entered distance | **Fixed.** No sensor pace line while "Entered distance" is in force | `live-default`, `controls-default` |

## New Low notes (none blocking)

- **W1 — scroll content shows around the floating control card.** The card has no backdrop, so
  clipped content peeks above and below it: a metric label cut at the card's top edge and a
  fragment of the next value under it (`live-axl` "Heart rate" / "8 cal", `paused-axl`), and at
  default size the Add Exercise / Add by Machine row appears half-hidden beneath the card
  (`outdoor-default`, `route-default`). I agree with the author that nothing is permanently
  obscured: the list respects the inset and `controls-*`/`route-*` show every row reachable.
  It does read as a layering glitch at rest. A background that runs from the card's top to the
  screen bottom (material or the page colour with a short fade) would remove it. Judgement.
- **W2 — the lifting-side cardio row has no affordance.** "Indoor Run … Recording" is a
  tappable row that switches focus, but it looks like a static caption (`lifting-banner-*`).
  A chevron or the segment time would signal it. It also offers no way to pause from Lifting
  focus, which is consistent with B. Judgement.
- **W3 — single-line card in the replacement picker.** "Starting another activity ends the
  current cardio segment." sits alone in a card (`replace-picker-*`), which item 3 discourages.
  As a list footer or plain caption it would carry the same consequence. Judgement.
- **W4 — pre-existing header wrap at AccessibilityL.** In Lifting focus the gym chip wraps to
  "No / gym" and the set counter to "0/0 / sets" (`lifting-banner-axl`). This header pre-dates
  cardio and is outside this ticket; noted so it is not attributed to it later.

Carried from visual-01 V7 and still true, all Low and outside the blocking set: the receipt
subtitle orphans "1" from "cardio activity" (`manual-finish`), and History shows "39s" beside a
card time of "0:22" in a different format (`mixed-history`).

## Checklist results

| # | Item | Result |
|---|---|---|
| 1 | Bold element | Pass. Pause or Resume is the only accent fill in Cardio focus; Add Exercise in Lifting focus; Start Lifting on Start; View in History on the receipt |
| 2 | Placement | Pass. Timer at the eye, Pause/Resume at the thumb, in the first viewport at both sizes and outdoors |
| 3 | Grouping | Pass, with W3 as a judgement |
| 4 | Figures | Pass. One hero per screen; V3 header-size judgement recorded as an exception |
| 5 | Type | Pass. No `.system(size:)` or Light weights in `Features/Cardio/` |
| 6 | Colour | Pass. Amber only on the primary, states and the route line (a deliberate content accent); red only for heart rate |
| 7 | Controls | Pass. One primary, Pause and End equal size, 44 pt rows, native segmented pickers, editor Save disabled until changed |
| 8 | Lists, sheets, tab bar | Pass. Picker and editor keep Cancel; receipt keeps Done; tabs only navigate |
| 9 | Dynamic Type | Pass. Same fixtures and states at both sizes; metrics, Pause/End and Add buttons stack; no figure truncated. V3 title truncation is a recorded native-chrome exception; W4 is pre-existing |
| 10 | Motion | Pass. No animation added |
| 11 | Copy | Pass. Identifiers preserved; new strings follow the spec's flow |
| 12 | Record | Pass. Ticket carries the contract, tells, exceptions, gate counts, and both capture sets with a gallery; first-round captures preserved under `screenshots/review-01/` |

## Limitations

Simulator captures with fixture data only. I did not run the app. The full UI suite was still
running. Nothing here speaks to real sensor delivery, GPS quality or background behaviour.

## Remaining before merge clearance

1. `full-ui-2` actual exit code and counts on the frozen sources, recorded in the ticket.
2. W1–W4 and the two carried copy notes recorded in the ticket as accepted Low items or fixed.
3. STATE and ticket keep AirPods treadmill and background GPS acceptance listed as outstanding,
   and no phone install happens without the migration and backup steps in DEVELOPMENT.
