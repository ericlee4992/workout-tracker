# Codex review — nutrition N8, round 4

Same branch. Your round-3 report: `work-record/nutrition/codex-review-n8-c.md` (R3-S1). Review the fix:
`git diff e7a7b28..HEAD` — server only (`food.ts`: `unitIn`, `offUnits`, `fromOpenFoodFacts`; the matrix test in
`server/test/food.test.ts`). Rerun your `/tmp/codex-n8-r3/` unit-consistency and serving-matrix probes against it.

Per AGENTS' reviewer rule: server tsc + `npm test`. No app, UI or UI-test source changed since round 3 (`git diff
e7a7b28..HEAD --stat`), so do not rebuild or rerun Unit/UI; say so in the report. Do not modify files other than the
report; do not commit or push.

Write `work-record/nutrition/codex-review-n8-d.md`: findings with file:line, failure scenario and fix; Verified / Not
verified / Known flaky; end with exactly `Verdict: clear` or `Verdict: not clear`.
