Round 2 (T6) of UI-redesign ticket 09. Round-1 review: .scratch/ui-redesign/codex-review-09.md;
the response is in .scratch/ui-redesign/issues/09-empty-states-icon-live-activity.md under
"Codex review 09 — response". Boundary of the fix: 59fd54a..HEAD on branch ui-redesign-09
(one commit).

Scope: are the two P2s and three P3s closed —
(1) WorkoutActivityView.swift: the Lock Screen content gets `.environment(\.colorScheme, .dark)`
    (`onInk()`) above `activityBackgroundTint` — does that resolve `.primary`/`.secondary` light
    inside the view in a light Lock Screen appearance, and is it the right scope (the Dynamic
    Island regions are unchanged)?
(2) ExercisePresetsSheet: "No presets yet…" is an `EmptyState` with the byte-identical string and
    `noPresets` on it; the Previous Performance messages are the recorded exception in the ticket
    — acceptable?
(3) scripts/render-app-icon.py: the shaft spans 0.12–0.88 of the tile, under every plate;
    AppIcon.png regenerated.
(4) docs/SPEC.md "Visual design" narrowed (native Forms named, "wherever exercises are listed",
    AXL captures listed by screen); (5) D54 names who reviewed what; STATE says 09 is in review.
Anything new introduced?

Do NOT run xcodebuild or simctl. If closed, say "clear" in one paragraph; otherwise report by
severity with file:line. Do not modify source files.
Write to .scratch/ui-redesign/codex-review-09b.md
