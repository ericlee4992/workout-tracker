# P1 — The app lags during a workout

Type: bug (performance)
Status: **merged to `main` 2026-11-12; the phone check waits for the 0.2.1 TestFlight build** (was: approved — for 0.2.1 (the user, 2026-11-11; first in order: lag → goal setup → Korean DB))
Implementer: Claude; Reviewer: Codex (a Paseo Codex agent, [tools-paseo](../../../docs/agents/tools-paseo.md)), to "clear".
Branch (when built): `ericlee4992/perf-01-workout-lag` off `main`.
Release: **0.2.1** together with [N13 goal setup](../../nutrition/issues/13-goal-setup.md).

## The report (the user, 2026-11-11, on 0.2.0 (10), iPhone 15 Pro Max)

"The app lags when you do workout" — typing weight/reps, scrolling the workout, opening/adding exercises: "basically
the whole app during workout". Not seen outside a workout (to confirm while measuring).

## Likely shape (to verify — not a conclusion)

Something that ticks while a workout is live (the elapsed clock, the rest timer, heart rate, the Live Activity, the
Today/Train views behind it) invalidating large view trees every second, or a whole-store `@Query`/recomputation
(records, previous performance, history, Today's food and up-next readings) re-run on each change, so every
keystroke and scroll pays for it. The soft redesign and nutrition (S1–S6, N5, N10) added views and queries that stay
alive under the workout.

## Plan (diagnose before fixing — `diagnosing-bugs`)

1. **Reproduce and measure** on the Simulator with a realistic store (the design sample + a long workout: 8+
   exercises, 30+ sets, rest timer and heart rate running) and on the user's phone with a development build:
   Instruments Time Profiler, SwiftUI (body evaluations, update causes) and Hangs; per-keystroke and per-scroll
   frame times. Record the numbers here.
2. **Find the cause(s)** from the measurements: which views re-evaluate on each tick or keystroke, which queries or
   computations run, and why.
3. **Fix** narrowly (isolate ticking views, move derived work out of `body`, scope queries, cache per-workout
   readings), keeping behaviour identical.
4. **Prove it**: the same measurements before/after (target: no dropped frames typing or scrolling on the phone, no
   hang over 100 ms); a regression guard where one is practical (e.g. a performance test or a body-count check);
   the Workout area plan and the user's feel on the phone.

## Acceptance

1. Before/after measurements recorded (Simulator and phone), the cause(s) named with evidence.
2. Typing, scrolling and Add Exercise feel immediate on the user's phone during a long workout (the user confirms).
3. Workout area plan green (flakes per DEVELOPMENT), unit tests for any moved logic; Codex clear.

## Progress

**2026-11-11 — diagnosis (measured, no fix yet).** Findings shown to the user before any fix.

### Setup

- Store: new fixture `-uiTestPerfStore` (with `-uiTestReset`; `Domain/PerfFixture.swift`): 150 finished workouts every
  other day × 6 exercises × 4 sets (3,600 sets), and a live "Perf Day" of 8 exercises × 4 sets (16 logged, a rest
  running), which the app reopens at launch. No heart-rate sensor (the simulator has none).
- Build: **Release**, simulator WT-Floodlight (iOS 27), arm64 only; the UI driver build adds `ENABLE_TESTABILITY=YES`
  (needed for the unit target to compile in Release; same for before and after).
- Probes (temporary, tagged `[DEBUG-p1]`, not committed): a `CADisplayLink` hitch detector (frame gap > 34 ms logged
  with its length), per-5 s `body` counts for Today/History/Progress/Train/Workout/cards/rows, and timers around
  Today's week summary, the live badges and the Live Activity content. Switches `P1_NO_CARDIO_SAVE` /
  `P1_NO_CARDIO_TICK` turn the recorder's save / its whole 2 s refresh off.
- Loops (scripts in [p1-tools](../p1-tools/)): `idle-loop.sh` (launch, settle 12 s, 20 s idle in the open workout:
  CPU, hitches, body counts); `drive.sh` runs the temporary UI driver `P1WorkoutLagUITests` (idle 10 s → scroll to
  the end → type weight + reps into the unlogged sets → scroll → Add Exercise) and splits hitches per phase;
  `drive-sample.sh` also attaches macOS `sample` to the app during one phase. Time Profiler via `xctrace --attach`
  picked the other booted simulator's process, so `sample` on the host pid is used instead.

### Numbers (baseline, Release, heavy store)

| Measurement | Result |
|---|---|
| Idle 20 s in the open workout, untouched | CPU 58 %; 13 freezes totalling **8.4 s**, worst **2.2 s** |
| …with the recorder's save off (`P1_NO_CARDIO_SAVE`) | unchanged: 8.6 s frozen, worst 2.5 s — the save is not needed |
| …with the recorder's 2 s refresh off (`P1_NO_CARDIO_TICK`) | after launch settles: **0** freezes, **0** hidden-tab bodies |
| Idle 20 s **with heart rate** (`EXTRA_ARGS=-uiTestHeartRate`, fixture feed: 1 beat/s; the user wears AirPods for heart rate) | CPU 100 %; **19.0 s of 20 s frozen**, worst 3.6 s; 25 recorder saves; Today re-runs 10–14× per 5 s (3.5–6.1 s of week summary per 5 s); the workout's cards/rows re-render ~100× per 5 s |
| Driver, idle 10 s | 3.1–3.9 s frozen (32–39 %); 0 ms with the refresh off |
| Driver, scrolling to the end | 66–69 % of the time frozen |
| Driver, typing weight + reps in 3 sets | 36–44 s frozen, worst 3.6–7.0 s; after a weight, the reps field did not take focus (driver fails there in every run, also with the refresh off) |
| One Today week summary (`TodayView.weekSummary`) | 550–650 ms, run 2–3 times per 5 s **behind the cover** |
| One badge refresh (`ActiveWorkoutView.refreshBadges`, 8 entries) | 1.6–2.2 s, on each committed value |
| One Live Activity content build (`WorkoutActivityContent.make`) | 630–880 ms, on each committed value |
| Main thread while idle (sample, 8 s) | 67 % busy; 58 % in `TodayView.body → weekSummary → WeekSummaryInput.init(workout:)` |
| Main thread while typing (sample, 12–20 s) | 97–99 % busy: Today week summary 27–55 %, `SetBadgeMath` 2–31 %, Live Activity 3–13 % |

### Causes (from the measurements)

1. **Trigger — the cardio recorder's 2 s refresh runs in every workout, and again on every heart-rate sample**
   (`WorkoutHeartRateCoordinator.swift:128-135` calls `cardio.refresh()` per sample). With heart rate the writes are
   real (new sample rows each time), so "write only on change" alone cannot stop them for the user. `CardioRecorder.attach` starts a 2 s timer
   (`CardioRecorder.swift:97`); `refresh()` assigns the workout's sensor checkpoint fields every time, even unchanged
   and with no sensor or cardio (`:171-176`), then saves (`:216`). Every save had `hasChanges == true`. SwiftData's
   `@Query` reacts to the change itself (switching off only the save changed nothing), so every tab behind the cover
   (Today, History, Progress) refetches and re-runs `body` every 2 s.
2. **Amplifier — Today's week summary walks the whole history in `body`.** `TodayView.weekSummary` maps every
   finished workout to `WeekSummaryInput` (ordering all its entries and reading all its sets) although
   `WeekSummaryMath.summary` only uses this week and last week (`WeekSummary.swift:102-128`). ~600 ms per pass on
   150 workouts; the main cost of every freeze above.
3. **Per commit — the live badges re-read all history once per exercise.** `refreshBadges` calls
   `SetBadgeMath.badges(for:in:)` per entry; each fetches every finished workout and orders all their entries
   (`SetBadges.swift:99-121`). 8 entries × whole history ≈ 2 s per committed weight/reps/check.
4. **Per commit — the Live Activity content re-reads all history.** `PerformanceHistory.historicalEntries()` fetches
   every `ExerciseEntry` and orders each one's sets (`PreviousPerformance.swift:354`); the content key includes the
   badge inputs, so each commit rebuilds it (~0.7–0.9 s). The same lookup feeds each set row's "previous" value
   (`LiveSetRow` prefill), likely part of opening a workout / Add Exercise — not yet measured on its own.

Not yet measured: the Add Exercise phase (the driver stops at the reps focus failure first), the focus loss's cause,
History/Progress body cost on their own (~1 % each in the samples), and the phone (Release build with the user's
real store and a heart-rate source, which adds sample rows every tick). Mac simulator times are not phone times; the
ratios and the 2 s cadence are what transfer.

### Proposed fix (approved by the user 2026-11-11: "yes, start")

- F1 `CardioRecorder.refresh`: assign only changed values and save only when something changed (no write at all in a
  lifting workout without a sensor); keep the cadence for real cardio/heart-rate.
- F2 Today: build week inputs only for workouts from last week's start onward (identical result).
- F3 Badges: one history read per refresh, grouped by scope, instead of one per entry (the receipt already does
  this with `finishedEntries`); consider caching it for the live workout (finished history does not change while it
  runs except through History edits — invalidate then).
- F4 `PerformanceHistory`: fetch only finished, matching entries (predicate) and reuse one read per refresh.
- F5 (heart rate): keep heart-rate changes from re-rendering the whole workout list (the readout in its own small
  view) and make the hidden tabs cheap (F2); only if that is not enough, write samples less often — a durability
  trade-off for the user to decide.
- Guards: unit tests (recorder refresh without a sensor leaves `hasChanges` false; week summary unchanged with the
  filter; badges/previous identical with the shared read) and a timing check on the perf store; rerun the same loops
  for before/after.

**2026-11-11 — fix implemented (branch, not merged).** What changed, all behaviour-identical except the data fix:

- **F1 `CardioRecorder.refresh`** assigns the four sensor checkpoints only when they differ and `persist()` saves only
  when the context has changes. A lifting workout without a sensor no longer touches the store; heart-rate samples
  are still written and saved at once.
- **F2 week summary** — `WeekSummaryMath.summary(ofWorkouts:)` builds inputs only from `windowStart` (last week's first
  day); Today and the Workout tab's "This week" card use it. `summary(of:)` uses the same `windowStart`.
- **F3 shared finished history** — `FinishedHistoryCache` (Domain) holds the finished workouts' entries (membership
  only; contents read live), checked against two SQL counts before each use. The live screen owns one and uses it
  for the marks (`SetBadgeMath.badges/outcomes(for:finishedEntries:)`, one read per refresh instead of one per
  entry), the fresh-best band, the Lock Screen content (`WorkoutActivityContent.make(…, finishedEntries:)`) and
  each row's PREVIOUS (`PerformanceHistory(context:finishedEntries:)`, via the `finishedHistory` environment value;
  used only by `latestEntry(matching:)`, a maximum over a total order).
