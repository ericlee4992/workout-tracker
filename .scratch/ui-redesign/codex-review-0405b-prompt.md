Round 2 (T6) of UI-redesign tickets 04 + 05. Round-1 review: .scratch/ui-redesign/codex-review-0405.md;
the response is in .scratch/ui-redesign/issues/04-05-start-and-settings.md under "Codex review
0405 — response". Boundary: f80b00a..HEAD on branch ui-redesign-05 — now ONE commit (the branch
was squashed; the seven-commit history you saw is gone from the branch, main never had it).

Scope: are the two P3s closed — (1) the Gyms-sections move and the three test-route rewrites
(HeartRate, AskAI, Export) are in the same commit; (2) the test06 comment. And the Reduce Motion
point: StartWorkoutView reads `@Environment(\.accessibilityReduceMotion)` and the pulse is
`symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)` — correct use of the
`isActive` overload; anything new introduced by it? Everything else was clear in round 1 — only
re-check if the squash changed something you relied on.

Do NOT run xcodebuild or simctl (the simulator is in use). If closed, say "clear" in one
paragraph; otherwise report by severity with file:line. Do not modify source files.
Write to .scratch/ui-redesign/codex-review-0405b.md
