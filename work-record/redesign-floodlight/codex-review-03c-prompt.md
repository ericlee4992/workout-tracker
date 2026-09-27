Re-review (round 3) of ticket 03, Floodlight live workout, branch
`ericlee4992/redesign-floodlight-live` in `/tmp/wt-floodlight/live`. Your round-2 report is
`work-record/redesign-floodlight/codex-review-03b.md` (one medium: the band could announce a
revoked best; plus the `badgeInputs` completeness note). Fix range: `e6facea..HEAD`. Read the
"Codex review 03b — response (round 2)" section and the round-3 verification line in
`issues/03-live-workout.md`.

Check: `ActiveWorkoutView.reconcileFreshBest()` / `freshBest(for:)` — every path you listed
(warmup, delete set, delete exercise, un-log, correction below / still above the record) now
removes or updates the band, the original expiry is kept, and no second celebration or loop can
start; the widened `badgeInputs`; the `-uiTestLongCelebration` test hook (test-only, harmless in
production?) and the three new regressions (do they fail without the fix?).

Do NOT run xcodebuild or simctl. Do not modify files other than the report. Findings by severity
with file:line and a concrete failure case, or "clear" in one paragraph. Write the report to
`work-record/redesign-floodlight/codex-review-03c.md`.
