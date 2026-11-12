# Codex review — N13 goal setup, round 2

Same checkout and branch. Round 1: `work-record/nutrition/codex-review-n13.md` (not clear: R1–R5). Review the fix
commit(s) since `967d613c` (`git diff 967d613c..HEAD`) and the ticket's "Codex round 1 … fixed" section.

Check that R1–R5 are resolved without regressions: `GoalSetupDraft` now keeps entered pairs (height, weight, desired)
and derives the display; the flow's bindings (`heightCm` / `heightInches` wheels, `weightText`, `stepWeight`,
`stepDesired`, `switchUnits`) still behave; `selectableDesired` / `goalBlocked` / `desiredAtLowest`; the commit sees
unchanged pairs as unchanged; the new tests really cover your repro cases (your `/tmp/codex-n13/Repro.swift` harness may
help); the migration refresh assertion; the R3 labels.

Per AGENTS' reviewer rule: build and run the **Unit plan**; the fix changes UI behaviour and UI test code, so rerun
`AAAWarmUpUITests` + `GoalSetupUITests` (ProfileAI plan, 2 workers) and look at the new scrolled AXL captures. Claude's
evidence: `/tmp/n13-unit3.xcresult`, `/tmp/n13-ui3.xcresult`. Claude runs nothing while you run. Do not modify files
other than the report; do not commit or push.

Append a "Round 2" section to `work-record/nutrition/codex-review-n13.md` (new findings with file:line, failure scenario,
fix; Verified / Not verified / Known flaky) and end the file with exactly `Verdict: clear` or `Verdict: not clear`.
