# Codex review — C1 + N9b, round 3

Same checkout and branch (`ericlee4992/c1-n9b`). Your round-2 report: `work-record/nutrition/codex-review-c1-n9b-b.md`
(not clear: R2-S1). Review `git diff 4605b1b..HEAD` and the round-2 note at the end of
`work-record/nutrition/issues/09-body-weight-health.md`.

Check R2-S1 is fixed without new defects: `HealthSync.refreshBurned` (request number, latest-only publish, the part's
generation, task cancellation — including a cancelled latest request leaving the earlier value until the next refresh),
the fake's `answerEnergy`, and the test `anOlderBurnedAnswerNeverReplacesANewerOne`. Your burned-order probes under
`/tmp/codex-c1n9b-r2/` may be rerun.

This fix round changed no view or UI test: per AGENTS' reviewer rule, build, run the Unit plan and
`HealthNutritionSyncTests` ×10 yourself, and inspect the UI evidence instead of rerunning UI (`r2-ui.xcresult` 20/20 and
your own round-2 serial rerun). Claude's evidence:
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/20f5b25b-92e7-448e-a00d-dbd68fee92a9/scratchpad/`
`r3-health10`, `r3-unit` `.xcresult`. WT-iPhone27 with `scripts/prepare-test-simulator.sh <udid>` first; paths under
`/tmp/codex-c1n9b-r3/`. Do not modify files other than the report; do not commit or push.

Write `work-record/nutrition/codex-review-c1-n9b-c.md`: findings P1/P2/P3 with file:line, failure scenario and fix; a
Verified / Not verified / Known flaky block; end with exactly `Verdict: clear` or `Verdict: not clear`.
