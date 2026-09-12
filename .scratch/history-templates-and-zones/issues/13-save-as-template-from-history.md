# 13 — Save as Template from History

Status: resolved — Codex clear after 2 rounds (codex-review-13, 14 §A); `HistoryTemplateUITests` 3/3; full UI suite **70/70** on `c18538f`; merged to main 2026-09-12

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

## Step 1 — job, state, bold element

The History detail exists so the user can read what a past workout was (and repair it); it has
no bold element — it is a record. Ticket 13 adds one COMMAND to its existing command menu and
one ROW to its existing name group, in the finish sheet's words. The eye's landing (the name
card, then the exercises) and the composition are unchanged; the wireframe is ticket 06's.

## Step 4 — tells

- A control dressed as the command / the accent on a command: **absent** — the action is a
  menu item behind the existing ellipsis-style menu, no accent.
- A card around a single line: **absent** — the confirmation is a row of the name section (a
  group: name, gym · duration, then the confirmation), not a box of its own.
- New copy: **none** — "Save as Template" (the finish sheet's button, with the menu's "…"),
  "Template name", "Save", "Saved as template “…”" are all existing strings.
- Survives only the default size: the AXL run of the same test captures the menu, the alert and
  the confirmation row (`history-13-menu-axl`, `-alert-axl`, `-confirmation-axl`).

## Gate tests

Unit: `WorkoutTemplateTests` (`saveAsTemplateIsOfferedOnlyWhenItCanSucceed`,
`saveAsTemplateCapturesCompletedStructureAndSlotRepsOnly` — unchanged, the service is untouched).
UI: `HistoryTemplateUITests` (new, 3: History → detail → menu → name → Save → confirmation → the
tile on the Workout tab → the detail lists the exercise, at the default size and at AXL, each
with captures of the menu, the alert and the confirmation; and the finish sheet's own save —
prefilled name, Save, the confirmation replacing the button — which no test had exercised,
codex-review-13), `HistoryEditingUITests`, `WorkoutNameUITests` (the detail's menu and name
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

## Codex review 13 — response (2026-09-12)

`codex-review-13.md`: "no introduced functional defect"; copy and identifiers preserved; the
default-name timing, History-edited workouts (added sets carry `completedAt`; D23 snapshots not
read live), the menu's ellipsis and the confirmation row's grouping all accepted. Two P3s:
- **Design evidence** — steps 1 and 4 recorded above; captures added:
  `screenshots/history-13-{menu,alert,confirmation}.png` and the same three at AccessibilityL
  (`-axl`), from `testAHistoryWorkoutCanBeSavedAsATemplate(LargeText)`.
- **The finish-sheet path had no test** — `testTheFinishSheetStillSavesATemplate` (log a set,
  Finish, Save as Template, the prefilled "Workout …" name, Save, the confirmation replacing
  the button; `history-13-finish-sheet-saved.png`). The gate line is corrected above.
`HistoryTemplateUITests` 3/3.
