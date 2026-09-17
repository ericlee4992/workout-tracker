# Claude independent review — ticket 17, gate addendum

Reviewer: Claude (T6; Codex implemented). Written 2026-09-17 after the full UI suite finished.
Follows `claude-review-17.md` (initial) and `claude-review-17-final.md` (code/visual clearance,
written while the suite was running). Both are preserved unchanged and are identical to the copies
committed in the implementation branch at `2633b1d`. I read the artifacts myself, read-only, in
`finish-summary-order/work-record/ui-redesign/results/17/`; I ran no tests and changed no source.

## Merge clearance

**CLEAR to merge source `4d70d7d`.** No open findings. Code/contract, default and AccessibilityL
visuals, focused evidence and the full UI suite are all clear on that source.

## What I verified

| Check | Evidence | Result |
|---|---|---|
| Exit statuses | `status.txt`: `BUILD 0`, `FOCUSED 65`, `AXL_RETRY 0`, `FULL_UI 0`; runner PID 15547 exited | full suite exit 0; the red focused run is kept on record |
| Log result | `full-ui.log`: 72 started, 72 passed, 0 failed; `:9544` `Executed 72 tests, with 0 failures (0 unexpected) in 2473.685 s`; `:9554` `** TEST EXECUTE SUCCEEDED **`; suite 18:07:21 → 18:48:35 EDT | pass |
| Result bundle | `full-ui.xcresult` summary: result Passed, total 72, passed 72, failed 0, skipped 0, expected failures 0, 0 test failures | pass |
| Coverage | `Class method` names declared in `WorkoutTrackerUITests/*.swift` (72) diffed against the distinct passed names in the log (72): identical sets, none missing, none unexpected | pass |
| Callers of the reordered tiles | `HeartRateSummaryUITests` 3/3, `HeartRateUITests` 5/5, `HistoryTemplateUITests` 3/3 (incl. `testTheFinishSheetStillSavesATemplate`), `test02_activeWorkoutAndFinish`, `test03_finishSummaryLargeText` (64.1 s) | all passed |
| Source identity | Implementation HEAD `2633b1d`; `git diff --name-only 4d70d7d..2633b1d` lists only `docs/` and `work-record/` paths; no uncommitted change under app/test source or the project | product and test source are `4d70d7d` |
| Binary freshness | Changed Swift files last modified 18:01:30, before the runner started (18:01:50); no Swift file is newer than the runner start; build products 18:02; retry and full suite used `test-without-building` on that derived data | the suite ran the reviewed source |
| Runtime warnings | 22 × "Invalid frame dimension (negative or non-finite)" in the xcresult, non-failing | same count STATE records for the 72/72 run on `0b6515f` (ticket 16) — pre-existing, not introduced here; origin still uninvestigated |

## Findings — final status

- F0 (focused run red once): closed. AccessibilityL flow samples on unchanged source: 1 setup
  keyboard-focus failure (`RedesignScreenshotUITests.swift:495`, before the finish sheet), then 2
  passes (isolated retry, full suite). Keep it recorded as a one-off intermittent in untouched setup
  code; if it recurs in a later ticket it deserves its own diagnosis.
- F1 (capture completeness not asserted): visual concern closed in the final report; optional
  hardening remains optional.
- F2: closed. A1–A3: advisory notes only, no action for this ticket.

## Remaining (housekeeping, not review findings)

The ticket and STATE in `2633b1d` still say the suite is running — true when committed. Record
`FULL_UI 0`, 72/72, the finish time and the 22 pre-existing warnings, set the ticket status, then
fast-forward and push per AGENTS and confirm the remote tip. Those are docs-only commits and do not
affect this clearance; any product or test source change would need re-review. No phone install is
part of this ticket; installed source stays `0b6515f`.
