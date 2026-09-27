# 04 — Floodlight: the finish receipt

Type: feature (part of [01](01-implement-redesign.md))
Status: implemented and verified (targeted scope); Codex review pending (after ticket 03 clears)
Implementer: Claude. Reviewer: Codex.
Branch: `ericlee4992/redesign-floodlight-finish`, stacked on the live branch (ticket 03).

## Scope

`WorkoutFinishedSheet` in the approved receipt design (`reference/captures/*/F01-final.png`),
plain Floodlight (not the live Paper structure):

- Title "Nice work" (unchanged) · Done. Header (`FinishHeader`): the status ring — one segment
  per completed set in its muscle family's colour, in workout order, so it agrees with the set
  count — beside "Workout saved", "<template> · <gym>", "N exercises · M sets", and the family
  key (each family's map with its set count). "Nothing to save" keeps an empty ring and the
  reason (A2). AX sizes: ring above the text.
- Actions: View in History (filled) and Save as Template (outlined); after saving, the slot
  reads "Saved as template “<name>”" with a check (`FinishSavedTemplateLine`).
- Workout details: the tile grid (`FinishTileGrid`) — workout time, total volume, active and
  total calories, average and max heart rate; same values and conditions as before.
- **New bests** (new): one line per scope (exercise + equipment + variation, D36) with the
  workout's best set and, struck through, the best from BEFORE the workout.
- **Last <template>** (new): total volume of the template's previous finished run beside
  today's, with the change (`ComparisonBars`); only when both runs lifted something.
- Heart rate: the existing chart (shared with History, the approved Apple-Fitness shape) under
  a Floodlight "Heart rate" heading in a panel; time in zones directly below it (it was above).
- Cardio: the existing cards under a Floodlight heading (card restyle: the Cardio area).
- Exercises / Lifting: one row per exercise — name, "equipment · N sets", its best set
  (warmups out unless nothing else was logged), "NEW BEST" or "First time" mark.
- Domain: `FinishReceipt.build` (families, bests, rows, comparison — derived on read from the
  finished workout's snapshots; family reads the live `muscleGroup`, the documented exception);
  `SetBadgeMath.outcomes` (each mark with the incumbent it beat) and `workoutBest` (the
  receipt's line per scope); badge history is limited to sets completed before the workout
  started, so an old workout is judged against its own past; `SetValue` moved to Domain.
  The sheet builds the receipt once per saved workout (not per render) and
  `SetBadgeMath.receiptMarks` reads each scope's history once.

## Rules kept

Identifiers: `finishedDone`, `viewFinishedWorkout`, `saveAsTemplate`, `summaryExercise`,
`heartRateChart`, `heartRateAverageCaption`; template-drift dialog before the receipt; empty
finish discards and says so; save-as-template from the receipt; View in History opens the
workout just logged; no chart without a series; zones only with a basis.

## User decisions (2026-09-26)

- **New bests: one line per exercise, as in the prototype**, against the record from before the
  workout. "Exercise" here is the record scope (exercise + equipment + variation, D36): records
  never merge across machines, so the same exercise on two machines in one workout is two
  lines — each its own record. A first workout in a scope lists no best; its row says "First time".
- **Time in zones under the heart-rate chart: OK.**

## New / changed visible strings

New: "New bests", "Last <template>", "Today", the change badge ("↓ 70%"), "NEW BEST" /
"First time" on exercise rows, "Saved as template “<name>”" (was a label with the same words).
Changed: tile units "cal" / "bpm" (were "CAL" / "BPM"); section headings in Floodlight type.

## Not in this ticket

Heart-rate plate/zone restyle and the prototype's range chart (shared with History → History
ticket), cardio card restyle (Cardio area), the receipt's reveal motion.

## Tests

- New unit tests `FinishReceiptTests` (5): one best per scope against the pre-workout record,
  entries sharing a scope listed once, a later workout does not change an earlier receipt,
  first workout → no best + First time, comparison against the template's previous run.
- `SetBadgeTests` +3 (`workoutBest`, `outcomes` incumbents).
- New UI captures `FloodlightFinishUITests` (4: light/dark × Default/AXL, finishing the
  `-uiTestDesignLive` fixture and keeping the template on the drift dialog).

## Verification

Scope (DEVELOPMENT: the finish flow + new Domain rules): build; unit tests for the receipt and
badges; the finish-flow UI tests (empty finish, View in History, History template save from
the receipt and from History, heart-rate finishing summary, heart-rate summary chart, the
redesign screenshot finish tests, cardio capture + save); Default/AXL captures in light and dark.
Simulator WT-Floodlight (iOS 27.0).

- `finish-ui-1` (first cut, before the bests fix): 14/14 passed.
- `finish-unit-1`: `FinishReceiptTests` 5/5, `SetBadgeTests` 9/9, `NextSetTests` 6/6 — exit 0.
- `finish-ui-2` (after the bests fix and heart-rate heading; before the comparison-panel fix):
  exit 65 — UI 15/16 passed; the one failure is the **pre-existing**
  `HeartRateSummaryUITests.testFinishShowsTheChartAndHistoryShowsItAgain` at `:66` (History
  detail's heart-rate section, identical on main a0364f2 `base-5.log`); its finish-sheet part
  (chart on the receipt, View in History reachable) passed. Unit: 14/14 (`FinishReceiptTests`
  5, `SetBadgeTests` 9). Captures: `/tmp/wt-floodlight/shots/04b/`.
- `finish-ui-3`: started, then stopped when the receipt caching change landed (superseded).
- `finish-ui-4` (rebased on the ticket-03 fixes; receipt built once; comparison single panel):
  exit 65 — **UI 17/18 passed**; the one failure is the same pre-existing History assertion
  (`HeartRateSummaryUITests.swift:66`). Passed: FloodlightFinishUITests 4/4 (captures),
  CoreLoop empty finish + View in History, HistoryTemplate 3/3, HeartRate finishing summary,
  HeartRateSummary no-series + hour-long chart, RedesignScreenshot test02/test03, Cardio
  capture+save and both mixed cardio/lifting workouts (the "Lifting" heading, Cardio section).
  Unit: 14/14.
- Captures: `../captures/04/floodlight-04-finish-{light,dark}-{default,axl}-N.png` (scrolled
  pages of one receipt each).

## Progress

- 2026-09-26 (session 1): first cut in `/tmp/wt-floodlight/finish`; `finish-ui-1` 14/14.
- 2026-09-26 (session 2): capture review found the New bests list showing one line per
  improving set, each compared with the previous set of the same workout (two chest press
  lines, "110 × 8" over "100 × 10"). Fixed to one line per scope against the pre-workout
  record (`workoutBest`); receipt unit tests added. Heart-rate section given the Floodlight
  heading/panel with zones below. `ComparisonBars` draws its own panel; the receipt's extra
  panel around it (a card in a card) removed.

## Codex review 04 — response (round 1)

Report: [codex-review-04.md](../codex-review-04.md) — not clear; 4 medium, 1 low. All accepted.

1. **Ring dropped unmapped sets / merged families (medium).** `FinishReceipt.ringRuns`: every
   completed set in workout order as runs of one family; nil family (Core, Neck, Full Body,
   unclassified) drawn neutral (`textTertiary`). `familySets` stays the key (mapped totals).
   `FinishStatusRing` takes `[RingRun]`; its spoken summary totals per family plus "other".
   Tests: `theRingHasEveryCompletedSetInWorkoutOrder`, `aCoreOnlyWorkoutStillHasARing`.
2. **Locale count-up (medium).** `CountUpFormat.parse` reads with a `NumberFormatter` in the
   locale that formatted the string (German "1.880" → 1880, "1.234,25" → 1234.25). Test:
   `countUpParsesInTheFormattingLocale`.
3. **Volume precision (medium).** New `LookFormat.groupedDecimal` (grouped, ≤ 2 decimals) for
   the volume tile and `ComparisonBars` (7.5 stays 7.5). Whole figures still count up in whole
   steps. Test: `volumeKeepsItsDecimals`. Not changed: the live vitals strip's running volume
   (ticket 03, cleared) still shows whole numbers — noted for the History/live polish pass.
4. **VoiceOver scope (medium).** The best row's label includes the equipment/preset
   ("New best, Seated Chest Press, Chest Press 2, 110 lb × 8, previous best 45 lb × 8");
   identifier `finishNewBest`; asserted in `FloodlightFinishUITests`.
5. **Bar annotation (low).** `RecordSetInput.barWeightValue` (display only, never ranked) carries
   the bar through the incumbent; `SetValue(input)` keeps it; `FinishSetValueText` and
   `LookFormat.set` append "(20 kg bar)". Test: `barModeBestsKeepTheirBar`.
- **Performance note.** `SetBadgeMath.finishedEntries(in:)` is read once per receipt and shared
  by every entry (`receiptMarks(for:finishedEntries:)`).

Verification (round 2): `finish-build-6` exit 0; `finish-ui-5` **exit 0** — UI 12/12
(FloodlightFinishUITests 4/4 incl. the single spoken best with its machine, View in History,
finish-sheet template save, heart-rate finishing summary, Barbell 2/2, RedesignScreenshot
test02/test03, mixed cardio-first workout); unit 57/57 (`FinishReceiptTests` 10,
`SetBadgeTests`, `RecordsMathTests`, `RecordsSurfaceTests`). Captures refreshed in `../captures/04/`.

## Codex review 04b — response (round 2)

Report: [codex-review-04b.md](../codex-review-04b.md) — not clear; one medium (all round-1
findings resolved).

- **Bar annotation could overflow at AX sizes (medium).** `FinishSetValueText` keeps the load
  on one line and puts "(45 lb bar)" on its own wrapping line beneath, aligned with the value
  (leading at AX sizes, trailing otherwise); the struck-through incumbent wraps the same way.
  New fixture `-uiTestDesignBarBest` (with `-uiTestDesignLive`): a barbell Bench Press on a
  45 lb bar, 90 lb × 10 five days ago and today 102.5 lb × 10. New captures
  `testCaptureBarBest{Light,Dark}{Default,Accessibility}` assert two best lines, the spoken
  "102.5 lb × 10 (45 lb bar)" / "previous best 90 lb × 10 (45 lb bar)", and that the row stays
  inside the window. Captures: `../captures/04/floodlight-04-barbest-*.png`.
- Ticket count corrected: `FinishReceiptTests` has 10 tests.

Verification (round 3): `finish-build-7` exit 0; `finish-ui-6` **exit 0** — UI 11/11
(FloodlightFinishUITests 8/8, Barbell 2/2, RedesignScreenshot test03 AXL), unit
`FinishReceiptTests` 10/10; `finish-ui-7` exit 0 — the four bar captures re-shot with the whole
bench row in frame (4/4).
