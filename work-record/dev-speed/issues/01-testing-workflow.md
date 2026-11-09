# 01 — A faster, more reliable testing workflow

Type: task
Status: **approved** (the user, 2026-11-08: "fold it all into the test-speed ticket") — after S5, before N1
Implementer: Claude; Reviewer: Codex.

## Why

The user (2026-11-08): "even the unit tests sometimes take long", then: "testing takes significant portion of our
time… I want to see if there is a way to improve our testing workflow." The user's principles (kept as the goal):
simulator exploration for new features, unfamiliar behaviour and visual checks; maintained XCUITest automation for
repeatable workflows; fast relevant checks after small changes; targeted exploration only where needed; comprehensive
UI regression at major checkpoints and before release; never remove coverage, weaken assertions or claim untested
behaviour works; report results and remaining gaps.

**Where the time went (2026-11-07/08, measured in this project):**
- Fixed overhead, not the tests: 90 unit tests ran in ~50 s and 21 in ~42 s — the build, the hosted test bundle
  (`TEST_HOST`: the simulator boots, the app installs and launches), the app's launch work
  (`WorkoutTrackerApp.swift:43–47` reconciles the 1,877-model catalog on every launch), a few slow suites on a fresh
  simulator (`EquipmentLifecycleTests` 179 s once), ~1,100 unit tests run serially.
- Codex re-ran the same UI tests Claude had just run, every review round (S4: 3 rounds, 10–25 min each).
- Flaky tests forcing reruns and investigation: the cardio start (`cardioTimer` within 10 s; the warm-up and
  `testCardioAccessibilityCaptureAndSave`), the software keyboard not rising on parallel clones (7 goals-keyboard
  captures), typed digits dropped under load; the warm-up test itself uses the flaky cardio start.
- Screenshot volume: 150 of the 319 UI tests are captures; the Phase 1 run produced 1,007 screenshots (777 screens).
- A deferred "all captures at the end of the phase" run found two tests broken earlier (S1/S2) only at the end.

## Plan

1. **Measure:** one full unit run with per-test durations (xcresult); one UI class timing; record the slowest suites
   and the fixed overhead.
2. **Unit-test overhead:** skip the catalog reconcile when the app only hosts unit tests (check first which tests
   rely on it); keep the test simulator booted between runs; fix or isolate the slowest suites. Only with the user's
   OK: run pure Domain tests without the host app (a project change).
3. **Quick simulator exploration:** a script that launches the app with fixtures on the test simulator and takes
   screenshots, with the motion permission granted up front (`xcrun simctl privacy … grant motion`) so no alert
   covers the screen — for new screens and "does this look right" checks without writing a test. Capture tests stay
   for screens worth guarding.
4. **Named test groups (Xcode test plans):** e.g. Domain (unit, no UI), Today/Train, Workout core, History/Progress,
   Captures, Full. Choosing a scope = choosing a plan; Claude and Codex run the same sets.
5. **Fix the flakes instead of re-running around them:** a launch-only warm-up test in place of the cardio one; the
   cardio start waits on the app's state, not a fixed 10 s; the simulator's hardware keyboard off for test runs so
   the software keyboard always rises; 2 parallel workers for typing-heavy classes (or serial).
6. **Captures per ticket, not deferred:** each ticket captures only its changed screens (light/dark ×
   default/AccessibilityL); the full capture set only at checkpoints (after N5) and the release (R).
7. **Codex reruns less:** Codex keeps its own build and unit tests every round; it reruns UI tests in round 1 (the
   ticket's focused classes) or when a fix changes UI behaviour; test-only and docs-only rounds review Claude's
   xcresult evidence instead.
8. **Reporting:** each ticket's evidence ends with a short fixed block — **Verified** (named tests, counts, exit
   codes) / **Not verified** (and why) / **Known flaky** (named, with the follow-up).
9. **Write the rules down:** DEVELOPMENT → Verification scope (tiers: every edit = build; small change = affected
   unit suites + one affected UI class + a quick exploration screenshot for visual changes; ticket done = the ticket's
   test plan + changed-screen captures; checkpoint/release = Full) and AGENTS (Codex's rerun rule, the reporting
   block). Unchanged: never remove coverage or weaken assertions; ask before runs over ~20 min.

## Acceptance

