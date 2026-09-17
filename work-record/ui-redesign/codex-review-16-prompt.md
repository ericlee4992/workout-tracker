Round 1 (T6) of UI-redesign ticket 16 — the active workout's second pass, as the user decided it:
the current screen stays; the header becomes one status line (gym chip, the running clock with
SECONDS beside it in `stat`, and at the trailing end Codex A's small neutral ring + "N/M sets"
caption); the Large Title elapsed hero and the amber count chip are gone; and the rest bar's
"+15s"/"Skip" stack under the timer at accessibility sizes (the mid-word wrap bug from ticket 02).
Ticket: work-record/ui-redesign/issues/16-active-workout-second-pass.md (rounds 1–4: Claude's
three directions, your two, the revised A, then the user's decision). Grade against
.claude/skills/ios-design/REVIEW.md; boundary main..HEAD on branch ui-redesign-16-active-workout.

Files: WorkoutTracker/Features/ActiveWorkout/ActiveWorkoutView.swift (`header`, `elapsedSeconds`),
Features/ActiveWorkout/RestTimerBar.swift (the stacked layout), Domain/SharedEnums.swift
(`Format.elapsed`), WorkoutTrackerTests/FormatElapsedTests.swift (3), RedesignScreenshotUITests
(test02_activeWorkoutLargeText scrolls to the top first). Captures work-record/ui-redesign/
screenshots/16/: 02-active-workout (default, resting), 02-active-workout-axl (header at AXL) and
-axl-2 (the card and the stacked rest bar at AXL), 03-finish-summary.

Particular attention: (1) item 1 — with the hero gone, which element is bold on this screen now
(the amber Add Exercise? the completed set? Skip?) — the ticket records that the user chose to
keep the rest as it was; say whether the record is honest about what competes; (2) the clock
ticks every second via TimelineView(.periodic(by: 1)) — any cost concern versus the old 60 s
tick, and does `elapsedSeconds` handle a workout whose startedAt is in the future (clock skew)?
(3) `Format.elapsed` at ≥ 1 h ("1:02:03") next to the rest bar's `Format.duration` ("m:ss") —
consistent enough? (4) the accessibility label reads whole minutes while the text shows seconds
— acceptable, or should VoiceOver hear the seconds? (5) item 9 — the AXL captures; (6) item 11 —
no string or identifier changed (the header's old "N min" text was never queried; verify).
Do NOT run xcodebuild or simctl; do not modify source files. Report by severity with
file:line, or say "clear" in one paragraph. Write to work-record/ui-redesign/codex-review-16.md
