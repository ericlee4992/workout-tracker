Round 2 (T6) of UI-redesign ticket 07 (Gyms). Round-1 review: .scratch/ui-redesign/codex-review-07.md;
the response is in .scratch/ui-redesign/issues/07-gyms.md under "Codex review 07 — response".
Boundary of the fix: b0e924f..HEAD on branch ui-redesign-07 (one commit).

Scope: is the P2 closed — GymDetailView reads `@Environment(\.dynamicTypeSize)`; the machine
row shows the model as a wrapping `.caption` when `isAccessibilitySize`, the `Chip` otherwise.
Captures: .scratch/ui-redesign/screenshots/07/06-gym-detail-axl.png (the long model name on two
lines, whole) and 06-gyms-axl.png. New test `RedesignScreenshotUITests.test06_gymsLargeText`.
Anything new introduced?

Do NOT run xcodebuild or simctl. If closed, say "clear" in one paragraph; otherwise report by
severity with file:line. Do not modify source files.
Write to .scratch/ui-redesign/codex-review-07b.md
