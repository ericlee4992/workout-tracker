# Codex re-review 06b — Remove explanatory helper copy

Review boundary: `b0e0004...11bf70b`. Verdict: **not clear**.

## Standards

Clear. The restored sparse-series caveat uses `days`, closing the round-1 unused-binding finding. Each restored consequence is one short line attached to a valid section or alert; no explanatory paragraph, removed helper/state, documented-standard violation, or actionable baseline smell returned. Source changes are limited to the eight expected `Features/` files, with the other boundary changes confined to the review prompt/report and issue response.

**Standards — 0 findings (clear).**

## Spec

### High — `bestUnit` does not describe the Volume or e1RM source data

`unitSuffix` decides whether the kg axis needs `≈` solely by checking each point's overall best-set unit (`WorkoutTracker/Features/History/ExerciseProgressView.swift:273-280`). But a point's volume sums every eligible set, while e1RM can be won by a different set from the heaviest one whose unit is stored as `bestUnit` (`WorkoutTracker/Domain/ProgressSeries.swift:257-264`, `WorkoutTracker/Domain/RecordsMath.swift:199-223`, `WorkoutTracker/Domain/RecordsMath.swift:233-239`). For example, a day whose heaviest set is entered in kg can also contain lb sets that contribute to Volume or produce the best e1RM; on a kg display the axis then remains plain `(kg)` even though those metric values include an lb-to-kg conversion. The selected Volume value separately omits `≈` whenever the display unit is kg (`WorkoutTracker/Features/History/ExerciseProgressView.swift:247-252`). Track metric-appropriate source-unit provenance—every contributor for Volume and the winning set for e1RM—and use it for both axis and value markers. The round-1 D9/D25 finding is therefore only partially closed.

All other round-1 findings are closed: the Finish-It and template alerts disclose their consequences; Export, frozen-equipment, History-add, preset-rename, and model-rename lines are restored; the under-four-days caveat uses `days`; and no paragraph returned. `git diff --check b0e0004...11bf70b` passes, and a fresh unsigned `WT-iPhone` simulator build succeeded. No source files were modified by this review.

**Spec — 1 finding (worst: High).**
