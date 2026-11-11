# Codex review — C1 + N9b, round 2

Same checkout and branch (`ericlee4992/c1-n9b`). Your round-1 report: `work-record/nutrition/codex-review-c1-n9b.md`
(not clear: T1, S1–S7). Claude's fixes are in the commits after `09e471b`; review `git diff 09e471b..HEAD` and the
round-1 note at the end of `work-record/nutrition/issues/09-body-weight-health.md` (how each finding was fixed, the
tests added, evidence).

Check each finding is fixed without new defects — in particular the generation checks in `HealthSync` (every await
in a pass and in `refreshBurned`; `CancellationError` handling and the extra pass it asks for), the continuation after
the three-pass limit, version choice and read-back of sample ids (`reconcile`), the exactness of `same(_:_:)` against
HealthKit's own unit conversion (kg ↔ lb entries, kcal), unit conversion of Health rows keeping `normalizedKg` exact,
and that nothing else sends a Health-read weight off the phone (`latestWeight` vs `latestEnteredWeight` callers).
Your own probes under `/tmp/codex-c1n9b/` may be rerun against the new code.

Per AGENTS' reviewer rule: build; Unit plan; `HealthNutritionSyncTests` ×10. UI: the fixes changed the Ask AI sheet's
prefill glue (`AIRoutineSheet` → `AIRoutineFlowModel.prefillMissingMeasurements(from:)`) and no view — rerun
`AAAWarmUpUITests`, `AppleHealthUITests`, `FloodlightAIRoutineUITests` (2 workers). Claude's evidence:
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/20f5b25b-92e7-448e-a00d-dbd68fee92a9/scratchpad/`
`r2-health10`, `r2-unit`, `r2-ui` `.xcresult`. WT-iPhone27 with `scripts/prepare-test-simulator.sh <udid>` first;
paths under `/tmp/codex-c1n9b-r2/`. Do not modify files other than the report; do not commit or push.

Write `work-record/nutrition/codex-review-c1-n9b-b.md`: findings P1/P2/P3 with file:line, failure scenario and fix; a
Verified / Not verified / Known flaky block; end with exactly `Verdict: clear` or `Verdict: not clear`.
