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

### Review round 1 (Codex, `codex-review-04.md`): changes requested → fixed

- **#1 (High) a failed completion save** left the stamp, snapshot and gym memory in the context. Now edits already
  pending are saved first (they are the user's; autosave would), and a failed completion save is **rolled back whole**,
  the card refreshed; the same Done works once saving does.
- **#2 a failed rest save** was published as a running rest. Now a failed rest save (start or superset skip) rolls back
  only the rest — the set stays logged — and only the restored rest is broadcast and pushed (no notification, no alarm
  for an unsaved rest; a failed skip leaves the running rest and its notification as they were).
- **#3 the stale-card match** missed the set's type and compared a rounded weight. The card now carries a **log
  fingerprint** (`WorkoutActivityContent.logFingerprint`: set id, type, exact weight bits, unit, reps, bar, entry,
  exercise, machine, preset, free-weight tag); Done sends it back and the app logs only if the store's next set still
  has it. The intent carries the set id and the fingerprint instead of display strings.
- **#4 (High) a cold-launch Done** started a heart-rate rest that nothing evaluated. D43's check moved from the live
  screen into `WorkoutHeartRateCoordinator.evaluateHeartRateRest` (the screen calls it and only redraws); a runtime no
  screen has claimed runs it on each sample (`restEvaluator`, set by `WorkoutActivityCommands`, cleared when the
  workout's runtime ends) and tells the Watch, alarm, screen and card. A dead sensor still falls back only when
  something ticks — in the background the cap ends the rest, as D43 already accepts.
- Test seams: `WorkoutSession.persist`, `RestTimerService.persist`, `WorkoutActivityCommands.save` (default
  `context.save()`).
- New tests: type change / unseen decimal refused; failed completion save rolled back (context, store, memory,
  snapshot) and retried; failed rest save keeps the set and publishes no rest; failed superset skip keeps the running
  rest; cold Done heart-rate rest ended early by a recovering sample with no screen.
- Round 2 verification (author): build-for-testing exit 0; Unit plan **1307/1307**
  (`build/results/ls04-r2-unit.xcresult`); UI (2 workers): `HeartRateUITests`, `FloodlightLiveUITests`, the real
  Lock Screen Done and +15s/Skip tests, gallery light — **27/28** (`build/results/ls04-ui2.xcresult`); the one failure,
  `FloodlightLiveUITests/testTheKeyboardUnitSwitchFollowsTheFocusedWeight` ("lb" ≠ "kg" while the keyboard's unit
  switch followed focus — no rest or Live Activity code involved), passed alone and serially
  (`build/results/ls04-ui2-rerun.xcresult`) and in round 1's 32/32: **known flaky** under parallel load.

### Review round 2 (Codex): changes requested → fixed

- **R2 #1** the fingerprint lacked the load type: it now includes the entry's effective load type (the frozen snapshot
  once captured, D23). Tests: a weighted → bodyweight edit before the first completion refuses Done; after the entry is
  frozen the same catalog edit leaves the card valid.
- **R2 #2** a failed save in the moved D43 transitions (recovered, fell back) left the rest cleared/changed in memory
  and the fallback mark set. Now pending edits are saved first, a failed transition save is rolled back (the rest as
  saved, its notification and alarm untouched), and `degradedRestSetID` is set only after the save — the next sample
  or tick retries. Test: a failed recovery save keeps the rest; the next reading ends it.
- **R2 #3** the no-reading fallback needed a sample. A screenless runtime now also runs D43 on its own tick
  (`restEvaluatorInterval`, 5 s; the screen's liveness tick does this when the screen is up), so a dead or missing
  sensor falls back to the standard timer after the 20 s grace while the app runs. (When iOS suspends the app nothing
  runs; the persisted cap then ends the rest.) Test: a cold Done with no sample ever falls back (a failed fallback save
  first, retried on the next tick) and the card says "fallback". The coordinator's `now` is injectable for this.
- Round 3 verification (author): build-for-testing exit 0; Unit plan **1310/1310** (`build/results/ls04-r3-unit.xcresult`);
  `WorkoutActivityContentTests` 29/29 three more times (timing-sensitive tests stable); `HeartRateUITests` + the two
  real Lock Screen tests serially **7/7**, exit 0 (`build/results/ls04-r3-ui.xcresult`).

### Review round 3 (Codex): changes requested → fixed

- **R3 (High)** a minimised workout kept the dismissed screen's `onSample`, so the runtime never ran its own D43 check
  (and a dismissed screen cannot redraw or push). Now the live screen **claims** the samples on appear
  (`claimSamples(for:)`) and **releases** them on disappear (`releaseSamples(for:)`, only its own workout's claim);
  `WorkoutActivityCommands.install` installs the runtime's `restEvaluator` once for the app's life (D43 for whichever
  workout is attached while no screen owns it — a minimised workout, not only a cold launch); `end` no longer clears it.
  The runtime's tick runs whichever check owns the workout (the screen's while it is up, else the runtime's), the same
  hand-off as a sample, while a workout is attached.
- Tests: a workout claimed by its screen, minimised, then Done with no reading falls back through the runtime (and the
  released screen is never called; another workout cannot release the claim); with the screen up the tick runs the
  screen's check, not the runtime's.
- Round 4 verification (author): build-for-testing exit 0; Unit plan **1312/1312** (`build/results/ls04-r4-unit.xcresult`);
  `WorkoutActivityContentTests` three more times, all exit 0; UI (2 workers): `HeartRateUITests`, `FloodlightLiveUITests`
  and the three real Live Activity tests — **26/28** (`build/results/ls04-ui4.xcresult`); both failures passed alone
  serially (`build/results/ls04-ui4-rerun.xcresult`): the known-flaky keyboard unit test, and
  `testRealLiveActivityEndsWhenTheWorkoutIsCancelled` ("the workout's card is up before the cancel" — two real Live
  Activity tests on parallel clones competing for Notification Center; run serially it passes). **Known flaky in
  parallel:** both; the real Live Activity tests are best run serially.
