# Live-workout 03 — Codex review, round 2

Target: `a37ec844..4bf4d6380eebef6e1ca4cbcf92f492f10b356dbe`, branch
`ericlee4992/workout-chart-machines`. Clean checkout at start. Same ticket, decisions and review rules as round 1.

**Final report — 2026-11-13.** Two findings resolved; one P2 provenance case remains. Independent build, Unit and
focused UI checks pass. Only this report was changed by the reviewer.

## Standards

No new finding from the standards pass. The retaken AccessibilityL pooled-session capture resolves round-1 #2:
the badge is under the machine name and the date, set and machine retain useful width. Opened all ten retaken PNGs.
The current draft fallback resolves round-1 #3, is limited to its own unfrozen variation, and retains existing
snapshot names for historical choices. The between-workout scenario in #1 is fixed, but its exact-source requirement
is only partly resolved; see the spec finding below.

## Spec

1. **P2 — Keep the winning entry's identity, not just its workout and machine.**
   `WorkoutTracker/Domain/ExerciseOverview.swift:510–514`. `sessionMachineName` still selects the first matching
   exercise/machine entry from an unordered relationship. A workout can have several such entries, with distinct
   frozen names: log a machine set, minimize the workout, rename the machine in its detail page, resume, and change
   the preset (a frozen entry splits into a new entry on the same machine), then log and finish. For a preset with
   history on two machines, All machines can display the earlier entry's old name beside the later entry's best set,
   even though the earlier entry is outside the selected preset. The supported path is `ActiveWorkoutView.minimize`
   (`:665–673`), `MachineDetailView.commitName` (`:322–331`, no active-workout restriction),
   `EquipmentLifecycle.rename`, and `WorkoutSession.choosePreset` (`:372–390`). This remains the D23 provenance
   problem from round-1 #1, now narrowed to repeated-machine entries within one workout. Carry the actual winning
   entry's snapshot name/gym (or its exact entry identity) through the history/day selection instead of resolving
   its machine UUID again. Add a regression with two entries in one workout sharing exercise/machine IDs but
   different frozen labels, with the winning entry second and under a different preset. The new regression only
   covers one entry per workout, so it cannot catch this case.

## Band test failure assessment

Inspected the author's xcresult summaries and the failed test's activity tree/log, not only the ticket summary:

- `area-workout.xcresult`: 78/79 passed; failure is the 3-second disappearance expectation in `expectGone`.
  The activity tree records the Warmup tap, then an accessibility existence check that itself occupies roughly
  seven seconds before the timeout is reported. It does not prove that the product retained a warmup record.
- `rerun-band-1.xcresult`: 0/1 passed, failing earlier at “the New best band lands”. Its log shows **two 60-second
  animation-idle waits** around the completion tap. After the tap, the second wait lasts longer than the test's
  30-second celebration window, so the test does not look for the band until after its normal expiry. Increasing
  the subsequent 5-second existence wait cannot repair this failure mode.
- Traced `badgeInputs` (includes set type), `refreshBadges`, `reconcileFreshBest`, `freshBest(for:)` and the expiry
  task. Those paths and this test are unchanged from `7dc65b82`. The changed sheet destination is never opened by
  the failing test; `-uiTestDesignMachines` is not passed. No causal product regression from this ticket was found.
  Treat these as intermittent automation/timing failures for this ticket's gate, with a testing follow-up that
  addresses idle synchronization as well as wait duration. The exact cause of the disappearance failure is not
  established, and this review does not claim the flake is fixed or reproduced on main.
- This round's independent serial rerun passed in 21.955 seconds. The round-1 independent full class also passed
  this test. These passes support the intermittent classification; they do not erase the recorded failed runs.

## Verification

Only WT-Redesign-2 `EB4328A1-87BD-4850-A3B2-A6E604701F1C`; preparation script run first. Derived data:
`/tmp/wt-live03-codex`. Round-2 logs/exits/results: `/tmp/wt-live03-codex-review-r2/`.

- Independent build-for-testing: exit 0 (`build.log`, `build.exit`).
- Independent Unit plan: 1358/1358 passed, exit 0 (`unit.log`, `unit.exit`, `unit.xcresult`), summary inspected.
- Independent UI: 5/5 passed, exit 0 (`ui.log`, `ui.exit`, `ui.xcresult`), summary inspected. Workout plan narrowed
  to `FloodlightLiveUITests/testCaptureLiveChartLight`, `testCaptureLiveChartDark`,
  `testCaptureLiveChartLightAccessibility`, `testLiveChartOpensOnTheMachineInUseAndSwitchesMachines`, and
  `testMakingAFreshBestAWarmupTakesTheBandAway`. The four chart tests cover the changed UI; the fifth independently
  checks the reported intermittent failure. The author already ran both affected area plans, inspected above.
- Author results directly inspected: Unit 1358/1358, HistoryProgress 46/46, Workout 78/79, failed band rerun 0/1.
- `git diff --check a37ec844..HEAD`: exit 2 for one added blank line at the ticket's EOF (`:181`); no source
  whitespace issue. `python3 scripts/test-plans.py --check`: passed.

Verified: build-for-testing exit 0; Unit 1358/1358, exit 0, `/tmp/wt-live03-codex-review-r2/unit.xcresult`;
          focused UI 5/5, exit 0, `/tmp/wt-live03-codex-review-r2/ui.xcresult`;
          source review; all ten retaken captures; author's xcresult summaries and failure evidence.
Not verified: exact-entry regression above; phone behavior; the exact cause of the band disappearance failure.
Known flaky: `FloodlightLiveUITests.testMakingAFreshBestAWarmupTakesTheBandAway` — timing/idle failures detailed above.

Standards: 0 new findings. Spec: 1 remaining P2.

Verdict: not clear
