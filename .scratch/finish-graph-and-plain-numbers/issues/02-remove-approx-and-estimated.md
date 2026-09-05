# 02 — Remove ≈ and "estimated" from every screen

Status: built — awaiting Codex review
Blocked by: 01
Added 2026-09-04: "Don't use that; just show number. … get rid of any of those."

## What to change

Every on-screen ≈ and every on-screen "estimated" / "(estimated)" / "est." goes. The data behind
them stays (D52): `MaxHeartRate.isEstimated`, `Workout.zonesFromEstimatedMax`, the export fields,
`ProgressPoint.enteredUnits` / `bestUnit` / `e1rmUnit` — no file format and no model changes.

Sites (grep `≈` and `estimated` under `WorkoutTracker/`, non-comment lines):
- `WeightMath.displayLabel` — the prefix. Used by History's convert toggle and the set rows.
- `WorkoutFinishedSheet.volumeLabel` (the user's screenshot), `zoneRow`'s "(estimated)" and
  `summaryZonesEstimated`.
- `PreviousPerformanceSheet`: "e1RM (Brzycki, est.)" → "1RM (Brzycki)", value without ≈.
- `ExerciseProgressView`: `calloutValue` (volume, e1rm), `unitSuffix` (always "(unit)"), `yLabel`
  "Estimated 1RM" → "1RM".
- `AppSettingsSection.maxHeartRateSummary`: "184 bpm", never "(estimated)".
- `HeartRateBar`: the "· zone estimated" button keeps its tap (it is the mid-workout way to the
  measured-max field) as "· edit zones", identifier `hrZoneEdit`.
- `MaxHeartRateSheet`: preview row without "(estimated)"; the "Estimate" header → "Date of birth".
- Comments that describe the old screen behaviour are updated where they would now mislead
  (`WeightMath`, `HeartRateZones`, `Models`, `WorkoutDetailView`, `ExerciseProgressView`,
  `WorkoutFinishedSheet`); comments that only cite D9/D25 by analogy are left.

Docs: D52 in DECISIONS.md; SPEC lines 55/71 and the D45 mention at line 93; the CLAUDE.md
convention line; STATE.

## Acceptance criteria

- `grep -rn "≈" WorkoutTracker/ | grep -v "//"` is empty; `grep -rni "estimated" WorkoutTracker/
  Features/` finds no string literal.
- Tests that asserted the marks are inverted, not deleted: `WeightMathTests`,
  `HistoryRenderingTests`, `DisplayUnitTests` assert the plain form; `ExportTests`' "no ≈ in the
  file" still holds; `CodexReviewRegressionTests` 1.1 (the DATA flag) untouched and green.
- Unit suite green in full; UI classes HeartRate, HeartRateSummary, Charts (tooltip + progress),
  HistoryEditing, CoreLoop green.
- Codex clear.


## Resolution (2026-09-05)

Every on-screen mark is gone; `grep -rn "≈" WorkoutTracker/` finds comments only, and no string
literal under `Features/` says "estimated", "(estimated)", "est." or "Estimate":

- `WeightMath.displayLabel` — no prefix (History's convert toggle, set rows, everything that used it).
- `WorkoutFinishedSheet` — volume plain ("9740 lb"); "Time in zones" without "(estimated)";
  `summaryZonesEstimated` deleted.
- `PreviousPerformanceSheet` — "1RM (Brzycki)", value plain.
- `ExerciseProgressView` — tooltip volume/1RM plain, axis always "(unit)", metric "1RM"; the
  contributor-unit scan in `unitSuffix` and `calloutValue` deleted (`ProgressPoint` keeps the fields).
- `AppSettingsSection` — "184 bpm".
- `HeartRateBar` — "· edit zones" (`hrZoneEdit`) keeps the mid-workout way to the measured field.
- `MaxHeartRateSheet` — preview plain; section header "Date of birth".
- Comments updated where they described the old screens: `WeightMath`, `HeartRateZones`, `Models`
  (`measuredMaxHeartRate`), `WorkoutDetailView` (3), `WorkoutFinishedSheet`, `HeartRateBar`,
  `MaxHeartRateSheet`.

Data untouched: `MaxHeartRate.isEstimated`, `Workout.zonesFromEstimatedMax`, the export fields,
`ProgressPoint.enteredUnits/bestUnit/e1rmUnit`. No model or file-format change.

Docs: **D52** written; D9, D25 and D45 rows annotated as reopened by it (struck text, not deleted);
SPEC lines 55/71/93; the CLAUDE.md convention line.

Tests inverted, not deleted: `WeightMathTests` (3 assertions), `HistoryRenderingTests`
(`convertedValuesArePlain`), `DisplayUnitTests` (`aConvertedDisplayIsPlain`). `ExportTests`' "no ≈
in the file" and `CodexReviewRegressionTests` 1.1 (the data flag) untouched. **654 unit green.** UI: HeartRate (5) + HeartRateSummary (3) + ProgressChart (2) + ProgressChartTooltip
(4) + CoreLoop (9) + HistoryEditing (2) — **25/25 green**, 2026-09-05, two chunks. Screenshot
`workout-summary`: "Total volume 600 lb".


## Codex review 02 — response (2026-09-05)

`codex-review-02.md`: 2 medium, 5 low. All seven real, all fixed:

- **"Est. 1RM" survived in the chart's metric picker (medium).** The `Metric` enum's raw value,
  rendered by the segmented picker. Now "1RM". The resolution's "every mark is gone" was false by
  one string; the grep in the acceptance criteria only looked for "estimated", not "est.".
- **STATE stale (medium + low).** Four lines still promised ≈-per-contributor or "(estimated)";
  rewritten as history, and STATE's head now describes this branch.
- **WeightMath header (low).** Says plain now.
- **D45 contradicted itself; D52 overstated "no conversion is ever stored" (low).** D45 opens on the
  DATA rule and says the screen rule was dropped; D52 says a converted DISPLAY value never replaces
  the stored pair, with `normalizedKg` named as the canonical derivation D25 defines.
- **CLAUDE.md said D1–D51 (low).** D1–D52.
- **Three copies of "convert kg, round, suffix" (low, judgment).** `WeightMath.displayLabel(
  kilograms:in:locale:)` owns it; the finish sheet, the 1RM record and the chart tooltip call it.
  Tested ("9740 lb" from 4417.99 kg).

**655 unit green** (+1). UI: ProgressChart (2), ProgressChartTooltip (4), HeartRateSummary (3), Presets
re-run green.
