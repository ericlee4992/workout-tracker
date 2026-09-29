# Ticket 13 — independent Codex review, round 2

Reviewed 2026-09-29 in `/tmp/wt-floodlight/cardio`, branch
`ericlee4992/redesign-floodlight-cardio`, clean starting HEAD
`759aedfaf26e4e59d68ad3efb0db4723dc1a3ad1`.
Scope: `git diff 85a1f10 HEAD -- WorkoutTracker WorkoutTrackerTests WorkoutTrackerUITests`,
the round-1 report, Claude's response, affected callers and recorded `rc-fix-2` evidence.
STATE remains stale for this checkout; the explicit ticket and actual Git state govern this review.
No builds or simulator commands were run. Only this report was written.

**Verdict: not clear — one medium and one low test finding.** The three original findings are
resolved at their reported sites. No new production defect was found in the calendar fix.

## Medium — the tooltip drag assertion still assumes the fixture's old elapsed-day dates

**Location:** `WorkoutTrackerUITests/ProgressChartTooltipUITests.swift:191–193`, consumed at
`:41–47`; changed fixture call at `WorkoutTracker/Domain/ChartFixture.swift:126`.

`newestSessionDay` still subtracts 86,400 seconds from the test's clock, while the fixture now
subtracts a calendar day. This weakens the test that is meant to reject a drag that does nothing.

Concrete case: launch at **2026-03-09 00:30 EDT, America/New_York**. The newest fixture session
starts **March 8 00:30 EST**, with its set completed at 00:40. Its chart point therefore says
**Mar 8** (`ProgressSeries.swift:232–233` groups by completion day). The helper instead returns
**Mar 7**. If the drag does nothing, the chart retains its newest-point fallback
(`ExerciseProgressView.swift:210–222`), but `XCTAssertFalse(row.label.contains("Mar 7"))` passes.
The subsequent “lb” assertion also passes. A broken gesture can now receive a green result.

The same mismatch occurs at **2026-11-01 23:30 EST**: the new fixture's latest point is
**October 31**, while the old helper returns **November 1**. This is an affected test dependency
missed by the fixture change, despite the class being included in the passing run.

Compare the actual selection before and after the drag, or derive its identity from stable fixture
content. Simply changing the helper to calendar subtraction would retain an independent-clock race
and overlook the fixture's ten-minute offset between session start and set completion.

## Low — the new volume selector assumes pounds without setting that preference

**Location:** `WorkoutTrackerUITests/ProgressChartTooltipUITests.swift:133`, with setup at `:10–15`.

Concrete case: a fresh **English (United Kingdom)** simulator on **2026-09-29**. The app resolves
its initial preference to kg (`Models.swift:785–791`, `AppUnitSystem.swift:12–15`). History's row
converts total volume to that preference (`HistoryView.swift:52–55`, `HistoryPieces.swift:523–531`).
The intended 45 lb × 10 session ends in **“, 204, kg”**, so the predicate requiring **“, 450, lb”**
never finds it and the existence assertion fails after scrolling.

The fixture stores weights in lb but does not set the app's display preference. Neither this test's
setup nor the shared scheme pins units or locale. The previous localized date predicate did not have
this dependency. Set the intended unit explicitly or identify the session independently of converted
display values. This does not invalidate the recorded US-locale pass.

## Disposition of the three round-1 findings

1. **Calendar month omission: resolved.** `WorkoutCalendar.swift:93–98` reanchors each next cursor
   through the same month-start function used for the upper bound. After Asunción's October 2023
   start at 01:00, November is now reanchored to 00:00 and included. The new regression
   (`WorkoutCalendarTests.swift:111–124`) asserts the DST premise, both months, November's marked
   workout and today; its actual passing result is recorded in `rc-fix-2.log:579`.
   Caller tracing and source search find only `HistoryCalendarSheet.swift:28` constructing this
   calendar in production. Its initial-month lookup, index bounds and chevron logic consume the
   restored range correctly (`:34–46,89–94,155–158`). No stored dates, session selection rules or
   History list grouping change.
2. **Calendar days versus elapsed days: resolved for the calendar tests.**
   `ChartFixture.sessionDate` (`ChartFixture.swift:95–96,126`) supplies calendar-day dates to every
   seeded session, including the warmup and optional older row. The DST regression
   (`ChartFixtureTests.swift:56–75`) checks both reported New York boundary cases and all scripted
   offsets at the spring boundary. The forty-day test now exercises this helper too. Flags, store
   gating, set types, weights, tags and presets are unchanged. The missed tooltip helper above is
   the one concrete remaining dependency on the old seconds-based dates found in the caller search.
3. **Midnight between seeding and test lookup: resolved at the reported sites.** The History chart
   test now identifies content rather than reading another clock. In the recorded lb environment,
   450 is unique: the other dumbbell session is 400, and the optional older session would be 720.
   The final assertion still requires Dumbbell rather than the default plain variation.
   `HistoryCalendarUITests.swift:20–24,44,76` snapshots the launch day and relaunches into a fresh
   disposable store if midnight occurs during launch. Seeding is synchronous during app initialization.
   If midnight occurs later, both lookups still use the seeded day; that empty day remains reachable,
   including across a month boundary. The first-of-month forward step remains valid. The separate
   empty-store test supplies its own reset-only arguments.

## Verification scope

Independently inspected `/tmp/wt-floodlight/results/rc-fix-2.exit` (**0**), its xcresult summary
(**76 passed, 0 failed, 0 skipped**) and the log. The log confirms compilation of both changed
domain files and both UI test files, the new Asunción and DST regressions passing, **53 unit tests**
and **23 UI tests**, followed by `TEST SUCCEEDED`. The summary retains 17 runtime warnings;
this is not a claim of a warning-free run or new device verification.

**The scope is sufficient under DEVELOPMENT's Verification scope.** It includes `WorkoutCalendarTests`,
`ChartFixtureTests`, `HistoryOverviewTests`, fixture-gating coverage in `HeartRateSeriesTests`, the
calendar and tooltip UI classes, adjacent chart tests, Floodlight History captures, History template
flows, both chart-fixture History captures and the no-HR-series check. Source searches confirm coverage
of every UI test launching `-uiTestChartHistory` and the production calendar surface.

The two findings concern assertion correctness and test configuration, not missing suite breadth.
Repeating the full UI suite on the same September date and US locale would not resolve them. Correct
the affected tests and verify those specific boundary/configuration cases with the focused class.

**Standards:** one missed affected test dependency; no additional actionable code-smell finding.
**Spec:** the original product/date fixes are implemented; the medium and low test findings above remain.
