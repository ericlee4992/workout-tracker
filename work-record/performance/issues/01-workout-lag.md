# P1 — The app lags during a workout

Type: bug (performance)
Status: **approved — for 0.2.1** (the user, 2026-11-11; first in order: lag → goal setup → Korean DB)
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
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

Not started.

## Comments
