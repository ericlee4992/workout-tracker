# 13 — Save as Template from History

Status: in progress (branch `history-13-save-as-template`)

The user (2026-09-11): "I want to have an option to save as template from history."

## What exists

The finish sheet has had "Save as Template" since milestone 9 (`WorkoutTemplateService.
saveAsTemplate`, gated by `canSaveAsTemplate`: entries with a live exercise and at least one
completed set). History had no way to reach it — a workout you thought better of a day later
could not become a plan.

## Built

- `Features/Templates/SaveAsTemplateFlow.swift` — the naming alert ("Save as Template" /
  "Template name" / Save / Cancel, "Saves exercises, sets and target reps — not weights or rest
  times.") and the failure alert, as ONE view modifier; the default name "Workout <date>" is
  filled in when presented. The finish sheet now uses it (its own copy of the two alerts and
  the failure copy is gone; every string and identifier unchanged — `saveAsTemplate`,
  "Template name", "Save").
- `WorkoutDetailView` (History): a "Save as Template…" item at the top of the existing toolbar
  menu (identifier `saveAsTemplate`), offered only when `canSaveAsTemplate` — the same gate as
  the finish sheet, so it never fails on an empty workout; after saving, the finish sheet's
  confirmation line ("Saved as template “<name>”") as a row of the name section
  (`savedTemplateConfirmation`). The ellipsis matches the menu's other follow-up action
  ("Delete Workout…"). No new string.
- Design (ios-design rules): a command menu keeps its symbol; the action lives in the toolbar,
  not on the screen; nothing bold added.

## Gate tests

Unit: `WorkoutTemplateTests` (`saveAsTemplateIsOfferedOnlyWhenItCanSucceed`,
`saveAsTemplateCapturesCompletedStructureAndSlotRepsOnly` — unchanged, the service is untouched).
UI: `HistoryTemplateUITests` (new, 1: History → detail → menu → name → Save → confirmation → the
tile on the Workout tab → the detail lists the exercise), `HeartRateSummaryUITests` (the finish
sheet's save path), `HistoryEditingUITests`, `WorkoutNameUITests` (the detail's menu and name
section); then the full suite.

## Verification (2026-09-12)

Gate run on the branch: `WorkoutTemplateTests` 7/7 (Swift Testing), `CoreLoopUITests` 9/9,
`HeartRateSummaryUITests` 3/3, `HistoryEditingUITests` 2/2, `WorkoutNameUITests` 2/2 — 16/16
untouched-path tests green; `HistoryTemplateUITests` failed three times on ITS OWN name entry
(a long-press "Select All" that never appeared; then backspacing from wherever the tap put the
cursor; then reading the confirmation off the cell, whose label is "Selected"), never on the
app: the test now taps the field's far end and appends " From History", and matches the
confirmation's static text and the tile by predicate — 1/1. Lesson: an alert text field's tap
puts the cursor where it hits; an `accessibilityIdentifier` on a `Label` in a List row lands
on the cell.
