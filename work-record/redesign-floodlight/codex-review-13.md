# Ticket 13 — independent Codex review

Reviewed 2026-09-29 in `/tmp/wt-floodlight/cardio`, branch
`ericlee4992/redesign-floodlight-cardio`, clean starting HEAD `85a1f10318cc49b60549ccb535f4b1`.
Code comparison: `git diff f4303ec fe35a34 -- WorkoutTracker WorkoutTrackerTests WorkoutTrackerUITests`.
The other changes since `796ffe5` are documentation. STATE is stale for this checkout; this review uses the
explicit ticket, Git history and recorded results. No `xcodebuild` or `simctl` was run. Only this report was written.

**Verdict:** the fix addresses both recorded September 29 failures, and its fixture gating is sound.
There are **two medium findings and one low finding** below, including a separate, pre-existing app defect.
No critical or high findings. The release candidate is not unconditionally clear on date robustness.

## Findings, by severity

### Medium — a midnight DST jump in the first month can make today's month unreachable

**Location:** `WorkoutTracker/Domain/WorkoutCalendar.swift:88–93`, with month construction at `:106–107`
and the disabled Next button at `WorkoutTracker/Features/History/HistoryCalendarSheet.swift:92–94`.
**Pre-existing product defect; not introduced by fe35a34 and not the cause of rc-ui-1's failures.**

Concrete case: Gregorian calendar, `America/Asuncion`, earliest workout **2023-10-15**, today
**2023-11-15**, optionally another workout on November 14. October 1's midnight did not exist because of
the DST jump. Foundation constructs its month start at **October 1 01:00**. Adding one calendar month
retains that hour, producing **November 1 01:00**. The separately constructed `lastMonth` is
**November 1 00:00**. Thus `cursor <= lastMonth` fails before November is appended.

The calendar contains only October; Next is disabled and November's grid cannot be reached. History's
list still contains the workouts. This violates the documented range from the first marked month through
today (`WorkoutCalendar.swift:71–72`). Independently reproduced with Foundation's `NSCalendar` through
read-only JXA, including the same month-addition unit; this is arithmetic evidence, not a new UI run:

| Value | Local date and time |
|---|---|
| First month | `2023-10-01 01:00 -0300` |
| Next cursor | `2023-11-01 01:00 -0300` |
| Last-month bound | `2023-11-01 00:00 -0300` |
| Comparison | next cursor is greater than the bound |

Normalize each advanced cursor to that month's start, or enumerate month identities independently of a
carried hour. Add a regression covering this boundary. The existing DST test
(`WorkoutTrackerTests/WorkoutCalendarTests.swift:95–105`) checks cells within one month, not this iteration.

### Medium — the calendar tests still mix calendar days with elapsed 24-hour periods

**Location:** `WorkoutTrackerUITests/HistoryCalendarUITests.swift:35–42,68–71` versus
`WorkoutTracker/Domain/ChartFixture.swift:119`.
**Residual test defects; the older-month addition does not cause them.**

- **2026-03-09 00:30 EDT, America/New_York:** the fixture's newest session, `now - 86,400 s`, starts
  **March 7 23:30 EST**. `testTappingAMarkedDayOpensThatSession` instead selects calendar-yesterday,
  **March 8**. No fixture workout exists on that day, so its `calendarWorkoutRow` assertion fails.
- **2026-11-01 23:30 EST:** the same fixture session starts **November 1 00:30 EDT**, which is today.
  `testAnEmptyDayIsSelectableAndMonthsPage` selects today and fails its **“No workouts”** assertion.
  The marked-day test does not necessarily fail here: October 31 contains the two-days-back warmup
  session, so it can pass while opening that session instead of the intended newest one.

The app correctly displays those actual timestamps. Align fixture/test day semantics and use a shared,
controlled reference date. The new forty-day test at 08:00 does not exercise these near-midnight cases.

### Low — the new History selector computes its date after the fixture's clock can cross midnight

**Location:** `WorkoutTrackerUITests/ProgressChartTooltipUITests.swift:132–139` and
`WorkoutTracker/Domain/ChartFixture.swift:94–95,119`.
**In the changed selector.**

Concrete case: the app seeds at **2026-09-29 23:59:59 EDT**, but the test reaches line 132 at
**2026-09-30 00:00:15 EDT**. The dumbbell session is dated September 19; the predicate asks for
September 20. There is no September 20 row in that seeded script. Eight swipes cannot find it and the
existence assertion fails. Matching the same formatter templates does not synchronize the two clocks.
Supply a shared fixture reference date or identify the intended session without recomputing wall time.

## Diagnosis and fix assessment

**The two recorded failures are test defects.** `WorkoutCalendar` correctly has just September on
September 29 with the original 28-day fixture: its oldest workout is September 1. The inspected recording
frame, `/tmp/wt-floodlight/results/rc-ui-2-att/cal-019.0.png`, shows September, both chevrons dimmed, and
September 29 selected with “No workouts.” Disabling Previous agrees with the data and bounds.
The separate midnight-DST defect above does not explain this recording.

The History failure counted built lazy rows, not stored workouts. `HistoryView.swift:153–170` adds week
headers between groups. `rc-diag-1.log:178–270` records four rows initially (September 28, 27, 25, 22),
then the September 19 dumbbell row at y=292 after one swipe, then its release after the next swipe.
One correction to the ticket's wording: with the captured Sunday-first calendar, the first four rows
span **two** weeks on September 29; the fifth row starts the **third**. On September 27 the first four
span one week. The extra headers explain the changed initial row count.

