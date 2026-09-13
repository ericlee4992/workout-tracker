Round 1 (T6) of UI-redesign tickets 04 + 05 — the gear button on the Workout tab and the Settings
screen it opens, on the Ink / Amber design system (which YOU built; Claude built this ticket, so
you review). Ticket: work-record/ui-redesign/issues/04-05-start-and-settings.md; the plan:
work-record/ui-redesign/spec.md (tickets 04 and 05, and the constraints — copy policy, ids/strings the
tests read, "Settings move: tests rewritten in the same commit").
Boundary: f80b00a..HEAD on branch ui-redesign-05 (main is at f80b00a = ticket 03; two commits).

Files: WorkoutTracker/Features/Settings/SettingsView.swift (new),
Features/Start/StartWorkoutView.swift (toolbar gear `openSettings`; resume banner's pulsing dot),
Features/Gyms/GymsView.swift (loses AppSettingsSection + ExportSection),
WorkoutTrackerUITests/{HeartRateUITests,AskAIUITests,ExportUITests,RedesignScreenshotUITests}.swift.
Screenshots: work-record/ui-redesign/screenshots/05/05-settings.png and 04-start.png.

Scope:
1. Presentation: `AppSettingsSection` hangs its two `.sheet`s off ROWS (a Section-level sheet
   never presents inside a List). Inside a pushed `SettingsView` in the Workout tab's
   `NavigationStack`, is there any way those sheets — MaxHeartRateSheet, AskAISettingsSheet — or
   ExportSection's share sheet fail to present or present twice? Any state that the old
   Gyms-tab home relied on (environment, `@Query`) that the new home lacks?
2. Navigation: the gear is a `NavigationLink` in the toolbar. When a workout is started from the
   Start screen while Settings is pushed (can it be?), or a workout is resumed via the resume
   dialog, does the pushed Settings screen interfere with `onWorkoutStarted` / the full-screen
   workout cover? Check `RootView` / wherever `StartWorkoutView(onWorkoutStarted:)` is hosted.
3. Are ALL the ways in updated? grep the UI tests for `Gyms` taps that expected Settings/Export
   rows (`heartRateZonesSettings`, `askAISettings`, `exportSummary`, `exportCSV`, `exportJSON`,
   `dumbbellMoveNote`) — anything left pointing at the Gyms tab?
4. Copy policy: new strings are "Settings" (toolbar accessibility label + navigation title); the
   `AppSettingsSection` "Settings" header was REMOVED (it doubled the title). Any other new or
   lost string? Anything (test, doc) that expected that header?
5. The pulsing dot (`symbolEffect(.pulse, options: .repeating)` on a `circle.fill`): is it hidden
   from accessibility, does it respect Reduce Motion (SwiftUI symbol effects do by default — confirm
   or correct), and is the resume row's accessibility label unchanged (`resumeWorkout` test)?
6. SPEC.md / DECISIONS.md: does any doc still say Settings/Export are on the Gyms screen? List
   file:line if so.

Do NOT run xcodebuild or simctl (the simulator is in use). Review by inspection; verification is
in the ticket. Report by severity with file:line, or say "clear" in one paragraph. Do not modify
source files. Write to work-record/ui-redesign/codex-review-0405.md
