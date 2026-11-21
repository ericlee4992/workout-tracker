# Codex review — N16, round 2 (fixes)

Same rules, simulator (WT-Redesign-2, `-derivedDataPath /tmp/wt-n16-codex`) and report format as
`work-record/nutrition/codex-review-n16-prompt.md`. Previous report: `work-record/nutrition/codex-review-n16.md`.

**Diff since the reviewed commit:** `8ea159df..HEAD` (the app/test changes are in the fix commit; the rest is records).

## Findings → fixes → regression tests

1. **P2, failed-scan recovery used a stale day.** `WorkoutTracker/Features/Today/TodayView.swift` — the card's
   `retake` and `manualAdd` now set `logDay = scan.pickedDay` before presenting (nil for a scan not sent from a picked
   day: today, as before N16). Regression: `WorkoutTrackerUITests/TodayPickDayUITests.testAFailedScansManualAddGoesToItsDay`.
2. **P2, a picked-day library label back-dated creation and recency.** `WorkoutTracker/Domain/TodayDayPick.swift`
   `FoodLogDay.labelTimes` (created now; eaten = the picked day's meal time, else the photo's own time) used by
   `LabelFoodView.log` in `WorkoutTracker/Features/Food/Scan/FoodScanFlow.swift`. Note: a library label **without** a
   pick is now also created now (before, `createdAt` and the saved food's "last used" took the photo's time); its
   `loggedAt` is still the photo's time (D83(9)). Say if you think that change needs its own decision. Regression:
   `WorkoutTrackerTests/TodayDayPickTests.anOldLabelPhotoOnAPickedDayIsCreatedNow` (Save to My foods on and off).

## Runs due

Build; the Unit plan (or `TodayDayPickTests`, `FoodScanTests`, `FoodLogTests`); UI — the fixes changed UI behaviour and
UI test code: `TodayPickDayUITests` (7) and `ScanFoodUITests` (the label path). The author's runs:
`build/results/n16b-unit.xcresult`, `build/results/n16b-ui.xcresult`.

## Report

`work-record/nutrition/codex-review-n16b.md`, last line exactly `Verdict: clear` or `Verdict: not clear`.
