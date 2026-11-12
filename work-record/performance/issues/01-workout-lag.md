# P1 — The app lags during a workout

Type: bug (performance)
Status: **approved — for 0.2.1** (the user, 2026-11-11; first in order: lag → goal setup → Korean DB)
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
| Driver, idle 10 s | 3.1–3.9 s frozen (32–39 %); 0 ms with the refresh off |
| Driver, scrolling to the end | 66–69 % of the time frozen |
| Driver, typing weight + reps in 3 sets | 36–44 s frozen, worst 3.6–7.0 s; after a weight, the reps field did not take focus (driver fails there in every run, also with the refresh off) |
| One Today week summary (`TodayView.weekSummary`) | 550–650 ms, run 2–3 times per 5 s **behind the cover** |
| One badge refresh (`ActiveWorkoutView.refreshBadges`, 8 entries) | 1.6–2.2 s, on each committed value |
| One Live Activity content build (`WorkoutActivityContent.make`) | 630–880 ms, on each committed value |
| Main thread while idle (sample, 8 s) | 67 % busy; 58 % in `TodayView.body → weekSummary → WeekSummaryInput.init(workout:)` |
| Main thread while typing (sample, 12–20 s) | 97–99 % busy: Today week summary 27–55 %, `SetBadgeMath` 2–31 %, Live Activity 3–13 % |

### Causes (from the measurements)

1. **Trigger — the cardio recorder's 2 s refresh runs in every workout.** `CardioRecorder.attach` starts a 2 s timer
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

### Proposed fix (waiting for the user)

- F1 `CardioRecorder.refresh`: assign only changed values and save only when something changed (no write at all in a
  lifting workout without a sensor); keep the cadence for real cardio/heart-rate.
- F2 Today: build week inputs only for workouts from last week's start onward (identical result).
- F3 Badges: one history read per refresh, grouped by scope, instead of one per entry (the receipt already does
  this with `finishedEntries`); consider caching it for the live workout (finished history does not change while it
  runs except through History edits — invalidate then).
- F4 `PerformanceHistory`: fetch only finished, matching entries (predicate) and reuse one read per refresh.
- Guards: unit tests (recorder refresh without a sensor leaves `hasChanges` false; week summary unchanged with the
  filter; badges/previous identical with the shared read) and a timing check on the perf store; rerun the same loops
  for before/after.

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

