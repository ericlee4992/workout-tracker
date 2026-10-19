# Codex review — ticket 21 (the Live Activity stays after cancelling a workout)

Same session and rules as tickets 19–20 (you are the independent reviewer; Claude implemented). Branch
`ericlee4992/beta-19-bug-fixes`, checkout `/Users/ericlee06/orca/workspaces/Health App/beta-19-bug-fixes`.

Review the ticket-21 commit: `git diff c3952da..<the commit named at the end of the ticket>`.

Read first: `work-record/public-beta/issues/21-live-activity-after-cancel.md` (report, cause with the probe and the
reproduction, build notes, verification), D46 (the app pushes, the system renders) in `docs/DECISIONS.md`, Floodlight
ticket 11's lock-screen commands (`WorkoutActivityCommands`), and AGENTS.md's code rules.

Check in particular:
1. **The cause.** Is the explanation right (cancel ends the card, then a push from the still-visible screen re-posts
   it because SwiftData's `isDeleted` is false after the save)? Any other path that could leave or bring back a card
   after cancel, finish, the templated finish, "Finish It & Start New", minimize → cancel, or a lock-screen command
   (`WorkoutActivityCommands.perform`) arriving for a workout that just ended?
2. **The controller** (`Domain/WorkoutActivityController.swift`): the `ended` set (is there any legitimate way a
   workout whose card was ended shows again — e.g. a finish that throws after `stopHeartRate`, a resumed workout?),
   `end(workoutID:)` sweeping when nothing is tracked vs. leaving another workout's card alone, `endAny()` →
   `endAll()`; the system presenter's `endAll()` (ending a card while a just-requested one is not yet listed, the
   Task ordering against a following `start`).
3. **Launch sweep** (`App/RootView.swift` `recoverActiveWorkout`): it must not end the card of a workout that IS live
   (a relaunch, or an app launched in the background by a lock-screen command), nor run in the guided tour.
4. **The screen guard** (`ActiveWorkoutView.pushActivityState`, `modelContext != nil`).
5. **Tests.** `WorkoutTrackerTests/WorkoutActivityTests.swift` (the four new cases fail without the fix?) and
   `WorkoutTrackerUITests/FloodlightSystemUITests.swift` `testRealLiveActivityEndsWhenTheWorkoutIsCancelled`.

Run yourself: `xcodebuild … build` and `-only-testing:WorkoutTrackerTests/WorkoutActivityTests
-only-testing:WorkoutTrackerTests/WorkoutActivityProviderTests -only-testing:WorkoutTrackerTests/WorkoutActivityContentTests
-only-testing:WorkoutTrackerTests/WorkoutActivityCommandsTests` (skip a suite that does not exist and say so) on
WT-Floodlight `9E822EF6-DC67-4958-AEA2-D53D2D36D674` (your own paths under `/tmp/codex-21/`), and report exit codes.
UI tests are optional; say if you skip them. Do not modify files other than the report; do not commit or push.

Write `work-record/public-beta/codex-review-21.md`: findings numbered P1/P2/P3 with file:line, failure scenario and fix;
end with exactly `Verdict: clear` or `Verdict: not clear`.
