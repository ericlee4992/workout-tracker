# Codex review — ticket 20 (delete one cardio activity in History)

Same session and rules as ticket 19 (you are the independent reviewer; Claude implemented). Branch
`ericlee4992/beta-19-bug-fixes`, checkout `/Users/ericlee06/orca/workspaces/Health App/beta-19-bug-fixes`.

Review the ticket-20 commit: `git diff 0e22935..<the commit named in the ticket's Progress / Verification section>`.

Read first: `work-record/public-beta/issues/20-delete-cardio-in-history.md` (the user's report and decision, build
notes, verification), D47/D50 (history editing is marked and confirmed) and D64 (cardio-only time) in
`docs/DECISIONS.md`, and AGENTS.md's code rules.

Check in particular:
1. **Domain.** `HistoryEditing.deleteCardio(_:in:at:)` and `isOnlyContent(_:)` (`Domain/HistoryEditing.swift`):
   refuses a running workout and the only content; marks the edit; nothing else of the workout is touched (heart-rate
   samples, entries, planned cardio). Is "only content" right for every finished workout shape (cardio-only with one
   or several segments, unrecorded segments with no activity, a workout whose entries have no completed set)?
2. **Everything derived from cardio after a delete.** The detail's hero choice and tiles (D64: one-segment hero vs
   the time tile), Splits, the History row and month/week totals (`HistoryOverviewMath.facts`, keyed on
   `historyEditedAt`), Progress cardio charts, the finish receipt (unchanged), export. Any cache that keeps the deleted
   segment, or a view that touches a deleted `CardioSegment` (SwiftData: `isDeleted` is false after the save).
3. **UI.** `CardioDeleteMenu` on `CardioSummaryCard` and `CardioHistoryHero` (the route-map overlay and the title-row
   variant), accessibility (the header's combined element no longer contains the menu; labels; AccessibilityL), the
   receipt passes no action. The "Delete this cardio?" confirmation and its copy (`HistoryDeleteCopy.cardio`); the
   only-content path opens the existing Delete Workout confirmation.
4. **Tests.** `WorkoutTrackerTests/CardioHistoryDeleteTests.swift` and `WorkoutTrackerUITests/
   CardioHistoryDeleteUITests.swift` cover the claims.
5. No stored-format change (no Gate S).

Run yourself: `xcodebuild … build` and `-only-testing:WorkoutTrackerTests/CardioHistoryDeleteTests
-only-testing:WorkoutTrackerTests/CardioOnlyTimeTests -only-testing:WorkoutTrackerTests/ReorderAndHistoryStructureTests`
on WT-Floodlight `9E822EF6-DC67-4958-AEA2-D53D2D36D674` (your own paths under `/tmp/codex-20/`), and report exit
codes. UI tests are optional; say if you skip them. Do not modify files other than the report; do not commit or push.

Write `work-record/public-beta/codex-review-20.md`: findings numbered P1/P2/P3 with file:line, failure scenario and fix;
end with exactly `Verdict: clear` or `Verdict: not clear`.

## Round 2

Round 1: [codex-review-20.md](codex-review-20.md), not clear (P2 route/splits test, P3 README). Claude's response: the
ticket's "Codex round 1" section and `git diff 19438e7..HEAD`. Check both are closed and nothing regressed; rerun
`-only-testing:WorkoutTrackerTests/CardioHistoryDeleteTests -only-testing:WorkoutTrackerTests/CardioExportTests`
(same rules, a new result path). Write `work-record/public-beta/codex-review-20b.md`, ending with exactly
`Verdict: clear` or `Verdict: not clear`. Do not commit or push.
