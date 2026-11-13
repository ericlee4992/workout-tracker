You are the independent reviewer (AGENTS.md T6) for live-workout-fixes ticket 03 (the chart from a live workout, by
machine). Claude implemented it. Repository: /Users/ericlee06/.paseo/worktrees/1qmeipq9/workout-chart-machines,
branch ericlee4992/workout-chart-machines. Diff under review: `git diff 7dc65b82..HEAD` (a3305a2e only adds the
tickets and D87; the code is b8559b9f).

Read first: AGENTS.md; work-record/live-workout-fixes/issues/03-chart-from-workout.md (the user's ask, their choices,
the Design section with the decisions Claude took on the "To work out" list, the strings, the evidence); D87, D1, D8,
D11, D19, D23, D36, D47 in docs/DECISIONS.md; docs/SPEC.md "History, PRs, integrity"; .claude/skills/ios-design/SKILL.md
and REVIEW.md; the captures in work-record/live-workout-fixes/captures/03/ (open them).

Review for correctness and regressions:
1. Domain (WorkoutTracker/Domain/ProgressSeries.swift, ExerciseHistory.swift, PreviousPerformance.swift,
   ProgressPins.swift, ExerciseOverview.swift): `ProgressEquipment.anyMachine`, `pooledMachineVariations`, `scoped`
   for the pool, the label change (a machine's gym now always in its label; the `.gym` stage removed), and
   `ProgressVariationKey.current(for:)` (draft vs frozen entry). Does All machines pool only machine sets of one load
   type and preset, exclude warmups, and never become a default (`rankedVariations`/`defaultVariation`, the Progress
   tab, AddChartSheet, pins)? Do records respect load type? Any other `switch` over `ProgressEquipment` or caller of
   the labels whose output changed unexpectedly (Progress tab labels, AddChartSheet)?
2. UI (ExerciseProgressView.swift, LastTimeSection.swift, ActiveWorkoutView.swift, ExerciseEntryCard.swift):
   the live sheet (exercise id/name, opening variation), "Last time" (layer choice, fallback notes, loading on
   appear — a `.task` on the then-empty section never ran, see the ticket), the grouped picker, session machine names
   under All machines, the new-best band now opening the chart. Removing PreviousPerformanceSheet: anything still
   depending on it (`PerformanceHistory.summary` callers, tests, docs)? Performance: the chart open over a running
   workout (P1 lag history: the rest timer and heart rate keep ticking) — any re-fetch per tick?
3. Design against ios-design (one dominant treatment, Dynamic Type, tells) using the captures.
4. Tests: WorkoutTrackerTests/ChartByMachineTests.swift, PreviousPerformanceTests.swift, the new
   FloodlightLiveUITests tests, the fixture `-uiTestDesignMachines` in DesignSampleFixture.swift. Do they prove the
   acceptance (open on the machine in use, Last time on top, switching machines, All machines, close returns)? Is the
   verification scope in the ticket sufficient per docs/DEVELOPMENT.md → Verification scope (Claude plans the Workout
   and HistoryProgress area plans before merge)?
5. Ticket, SPEC and README accuracy; new strings listed.

You may build and run focused tests ONLY on simulator WT-Redesign-2 (EB4328A1-87BD-4850-A3B2-A6E604701F1C) with
`-derivedDataPath /tmp/wt-live03-codex` (Claude uses WT-Floodlight; do not touch it). Run
`scripts/prepare-test-simulator.sh EB4328A1-87BD-4850-A3B2-A6E604701F1C` first.

Rules: modify nothing except the report; no phone, Apple account or ~/WorkoutTracker-Backups access, no network
deploys, no desktop control. Write the report to work-record/live-workout-fixes/codex-review-03.md: numbered findings
with severity (P0 … P3), file:line, the failure scenario and a suggested fix; what you ran and its results; then a
last line that is exactly "Verdict: clear" or "Verdict: not clear".