- **F4 `PerformanceHistory.historicalEntries`** tests "has a completed set" with `contains` instead of sorting every
  entry's sets.
- **F5 typed values are never prefilled over.** Reproduced first: `LivePrefillUITests` types 77 into the incline
  press's first set (nothing logged in that exercise), minimises and resumes — on `main`'s logic the row shows (and
  the store holds) last session's 55; a temporary trace showed `applyPrefill` called on the rebuilt row with
  `dirty=false` and the typed 77. Fix: `applyPrefill` also refuses a set that `holdsTypedValues` (values without
  `prefilledAt`; every commit clears it, only prefill and carry-forward set it). The test fails with the guard
  switched off (55) and passes with it (77). A first version of the test was wrong (it scrolled, and the field index
  then named another exercise's row); fixed by skipping the rest instead of scrolling. Fix 2 as first proposed ("only
  the heart-rate readout redraws") was dropped: measured, the workout screen's own redraws were 2–3 % of the main
  thread; the cost was the history scans above.
- Test-only: `-uiTestPerfNoHistory` (the same live workout over an empty history, the control run).

### After (same loops, Release simulator build)

| Measurement | Before | After | No-history control |
|---|---|---|---|
| Idle 20 s, no heart rate | 8.4 s frozen, worst 2.2 s, CPU 58 % | **0.05 s**, worst 51 ms, CPU 11 % | — |
| Idle 20 s, heart rate 1/s | 19.0 s frozen, worst 3.6 s, CPU 100 % | **2.3 s**, worst **83 ms**, CPU 17 % | 1.1 s, worst 68 ms, CPU 15 % |
| One Today week summary | 550–650 ms | ~18 ms | — |
| One badge refresh (8 entries) | 1.6–2.2 s | ~45 ms (first read of a screen ~575 ms) | — |
| One Lock Screen content build | 630–880 ms | ~10 ms | — |
| Driver: idle / scroll-to-end / typing / scroll / Add Exercise (frozen share) | 32–39 % / 66–69 % / 36–44 s frozen / 41 % / not reached | 0 % / 38 % / 50 % / 14 % / 59 % | 1 % / 37 % / 49 % / 15 % / 61 % |

With the fixes the heavy store behaves like the empty-history control in every driven phase; what remains there is
the UI-test tool (its accessibility snapshots took 25 % of the main thread while typing) and the simulator keyboard,
present with no history at all. With heart rate, each saved sample still costs a short stutter (~60 ms on the Mac
simulator; 83 ms worst), about twice the no-history control: every save makes SwiftData re-notify every view that
reads a workout. The remaining lever is saving samples less often — a durability trade-off left to the user, only if
the phone still shows it.

Probes for re-measuring (the phone check): `p1-tools/probe.patch` (`patch -p0 < work-record/performance/p1-tools/probe.patch`
from the repo root; adds `P1Probe.swift` and the `[DEBUG-p1]` lines) and `p1-tools/P1WorkoutLagUITests.swift.txt`
(copy into `WorkoutTrackerUITests/` as `.swift`). Never commit either applied.

### Verification (2026-11-11)

- `xcodebuild build-for-testing` Debug: exit 0 after the probes were removed.
- Unit plan (`-testPlan Unit`): **1,289 tests in 136 suites passed**, exit 0 (`/tmp/p1/unit-clean.xcresult`). New:
  `WeekSummaryTests.windowedSummaryEqualsTheWholeHistorysSummary`,
  `SensorCheckpointWriteTests.aRefreshWithNothingNewWritesNothing`,
  `PreviousPerformanceTests.aTypedValueIsNeverReplacedEvenFromACleanRow` and `.sharedFinishedHistoryGivesTheSameReference`,
  `FinishedHistoryCacheTests.sharedHistoryMarksEqualPerEntryReadsAndFollowHistoryChanges`.
- `LivePrefillUITests` (new, added to the Workout plan): passes, exit 0; fails with the guard off (shown above).
- Workout area plan (the user approved the run, 2026-11-11), 2 workers, `/tmp/p1/workout-1.xcresult`: **73 of 74
  passed**, exit 65. The one failure, `FloodlightLiveUITests.testACompletedSetCanBeCorrectedInPlace` (typed "102.5"
  arrived as "102."), is the known parallel-only flake recorded in Floodlight 11 and release R; rerun alone,
  serially: passed, exit 0 (`/tmp/p1/workout-1-rerun.xcresult`).

Verified: build; Unit plan; Workout plan (one known flake, passing alone); `LivePrefillUITests` red without the guard,
green with it; before/after loops on the Release simulator build. Not verified: the phone (dev build, the user's store
and AirPods heart rate); Codex review. Known flaky: `FloodlightLiveUITests.testACompletedSetCanBeCorrectedInPlace`
(parallel only).

**2026-11-12 — Codex round 1: clear** ([report](../codex-review-p1.md); reviewer's build, Unit 1,289/1,289 and focused
UI 27/27 in `/tmp/codex-p1/`). One P3, resolved on the user's complaint list (Add Exercise): "Recent at <gym>" was
read in `body` — twice per redraw in `ExercisePickerSheet`, once in the empty workout — and at a gym with fewer than
five past exercises it walks the whole history; with heart rate every saved sample redraws. Now read once when the
sheet / the screen appears (and when the workout's gym changes): `ExercisePickerSheet.recentAtGym`,
`ActiveWorkoutView.recentAtGym` + `loadRecentAtGym`. Measured with the probes re-applied (`probe.patch`), the driver
plus a 5 s pause on the open sheet, heart rate on and the new fixture flag `-uiTestPerfNewGym` (the live workout at a
second gym with no history): lookups 47 → 2 per run; the open sheet with an empty search 23 % → 18 % frozen, worst
155 → 113 ms (the rest is the per-sample save). New `LiveRecentUITests` (Workout plan) checks both places still
show the list and that a search hides and restores it.
Round-2 verification: Debug build exit 0; focused UI (2 workers) `AAAWarmUpUITests`, `CoreLoopUITests`,
`FloodlightLiveUITests`, `FloodlightTourUITests`, `LivePrefillUITests`, `LiveRecentUITests`: **38/38 passed**, exit 0
(`/tmp/p1/focused-r2.xcresult`). Unit plan not rerun: only view code and the test fixture changed since the green
Unit run, and no unit test covers them (the reviewer reruns it).

**2026-11-12 — Codex round 2: clear, no findings** ([report](../codex-review-p1-b.md)): reviewer build exit 0, Unit
1,289/1,289 exit 0; focused UI 20/21 in parallel (exit 65: `CoreLoopUITests.testAddSetCarriesForwardTheLastCompletedSet`
"kg" for "lb", the parallel-only flake in public-beta 22), CoreLoop alone 9/9 exit 0 (`/tmp/codex-p1-r2/`).
**2026-11-12 — merged; phone check deferred (the user).** Asked how to test on the phone, the user chose to wait for
the 0.2.1 TestFlight build (with N13) rather than a dev build over the TestFlight app now. So P1 merges with
acceptance 1–2 open: in 0.2.1, the user does a long workout with AirPods heart rate and confirms typing, scrolling and
Add Exercise feel immediate; if not, re-measure on the phone with `p1-tools/probe.patch` (and consider saving heart
rate less often — the user's call, see "After").

## Comments

- **2026-11-11, second opinion (Fable 5.2, static read, nothing measured; asked by the user).** Agrees with causes 1,
  3 and 4 above. Adds, to measure during the fix: (a) each set row's `.task(id: prefillTaskID)` re-runs the
  whole-history "previous" lookup whenever the row reappears in the lazy `List`, a scroll cost; (b)
  `ActiveWorkoutView` passes fresh closures to every card and row, so each body pass re-renders all visible rows; (c)
  Add Exercise reads `recent` (all finished workouts, sorted) twice per body. Focus suspects: the per-row conditional
  keyboard `.toolbar` rebuilt during commit + badge animation, and `.scrollDismissesKeyboard(.interactively)`.
  **Possible data issue (unverified):** `isDirty` is row `@State` and is never reset, so a row only loses its
  protection if `List` discards its state off-screen. If it does, `applyPrefill` (`PreviousPerformance.swift:133`)
  could overwrite a committed, typed but uncompleted first set with last session's values when the row reappears. It
  checks neither `prefilledAt` nor existing typed values. To reproduce with a UI test before or with the fix; if it
  reproduces, guard it (skip when the set has values without `prefilledAt`).

