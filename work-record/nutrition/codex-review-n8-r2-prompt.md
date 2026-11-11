# Codex review — nutrition N8, round 2

Same branch `ericlee4992/nutrition-08-barcode`. Your round-1 report: `work-record/nutrition/codex-review-n8.md`
(5 P2, 2 P3). Review the fixes: `git diff c9fd8a0..HEAD`. The ticket's "Codex round 1" section says how each finding
was fixed.

Check each of S1–S6 and T1 is fixed without regressions — rerun your offline probes under `/tmp/codex-n8/` against the
new code (`food.ts` now exports `sameGTIN`; the wire shape adds `per100Unit`); the new server tests in
`server/test/food.test.ts` (EAN-8 padded forms, drinks by volume, malformed replies, the barcode-free error log,
impossible numbers); the app's `DatabaseFood(json:)` bounds and `storedServing` for ml; `LogFoodView` credits and the
online row's check; tests `FoodDatabaseTests` (2 new), `BarcodeSearchUITests` (`testAnOnlineRowShowsItsCheckUntilUndo`,
the credit in the found test).

Per AGENTS' reviewer rule: server tsc + `npm test`; build; Unit plan; UI changed, so rerun `BarcodeSearchUITests`,
`LogFoodUITests`, `LogFoodFlowUITests` (2 workers). Claude's evidence: scratchpad `r2-unit.xcresult`, `r2-ui.xcresult`
(same scratchpad as round 1). Claude runs nothing while you run. Do not modify files other than the report; do not
commit or push.

Write `work-record/nutrition/codex-review-n8-b.md`: findings with file:line, failure scenario and fix; Verified / Not
verified / Known flaky; end with exactly `Verdict: clear` or `Verdict: not clear`.
