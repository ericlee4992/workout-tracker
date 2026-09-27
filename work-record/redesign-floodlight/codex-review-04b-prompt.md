Re-review (round 2) of ticket 04, Floodlight finish receipt, branch
`ericlee4992/redesign-floodlight-finish` in `/tmp/wt-floodlight/finish`. Your round-1 report is
`work-record/redesign-floodlight/codex-review-04.md`. Fixes: the commit after `743f609`
(range `743f609..HEAD`). Read "Codex review 04 — response (round 1)" and the round-2
verification in `issues/04-finish.md`.

Check each of your five findings and the performance note, and review the new code for
regressions: `RingRun` / `FinishStatusRing` (order, neutral colour, >24-set fallback, spoken
summary), `CountUpFormat.parse(locale:)` and `LookFormat.groupedDecimal` (every caller of
`CountUpFormat` / `ComparisonBars`, including History or Home if they use them), the new
`RecordSetInput.barWeightValue` (must never affect ranking or grouping; every construction
site), `LookFormat.set` now appending the bar (every caller — any place the suffix is wrong?),
the shared `finishedEntries` read, and the new tests (do they fail without the fixes?).

Do NOT run xcodebuild or simctl. Do not modify files other than the report. Findings by severity
with file:line and a concrete failure case, or "clear" in one paragraph. Write the report to
`work-record/redesign-floodlight/codex-review-04b.md`.
