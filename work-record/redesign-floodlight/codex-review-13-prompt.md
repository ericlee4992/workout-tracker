Independent review (T6) of ticket 13 of the Floodlight redesign — the release-candidate pass — on branch
`ericlee4992/redesign-floodlight-cardio`. Run in the checkout `/tmp/wt-floodlight/cardio` and stay in it. Claude ran
the pass and wrote the fix; you review. The code under review is `fe35a34` against `f4303ec` (`git diff
f4303ec fe35a34 -- WorkoutTracker WorkoutTrackerTests WorkoutTrackerUITests`); everything since `796ffe5` besides that
is ticket-13 documentation.

Read first: AGENTS.md; DEVELOPMENT.md "Verification scope" and "Simulator and UI-test pitfalls";
`work-record/redesign-floodlight/issues/13-release-candidate.md` (scope, the runs table, "Failures and causes",
"Fixes"). The full UI suite `rc-ui-1` passed 227/229; the two failures repeated alone; the fix is test and fixture
code only. Evidence (logs, `.exit` files, xcresult bundles) is in `/tmp/wt-floodlight/results/rc-*`; you may read
them (e.g. `xcrun xcresulttool get test-results summary --path …`) but do NOT run xcodebuild or simctl.

Review for:
1. **The diagnosis.** Are both failures really date-dependent test defects and not app bugs? Check
   `WorkoutCalendar` (months from the first workout's month through today's), `HistoryCalendarSheet` (the initial
   month, the chevrons' disabled state), `ChartFixture.script` (oldest 28 days), the History list's week grouping
   (`HistoryView`), and the recordings' evidence as the ticket describes it. Is there a date on which the app itself
   misbehaves here (e.g. a month the calendar should reach but cannot, the 1st of a month, a DST change)?
2. **The fixture change** (`Domain/ChartFixture.swift`): `-uiTestChartHistoryOlderMonth` is off in a real launch and
   without `-uiTestReset` (can it ever seed a real store?); the default parameter `includeOlderMonth:
   includesOlderMonth` evaluated per call; the added row's type/tag/preset (does it change any chart test that does
   not pass the argument, or `defaultVariation`?); "forty days back is always an earlier month" given
   `now − days × 86,400 s` across DST.
3. **The two tests.** `HistoryCalendarUITests`: the argument added in `setUp` for all three tests (does it change
   `testTappingAMarkedDayOpensThatSession` — e.g. on the 1st, where yesterday is in the previous month?); the paging
   test's forward step on the 1st and its wait for the label change (can it pass vacuously?).
   `ProgressChartTooltipUITests.testHistoryOpensTheChartOnThatSessionsVariation`: the date-prefix predicate against
   the row's label (can another row match — the same day number and weekday within the fixture's span?), the test
   process's `DateFormatter` templates vs. the app's `HistoryFormat`, the swipe loop (overshoot, the row released
   above), and whether the test still proves what it claims (a dumbbell session opens the chart on Dumbbell).
4. **Other date-dependent tests.** Search the UI and unit tests for the same class of defect — fixtures dated relative
   to `now` whose assertions assume a month, a week, a weekday or a count of built lazy rows (e.g.
   `HistoryCalendarUITests.testTappingAMarkedDayOpensThatSession`, the History / Floodlight History capture tests,
   the week summary, `DesignSampleFixture`, `HeartRateHistoryFixture`). List any that would fail on some date, with
   the date; do not fix them.
5. **Verification scope** per DEVELOPMENT: is `rc-fix-1` (38/38: the three affected classes, `ProgressChartUITests`,
   the new `ChartFixtureTests`, `HeartRateSeriesTests`) enough for this change, given the full suite already passed
   the other 227?

Do not modify files other than the report. Report findings by severity (critical / high / medium / low) with
file:line and a concrete failure case, or say "clear" in one paragraph. Write the report to
`work-record/redesign-floodlight/codex-review-13.md`.
