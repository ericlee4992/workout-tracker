# 12 — Floodlight: Cardio (plain Floodlight)

Type: feature (part of [01](01-implement-redesign.md), area order item 3 — missed in the 02–10 sequence)
Status: in progress
Implementer: Claude. Reviewer: Codex.
Branch: `ericlee4992/redesign-floodlight-cardio` (scratch checkout `/tmp/wt-floodlight/cardio`), reset
2026-09-28 from `0fa6814` onto the ticket-11 tip `af30f66` (Codex clear) and force-pushed. Nothing merged to
`main`; nothing installed.

## User decisions

- **2026-09-28 (ticket 01):** "keep cardio plain floodlight" — the cardio area is restyled in plain Floodlight,
  not the Anatomy direction's cardio screen (D59).
- **2026-09-28 (asked in this session):**
  1. **Choose Cardio: select, then Start.** A tap selects a tile; nothing starts until the pinned
     "Start <activity>" capsule. The picker preselects the first unstarted planned target, else the activity
     done most recently; nothing is preselected while a segment records (one tap on an armed Start would end
     it). The search field goes (nine activities). Today a tap started the activity at once.
  2. **Outdoor GPS status only on a problem.** No signal line while fixes arrive (the September 19 removal of
     the redundant "GPS" caption stands); bars + the recorder's message while it waits ("Waiting for GPS…",
     "Allow location to record distance and your route.", "Precise Location is off. Route accuracy is
     limited."); the "Location unavailable." plate (with "Recording time continues.") when the location is
     denied or GPS fails. Not the prototype's always-on "GPS" line.
  3. **The distance ring is approved** (PROPOSED in the prototype): with no planned target and a distance, the
     ring counts toward the next mile / km ("1.47", "of 2 mi") and Time moves into the figures; with a target,
     the ring counts the target time ("12:40", "of 20:00"); with neither, a 60-second sweep around the clock.
  4. **The receipt keeps its distance edit** (the prototype dropped it): the receipt's cardio card keeps the
     tappable distance row that opens the Distance sheet.

Record these with ticket 12's line in D59's list.

## Scope

Reference: prototype captures 2026-09-28 in `../reference/prototype-cardio/{dark,light}/`
(`LOOKS=final APPEARANCE=dark|light AXL=1 SETTLE=5 scripts/capture.sh all … C01 C01:planned C01:replace C01:p2
C02 C02:p2 C02:planned C02:noCardio C02:cycle C02:met C02:manual C02:ended C02:ended+p2 C02:lifting C02:noMax C03
C04 C04:gpsLost C04:acquiring C05 C05:typed C05:invalid C05:km F02 F02:p2 H04 H04:p2 H04:p3`, dark then light).
Real code: `WorkoutTracker/Features/Cardio/` (ticket 11 moved it to Look tokens, layout unchanged), the live
workout's cardio focus (`ActiveWorkoutView`), the finish receipt (`WorkoutFinishedSheet`), the History detail
(`WorkoutDetailView`).

1. **C01 Choose Cardio** (sheet): Cancel · "Choose Cardio"; "Planned cardio" rows first when the workout has
   unstarted targets; **Gym** (six) and **Outdoors** (three) as a 3-column tile grid — each tile the activity
   disc, its name (two lines reserved), what was last done with it (distance, "3 days ago"-style label), and
   what it records (distance or GPS glyph, heart); the recording segment's tile carries the live dot. AX sizes:
   one tile per row. Pinned at the thumb: the consequence line while a segment records ("Starting another
   activity ends the current cardio segment.") over **Start <activity>** / "Start Cardio" (off until chosen).
2. **C02 live indoor cardio** (the cardio focus of the live workout; Lifting | Cardio switch unchanged): the
   activity disc + name + the status pill ("Recording" with the live dot); **the ring** (bold element; see
   decision 3; target met → the ring lit with a check at 12 o'clock); the figures in one hairline table (Time or
   Distance, current and average pace — or speed for cycles — and active calories); the heart-rate plate (the
   beating bpm, the zone meter and zone name — "Set up zones" without a maximum, opening Max Heart Rate — and the
   last six minutes as a zone-coloured trace once two minutes exist; "Waiting for heart-rate data" while
   recording without a reading). Pinned tray: **Pause** (filled) · End Cardio.
3. **C03 paused:** the pill inverts to "Paused 0:42" (time since the pause); the ring's lit segments go hollow,
   the centre goes secondary with a pause glyph over it (blinks; steady under Reduce Motion); the tray's filled
   command is **Resume**.
4. **C04 outdoor:** as C02 with decision 2's status; GPS lost stalls a distance ring at a slashed pin (the
   clock runs on). **No map during the workout** (unchanged rule).
