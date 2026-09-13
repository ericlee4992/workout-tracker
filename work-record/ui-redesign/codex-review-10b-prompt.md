Round 2 (T6) of UI-redesign ticket 10 (Start, second pass). Round-1 review:
work-record/ui-redesign/codex-review-10.md; the response is in
work-record/ui-redesign/issues/10-start-second-pass.md under "Codex review 10 — response".
Boundary of the fix: e608fa6..HEAD on branch ui-redesign-10-start.

Scope — are the four P2s and the P3 closed:
(1) gym picker: `Theme.text` / `Theme.secondary` on the texts, the pin tile a `@ScaledMetric`,
    accessories stacked at accessibility sizes (StartWorkoutView.swift `gymPicker`); measure the
    subtitle pair on `04-start-templates.png` again;
(2) the tile's exercise line whole (no lineLimit) — check `04-start-templates.png` and
    `04-start-axl.png`;
(3) `MuscleIcon`'s glyph style from the base size; the capsule's disc scaled (`disc`), the dot in
    `.caption2` — check the glyphs sit inside their backgrounds in `04-start-axl.png` and
    `04-start-live-axl.png`;
(4) captures: same state at both sizes for the idle screen, `04-start-axl-2.png` (scrolled),
    `04-start-live-axl.png` (the live fixture at AXL);
(5) the counts in the ticket.
Then REVIEW.md items 1, 6, 9 and 12 again on the new captures in work-record/ui-redesign/screenshots/10/.
Anything new introduced?

Do NOT run xcodebuild or simctl. If closed, say "clear" in one paragraph; otherwise report by
severity with file:line. Do not modify source files. Write to work-record/ui-redesign/codex-review-10b.md
