# Codex review — nutrition N9a (body weight logging)

You are the independent reviewer; Claude implemented. Back in this checkout:
`/Users/ericlee06/orca/workspaces/Health App/UI_design`, branch `ericlee4992/nutrition-09-weight-health` (on `main`
`d38cf18`). Review `git diff d38cf18..HEAD`.

Read first: `work-record/nutrition/issues/09-body-weight-health.md` (the N9a / N9b split and why; Progress: built, own
decisions, the open question about N3's refresh, new strings, evidence), decisions D52 (plain numbers; units kept),
D70 (dated goals), D80 (Profile grouping), the prototype's Log weight sheet at tag `design/soft-approved-2026-11-07`
(`DesignPrototype/Sources/Screens/Soft/SoftProfileAndAdd.swift` `SoftLogWeightSheet`),
`.claude/skills/ios-design/REVIEW.md`; swiftui-pro / swiftdata-pro apply. The user is asleep; strings are for the
morning. Apple Health (N9b) is out of this review.

Check in particular:
1. `Domain/BodyWeightLog.swift` + `BodyWeightLogTests`: entered `(value, unit)` and `normalizedKg` kept in step; the
   2 kg rule in kg whatever the unit; ranges and steps.
2. `Features/Nutrition/BodyWeightView.swift`: the sheet's field/stepper sync (typing vs ± rounding to 0.1; a typed
   value outside the range; editing an entry in another unit than the app's), no deleted-model reads after Delete, the
   Recalculate card (runs N3's `NutritionGoalStore.update` — interaction with N3's goals-page refresh, which already
   recalculates from the latest weight: is the offer meaningful? the ticket records this as a question for the user),
   empty state, accessibility identifiers/labels, AX layout, Reduce Motion.
3. `ProfileTabView`: the new Goals & tracking row and navigation.
4. Tests: `BodyWeightUITests` (flow + captures), test-plan mapping.

Per AGENTS' reviewer rule (round 1): build; Unit plan; UI classes `AAAWarmUpUITests`, `BodyWeightUITests`,
`FloodlightProfileUITests`, `NutritionGoalsUITests` (2 workers; rerun failures serially). Claude's evidence in
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/d3ab4aaa-bbbb-43da-8c54-44b94b2255ab/scratchpad/`
(`n9u`, `n9ui`, `n9ui2`, `n9unit`, `n9reg` `.xcresult`; captures `n9att/N9.png`). WT-iPhone27 with
`scripts/prepare-test-simulator.sh` first; paths under `/tmp/codex-n9a/`. Claude runs nothing while you run. Do not
modify files other than the report; do not commit or push.

Write `work-record/nutrition/codex-review-n9a.md`: findings P1/P2/P3 with file:line, failure scenario and fix; a
Verified / Not verified / Known flaky block; end with exactly `Verdict: clear` or `Verdict: not clear`.
