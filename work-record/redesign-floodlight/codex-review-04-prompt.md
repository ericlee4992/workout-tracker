Independent review (T6) of ticket 04 of the Floodlight redesign: the finish receipt, on branch
`ericlee4992/redesign-floodlight-finish`. Range: `ericlee4992/redesign-floodlight-live..HEAD`
(the branch is stacked on ticket 03's live branch). Claude implemented; you review. Run in the checkout `/tmp/wt-floodlight/finish`
and stay in it.

Read first: AGENTS.md; `work-record/redesign-floodlight/issues/01-implement-redesign.md` (user
decisions); `issues/04-finish.md` (scope, kept rules, user decisions of 2026-09-26, strings,
verification); `reference/look-api.md`, `reference/brief/constraints.md` §1–2,
`reference/brief/domain-data.md` §3. Approved screen: `reference/captures/{dark,light}/F01-final.png`;
prototype source (read-only) `/Users/ericlee06/orca/workspaces/Health App/redesign-prototype/RedesignPrototype/Sources/Screens/Finish/`.
Actual captures: `captures/04/`. Old sheet: `git show ericlee4992/redesign-floodlight-live:WorkoutTracker/Features/ActiveWorkout/WorkoutFinishedSheet.swift`.

Review for:
1. Derived data (`Domain/FinishReceipt.swift`, `SetBadgeMath.outcomes/workoutBest`,
   `FinishReceiptTests`): one new-best line per record scope against the pre-workout record;
   history limited to sets completed before the workout started; assisted lower-is-better,
   warmups, bodyweight, bar mode (does a history best logged in bar mode display correctly?),
   units as entered (D25/D52); families from the live `muscleGroup` (documented exception);
   the ring = completed sets; exercise rows' best set and mark; comparison with the template's
   previous run (which run, volume rules, zero-volume cases). Any case where a number is wrong.
2. Behaviour preserved: template drift dialog before the receipt, empty finish (A2), Save as
   Template, View in History, Done, heart-rate chart/zones conditions, cardio summaries, the
   "Lifting"/"Exercises" heading, identifiers the UI tests use. The shared
   `HeartRateSummarySection` gained a `.receipt` style — is History's `.listSection` unchanged?
3. Look and accessibility: light/dark, AXL layouts, VoiceOver labels of the ring/key, best rows,
   comparison bars; 44 pt targets; Reduce Motion; strings listed vs actual.
4. Performance: the receipt is built once per saved workout (`@State`, on appear / id change)
   and `SetBadgeMath.receiptMarks` fetches history once per entry. Still acceptable as history
   grows? Can the cached receipt go stale while the sheet is up (e.g. Save as Template)?
5. Verification scope per DEVELOPMENT, and any product change ticket 04 does not list.

Do NOT run xcodebuild or simctl. Do not modify files other than the report. Report findings by
severity (critical / high / medium / low) with file:line and a concrete failure case, or say
"clear" in one paragraph. Write the report to `work-record/redesign-floodlight/codex-review-04.md`.
