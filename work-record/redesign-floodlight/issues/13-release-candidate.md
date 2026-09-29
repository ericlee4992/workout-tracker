# 13 — Floodlight: release-candidate pass

Type: task (part of [01](01-implement-redesign.md), plan step 4; then step 5, the install)
Status: claimed — in progress
Implementer: Claude. Reviewer: Codex (for any code fix).
Branch: `ericlee4992/redesign-floodlight-cardio` (scratch checkout `/tmp/wt-floodlight/cardio`). Tested tip:
**`796ffe5`** (ticket 12, Codex clear; tickets 02–12 stacked beneath it, each Codex clear). Nothing merged to
`main` (`a0364f2`, an ancestor of the tip); nothing installed.

## Scope

DEVELOPMENT → *When to run the full UI suite*: **a major release candidate** — the whole-app Floodlight redesign
(tickets 02–12: every screen area, the Look tokens, `Theme` and `Legacy*` deleted, shared navigation, the live
workout lifecycle's views, the Live Activity). Targeted runs per ticket cannot bound the combined regression risk.

1. **Full unit suite** — `WorkoutTrackerTests` on `796ffe5`.
2. **Full UI suite** — `WorkoutTrackerUITests` on `796ffe5` (229 test methods at the start of the pass).
3. Each failure: rerun alone (and note the load); a failure that repeats alone is diagnosed; a code fix gets a
   focused test, then its affected checks, then a Codex review in a visible Orca terminal.
4. Default + AccessibilityL captures: already taken per ticket (`../captures/02/` … `../captures/12/`); this pass
   does not retake them unless a fix changes a screen.
5. Then the one install (ticket 01 step 5, DEVELOPMENT *Real-device installation* / *Provisioning expiry*):
   fresh full backup, signing renewal, install, launch, data-preservation check. **Blocked** until the user adds
   their Apple ID in Xcode → Settings → Accounts; app and widget profiles expired 2026-09-24. Ask the user
   before merging to `main` or touching the phone.

Known flakes under load (tickets 06–12): the Gyms model picker (CoreLoop), a typed value losing a character in
FloodlightLive, a launch that stayed on the Workout tab.

Not exercised by this pass (carried from tickets 08–12): VoiceOver by a person, Reduce Motion at runtime, real GPS
and sensors, a real device (the install covers launch and data only).

## Environment

Xcode 27.0 (27A266a). Simulator **WT-Floodlight** `9E822EF6-DC67-4958-AEA2-D53D2D36D674` (iOS 27). Runner
`/tmp/wt-floodlight/cardio-run.sh <name> build|test …` (derived data `/tmp/wt-floodlight/dd-cardio`); logs,
`.exit` files and result bundles `/tmp/wt-floodlight/results/rc-*`. Other sessions keep four more simulators
booted (WT-iPhone, WT-Redesign, -2, -3); load at the start: 23.6 / 21.4 / 15.8 on 10 cores, no other xcodebuild.

## Runs

| Run | Commit | What | Load at start | Exit | Result |
|---|---|---|---|---|---|
| `rc-build-1` | `796ffe5` code (`dfa8062`) | build-for-testing | 15.5 / 19.6 / 15.4 | 0 | TEST BUILD SUCCEEDED |
| `rc-unit-1` | same | `WorkoutTrackerTests` (whole target) | 14.2 / 19.2 / 15.3 | 0 | **919/919** passed, 0 failed, 0 skipped (xcresult summary); 94 s |
| `rc-ui-1` | same | `WorkoutTrackerUITests` (whole target) | 16.4 / 18.9 / 15.7 | 65 | **227/229**, 2 failed, 0 skipped; 04:12–08:36 (4 h 24 min). Failures 1–2 below |
| `rc-ui-2` | same | the two failures, alone | 13.6 (08:36) | 65 | 0/2 — both repeat alone: not load |
| `rc-diag-1` | same + a throwaway diagnostic test (not committed) | History row labels while scrolling | 9.7 / 13.1 / 15.2 | 0 | rows read "19, Sat, Seated Chest Press, …"; scrolling releases the rows above |
| `rc-fix-1` | fix (working tree, then committed as below) | unit `ChartFixtureTests` (new, 3), `HeartRateSeriesTests`; UI `HistoryCalendarUITests` (3), `ProgressChartTooltipUITests` (4), `ProgressChartUITests` (2) | 14.7 (08:46) | 0 | **38/38**, 0 skipped |
| `rc-fix-2` | round-1 fixes (Codex review 13) | unit `ChartFixtureTests` (4), `WorkoutCalendarTests`, `HeartRateSeriesTests`, `HistoryOverviewTests`; UI — every chart-fixture or History-calendar user: `HistoryCalendarUITests` (3), `ProgressChartTooltipUITests` (4), `ProgressChartUITests` (2), `FloodlightHistoryUITests` (8), `HistoryTemplateUITests` (3), `RedesignScreenshotUITests` `test05_history` + `…LargeText`, `HeartRateSummaryUITests.testAWorkoutWithoutASeriesShowsNoChart` | 7.7 / 9.2 / 12.3 | 0 | **76/76** (23 UI + 53 unit), 0 skipped |

`rc-ui-1` ran as xcodebuild PID 78787 from Claude Code's background Bash (not a shell `&`). None of the known
load flakes (Gyms model picker, FloodlightLive typing, launch on the Workout tab) appeared in it.

## Failures and causes

Both are **test defects that depend on the calendar date** (both tests from ticket 05, 2026-09-27; they passed
then). The app behaves as designed in both. Neither is load: both failed identically alone (`rc-ui-2`, load 13.6).

1. **`HistoryCalendarUITests.testAnEmptyDayIsSelectableAndMonthsPage`** — "("Sep 2026") is equal to ("Sep 2026") -
   the chevron shows the previous month". The failure recording shows "Previous month" dimmed and disabled: the
   calendar runs from the first workout's month (`WorkoutCalendar`, `HistoryCalendarSheet` disables the chevron at
   index 0), and the test's fixture `-uiTestChartHistory` reaches back only 28 days — on 2026-09-29 its oldest
   session is Sep 1, so there is one month. It fails on the 29th–31st (the 29th–30th of a 30-day month). Two more
   defects in the same test: it read the header's label right after the tap with no wait for the page to turn
   (`waitForExistence` on an element that always exists), and on the 1st of a month the calendar opens on the
   latest workout's month (yesterday's: the previous month), where today's cell does not exist.
