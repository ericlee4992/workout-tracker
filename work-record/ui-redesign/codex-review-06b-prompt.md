Round 2 (T6) of UI-redesign ticket 06 (History). Round-1 review:
work-record/ui-redesign/codex-review-06.md; the response is in
work-record/ui-redesign/issues/06-history.md under "Codex review 06 — response".
Boundary of the fix: ba090f6..HEAD on branch ui-redesign-06 (one commit).

Scope: are the two P2s and the P3 closed —
(1) ExerciseProgressView: both marks `.monotone` (documented deviation from the plan's catmullRom);
(2) HistoryCalendarSheet: `markedFuture` = hollow `Theme.accent` ring + `Theme.text` numerals;
    every ring drawn 2 pt OUTSIDE the disc (`.padding(-4)` on the strokeBorder overlay);
    `markedToday` ring `Theme.secondary`. Contrast by your asset arithmetic; is a 48 pt ring
    inside a flexible 7-column grid safe from clipping/overlap at 40 pt cells with 8 pt spacing?
(3) WorkoutDetailView: the first Section now carries `.listRowBackground(Theme.card)`.
And the AccessibilityL ask: `RedesignScreenshotUITests.test05_historyLargeText` (new);
`screenshots/06/05-history-axl.png` and `05-detail-axl.png` — the row stacks the day tile above
the text (`AnyLayout` on `dynamicTypeSize.isAccessibilitySize`, title lineLimit 3), the header
stacks equipment and chip, the chip `fixedSize`. Anything new introduced by the `AnyLayout`s
(the row is still one Button; ids unchanged)? The ticket's gate counts were corrected.

Do NOT run xcodebuild or simctl. If closed, say "clear" in one paragraph; otherwise report by
severity with file:line. Do not modify source files.
Write to work-record/ui-redesign/codex-review-06b.md
