# S4 — History journal and Progress pin-anything (training metrics)

Type: change
Status: **review clear** (Codex round 2, 2026-11-07) — merge waits for the deferred Phase 1 test run
Blocked by: S2
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/soft-04-history-progress` off `main`.
Spec: [soft-redesign](../spec.md). Decisions: extends D63 (Progress pins).

## Goal

History reads as a daily journal; Progress can pin more kinds of training metric. Food and body-weight metrics join
in Phase 2 (N9).

## Scope

- **History journal:** one section per day — each workout with its muscle families, time and key figures; the
  calendar stays. A day's **food line** ("1,240 cal eaten · 1,048 under goal") is added in N9, not here. Workout
  detail, editing and deleting (tickets 19–20) unchanged.
- **Progress:** the shipped model (pinned charts + Add Chart, D63) with these pinnable training metrics: exercises
  (best set — today), cardio activities (today), **workouts per week**, **training volume**, **running distance**.
  Each card: title, what it measures, the figure, its change, a chart; "…" for Move Up / Remove. Add Chart groups:
  Training now; Body and Nutrition in N9.
- Pins stay in UserDefaults (`ProgressPins.swift`, "a view preference, not workout data") — **no store change**.
  A new pin kind must decode alongside old pins (older builds ignore unknown kinds; test both directions).

## Acceptance

1. History shows days as journal sections at default and AccessibilityL; tapping a workout opens its detail as today.
2. The three new metrics compute correctly (unit tests: warmups excluded, assisted load rules, as-entered units with
   plain-number display — D52) and chart over the existing ranges.
3. Existing pins survive the update unchanged (decode test with today's JSON).
4. Progress / ProgressChart / History UI tests pass; captures; Codex clear.

## Verification scope

New metrics → `ProgressSeries` / `ProgressPins` unit tests; History, HistoryCalendar, HistoryEdit, Progress UI classes.

## Code map

- `Features/History/HistoryView.swift`, `HistoryPieces.swift`; `Domain/HistoryOverview.swift`, `HistoryRendering.swift`.
- `Features/Progress/*`; `Domain/ProgressPins.swift`, `ProgressSeries.swift`, `WeekSummary.swift`.
- Prototype: `Screens/Soft/SoftProgressBoard.swift`, `SoftProgressScreen.swift`, `SoftRound3Screens.swift` (journal).

## Progress

- **2026-11-07 — implemented, NOT yet tested or reviewed** (branch `ericlee4992/soft-04-history-progress`, stacked
  on S3; commit after `55831f0`). Builds (`build-for-testing` exit 0).
  - **History journal:** `HistoryOverviewMath.journal` / `dayTitle` (months → day sections, "Today" / "Yesterday" /
    "Friday, Nov 6", year when not this year); `HistoryView` renders a `HistoryDayHeader` per day (count only when
    > 1, id `historyDay`) and rows with `dateStyle: .hidden`; the month card, calendar and month breaks stay. The
    week header view was removed (`HistoryOverviewMath.sections` kept — still unit-tested). Tests:
    `HistoryJournalTests` (3).
  - **Progress training metrics:** `Domain/TrainingProgress.swift` — `TrainingMetric` (workouts per week, training
    volume, running distance), `TrainingProgressMath.weekly` (calendar weeks from the first with data to this week,
    ≤ 12, empty weeks 0) and `inputs` (volume = `HistoryWorkoutFacts.volumeKg`, runs = indoor/outdoor run distance).
    Pin: `ProgressPin.Subject.training(_)`, custom Codable that writes it in the cardio shape with activity
    "training.<metric>" so pre-S4 builds skip it (D63 unknown-activity rule) instead of dropping every pin; the
    original cases' JSON unchanged. `ProgressReading.training` (this week so far; caption "This week · last week N";
    no change badge), panel case, `TrainingProgressView` (large chart + weeks list), Add Chart's third segment
    "Training". Tests: `TrainingProgressTests` (6, incl. old-JSON decode and the legacy-shape check).
- **2026-11-07 (session 2) — tested; captures checked; ready for Codex.** Changes: `AddChartSheet` keeps `dismiss` /
  `matches` private (a same-file extension sees them); the Training rows show a "+" instead of a chevron (one tap adds,
  no second step); new UI tests `FloodlightProgressUITests.testTrainingChartsDarkDefault` /
  `testTrainingChartsLightAccessibility` (add all three from empty, open Training volume, captures).
  **Evidence (WT-Floodlight, Claude):**
  - Unit, serial: `HistoryJournalTests`, `TrainingProgressTests`, `HistoryOverviewTests`, `ProgressPinTests`,
    `CardioProgressMathTests`, `ProgressSeriesTests`, `ChartPresetScopingTests`, `HistoryRenderingTests` — exit 0,
    xcresult **90/90 passed**.
  - UI, serial (warm-up first): `FloodlightHistoryUITests`, `HistoryCalendarUITests`, `HistoryEditFlowsUITests`,
    `FloodlightProgressUITests` (incl. the two new tests), `ProgressChartUITests` — exit 0, xcresult **28/28 passed**.
    After the "+" change: warm-up + the two training tests — exit 0, **3/3**.
  - Captures (History journal light/dark × default/AXL; Training add/tab/detail dark-default and light-AXL) checked:
    figures match the sample (this week 11,240 lb = 5,620 + 5,620; last week 22,577 lb = the four Oct 26–31 workouts).
    The detail's in-content title under the inline bar title when scrolled is the same as `CardioProgressView` (kept).
  - Observation for the reviewer: rows no longer speak their date; the day header is a VoiceOver heading.
- **2026-11-07 — Codex round 1** ([report](../codex-review-s4.md)): **not clear**, 3 × P2, all accepted and fixed
  (its runs on WT-iPhone27: unit 26/26, UI 15/15). (1) a weekly chart's lone point no longer says "One session"
  (`ProgressReading.singleNote`); (2) Today's clock refresh moved to `Features/RefreshingNow.swift`
  (`.refreshingNow($now)`: day change, clock/time-zone change, app active) and used by Today, History's journal and
  Progress's training readings (the open detail follows through `destination`); (3) a visible "…"
  (`ProgressPanelMenu`, "<title> options", id `progressPanelOptions`) on each panel's top-right corner with the
  long-press menu's items; the chevron is gone (as in the prototype). Also `TrainingProgressTests`' legacy decoder is
  now `BuildNinePin`, a verbatim copy of `main`'s synthesised pin. New tests:
  `aSingleWeekOfSeveralWorkoutsIsNotOneSession`, `lastWeekJoinsTheCaption`,
  `FloodlightProgressUITests.testOptionsMenuMovesAndRemovesTrainingCharts`. No automated test posts the clock
  notifications (as in S2).
  **Evidence (WT-Floodlight, serial):** unit `TrainingProgressTests`, `HistoryJournalTests`, `TodayDayBoundaryTests`,
  `ProgressPinTests` — exit 0, **21/21**; UI warm-up + `FloodlightProgressUITests` (10) + `ProgressChartUITests` +
  `FloodlightHistoryUITests` + `CoreLoopUITests/testCoreLoopFromEmptyStoreToOneTapRepeatSet` — exit 0, **22/22**.
  Captures: the "…" on every panel, light/dark × default/AXL, no overlap with titles.
- **2026-11-07 — Codex round 2 [clear](../codex-review-s4b.md)** (`1e298e3..224289c`): all three P2s closed, 0 new
  findings; its runs on WT-iPhone27: unit 18/18, UI warm-up + `FloodlightProgressUITests` 11/11, captures inspected.
  Noted, not findings: five non-failing "Invalid frame dimension" runtime warnings (as in round 1; already listed in
  deferred work); clock refresh is source-reviewed, not driven by a test. **Next:** the deferred Phase 1 run (ask the
  user), then merge S1→S4.
- **Next (for the fresh session, superseded by the entry above):** run unit tests `HistoryJournalTests`, `TrainingProgressTests`,
  `HistoryOverviewTests`, `ProgressTabTests`; UI `FloodlightHistoryUITests`, `HistoryCalendarUITests`,
  `HistoryEditFlowsUITests`, `FloodlightProgressUITests`, `ProgressChartUITests` (serial with the warm-up first, or 3
  workers; open the "Test progress" tab); capture History + Progress (training panels) light/dark/AX and show the user;
  fix; ticket progress + new strings ("Today", "Yesterday", weekday dates, "Workouts per week", "Training volume",
  "Running distance", their "measures" lines, "This week · last week N", "Across all your training", "Weeks", "Week
  of <date>", "Training", "Charts"); Codex review (prompt `codex-review-s4-prompt.md`). Then ask the user to start the
  deferred Phase 1 run.

## Comments
