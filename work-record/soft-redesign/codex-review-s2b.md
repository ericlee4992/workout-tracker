# S2 independent review — Round 2

Reviewed 2026-11-07 by Codex; implementation by Claude.

## Scope

Branch `ericlee4992/soft-02-tabs`, HEAD `f9aef40ad4848af599c071f42fcd9604e8321378`.
Reviewed `git diff 2966c66..f9aef40`: corrective commits `4433592` and `f9aef40`, against all three P2 findings in
[Round 1](codex-review-s2.md) and the full [review brief](codex-review-s2-prompt.md), including Round 2.
Read AGENTS, STATE, the S2 ticket and its response/evidence, the Soft spec, D67/D68/D63, and relevant development and
SwiftUI/SwiftData guidance. The approved Soft direction supersedes the design skill's older Floodlight palette.
Separate standards and spec source checks found no new actionable findings. Only this report was written; no
implementation files were changed, and nothing was committed or pushed.

## Spec

No new findings. The two prior product findings are closed in source:

1. **Root-only Train switch:** `TrainView.swift:72,77` defaults `trainRoot` to false and requires explicit opt-in.
   Exactly three call sites opt in: `StartWorkoutView.swift:93`, `GymsView.swift:36`, and `ExercisesView.swift:62`.
   Gym, machine, Deleted Machines, and exercise detail pages retain ordinary title handling. Settings, account,
   Export, and Today also use the false default. `TabNavigation.swift:16` re-taps Train when a retained pushed page
   hides the switch before choosing a section.
2. **Today day changes:** `TodayView.swift:35,56,74–102,172` uses one private stateful date for the header, week,
   and log. Local day-change, significant-time-change, and timezone-change notifications refresh it on the main
   run loop; foreground activation also refreshes it. Calendar defaults are obtained when recomputing membership
   and the week, and workouts remain assigned to their start date. The three new tests cover midnight, timezone
   membership, and week rollover. Notification delivery itself was source-reviewed, not tested by changing the
   simulator/system clock.

## Standards and test rewrite

No new findings. Prior finding 3 is closed in source: Profile persistence/capture/theme tests now leave via Train,
AI flows wait for the Train title, and the Export tab round trip returns to Profile. Downstream assertions remain.
An exhaustive UI-test text search found no remaining `navigationBars["Settings"]` or `navigationBars["Workout"]`.
Remaining positional Back calls originate in pushed screens, including Export → Profile at
`FloodlightSettingsUITests.swift:282`, rather than tab roots. No unrelated modernization or file split is requested.

## Independent verification

Xcode 27.2 (27B52), iOS 27.0, WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`.
All artifacts are under `/tmp/codex-s2/round2/`; derived data is `DerivedData` there.

- Build for testing: **exit 0**, `TEST BUILD SUCCEEDED`; result status `succeeded`, **0 errors, 31 warnings**.
  Evidence: `build-approved.log`, `build-approved.xcresult`. The initial sandboxed attempt exited 70 because
  CoreSimulator was inaccessible (`build.log`); the authorized rerun above succeeded.
- `TodayDayBoundaryTests`: **exit 0**, **3 passed, 0 failed, 0 skipped**; `unit.log`, `unit.xcresult`.
- Requested UI run: **exit 0**, `TEST EXECUTE SUCCEEDED`; xcresult **32 passed, 0 failed, 0 skipped**.
  Three workers: `FloodlightSettingsUITests` **10/10**, `FloodlightGymsUITests` **12/12**, and
  `FloodlightExercisesUITests` **10/10**. Evidence: `ui.log`, `ui.xcresult`. All passed on the first run; no retry
  was needed, including `testTabRoundTripDropsTheFileCard`. Counts were read directly with
  `xcresulttool get test-results summary`, rather than inferred from the implementer's report.
- Exported and visually inspected fresh light/dark, default/AccessibilityL captures for the Gyms and Exercises
  roots, gym/machine/exercise details, Deleted Machines, Profile, and Export. The roots retain their switch;
  pushed pages omit it and show their own inline titles after scrolling. Profile and Export also keep their titles.
  No regression found in the reviewed navigation/title regions. Evidence: `captures/manifest.json`, original PNGs,
  and inspected contact sheets `captures/review-light.png`, `review-dark.png`, `scrolled-light.png`, and
  `scrolled-dark.png`. These are targeted Round 2 captures, not the deferred full Phase 1 visual acceptance.
- `git diff --check 2966c66..f9aef40`: **exit 0**.

The full combined Phase 1 capture/core-flow run remains deferred, as requested. This review does not claim a new
full-suite run, device installation, actual VoiceOver interaction, or real midnight/timezone notification testing.
The older Round 1 report still contains an unfinished UI-run checkpoint; it is not counted as passing evidence here.

The build used `build-for-testing`; both test runs used `test-without-building` with the same derived data,
project `WorkoutTracker.xcodeproj`, scheme `WorkoutTracker`, Debug configuration, simulator SDK and destination
above. Unit selection: `-parallel-testing-enabled NO -only-testing:WorkoutTrackerTests/TodayDayBoundaryTests`.
UI selection: `-parallel-testing-enabled YES -parallel-testing-worker-count 3` and one `-only-testing:` selector
for each of the three classes above. Both test runs used `-collect-test-diagnostics never`; their logs preserve
the exact invocations.

Standards: **0 new findings**. Spec: **0 new findings**. All three Round 1 findings are closed within this review's
scope; the deferred combined Phase 1 verification remains a separate merge gate.

Verdict: clear
