Round 1 (T6) of UI-redesign ticket 10 — the Start screen's second pass, the FIRST screen designed
under the new skill. Grade it against .claude/skills/ios-design/REVIEW.md (read SKILL.md's rules
and REFERENCE.md too); the ticket supplies the composition record:
.scratch/ui-redesign/issues/10-start-second-pass.md (job/state sentences, the chosen structure,
the user's picks, the tells answered). Boundary: main..HEAD on branch ui-redesign-10-start
(main = d492374).

Files: WorkoutTracker/Features/Start/StartWorkoutView.swift (HeroCapsuleLabel, TemplateTile, the
grid), Features/Design/MuscleGroupStyle.swift (MuscleIcon gains `size`),
WorkoutTrackerUITests/RedesignScreenshotUITests.swift (test04_startTemplates, test04_startLargeText).
Captures: .scratch/ui-redesign/screenshots/10/ — 04-start (live state, resume capsule),
04-start-templates (idle, five-exercise template, default size), 04-start-axl (same at
AccessibilityL). Mockups the user chose from: the canvas working files in
.scratch/ui-redesign/canvas/start/ (Main.dc.html = the chosen composition; MainLive = the live state).

Walk REVIEW.md items 1–13 and report each with a checkable answer. Particular attention:
- Item 1: the capsule is the only accent-filled command; the gym card's pin tile is amber at
  10 % opacity with an amber pin (unchanged from before) — a state of the picker, or a competing
  accent? Say which and why.
- Item 8: the template grid lost swipe-to-delete (a grid has no rows); Edit/Delete stay on the
  long-press menu. The ticket accepts that; do you?
- Item 9: at AXL, does the two-column grid still hold a tile with five icons + a name + two lines?
- Item 11: `startEmptyWorkout` is ABSENT while a workout is live (the capsule becomes
  `resumeWorkout`). No UI test starts while live; is anything else in the app (a deep link, the
  Live Activity tap, the finish sheet's "start another") relying on that button existing?
- The `HeroCapsuleLabel` accessibility: `.accessibilityElement(children: .combine)` — the
  combined label for the live state; the pulse dot hidden and gated by Reduce Motion.

Do NOT run xcodebuild or simctl (the simulator is in use). Report by severity with file:line, or
say "clear" in one paragraph. Do not modify source files. Write to .scratch/ui-redesign/codex-review-10.md