2. **`ProgressChartTooltipUITests.testHistoryOpensTheChartOnThatSessionsVariation`** — "("4") is not greater than
   ("4") - the fixture seeds more than five sessions". The test counted the lazy History list's built rows and
   tapped index 4 (the fixture's dumbbell session ten days back). The Floodlight History groups rows by week, each
   with a header, under the month card; on 2026-09-29 (Sunday-first weeks) the first four sessions span two weeks and the fifth
   starts a third, so only four rows are built at launch (wording corrected after Codex review 13). On 2026-09-27
   the first four fell in one week and five were built. The diagnostic run also showed that
   scrolling releases the rows above, so no index is stable after a scroll.

## Fixes

Commit: see Progress. Test and fixture code only; no app behaviour changes.

- **Fixture** `ChartFixture` (`Domain/ChartFixture.swift`): `-uiTestChartHistoryOlderMonth` (guarded like every
  fixture by `WorkoutTrackerStore.fixtureIsEnabled`, i.e. only with `-uiTestReset`) adds one working session forty
  days back — an earlier calendar month on every date. A separate argument, so the four chart tests' series is
  unchanged. `seed(in:now:includeOlderMonth:)` defaults to the argument.
- **`HistoryCalendarUITests`** launches with that argument too; the paging test pages forward to today when the
  calendar opened on the previous month (the 1st), and waits for the header's label to change after the tap.
- **`ProgressChartTooltipUITests.testHistoryOpensTheChartOnThatSessionsVariation`** finds the dumbbell session's
  row by its date prefix (`"<d>, <EEE>, "`, the app's own templates, the fixture's `now − 10 × 86,400 s`), swiping
  until it is hittable above the tab bar, instead of by index.
- **Unit tests** `ChartFixtureTests` (3): the fixture alone spans one month on 2026-09-29 and two with the
  argument; forty days back is in an earlier month for every day of 2026; the extra session arrives only with its
  argument (and the argument alone, without `-uiTestReset`, is off).

## Install (ticket 01 step 5)

- **Account:** the user added their Apple ID in Xcode → Settings → Accounts (2026-09-29, ~04:45 EDT); team
  `X68M8SR6NA` (Personal Team).
- **Signing renewal — done 2026-09-29.** `rc-device-build-1` exit 0 (`** BUILD SUCCEEDED **`), code identical to
  `796ffe5`: `xcodebuild … -configuration Debug -destination 'generic/platform=iOS' -allowProvisioningUpdates
  -derivedDataPath /tmp/wt-floodlight/dd-device WT_DEVELOPMENT_TEAM=X68M8SR6NA
  WT_BUNDLE_ID_BASE=com.ericlee4992.workouttracker build` (the Local.xcconfig values on the command line, so the
  scratch checkout's simulator builds are unchanged). Run during `rc-ui-1` (load ~15). The profile directory had been
  empty since 2026-09-24 03:57, so nothing needed moving aside. New profiles, both with the phone
  `00008130-001E10C01E62001C`:
  - app `com.ericlee4992.workouttracker` — `9919493b-3fcd-4956-a418-880cfb7df595`, expires **2026-10-06 08:45:50 UTC**;
  - widget `….widget` — `ba4e9c29-50ac-4fa2-9979-a5ccd3951f39`, expires **2026-10-06 08:45:48 UTC**.
- **Freshness:** product `/tmp/wt-floodlight/dd-device/Build/Products/Debug-iphoneos/WorkoutTracker.app`, dylib
  04:46; ticket 12's symbols/strings present (`CardioRingModel`, `startSelectedCardio`, `historyCardioSection`,
  "Recording time continues."); HealthKit usage string, `NSSupportsLiveActivities`, widget `NSExtension` present.
  If a fix lands after this build, rebuild (the profiles are reused) and recheck.
- **Remaining, with the user's go-ahead:** fresh full backup, install, launch, data-preservation check; merge to
  `main` when the RC pass is clear.

## Codex review 13 — response (round 1)

Report: [codex-review-13.md](../codex-review-13.md) — not clear; two medium, one low. It confirms the diagnosis (both
failures are test defects; the recording shows the disabled chevron with the data), the fixture's gating (cannot
seed a real store) and that `rc-fix-1`'s scope suffices for a test-only diff. All three findings accepted.

