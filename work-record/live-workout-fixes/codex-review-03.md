# Live-workout 03 — Codex review, round 1

Review target: `7dc65b82..a37ec844c676f025e77bf18f056c720409726b4b`, branch
`ericlee4992/workout-chart-machines`. Implementation: `b8559b9f`. Reviewed against the ticket, D87,
D1/D8/D11/D19/D23/D36/D47, SPEC, AGENTS, and ios-design/SwiftUI/SwiftData guidance.

**Final report — 2026-11-13.** Three P2 findings; independent build, Unit plan and focused UI class pass.

The checkout was clean at review/build start. At completion, concurrent author edits were present in
ExerciseOverview.swift, ExerciseProgressView.swift, ChartByMachineTests.swift, FloodlightLiveUITests.swift and the
ticket. Those uncommitted fixes are **not** cleared by this round; the test-without-building runs used this round's
previously built binary. This reviewer changed only this report.

## Standards

1. **P2 — Preserve each pooled session's own frozen machine and gym names.**
   `WorkoutTracker/Features/History/ExerciseProgressView.swift:607–612` resolves every date's machine UUID through
   `ExerciseOverview.variationWords`, which takes the first matching entry in the entire unsorted store
   (`ExerciseOverview.swift:483`). Log a machine, rename it or its gym, then log it again: both dated rows in
   All machines get the same arbitrarily selected snapshot name. Deleting that source workout can change the other
   rows' displayed names. D23 requires the session's frozen context, and this method promises the snapshot for
   that session's best set. Carry the winning set's originating entry/snapshot label and gym through `ProgressData`
   instead of reducing it to a machine UUID. Add a regression for sessions before and after a rename.

2. **P2 — Stack the pooled session's trailing badge at AccessibilityL.**
   `WorkoutTracker/Features/History/ExerciseProgressView.swift:423–440` keeps the expanded session text beside the
   large New Best badge in an `HStack`. The horizontal badge placement is inherited, but the new essential
   machine/gym line makes this a newly affected row. The supplied `live-fixes-03-all-machines-light-axl.png` shows the
   Oct 28 date splitting, `70 lb × 8` breaking into two lines, and `Chest Press · Hotel Gym` squeezed into four
   lines while the badge consumes most of the row. ios-design requires trailing accessories below the text at
   accessibility sizes. Use an accessibility layout that gives the date, set and machine the available width,
   with the badge beneath; retake the pooled AccessibilityL capture including a record row.

## Spec

3. **P2 — Name the current draft machine and preset before its first completed set.**
   `WorkoutTracker/Features/History/ExerciseProgressView.swift:589–593` supplies labels only from entry snapshots.
   `WorkoutSession.addEntry` initializes only provisional exercise fields (`WorkoutSession.swift:195–214`);
   machine/gym/preset snapshots are not captured until the first completion (`:863–877`). On a never-logged
   machine, open the live chart before completing a set: `.current(for:)` selects the right machine UUID, but the
   label is **“Machine · nothing eligible”** without its gym; a never-logged preset becomes **“Variation”**.
   This misses D87's named current-machine selection. Supply live words for the current unfrozen entry and retain
   frozen words for historical options. Cover opening before first completion on a new machine and preset.

The spec axis independently found #1 too; it is recorded once above. No additional scope finding. Pooling,
warmup exclusion, per-load-type/preset boundaries, assisted ranking, defaults and pin exclusion match the recorded
design. No actionable baseline code-smell finding.

## Verification and coverage

- Build/test simulator only: WT-Redesign-2 `EB4328A1-87BD-4850-A3B2-A6E604701F1C`; preparation script succeeded.
  Derived data `/tmp/wt-live03-codex`; logs, exit files and results `/tmp/wt-live03-codex-review/`.
  Build-for-testing succeeded, exit 0 (`build.log` / `build.exit`). Unit plan passed 1355/1355, exit 0
  (`unit.log`, `unit.exit`, `unit.xcresult`), independently checked with `xcresulttool get test-results summary`.
  Workout plan restricted to `WorkoutTrackerUITests/FloodlightLiveUITests`, serial: 20/20 passed, exit 0
  (`ui.log`, `ui.exit`, `ui.xcresult`), independently checked with `xcresulttool get test-results summary`.
  All four new chart tests passed, along with the adjacent live-workout tests in that class.
- Opened all ten supplied captures, including light/dark Default and light AccessibilityL, picker and pooled rows.
  The initial screen keeps Last time before the selector and the chart's hero figure dominant. Labels fit in the
  supplied selector captures. The pooled record-row accessibility problem is #2.
- Inspected author's xcresult summaries directly: `unit-03.xcresult` 1355/1355 passed;
  `unit-03b.xcresult` 36/36 passed; `ui-03.xcresult` 4/4 passed.
- The new UI test covers chart opening, current-machine selection with existing history, switching, pooling and
  dismissal. It does not exercise first-use draft names or renamed historical session labels (#1/#3).
- Traced the chart and new-best band's entry points, draft versus frozen variation keys, label callers in
  AddChartSheet/Progress/Exercises, pool exclusion from ranked defaults and pins, and removal of
  PreviousPerformanceSheet. No remaining product caller requires the removed sheet. `PerformanceHistory.summary`
  remains test-covered but no longer has a product caller; its sheet-specific comments are now stale (cleanup).
- Performance inspection: Last time loads on appearance, not a timer; the chart has no new rest/heart-rate
  subscription. Existing chart history/label reads still happen during rendering. This review did not measure
  fetch counts or frame times with live sensor updates and does not claim a P1-scale performance benchmark.
- README and SPEC describe the implemented flow; the ticket lists the new strings and pending user acceptance.
  No schema or persistence change is introduced.
- The planned Workout and HistoryProgress area plans are appropriate for the live navigation change and the
  shared chart/picker callers; complete them before merge, plus focused regressions for these findings. Full UI
  is not warranted by this bounded change. Phone testing remains outside this round.

Verified: build-for-testing exit 0; Unit 1355/1355, exit 0, `/tmp/wt-live03-codex-review/unit.xcresult`;
          FloodlightLiveUITests 20/20, exit 0, `/tmp/wt-live03-codex-review/ui.xcresult`;
          source and all ten supplied captures reviewed; author's xcresult counts inspected;
          `git diff --check 7dc65b82..HEAD` and `python3 scripts/test-plans.py --check` passed.
Not verified: full Workout/HistoryProgress area plans (author's pending merge checks); phone behavior;
              live-sensor performance measurements; fixes/regression tests for #1–3.
Known flaky: none seen in this round.

Standards: 2 findings, worst P2. Spec: 2 findings, worst P2 (one overlaps Standards #1; three distinct findings).

Verdict: not clear
