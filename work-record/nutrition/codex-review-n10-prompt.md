# Codex review — nutrition N10 (Progress body and food charts, History food line)

You are the independent reviewer; Claude implemented. Same checkout, branch `ericlee4992/nutrition-10-progress` (on
`main` `54d5f80`). Review `git diff 54d5f80..HEAD`.

Read first: `work-record/nutrition/issues/10-progress-history-nutrition.md` (Scope; Progress: the user's choices of
2026-11-11 — one Nutrition tab with Body and Food groups, a day's food page — built, own decisions, new strings, design,
evidence), decisions D63 (pins in UserDefaults), D70 (dated goals), D71, D52, D80; the approved prototype at tag
`design/soft-approved-2026-11-07` (`DesignPrototype/Sources/Screens/Soft/SoftProgressBoard.swift` `SoftChartCard`,
`SoftAddChartSheet`; `SoftRound3Screens.swift` History day card); `.claude/skills/ios-design/REVIEW.md`; swiftui-pro /
swiftdata-pro apply.

Check in particular:
1. `Domain/NutritionProgress.swift` + `NutritionProgressTests`: trend smoothing (window over weigh-in days), weekly rate,
   change, food days (each day's own goal, days without food, timezone/day bounds), averages, macro shares and percents,
   `HistoryFoodLine`, `FoodDayMath.loggedDays`.
2. Pins (`Domain/ProgressPins.swift`): the `nutrition.<chart>` encoding — old pins decode, an older build skips the new
   ones without dropping the rest, unknown charts skipped.
3. Readings and charts (`Features/Progress/ProgressPanel.swift` styles `.bars` / `.macros`, `NutritionProgressReading.swift`,
   `NutritionProgressView.swift`): figures and captions, units (lb/kg), goal line, x-domain, empty and single states, AX.
4. History (`HistoryOverviewMath.journal(_:foodDays:)`, `HistoryView`, `HistoryFoodRow`, `DayFoodView`): food-only days,
   panel rows (first/last), the empty state now also waits for food, navigation to the day page, editing and Undo there,
   the fuel card's past-day wording (`TodayFuelCard.isToday`); the shared `FoodDeletedToast` (Today unchanged).
5. `SegmentedPills` `wraps` (opt-in; every other use must draw exactly as before).
6. Performance: queries of all entries/weights in Progress and History (re-renders), `foodDays` loops.
7. Tests: `NutritionProgressUITests` (flows + captures), the fixture `-uiTestNutritionCharts`, test-plan mapping.

Per AGENTS' reviewer rule (round 1): build; Unit plan; UI: `AAAWarmUpUITests`, `NutritionProgressUITests`,
`FloodlightProgressUITests`, `FloodlightHistoryUITests`, `TodayFoodUITests` (2 workers; rerun failures serially).
Claude's evidence: `/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/20f5b25b-92e7-448e-a00d-dbd68fee92a9/scratchpad/` (`n10-unit`, `n10ui`, `n10-hp`, `n10-today` `.xcresult`; captures `n10att/`, `n10att2/addchart.png`).
WT-iPhone27 with `scripts/prepare-test-simulator.sh <udid>` first; paths under `/tmp/codex-n10/`. Claude runs nothing
while you run. Do not modify files other than the report; do not commit or push.

Write `work-record/nutrition/codex-review-n10.md`: findings P1/P2/P3 with file:line, failure scenario and fix; a
Verified / Not verified / Known flaky block; end with exactly `Verdict: clear` or `Verdict: not clear`.