1. **M — a pre-existing app defect: a month that begins on a DST jump at midnight drops today's month.**
   `WorkoutCalendar` built its months by adding a month to the previous start; in America/Asuncion 1 Oct 2023 has no
   midnight, the start is 01:00, 1 Nov 01:00 passed the last month's start (00:00) and November was never built
   (Next disabled; the list still had the workouts). The cursor is now re-anchored to its month's start each step.
   Not reachable in the user's time zone (New York changes at 02:00); fixed because it is one line and wrong.
   Test `WorkoutCalendarTests.aMonthStartingOnAMidnightDSTJumpStillReachesTodaysMonth` (premise asserted: the
   month start's hour is 1).
2. **M — the fixture counted days in seconds, the tests in calendar days.** `ChartFixture.sessionDate` now goes
   back `daysAgo` calendar days at the same wall-clock time. Test `ChartFixtureTests.sessionsAreCalendarDaysBackAcrossDST`
   (2026-03-09 00:30 and 2026-11-01 23:30 New York: "one day ago" is the calendar yesterday, where seconds
   arithmetic is not; every script day is exactly its count of calendar days back); the forty-day test uses the
   same function.
3. **L — a midnight between the app's seeding and the test's clock.** The chart test finds the dumbbell session
   by its content (its row ends with the volume "450, lb", unique in the fixture), not by a date. The calendar tests
   keep the day they launched on (`seedDay`) and launch again, on a fresh store, if a midnight passed while
   launching; their "yesterday" and "today" count from it.

Also: the round-1 insertion had separated `seed`'s doc comment from `seed`; restored.

Verification: `rc-fix-2` exit 0, 76/76 (runs table). Scope: the calendar change reaches every History calendar
screen; the fixture's dates reach every test launching `-uiTestChartHistory` — all run.


- 2026-09-29: resumed from STATE (`1794867`) and tickets 01 / 12; branch map verified against `origin` (every
  ticket tip as STATE lists; the cardio checkout clean at `796ffe5`). Ticket opened.