**Fixture:** `WorkoutTrackerApp.swift:20–22,45–47` selects the disposable store on reset and invokes
`ChartFixture.seed` only through the reset-gated chart flag. `Models.swift:900–902` requires both the
requested fixture flag and reset. The older-month flag alone, or both chart flags without reset, cannot
seed a real store through app launch. Direct unit-test calls can explicitly seed their supplied context;
that is not a launch path. `includeOlderMonth: includesOlderMonth` evaluates the computed property when
the default is used on each call; it is not a cached startup value.

The extra row is a **working** set with **nil preset and nil tag** (`ChartFixture.swift:114–116`).
Without the argument, the original 17 sessions are unchanged. With it, the richest plain variation grows
from nine to ten eligible days and remains `defaultVariation` (`ProgressSeries.swift:187–190`). Forty
elapsed days exceeds even a 31-day Gregorian month plus a DST offset change, so that row is always in an
earlier month. This claim is sound despite the shorter-offset DST problems above.

**Calendar tests:** on an ordinary first of a month, the latest session is yesterday in the previous
month, and `HistoryCalendarSheet.swift:31–41` opens there. Today's month is included and Next is enabled.
The paging test's forward step therefore works; adding the older row does not change which month or day
the marked-day test opens. The empty-store test replaces its launch arguments. The new inequality wait
observes the persistent month header's actual label change; the old existence wait could not do that.
The header is outside the transitioning grid, so no normal removal/reinsertion makes this pass vacuously.

**Tooltip test:** at the default text size, `HistoryPieces.swift:451–457` yields the observed
`<d>, <EEE>, ` prefix. Its `HistoryFormat` templates (`:31–38`) match the test's defaults in the recorded
runner/app locale and time zone. The ten-day target cannot collide with another day-number/weekday pair:
other fixture rows are at most 18 elapsed days away from it, too close for that calendar pair to repeat.
This test does not pass the older-month argument or request AccessibilityL's different label order.

The query is reevaluated while swiping, so released rows do not invalidate an index. The recorded first
swipe brings the target safely into view, and the successful rerun confirms that path. The eight-swipe
limit and upward-only recovery are not a proof against overshoot on every layout, but no concrete
date-specific overshoot is established by this evidence. The assertion after opening the chart still
requires **Dumbbell**; the fixture's default is plain, so the test retains its intended variation check.

## Other date-dependent test audit

Searched UI and unit tests for relative dates, month/week/weekday assumptions and lazy row counts or
indices. The definite failures found are listed above; no additional failing date was established for:

- **History captures:** `FloodlightHistoryUITests.swift:47–62` opens the calendar's selected latest day;
  `RedesignScreenshotUITests.swift:357–445` uses the first session or the sole HR session. They do not
  require two months or a fixed number of built history rows. The “Aug 31” comment in the large-text
  capture is stale, but not an assertion.
- **Design samples and week summary:** `DesignSampleFixture.swift:147–154` uses calendar-day subtraction
  and sets 18:10. `FloodlightWorkoutTabUITests.swift:241–259` captures the summary without a fixed weekly
  count. `WeekSummaryTests.swift:13–22` freezes Gregorian UTC dates and Monday-first weeks;
  `HistoryOverviewTests.swift:13–22` freezes its calendar and dates too.
- **Heart-rate history:** `HeartRateHistoryFixture.swift:100–101` can drift from its “two days ago”
  description across DST, but its capture tests select the sole row, and
  `HeartRateSeriesTests.swift:136–164` asserts series shape, values and idempotence, not a calendar date.
- **Remaining indices:** `ProgressChartTooltipUITests.swift:173` selects the second, warmup-only row;
  `FloodlightScanUITests.swift:344–347` also uses indices during scrolling. These are potential lazy-list
  fragility, but this review has no concrete failing date for them and does not promote that suspicion
  to a finding. The new `ChartFixtureTests` uses `Calendar.current`; non-Gregorian settings are an
  environment assumption, distinct from an assertion that fails merely because today's date changes.

## Verification scope and evidence

Independently read the actual `.exit` files, xcresult summaries and relevant log sections in
`/tmp/wt-floodlight/results/`:

| Run | Actual exit | Result |
|---|---:|---|
| `rc-build-1` | 0 | Test build succeeded |
| `rc-unit-1` | 0 | 919 passed, 0 failed, 0 skipped |
| `rc-ui-1` | 65 | 227 passed, the two named failures, 0 skipped |
| `rc-ui-2` | 65 | Both failures repeated with the same assertions |
| `rc-diag-1` | 0 | Diagnostic passed; row labels/positions recorded |
| `rc-fix-1` | 0 | 38 passed, 0 failed, 0 skipped |

`rc-fix-1.log` records compilation of the changed fixture and new tests, followed by `TEST SUCCEEDED`.
Its selected scope is three UI classes—`HistoryCalendarUITests` (3), `ProgressChartTooltipUITests` (4),
`ProgressChartUITests` (2)—plus `ChartFixtureTests` (3) and `HeartRateSeriesTests` (26).
The bundles still contain the previously documented runtime warnings; a passing count is not a
warning-free result. No fresh hardware or installation verification is claimed.

**That scope is sufficient for this fixture/test-only diff under DEVELOPMENT's Verification scope.**
The full RC suite already ran, unchanged production flows retain their 227 passing results, and the
focused run covers both fixes, all tests sharing their setup and adjacent chart behavior. Another full
suite on September 29 would not resolve the boundary findings. Those need targeted date-controlled
regressions and disposition of the pre-existing calendar defect before unconditional RC clearance.

**Standards:** clear; no documented-standard violation or actionable code smell in the diff.
**Spec/date correctness:** two medium findings and one low finding as detailed above.