- A before/after timing table (unit full run, one UI class, a typical ticket check).
- The warm-up and cardio-start flakes and the parallel keyboard/typing failures gone in two consecutive runs.
- Test plans in the scheme; the exploration script works on WT-Floodlight with no permission alert.
- DEVELOPMENT and AGENTS updated; Codex clear.

## Progress

Branch `ericlee4992/dev-01-testing-workflow` (off `main` `4204fbc`), worktree `…/workspaces/Health App/UI_design`.

### 1. Measurement (2026-11-08, "before"; WT-Floodlight `9E822EF6-…`, iOS 27.0, Xcode 27.2, derived data in the session scratchpad)

| What | Wall time | Notes |
|---|---|---|
| Cold `build-for-testing` (empty derived data) | **78 s** | exit 0 |
| Full unit run, `test-without-building`, simulator already booted | **108 s** | **1112/1112 passed**, exit 0; Swift Testing reports 69.7 s for the tests themselves |
| 3-test suite, `test-without-building`, simulator booted | **8–9 s** (3 runs) | install + host-app launch + tests: 5.4 s |
| Same, `xcodebuild test` (build + test), no source change | **21 s** | the build step's no-op cost is ~13 s |
| Same, after editing one existing Domain file / one view file | **29 s / 28 s** | incremental compile + link |
| Same, simulator **shut down** before the run | **41–49 s, every run** (4 runs) | xcodebuild boots it, then **shuts it down again after the run**, so each run repeats the boot; the time is all in "Launching WorkoutTrackerTests" (30.5 s), install 0.0 s |
| Same, simulator booted with `simctl bootstatus -b` and left booted | **39 s, then 18 s, 16 s** | first run after a boot still pays the settling cost |

Findings:
- **The unit tests themselves are not slow.** 1,112 tests take ~70 s because Swift Testing runs them in parallel in one
  process (their summed durations are 18,867 s; no suite dominates, so per-test durations from the xcresult don't
  rank anything useful). The scheme runs the unit target serially between targets, which is fine.
- **The biggest avoidable cost is a shut-down simulator:** a run against a shut-down simulator costs ~35 s extra, and
  because xcodebuild shuts it down again afterwards, *every* following run pays it too. This explains "even the unit
  tests sometimes take long". Fix: boot the test simulator once (`xcrun simctl bootstatus <id> -b`) and keep it booted.
