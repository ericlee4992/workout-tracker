# Codex review — P1 workout lag (round 1), plus the Paseo tooling commit

You are the independent reviewer; Claude implemented it. Branch `ericlee4992/perf-01-workout-lag` off `main` `97e63f9`.
Review `git diff 97e63f9..HEAD`. Two parts:

**A. Tooling, docs only — `c81a24c`**: agent steps moved from Orca to Paseo (`AGENTS.md`, `docs/agents/tools-paseo.md`,
`docs/agents/tools-orca.md`, STATE). Check links, consistency with AGENTS' rules (one reused Codex agent, the "Test
progress" tab, worktrees/handoff), and that nothing the Orca setup recorded was lost.

**B. P1 — the app lags during a workout.** Read first: `work-record/performance/issues/01-workout-lag.md` (report,
the measured diagnosis, the user's approval, the fix list F1–F5, before/after numbers, verification); AGENTS (domain
rules, SwiftData conventions); D11, D19, D23, D26, D36, D39 (prefill, snapshots, typed vs inherited values) and D47
(history edits stamp `historyEditedAt`) in `docs/DECISIONS.md`.

Check:
1. **Behaviour identical** where the ticket claims it:
   - `WeekSummaryMath.summary(ofWorkouts:)` / `windowStart` vs the whole-history summary (Today and
     `StartWorkoutView`; its `finishedWorkouts.isEmpty` first-run test vs the old `inputs.isEmpty`).
   - `CardioRecorder.refresh`/`persist`: nothing a sensor or cardio segment produces may go unsaved or be saved later
     than before (heart-rate rows, checkpoints, segment fields, distance); the Lock Screen and rest-alarm paths that
     rely on this refresh.
   - `FinishedHistoryCache`: is membership-by-two-counts sound for every path that can change finished history while
     the live screen is up (sheets over the cover, Lock Screen commands, Watch, CloudKit-shaped merges, a backup
     restore)? Contents are read live — confirm nothing cached is a value. Main-actor use only.
   - Marks/fresh-best/Lock Screen: `SetBadgeMath.badges/outcomes(for:finishedEntries:)` give exactly the per-entry
     reads' results (order of `finishedEntries` preserved — ties in `outcomes` depend on it).
   - `PerformanceHistory(context:finishedEntries:)`: used only by `latestEntry(matching:)`; is its result really
     order-independent? `historicalEntries` `contains` vs `!completedSets(of:).isEmpty`.
2. **F5, the data fix** — `PerformanceHistory.holdsTypedValues` / `applyPrefill`: every path that creates or changes a
   draft set's values with or without `prefilledAt` (template start, `addSet` carry-forward, equipment/preset switch
   moving drafts, bar picking, unit toggle, Repeat workout, AI routine, history edits, migration of older stores):
   could any now-refused prefill be one the user expects (a draft with values but no `prefilledAt` that is not
   typed)? Does `LivePrefillUITests` really go red without the guard (ticket says it was shown) and is it robust?
3. **Test-only code**: `PerfFixture` (`-uiTestPerfStore`, `-uiTestPerfNoHistory`) gated by `-uiTestReset`; never reaches
   a real store. Confirm no `[DEBUG-p1]` probe, `P1Probe` or `P1_` switch is left in app/test sources
   (`work-record/performance/p1-tools/probe.patch` and `P1WorkoutLagUITests.swift.txt` are parked, uncompiled).
4. Doc comments vs callers; Swift 5 mode, the existing concurrency style; anything missed that still scans the whole
   history per change on the live workout path (report as a finding with evidence, not a rewrite).

Per AGENTS' reviewer rule: build; the Unit plan; UI round 1: `AAAWarmUpUITests`, `LivePrefillUITests`,
`FloodlightLiveUITests`, `CoreLoopUITests` (2 workers). You may inspect Claude's xcresults rather than rerunning the
whole Workout plan: `/tmp/p1/unit-clean.xcresult` (Unit plan), `/tmp/p1/prefill-clean.xcresult`,
`/tmp/p1/workout-1.xcresult` (Workout plan, 2 workers). Use your own derived data and result paths under
`/tmp/codex-p1/`. Claude runs nothing while you run. Do not modify files other than the report; do not commit or push.

Write `work-record/performance/codex-review-p1.md`: findings P1/P2/P3 (severity) with file:line, failure scenario and
fix; Verified / Not verified / Known flaky; end with exactly `Verdict: clear` or `Verdict: not clear`.
