# Codex cross-review 06 — Remove explanatory helper copy

Review boundary: `802c7dc...b0e0004` (commit `b0e0004`). Verdict: **not clear**.

## Standards

### Low — Removing the chart footer left an unused pattern binding

`WorkoutTracker/Features/History/ExerciseProgressView.swift:73` still matches `case .series(let days)`, but the deleted `footer(days:)` was the only consumer of `days`. Match `case .series:` unless the count is restored to the UI. This is the only newly uncalled leftover I found: `isFrozen` and `footer(days:)` themselves are gone, while `canSaveAsTemplate`, `savedTemplateName`, `displayUnit`, `currentUnit`, `intervalSeconds`, `linkTo`, and the other values interpolated by deleted text still have live behavior/UI uses. There are no localization resources containing orphaned copies.

No surviving `Section` is empty or malformed. The footer-only section in `WorkoutDetailView` was removed as a whole; every other touched section retains its intended row closure. Every `if` removed with a footer/message selected text only and carried no mutation or presentation logic. No additional baseline smell was introduced.

**Standards — 1 finding (worst: Low).**

## Spec

### High — A kg progress axis can now silently contain converted lb values

The series stores plotted loads in canonical kg and converts them to the app display unit (`WorkoutTracker/Features/History/ExerciseProgressView.swift:256-269`, `WorkoutTracker/Features/History/ExerciseProgressView.swift:281-293`). When the app preference is kg, `unitSuffix` emits plain `(kg)` even if one or more plotted best sets were entered in lb. Before this commit, the removed footer at least disclosed that other-unit sessions were converted; afterward neither the axis nor any nearby copy marks that conversion. This contradicts D9/D25 and the ticket's explicit promise to retain `≈` on converted axis labels and values. Derive the axis marker from the series' entered units (or otherwise keep the conversion disclosure), including mixed-unit kg charts.

### High — “Finish It & Start New” lost its data-loss warning

The confirmation now presents a bare `Finish It & Start New` action (`WorkoutTracker/Features/Start/StartWorkoutView.swift:93-101`). Finishing deletes every uncompleted set, deletes entries with no completed set, and deletes the whole workout if nothing survives (`WorkoutTracker/Domain/WorkoutSession.swift:100-106`, `WorkoutTracker/Domain/WorkoutSession.swift:156-173`). The removed “only its completed sets are kept” message stated that consequence; it did not merely explain the screen. Restore that disclosure in the confirmation.

### Medium — The template action no longer says what the new template omits

Both disclosures around `Save as Template` were removed, leaving the section and naming alert with no explanation (`WorkoutTracker/Features/ActiveWorkout/WorkoutFinishedSheet.swift:63-80`, `WorkoutTracker/Features/ActiveWorkout/WorkoutFinishedSheet.swift:109-114`). The service copies completed exercise structure and target reps only (`WorkoutTracker/Domain/WorkoutTemplates.swift:168-180`); weights and rest settings are omitted. That is a non-obvious result of the action and falls on the ticket's “state a consequence” side. The alert message can retain it without restoring a permanent gray paragraph to the finish sheet.

### Medium — Safety and history-identity consequences were removed with tutorial copy

The Export section no longer warns that this iPhone holds the only copy until an export is saved (`WorkoutTracker/Features/Settings/ExportSection.swift:37-70`), despite the file's own backup contract at lines 4-8. Other bare actions likewise lost persistent-history consequences: choosing equipment can create a new entry after a completed set and partitions comparable records (`WorkoutTracker/Features/ActiveWorkout/MachinePickerSheet.swift:20-84`, `WorkoutTracker/Features/ActiveWorkout/MachinePickerSheet.swift:147-163`); adding an exercise to History records today's definition without equipment (`WorkoutTracker/Features/History/WorkoutDetailView.swift:170-175`); and preset/model renames leave captured names in old History (`WorkoutTracker/Features/Exercises/ExercisePresetsSheet.swift:43-55`, `WorkoutTracker/Features/Exercises/ExercisePresetsSheet.swift:99-109`, `WorkoutTracker/Features/Gyms/GymsView.swift:177-189`). These are safety, comparability, or provenance outcomes, not instructions for operating the screen. Keep concise consequence copy at the relevant action boundary.

### Medium — A two- or three-day line no longer carries its confidence caveat

`ProgressConfidence.series(days:)` retains the day count expressly so presentation can qualify sparse evidence (`WorkoutTracker/Domain/ProgressSeries.swift:33-43`), and two days already become a drawn series (`WorkoutTracker/Domain/ProgressSeries.swift:273-278`). Removing `footer(days:)` makes `WorkoutTracker/Features/History/ExerciseProgressView.swift:73-91` draw the line and percentage change without the former “Only N days ... read the shape with caution” honesty cue. The count becoming unused is evidence that this was behavior-significant copy, not just decoration. Preserve the caveat in a compact non-footer treatment if the gray paragraph must remain gone.

The other required markers survive: converted detail values still go through `WeightMath.displayLabel`; non-kg chart/summary conversions retain `≈`; `(estimated)` remains on max-heart-rate preview, finish summary zones, and Settings; workout/set/entry deletion dialogs still name their impact; the History edited marker, Previous Performance layer notes, three functional hints, and “It was not renamed...” alert remain. D44's absent-heart-rate rows remain omitted rather than zeroed.

`git diff --check 802c7dc...b0e0004` passes. A fresh unsigned simulator build completed successfully. The ticket records 643 unit tests and all 36 UI tests green; I did not rerun those suites. No source files were modified by this review.

**Spec — 5 findings (worst: High).**
