# 02 — Remove ≈ and "estimated" from every screen

Status: in progress (2026-09-05)
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
