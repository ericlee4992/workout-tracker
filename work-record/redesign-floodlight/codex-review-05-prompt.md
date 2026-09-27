Independent review (T6) of ticket 05 of the Floodlight redesign: History, on branch
`ericlee4992/redesign-floodlight-history`. Range: `ericlee4992/redesign-floodlight-finish..HEAD`
(the branch is stacked on ticket 04's finish branch). Claude implemented; you review. Run in the
checkout `/tmp/wt-floodlight/history` and stay in it.

Read first: AGENTS.md; `work-record/redesign-floodlight/issues/01-implement-redesign.md` (user
decisions); `issues/05-history.md` (scope, kept rules and identifiers, user decisions of
2026-09-27, strings, tells, verification); `.claude/skills/ios-design/REVIEW.md`;
`reference/look-api.md`, `reference/brief/constraints.md` §1–2, `reference/brief/domain-data.md` §3;
DECISIONS D23, D36, D39, D47, D50, D51, D52. Approved screens: `reference/captures/{dark,light}/H01-final.png`,
`H03-final.png`; prototype source (read-only)
`/Users/ericlee06/orca/workspaces/Health App/redesign-prototype/RedesignPrototype/Sources/Screens/History/`.
Actual captures: `captures/05/`. Old screens: `git show ericlee4992/redesign-floodlight-finish:WorkoutTracker/Features/History/<file>`.

Review for:
1. Derived data (`Domain/HistoryOverview.swift`, `SetBadgeMath.newBestCounts`,
   `ProgressSeriesMath.scoped/recordDays/change(first:last:)`, `HistoryEditing.addSet/
   pruneAbandonedSet/setNotes`, and their tests): month/day/week figures (start-day rule, the
   calendar's first weekday, a week across a month end), sets counted consistently between row,
   month card, calendar and ring, new-best counts per workout judged only against the past (ties,
   first time, assisted, warmups; does it agree with the receipt's "New bests"?), volume rules,
   unit badge, the progress chart's record days and per-metric change. Any case where a number
   is wrong or two screens disagree.
2. History edits (D47/D50 and the user's 2026-09-27 notes decision): every mutation marked;
   snapshots never re-resolved; an abandoned Add Set / Add Exercise leaves nothing; set delete
   (swipe and the sheet's Delete Set) prunes an emptied exercise and says so; retype refusal;
   rename; notes; the detail's cached receipt/marks refresh after each edit.
3. Behaviour preserved and identifiers the UI tests use (list in the ticket): swipe-to-delete on
   rows and sets with confirmations, C2 "View in History", the calendar's push-after-dismiss and
   `destinationAfterCalendar`, progress chart variation scoping (D36), as-entered values (D25),
   the convert toggle (display only), bar breakdown (D39), D51 reclassified line, the finish
   receipt's shared heart-rate plate and tiles (`FinishTile.summaryTiles`). The empty History's
   Start Lifting path (RootView → StartWorkoutView) — any way it double-starts or misfires?
4. Look and accessibility per REVIEW.md: the bold element per screen, grouping (panel rows drawn
   with `historyPanelRow`), light/dark, AXL layouts, VoiceOver (rows now read their texts; set
   lines, calendar cells, chart adjustable action), 44 pt targets, Reduce Motion, strings listed
   vs actual.
5. Performance: facts rebuilt on history signature changes; the detail's receipt/marks on edit;
   the progress view's history reads per render. Acceptable as history grows?
6. Verification scope per DEVELOPMENT, and any product change ticket 05 does not list.

Do NOT run xcodebuild or simctl. Do not modify files other than the report. Report findings by
severity (critical / high / medium / low) with file:line and a concrete failure case, or say
"clear" in one paragraph. Write the report to `work-record/redesign-floodlight/codex-review-05.md`.
