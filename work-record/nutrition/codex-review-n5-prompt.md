# Codex review — nutrition N5 (Today's food parts)

You are the independent reviewer; Claude implemented. Same terminal and rules as N4. Checkout
`/Users/ericlee06/orca/workspaces/Health App/UI_design`, branch `ericlee4992/nutrition-05-today` (off `main` `c03bd12`).
Review `git diff c03bd12..HEAD`.

Read first: `work-record/nutrition/issues/05-today-food.md` (scope, the two items moved from N4, Progress: built, own
decisions, new strings, fixture, evidence), decisions D70 (dated goals), D71 (burned shown, never added), D67 (macro
hues on icons/rings only), D68 (Today), the approved prototype at tag `design/soft-approved-2026-11-07`
(`DesignPrototype/Sources/Screens/Soft/SoftTodayTop.swift`, `SoftTodayScreen.swift`), `work-record/nutrition/spec.md`,
`.claude/skills/ios-design/REVIEW.md` for the screens; swiftui-pro / swiftdata-pro apply (project rules override). The
user is asleep and gave standing permission to build and merge on your clear; strings are for the morning.

Check in particular:
1. **Math** (`Domain/FoodDay.swift`, `FoodDayTests`): totals = per serving × servings; left/over/fill against the goal
   in force on each day (a goal changed mid-week; a goal created today vs past days); macro shares 4/4/9 and a
   calories-only day; burned (workout energy, else cardio segments; nil ≠ 0) never added; days logged; day boundaries
   and time zones.
2. **Entry edit / delete / Undo** (`FoodLog.update`, `delete`, `restore`; `EditEntrySheet`): unchanged numbers keep
   stored values; the sheet never reads a deleted entry; Undo restores the same id, times, Health sample id and food
   link (only while the food exists); the toast timer.
3. **Today** (`TodayView`, `TodayPieces`, `TodayFood`): the rings (dashed now means "no food" — a trained day without
   food is dashed with its disc; is that the spec's intent?), the key, the header, AX rows; the fuel card at default and
   AX (one hero), "Set your goals" → Nutrition goals; today's log by meal with stable order; workouts' calories;
   accessibility labels/identifiers; Reduce Motion; the all-entries `@Query` (performance with a long history).
4. **Fixture** `-uiTestFoodDiary` / `-uiTestFoodOver` gated by `fixtureIsEnabled`; the goal back-dating only in UI tests.
5. **README** "Five tabs" and "Food logging".

Per AGENTS' reviewer rule (round 1): build; Unit plan; UI classes `AAAWarmUpUITests`, `TodayFoodUITests`,
`TodayUpNextUITests`, `LogFoodFlowUITests`, `NutritionGoalsUITests` (2 workers; rerun failures serially). Claude's
evidence: scratchpad
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/d3ab4aaa-bbbb-43da-8c54-44b94b2255ab/scratchpad/`
(`n5u`, `n5ui`, `n5unit`, `n5reg` `.xcresult`; captures `n5shots/`). Run on WT-iPhone27 with
`scripts/prepare-test-simulator.sh` first; paths under `/tmp/codex-n5/`. Claude runs nothing while you run. Do not
modify files other than the report; do not commit or push.

Write `work-record/nutrition/codex-review-n5.md`: findings P1/P2/P3 with file:line, failure scenario and fix; a
Verified / Not verified / Known flaky block; end with exactly `Verdict: clear` or `Verdict: not clear`.
