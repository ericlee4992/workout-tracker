# Codex review — ticket 19 (Add Chart grouped by body area)

You are the independent reviewer (AGENTS.md T6); Claude implemented this. This terminal is the one Codex session for
tickets 19–22 on branch `ericlee4992/beta-19-bug-fixes` (checkout `/Users/ericlee06/orca/workspaces/Health
App/beta-19-bug-fixes`); later prompts will ask for the next tickets. Do not touch the other checkout
`…/Health App/public-beta`.

Review the ticket-19 commit: `git diff 37a72d8..<the commit named in the ticket's Progress section>`.

Read first: `work-record/public-beta/issues/19-add-chart-body-areas.md` (the user's report, decision, acceptance,
verification), D63 in `docs/DECISIONS.md` (Add Chart), and AGENTS.md's code rules.

Check in particular:
1. **The rule.** `BodyArea.sections(of:group:)` (`Domain/CatalogBrowsing.swift`): head-to-toe order, other groups
   A–Z, "Uncategorized" last (nil and ""), incoming order kept inside a section. Is it exactly the rule the Add
   Exercise picker had before (`ExercisePickerSheet` now calls it — behaviour must be unchanged there)?
2. **Add Chart** (`Features/Progress/AddChartSheet.swift`): sections from the logged rows, most recently trained first
   within a section; search drops empty sections and still shows "No matches"; step 2 and Add unchanged; the
   `addChartExercise` identifiers still reachable by the existing UI tests; accessibility (section headers are
   headers; VoiceOver order) and AccessibilityL layout.
3. **Tests.** `WorkoutTrackerTests/BodyAreaSectionsTests.swift` covers the claims.

Run yourself: `xcodebuild … build` and `-only-testing:WorkoutTrackerTests/BodyAreaSectionsTests
-only-testing:WorkoutTrackerTests/CatalogBrowsingTests` on an iOS 27 simulator (WT-Floodlight
`9E822EF6-DC67-4958-AEA2-D53D2D36D674`; your own `-derivedDataPath` and `-resultBundlePath` under `/tmp/codex-19/`),
and report exit codes. UI tests are optional; say if you skip them. Do not modify files other than the report; do not
commit or push.

Write `work-record/public-beta/codex-review-19.md`: findings numbered P1/P2/P3 with file:line, failure scenario and fix;
end with exactly `Verdict: clear` or `Verdict: not clear`.

## Round 2

Round 1: [codex-review-19.md](codex-review-19.md), not clear (P3 README). Claude's response: the ticket's "Codex
round 1" section and `git diff 9db69e7..HEAD` (README only). Check the finding is closed (including Claude's reason for
not adding a screenshot) and nothing else changed. No rebuild is needed for a README-only diff; say so. Write
`work-record/public-beta/codex-review-19b.md`, ending with exactly `Verdict: clear` or `Verdict: not clear`. Do not
commit or push.
