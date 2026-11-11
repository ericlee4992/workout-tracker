# Codex review — nutrition N8, round 3

Same branch. Your round-2 report: `work-record/nutrition/codex-review-n8-b.md` (R2-S1, R2-S2, the 900-kcal advisory).
Review the fixes: `git diff 9b754ab..HEAD` (server `food.ts` serving unit and `NOT_FOUND`; app
`DatabaseFood.maxPer100gCalories`; tests). Rerun your `/tmp/codex-n8-r2/` probes (serving-volume, OFF-200-null) against
the new code.

Per AGENTS' reviewer rule: server tsc + `npm test`; build; Unit plan. No UI code or UI test changed this round, so
inspect Claude's xcresult instead of rerunning UI (round 2's `r2-ui.xcresult` is the last UI run; the app change is a
constant). Claude's evidence: `r3-unit.xcresult` in the same scratchpad. Do not modify files other than the report; do
not commit or push.

Write `work-record/nutrition/codex-review-n8-c.md`: findings with file:line, failure scenario and fix; Verified / Not
verified / Known flaky; end with exactly `Verdict: clear` or `Verdict: not clear`.
