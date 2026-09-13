Round 4 (T6) of UI-redesign ticket 03 (finish summary). Round-3 review:
work-record/ui-redesign/codex-review-03c.md; the response is in
work-record/ui-redesign/issues/03-finish-summary.md under "Codex review 03c — response".
Boundary of the fix: 73379e4..HEAD on branch ui-redesign-03 (one commit).

Scope: is the P3 closed — `WorkoutFinishedSheet` uses one grid column when
`dynamicTypeSize.isAccessibilitySize`; `HeartRateSummarySection` labels only the first clock tick
at those sizes. Look at `screenshots/03/03-finish-summary-axl.png` and `-axl-2.png`: every tile
whole, values untruncated; and `03-finish-heart-rate.png` unchanged at the default size. Anything
new introduced (the `@Environment(\.dynamicTypeSize)` reads, the tick filter)?

Do NOT run xcodebuild or simctl. If closed, say "clear" in one paragraph; otherwise report by
severity with file:line. Do not modify source files.
Write to work-record/ui-redesign/codex-review-03d.md
