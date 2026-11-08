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

Not started.

## Comments
