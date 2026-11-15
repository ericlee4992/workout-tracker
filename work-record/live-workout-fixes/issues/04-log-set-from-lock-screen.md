# 04 — Log a set from the Lock Screen (Live Activity)

Status: implemented, in review (Claude implements, Codex reviews — T6); branch `ericlee4992/lock-screen-log-set`
Type: task

## The user's request (2026-11-15)

> next update is being able to log a [set] from live screen widget. build the mock and show me first

Research: [competitor gaps](../../research/2026-11-13-competitor-gaps.md) #3 "Lock Screen set confirm" (Hevy has it).

## Decided from the mock (the user, 2026-11-15)

Mock captures: `captures/04/mock-options-AB.png` (today, A, B), `captures/04/mock-A-now.png` (chosen).
- **Option A, revised:** once rest is over, the card shows the **current** set only — **"Now"** over its value
  (`110 lb × 8`) with a **Done ✓** pill; no PREVIOUS (the user: "just show the current set (not next or previous)").
  The footer keeps the gym, heart rate and sets. The Dynamic Island's expanded view the same ("Now", Done, no
  PREVIOUS). During a rest the card is unchanged (countdown, +15s / Skip, footer "Next · Set 3 · …").
- **Done logs the set as shown and starts the rest** — the same as the set's check in the workout: superset members
  rest only after the last member (D48), heart-rate rests as configured (D43). Changing the numbers stays in the app;
  no Done when the set has no value to log.
- The card keeps following the phone's Light/Dark appearance (the island is always black).

## Acceptance

- Done appears only in the ready phase with a loggable value; VoiceOver: "Log set 3, 110 lb × 8" (warmup / drop /
  failure named).
- Done logs **exactly the set the card showed, with the values it showed**: if the workout moved on (that set is done,
  deleted, no longer next, its values changed, the workout finished) nothing is logged and the card is refreshed.
- The same completion path as the in-app check (snapshot, memory, rest start / superset skip, notification, alarm,
  Watch), working from a minimised workout and a cold background launch.
- The card fits the 160 pt budget at every Dynamic Type size; Light/Dark captures; gallery tests updated.
- Unit tests for the stale/wrong-set guards and the shared completion path; UI: the gallery captures.

## Progress

### What changed

- **Widget (shared with the app):** `NextSet.setID` — present only when `WorkoutSession.isLoggable` (reps, and a weight
  where taken), so `isLoggable` = Done offered; `NextSet.previous` removed (nothing draws it; the builder no longer
  reads `PerformanceHistory` for it on every push). `WorkoutActivityLogSetIntent` (a `LiveActivityIntent`, runs in the
  app) carries the workout, the set and the value shown; `WorkoutActivityCommandBridge.logSetHandler`.
  `ActivityLogSetButton` ("Done", VoiceOver "Log set 3, 110 lb × 8" / warmup / drop / failure). Card ready instrument:
  "Now" + value + Done (no PREVIOUS); island expanded: "Now", Done in place of the sets readout, no PREVIOUS line.
- **App:** `WorkoutActivityCommands.performLogSet` — rebuilds the card's current set from the store and logs only if
  the set id, weight, unit and reps all match what was shown and it is still `WorkoutSession.nextSet` and undone;
  otherwise logs nothing and re-pushes the card. Then `WorkoutSession.toggleCompletion` (the row's check) and
  `RestTimerService.restAfterCompletionChange` → `broadcastRest`, `didApply`, card push. The command steps shared by
  +15s / Skip / Pause / Resume / Done are one `apply` (no behaviour change for the old commands).
- **Shared rest rule:** D48 (no rest between superset members; a running one skipped) moved from
  `ActiveWorkoutView.updateRest` into `RestTimerService.restAfterCompletionChange`, used by the screen and by Done.
- Mock code, the `-protoLogSet` switch and `LockScreenLogSetMockUITests` removed. D90; README; SPEC.

### Verification (author)

- `build-for-testing` exit 0. Unit plan **1302/1302** (`build/results/ls04-unit.xcresult`): new
  `WorkoutActivityContentTests` (the card's set id only for a loggable set; Done logs the shown set, starts the rest,
  notification, alarm, card; a stale Done — value edited, set already checked, not the next set, set deleted, workout
  finished / unknown — logs nothing and refreshes the card; Done inside a superset skips the rest) and
  `RestTimerTests.supersetMembersRestOnlyAfterTheLastOne`.
- `FloodlightSystemUITests` **7/7** (`build/results/ls04-sys.xcresult`): the gallery in light/dark × Default/AXL with a
  Done check per state and the 160 pt check; **`testRealLiveActivityDoneLogsTheSet` presses Done on the Simulator's
  real Lock Screen card** — the app's header goes N → N+1 sets and its rest runs (captures `04-real-*`, copied to
  `captures/04/`).
- After the loggability fix: `FloodlightLiveUITests` 20 + `CoreLoopUITests` 9 + the real Done test + gallery light /
  dark AXL — **32/32**, exit 0 (2 workers; `build/results/ls04-ui.xcresult`).

**Not verified:** on a phone (the Simulator's real Live Activity is the closest check); a cold background launch by
Done (the existing commands' cold path is unit-tested and shared). **Known flaky:** none seen.