5. **C05 Distance** (sheet, medium/large detents): Cancel · "Distance" · Save; the segment line ("Indoor Run ·
   12:40"); one big number field ("—" when blank), the unit as pills (km | mi — relabels, never converts);
   the invalid-entry line; **Average pace / speed** updating as you type; **Measured** (tap to use it, a check
   when the field is blank) when the segment has a measured distance.
6. **Ended segments** in the live cardio focus: a card per ended segment — disc, name, the active time as the
   card's figure ("20:05 of 20:00" with a target), a small done ring (lit with a check when the target was met);
   the figures as a hairline table; Distance ("Entered distance" once typed) opens C05. Planned target not yet
   started, in the cardio focus with nothing recording: the empty target ring with its Start capsule and the
   quiet facts (last time this activity was done; lifting so far). Nothing at all: the empty state with Add
   Cardio.
7. **The receipt's cardio card** (F02): disc, name and start time; the route (outdoor, after Finish) as a
   greyed map snapshot with the route drawn per GPS portion, start dot and finish ring; the figures on a
   3-column grid (Distance · Time · Average pace/speed, then Avg. heart rate · Active calories); **Splits** as
   bars when there are two or more; the distance row (decision 4).
8. **History:** the cardio card in a mixed workout (figures + the distance row); the **cardio-only detail (H04)**
   — the hero: the route map (larger, with a marker per mile / km) or the activity disc, the distance as the
   hero figure (editable), Time and pace/speed beside it; the tiles without workout time; **Splits**.

Kept rules: explicit cardio Start (D57 targets and now the picker), D52 plain numbers, no visible distance-source
or estimate captions (the source is spoken only; "Entered distance" is the one visible provenance, as today),
manual distance for indoor cardio only when nothing measured it or it was typed (September 19), outdoor live has
no distance editor, "Location unavailable.", routes only after Finish / in History, the recorder and fixtures'
behaviour, the September 19 cardio decisions in D54 (now D59).

## Screen jobs, bold element (ios-design steps 1–2)

- **C01:** exists so the user can choose an activity and start it with the Start capsule; the eye lands on the
  tiles, the thumb on Start (the bold element, at the thumb). Runner-up: the planned row, demoted to a row.
- **C02 recording:** exists so the user can glance at the segment's progress; the eye lands on the ring's centre
  (time, or distance on a distance ring). Runner-up: the figures (stat numbers, smaller). The thumb's one filled
  command is Pause.
- **C03 paused:** exists to say it is NOT recording and to resume in one tap; the eye lands on the inverted
  "Paused 0:42" pill and the hollow ring; Resume is the filled command.
- **C04 GPS lost:** exists to say distance has stopped while time continues; the eye lands on the
  "Location unavailable." plate under the ring.
- **C05:** exists so the user can type the machine's distance; the eye lands on the big number; Save commits.
- **Receipt / History cardio card:** exists to show the result; the eye lands on the route (outdoor) or the
  figures. **H04:** the route map, then the distance figure (hero number).

Wireframe (C02, indoor run with a 20-min target, default size):

```
┌──────────────────────────────────────────────┐
│ ⌄        Push Day ✎                  Finish  │  live chrome (unchanged)
│ Iron Temple · 18:42                          │  header line, vitals (unchanged)
│ [ Lifting | Cardio ]                         │  focus switch (unchanged)
│ (◉) Indoor Run                 (• Recording) │  disc · name · status pill
│            ╭──────────────╮                  │
│           ╱  ▮▮▮▮▮▮▮▯▯▯▯   ╲                 │  THE RING (largest block, ~236 pt)
│          │     12:40        │                │   centre: the hero figure
│          │    of 20:00      │                │
│           ╲                ╱                 │
│ ┌─────────────────┬──────────────────┐       │  figures: hairline table
│ │ Distance ✎ 1.47 mi │ Current pace 8:12 │   │   (stat numbers)
│ ├─────────────────┼──────────────────┤       │
│ │ Average pace 8:36 │ Active calories 142│   │
│ └─────────────────┴──────────────────┘       │
│ ♥ 148 bpm ▬▬▬▬ Zone 3        ~~trace~~       │  heart-rate plate
│ ┌──────────────────────────────────────┐     │
│ │ [ ⏸ Pause          ] [ ■ End Cardio ] │     │  pinned tray (Pause filled)
│ └──────────────────────────────────────┘     │
└──────────────────────────────────────────────┘
```

## Prototype features the real app lacked (approved with the prototype unless noted)

- C01: tiles with last done distance/when and the records glyphs; select + Start (decision 1); planned row;
  default choice. Dropped: the search field.
- C02–C04: the ring and its three modes (decision 3 for distance), target-met check, the status pill with the
  pause duration, the current-pace figure as a table cell ("—" when stale; today a footnote line), the heart-rate
  plate with trace and zone meter, "Set up zones", the stalled ring, the GPS-lost plate's second line
  "Recording time continues." (the recorder's GPS-failure message already says it), the ended-segment card with
  the done ring, the planned-target hero with "Last <activity>" and "Lifting N/M sets" facts, haptics (target
  met, each split, Pause, End).
- C05: the big field, the live pace/speed readout, the Measured row as a choice. Removed: the instruction
  footnote ("Enter the machine’s distance. Clear it to use the measured distance.") — the copy policy.
- Receipt / History: the snapshot route map (greyed, drawn route, markers), Splits, the cardio-only hero.
- Not ported: prototype capture helpers (`CardioVariants`, `CardioPauseLedger`, tapping the GPS line to
  simulate a loss).

Kept from today where the prototype differs (not a user decision; open to veto): Save on C05 stays off until
the value or unit changes (the prototype kept it always on; an unchanged Save has nothing to record).

## Tells (ios-design step 4)

- Same container on everything: absent — the ring stands on the ground; the figures are one hairline table;
  the heart plate, the ended cards and the planned facts are panels because each is a group.
- Chips: absent (the status pill is a state, the zone a meter).
- All-caps: absent.
- Middle dots: deliberate — the planned fact values ("5.00 km · 28:40 · Sep 21") and the Distance sheet's
  segment line are frozen stat lines.
- Accent everywhere: absent — violet on the ring's current segment (the live thing), Pause / Resume and Start;
  the lit segments and the recording dot are the done colour (white / ink).
- Equal full-width blocks: absent — the ring leads; the table and the plate are smaller.
- Control dressed as primary: absent — Start (picker) and Pause (tray) are the one filled command per state;
  End Cardio and Add Cardio are quiet.
- Only survives default size: answered by AccessibilityL captures (the ring shrinks to 190 pt, tiles become
  rows, the finished figures one per row, the header's title leaves the bar).

## Implementation

- **Domain** `CardioReadout.swift` (pure, unit-tested in `CardioReadoutTests`): `CardioRingModel.make` (target →
  distance → sweep), `CardioReadout.pausedSeconds` / `activeSeconds(at:)` / `splits` (route distance scaled to the
  segment's distance, active time only, portions never joined) / `lastDone`, `CardioHeartTrace.points` (15-s buckets
  of the last six minutes), `CardioLocationStatus.of` (decision 2).
- **Views** `Features/Cardio/`: `CardioSupport` (formatting, the ring, disc, pulse, blink, GPS bars, the figures
  table, the tray's style), `CardioPicker` (C01; `CardioChoice` = an activity or a planned target),
  `CardioLive` (the cardio focus rows, the live block, status pill, heart plate and trace, ended card, planned
  hero, the tray `CardioControls`), `CardioDistanceSheet` (C05), `CardioCards` (receipt / History card, the
  cardio-only hero, Splits, the route snapshot `CardioRouteMap`). `CardioViews.swift` is gone.
- **Hosts:** the live screen hides its vitals strip and the "Cardio targets" list in cardio focus (the panel has
  its own plate and planned hero); the picker gets the recording activity and the startable targets; Home's picker
  starts `choice.activity`; History's cardio-only workout gets `CardioHistoryHero` + Splits and its tiles drop
  workout time; the receipt keeps `CardioSummaryCard`.
- **Fixture** `CardioDesignFixture` (UI-test stores only): `-uiTestCardioTarget` (+`-uiTestCardioTargetMet`),
  `-uiTestCardioPlanned`, `-uiTestCardioLost` (the recorder's location message under UI tests, where it collects
  no sensors), `-uiTestCardioSplits`.

## Strings

New (prototype): "Start <activity>", "Start Cardio", "Planned cardio", "Gym", "Outdoors", "Recording", "Paused" +
the pause time, "of 20:00", "of 2 km" (decision 3), "Current pace", "Current speed", "Time", "Entered distance"
(now also a figure label), "Waiting for heart-rate data" (was a footnote), "Set up zones", "Recording time
continues." (under "Location unavailable."), "Last <activity>", "Lifting", "N/M sets", "Measured", "Splits",
"Enter distance" (History hero), VoiceOver: "Records distance and heart rate", "Records a GPS route and heart rate",
", recording now", "Paused, for …", "target reached", "Edits the distance", "Uses the measured distance",
"Split N, 8:43 per km", "Last 0.30 km, …", "Recorded cardio route".
Removed: the picker's search ("Search activities"); the Distance sheet's "Measured: X" line (now the Measured row)
and "Enter the machine’s distance. Clear it to use the measured distance."; the live "Current pace: X /km" footnote
(now a figure); the zone capsule and the heart-rate source caption in cardio focus (the zone meter; the source is
the live strip's, hidden in cardio focus).
Unchanged: "Choose Cardio", "Starting another activity ends the current cardio segment.", "Location
unavailable.", the recorder's messages, "Add cardio to this workout", "Pause", "Resume", "End Cardio",
"Distance", "Save", "Cancel", "Average pace", "Average speed", "Avg. heart rate", "Active calories".

## Identifiers

Kept: `cardioActivity.<raw>`, `cardioTimer` (the ring when it counts time, else the Time figure),
`cardioDistanceMetric` (the ring when it counts distance, else the Distance figure), `cardioEditDistance`,
`cardioCurrentPace`, `cardioPauseResume`, `endCardio`, `cardioSummary.<raw>`, `cardioSummaryEditDistance`,
`cardioRoute`, `cardioDistanceField`, `saveCardioDistance`, `cardioDistanceUnit`, `startPlannedCardio`, `addCardio`,
`startCardio`, `workoutActivityFocus`. New: `startSelectedCardio`, `cardioPickerCancel`, `cardioPlanOption.<n>`,
`cardioStatus`, `cardioLocationStatus`, `cardioHeartRate`, `cardioMeasuredDistance`, `cardioSplits`.
Tests moved with the structure (CardioUITests, RedesignScreenshotUITests' unit-system flow): select + Start; figures
are single accessibility elements (label + value + unit), so value checks read labels; the unit pills are buttons;
Cancel is `cardioPickerCancel`.

## Verification

Runner `/tmp/wt-floodlight/cardio-run.sh <name> build|test …` (derived data `/tmp/wt-floodlight/dd-cardio`); logs,
`.exit` files and result bundles `/tmp/wt-floodlight/results/cardio-*`.

- Prototype captures: dark and light both exit 0, 56 each, every PNG has content (checked by histogram and by eye).
  In the prototype too the Simulator's route well sometimes shows the grid without map tiles (tiles load late).
- `cardio-build-1` (exit 65: `CardioChoice` not Hashable — `PlannedCardio` is only Equatable; hashed by id),
  `cardio-build-2` exit 0.
- `cardio-ui-1` (exit 65): `CardioReadoutTests` 9/9; `testFinishedDark` passed; `testLiveDark` failed on an
  over-exact assertion (the heart-rate fixture adds distance to the seeded 2.36 km; now "Distance 2.").
- `cardio-ui-2` (on `76eb6ae`; exit 65): unit `CardioReadoutTests`, `CardioTests`, `CardioRecorderTests` 27/27;
  UI 18/20 — `FloodlightCardioUITests` 7/8, `CardioUITests` 8/9, `RedesignScreenshotUITests` unit-system ×2,
  `AskAIUITests.testWeeklyRoutineDefault` (the planned Start from the lifting focus) passed. Failures, both test-side:
  the blank Distance field now reports its "—" prompt as its value; `testFinishedLightAccessibility` ran out of
  scroll steps before the lazy History list built Splits. `cardio-ui-3` exit 0: both 2/2 alone.
- Looked at every capture as a picture (light/dark × Default/AXL): fixed at AXL the figure labels breaking
  mid-word ("Dis-/tance": the glyph now drops at AX sizes), the Distance sheet's pace wrapping, split paces
  wrapping; the digit roll caught mid-frame (the capture-still flag now defaults on in UI-test stores).
- `cardio-ui-4` (on `2f43dae`; exit 65): **UI 18/19** — `CardioUITests` 9/9, `RedesignScreenshotUITests` unit-system
  2/2, `FloodlightCardioUITests` 7/8. `testFinishedDarkAccessibility` failed opening History, again alone
  (`cardio-ui-5`): at AccessibilityL the scroll left "View in History" under the receipt's pinned header and the tap
  hit Done (a test defect — the header is the receipt's, unchanged). The test now scrolls the link clear first;
  `cardio-ui-6` exit 0 (that case + `testLiveLightAccessibility`, 2/2).
- Distance sheet at AX: the readout row's title broke mid-word ("Aver-/age pace"); it now stacks title over figure.
  `cardio-ui-7` (on `40a3c79`) exit 0: the four `FloodlightCardioUITests` Live flows + the Distance editor case, 5/5.
- **Captures** `../captures/12/` (80): 20 states × light/dark × Default/AccessibilityL — Live flows from `cardio-ui-7`,
  Finished flows from `cardio-ui-4` (dark AXL from `cardio-ui-6`). Compared with the prototype side by side
  (`/tmp/wt-floodlight/results/cardio-sheets/compare-{dark,light}{,-axl}.png`).
- **Scope rationale** (DEVELOPMENT): a screen area restyled with behaviour changes (the picker's Start, the planned
  hero, hidden vitals in cardio focus, the cardio-only History hero) → its capture class and every flow that
  reaches cardio: `CardioUITests` (mixed workouts, manual distance, outdoor route, indoor motion, saved-distance
  editor), the unit-system flows (Home picker, the new cycle speed unit), the AI template's planned Start from the
  lifting focus; domain logic → `CardioReadoutTests` + the existing `CardioTests` / `CardioRecorderTests` (the
  recorder's UI-test location hook). Not run here: the full UI suite (the release-candidate pass after this ticket).
  Not exercised: VoiceOver by a person, Reduce Motion at runtime, real GPS / sensors, a real device.

## Progress

- 2026-09-28: resumed from STATE and ticket 01; the branch reset onto `af30f66` and force-pushed. Read ticket 11
  (workflow model), the ios-design skill, the prototype Cardio area and its Finish/History cardio pieces, the
  real cardio views, recorder, model and tests. Prototype captured (dark, light). User decisions 1–4. Ticket and
  references `db93ff4`; implementation `76eb6ae`; AX fixes `2f43dae`, `40a3c79`; captures (this commit). Next: Codex
  review 12 (`../codex-review-12-prompt.md`).
