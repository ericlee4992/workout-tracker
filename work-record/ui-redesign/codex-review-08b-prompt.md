Round 2 (T6) of UI-redesign ticket 08. Round-1 review: work-record/ui-redesign/codex-review-08.md;
the response is in work-record/ui-redesign/issues/08-exercises-and-sheets.md under "Codex review
08 — response". Boundary of the fix: b5c85c0..HEAD on branch ui-redesign-08 (one commit).

Scope: are the two P2s closed —
(1) `Features/Design/WrapLayout.swift` (new, a `Layout`): read `sizeThatFits` / `placeSubviews`
    / `arrange` — is the wrap arithmetic right (first child never wraps; a child wider than the
    line gets its own line; the returned height covers the last line; `proposal.width == nil`
    handled)? `ExerciseRow`'s caption + chips flow in it at every size.
(2) `TemplateRow` (StartWorkoutView.swift): the icon strip is a `WrapLayout`; at accessibility
    sizes the Start button sits under the text (`AnyLayout`). Capture
    `screenshots/08/04-start-axl.png` (a five-exercise template at AccessibilityL) and
    `07-exercises-axl.png` (the flow at AccessibilityL), `07-exercises.png` (default).
Anything new introduced?

Do NOT run xcodebuild or simctl. If closed, say "clear" in one paragraph; otherwise report by
severity with file:line. Do not modify source files.
Write to work-record/ui-redesign/codex-review-08b.md