- **The catalog reconcile is not a unit-test cost:** `CatalogSeeder.reconcile` returns early when the store's catalog
  fingerprint matches (`CatalogSeeder.swift:19–31`), so in the unit-test host (the simulator's persistent store) it
  is a fetch, and the whole install-launch-tests step is 5.4 s. Plan item 2's "skip the reconcile when hosting unit
  tests" would save under a second; **not done** (no code change for a sub-second gain). UI tests are different: every
  `-uiTestReset` launch seeds the full catalog into an empty store — measured under the UI timing below.
- Builds dominate small checks: 21–29 s of a ~30 s "build + one suite" check is the build.

**One UI class** (`CardioUITests`, 9 tests, serial, booted WT-Floodlight): **617 s, 9/9 passed, exit 0** (33–97 s per
test). The xcresult step timeline of `testIndoorPhoneMotionDefaultCapture` (39 s) showed where it goes:
- each launch ~11.4 s: 1.6 s ending the previous app, **5.5 s "Setting up automation session"** (XCTest's own), 4.4 s
  until the app is idle (start-up incl. seeding the catalog into the empty `-uiTestReset` store);
- then **~27 s in `reach()` polls on elements already on screen**: `for _ in 0..<10 where !visible() { … }` evaluates
  `visible()` (≈1 s of queries) on all 10 iterations — `where` only skips the body. 85 such loops in 29 UI-test files.

### 2. Changes (commit `38fa5c6`)

- **Polling loops** — all 85 `for _ in 0..<N where C { body }` → `for _ in 0..<N { guard C else { break }; body }`
  (mechanical, same bound/body; the assertions after the loops unchanged; no condition has side effects — checked:
  all are exists/isHittable/frame/value/`waitForExistence` reads). **After: `CardioUITests` 362 s, 9/9, exit 0
  (−41 %)**; e.g. `testIndoorPhoneMotionDefaultCapture` 39 → 17 s, `testOutdoorRouteDefaultCapture` 65 → 29 s.
- **The cardio-start flake was an app hang** (both failing xcresults of 2026-11-08 kept in session
  `7de0aa3c…/scratchpad`, `s5cardio.xcresult` and `main3.xcresult`): after the Start tap XCTest got no idle for 60 s
  ("App event loop idle notification not received") and attached a spindump. Both spindumps show the main thread for
  all samples in `WorkoutStartFlow.startNew` → `CardioSession.start` (`Cardio.swift:319`) → `RestTimerService.skip` →
  `UserNotificationScheduler.cancel()` (`RestTimer.swift:65`) → `removePendingNotificationRequests` → a synchronous
  XPC reply from the simulator's notification daemon that never came. So: the daemon's state (bad since ~02:00 on
  11-08), not the test; and on a phone with a slow daemon the same freeze would hit a cardio start or any rest
  start/skip. **Fix (app):** `UserNotificationScheduler` sends every notification-center call through one private
  serial queue — off the main thread, still in call order. It also closes a latent race: `schedule` removed
  synchronously but added in a detached `Task`, so `schedule` then `cancel` could leave a stale "Rest complete".
  Unit plan after the fix: **1112/1112, exit 0, 100 s**. The test's 10 s wait is unchanged (no longer timeout).
  (Ruled out first: the rest-alarm audio session — UI-test runs use `SilentRestAlarm`; motion/location prompts — UI
  tests collect no sensors.)
- **Keyboard on parallel clones** (the 7 goals-keyboard failures of the Phase 1 run, `p1.xcresult`): the keyboard
  element existed at y 976 on a 932-pt screen — iOS had minimised it for a hardware keyboard. The base simulator's
  `com.apple.keyboard.preferences` had `HardwareKeyboardLastSeen` and `AutomaticMinimizationEnabled` true; clones copy
  them and have no Simulator window to say otherwise. `scripts/prepare-test-simulator.sh` sets both false (and boots
  the simulator, leaving it booted).
- **Warm-up:** `AAAWarmUpUITests/testLaunchReachesTheTabBar` (launch + tab bar, 60 s) runs first in every area plan.
- **Test plans:** `TestPlans/` Full (default) · Unit · TodayTrain · Workout · HistoryProgress · GymsExercises ·
  ProfileAI · Review, written and checked by `scripts/test-plans.py` (every UI class in exactly one area plan; coverage
  off). `xcodebuild -showTestPlans` lists all 8; CI's `-only-testing:WorkoutTrackerTests` and
  `simulator_export.sh` keep working under the default Full plan.
- **Exploration:** `scripts/explore.sh`. **Progress tab:** `scripts/test-progress.sh` now counts Swift Testing and
  serial XCTest lines (it showed 0 for both before).
### 3. Verification so far (2026-11-08/09, WT-Floodlight, session `b075476f…` scratchpad `m/`)

- **Cardio-start fix proven by reproduction:** with the simulator's `usernotificationsd` paused (`kill -STOP`, resumed
  after), `CardioUITests/testSavedDistanceEditor…`: **old `RestTimer.swift` (from `main`) → failed at
  `CardioUITests.swift:58`, "App event loop idle notification not received", exit 65** (`stop-old.xcresult`) — the
  exact flake, now on demand; **fixed build → passed (34.5 s), exit 0** (`stop-fixed.xcresult`).
- **Parallel keyboard/typing run 1** (after `prepare-test-simulator.sh`; 3 workers; warm-up + `FloodlightAIRoutineUITests`
  + `FloodlightLiveUITests` + `FloodlightProfileUITests`): **42/42 passed, exit 0**, 1771 s (`par1.xcresult`) — incl.
  the 7 goals-keyboard tests, the number-pad test and the typing tests that failed on clones in the Phase 1 run. The
  wall time is set by the clone that gets the 15-test AI-routine class (XCTest spreads whole classes).
- **Parallel run 2** (same selection, `ec082d2`, the user chose to repeat it): **42/42 passed, exit 0**, 1642 s
  (`par2.xcresult`). Two consecutive clean runs.
- **Exploration script:** `scripts/explore.sh -s light,dark,dark-axl` on WT-Floodlight: exit 0, 3 PNGs in ~18 s, no
  permission alert; first version set the simulator's appearance, but the app's own `-appearance` setting wins, so it
  now passes `-appearance` like the capture tests.

- **Not done (and why):** skipping the catalog reconcile in the unit-test host — fingerprint-gated, < 1 s. Candidate
  follow-up, not in this ticket: a pre-seeded UI-test store copied per launch could save part of the 4.4 s idle wait
  on each of the suite's ~400 launches; needs care with the SwiftData store files.

## Comments
