Round 1 (T6) of ticket 15 — a bug the user hit on the phone: "when i press and hold a template
and click delete it deletes the other template. just have delete button appear when you open the
template." Ticket: .scratch/ui-redesign/issues/15-delete-template-in-detail.md. Boundary:
main..HEAD on branch templates-15-delete-in-detail (main = a350944).

Files: WorkoutTracker/Features/Start/StartWorkoutView.swift (the tile's .contextMenu and the
delete helper removed), Features/Start/TemplateDetailView.swift (a "Delete Template…" red text
button as the last row; alert "Delete Template" / Delete / Cancel with "Workouts already logged
from it are kept."; delete then dismiss), WorkoutTrackerUITests/TemplateDetailUITests.swift (new, 2).
Captures .scratch/ui-redesign/screenshots/15/.

Review for: (1) the bug's mechanism — the ticket's explanation (the grid is ONE List row; a List
presents contextMenus per row, so with several in one row the wrong one fires) — is that right,
or is there another cause (e.g. the ForEach identity, LazyVGrid cell reuse, the Button capturing
`template` by reference)? Say which, with evidence; the fix removes the menu either way.
(2) Deleting a template whose detail is on the stack: dismiss() after context.delete — any
window where the popped view re-renders a deleted model (the isDeleted guards)? The template
that a LIVE workout was started from (sourceTemplateID) — deleting it: drift dialog paths
(TemplateDriftService.sourceTemplate) must cope with a missing template; do they? (3) ios-design:
a destructive text button as the last List row vs the History detail's menu item — consistent
enough, or should both be one pattern? Item 7 (never destructive primary) and item 8 (sheet/
commit semantics unaffected). (4) New copy: "Delete Template…" and the consequence line — the
user asked for the button; is the line needed (copy policy: one line where a delete has a
non-obvious consequence)? (5) The tests. The full UI suite is running now. Do NOT run xcodebuild
or simctl; do not modify source files. Report by severity with file:line, or say "clear" in one
paragraph. Write to .scratch/ui-redesign/codex-review-15.md
