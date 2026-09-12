Round 1 (T6) of ticket 13 — "Save as Template…" from a History workout. The user: "I want to have
an option to save as template from history." Ticket:
.scratch/history-templates-and-zones/issues/13-save-as-template-from-history.md. Boundary:
main..HEAD on branch history-13-save-as-template (main = fcef729).

Files: WorkoutTracker/Features/Templates/SaveAsTemplateFlow.swift (new: the finish sheet's naming
alert + failure alert as one ViewModifier; default name filled when presented),
Features/ActiveWorkout/WorkoutFinishedSheet.swift (now uses it; its own alerts, saveTemplate and
templateFailureMessage removed), Features/History/WorkoutDetailView.swift (the menu item, gated
on WorkoutTemplateService.canSaveAsTemplate; the confirmation row; the modifier),
WorkoutTrackerUITests/HistoryTemplateUITests.swift (new).

Review for: (1) the finish sheet's behaviour unchanged — every string and identifier the UI tests
read (`saveAsTemplate`, "Template name", "Save", "Saved as template “…”"), the default-name
timing (the old code set it right before presenting; the modifier sets it on isPresented →
true — any case where the alert shows with a stale or empty name? e.g. the finish sheet's
savedWorkout arriving after the view appears); (2) History: a workout edited in History (sets
retyped, an exercise added/removed) — does canSaveAsTemplate / saveAsTemplate see the edited
truth (completedAt on history-added sets?), and is anything snapshot-only (D23) wrongly read
live? (3) the ios-design rules for a toolbar command menu (the item's ellipsis vs the finish
sheet's button without one; the confirmation row inside the name section — a card of a group,
or a stray line?); (4) the test's robustness (the far-end tap + append; predicates). Do NOT run
xcodebuild or simctl. Do not modify source files. Report by severity with file:line, or say
"clear" in one paragraph. Write to .scratch/history-templates-and-zones/codex-review-13.md
