You are the IMPLEMENTER this time (AGENTS.md: Codex implements, Claude reviews) for public-beta ticket 13, a bug the
user hit on TestFlight build 5. Repository: /Users/ericlee06/orca/workspaces/Health App/public-beta, branch
`ericlee4992/beta-13-goals-keyboard` (already checked out; HEAD `a3ebfc7`). Read first: AGENTS.md,
work-record/public-beta/issues/13-goals-keyboard.md (the report, the findings, the decision and the acceptance list),
then WorkoutTracker/Features/Templates/AIRoutine/AIGoalsStep.swift, AIRoutineSheet.swift, AIRoutineComponents.swift,
AIDayEditor.swift (its session-name Return pattern), and the ios-design skill (.agents/skills/ios-design/SKILL.md) for
the captures.

Do:
1. Implement decision items 1–5 of the ticket. Keep comments in the file's style; update the comment that explains why
   Next was hidden. No new dependencies; keep SwiftData/domain untouched.
2. Update the UI tests that assumed Next hides while typing or needed the toolbar Done; add a UI test for Return-dismiss
   (no newline left in the goal) and for tapping Next while the keyboard is up.
3. Verify on the iOS 27 simulator WT-iPhone27, id `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`:
   `xcodebuild build`, then `-only-testing:` WorkoutTrackerUITests/AskAIUITests, FloodlightAIRoutineUITests,
   FloodlightProfileUITests, plus the UI tests of any other screen you touch. Read each run's `** TEST …` line and
   failure count from the log yourself (a piped exit code can lie). Capture the Goals step with the keyboard up at
   Default and AccessibilityL, light and dark, and look at them.
4. Record in the ticket's Progress: what changed and why (including item 5's per-screen decisions and the newline
   choice), commands, exact results and capture paths. Commit on the branch and push. Do not merge to `main`, do not
   touch the phone, App Store Connect or the server.
5. When done, write a short summary to work-record/public-beta/codex-implement-13.md ending with the commit hash and a
   last line that is exactly "Status: ready for review" or "Status: blocked — <reason>".
