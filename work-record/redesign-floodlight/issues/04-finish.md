# 04 — Floodlight: the finish receipt

Type: feature (part of [01](01-implement-redesign.md))
Status: implemented; verification in progress; Codex review pending
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
- Next run: after rebasing on ticket 03's fixes — the same batch plus fresh captures.

## Progress

- 2026-09-26 (session 1): first cut in `/tmp/wt-floodlight/finish`; `finish-ui-1` 14/14.
- 2026-09-26 (session 2): capture review found the New bests list showing one line per
  improving set, each compared with the previous set of the same workout (two chest press
  lines, "110 × 8" over "100 × 10"). Fixed to one line per scope against the pre-workout
  record (`workoutBest`); receipt unit tests added. Heart-rate section given the Floodlight
  heading/panel with zones below. `ComparisonBars` draws its own panel; the receipt's extra
  panel around it (a card in a card) removed.
