# N13 — Codex independent review, round 1

Reviewed 2026-11-12 on `ericlee4992/nutrition-13-goal-setup`, HEAD
`ab5f10b619e8f9a263cd38dfbe54697bd25b8326`, against `e6255e85c4ded7b70b6611c92c39678633ae2fdf`.
The checkout was clean at the start. Scope: the round-1 brief, N13 ticket, D25/D52/D70/D80/D84,
DEVELOPMENT verification/persistence rules, and the vendored SwiftUI, SwiftData and iOS design guides.
Standards and spec were checked independently, with the findings below verified by the primary reviewer.

## Standards

### R1 — P2: Unit toggles overwrite untouched measurements

`WorkoutTracker/Features/GoalSetup/GoalSetupDraft.swift:231–238`,
`WorkoutTracker/Domain/GoalSetupStore.swift:60–71,82–88`.

Switching units repeatedly converts the already-rounded display value. An existing **171 cm** height becomes
**67 in → 170 cm** after Metric → Imperial → Metric. `isUnchanged` then returns false, and saving overwrites the
original height. Likewise, **100 lb → 45.4 kg → 100.1 lb** is treated as a changed weight and creates an unintended
weigh-in, including when the original came from Apple Health. This violates D52's prohibition on replacing entered
values with converted displays and the ticket's promise that an unchanged prefill adds no weigh-in.

**Fix:** retain the original entered pair and a full-precision working value; distinguish explicit field/picker edits
from a display-unit change. Convert from that value, and commit only explicit changes. Cover round trips that lose
precision; the existing 180 cm / 80 kg test happens to round back to its starting values.

### R2 — P2: Reopening setup rewrites an untouched desired weight

`WorkoutTracker/Features/GoalSetup/GoalSetupDraft.swift:49–51,67–68,160`,
`WorkoutTracker/Domain/GoalSetupStore.swift:95`.

The latest weigh-in chooses the draft's units, and the stored desired weight is immediately converted and rounded to
the step in those units. Unlike height/current weight, it has no preservation path. For a saved **75 kg** target
followed by a **176.4 lb** weigh-in, merely reopening setup and saving its unchanged answers writes **165 lb =
74.84274105 kg** as the target. The reverse direction also changes the target. D52 and N13's stored desired
`(value, unit, normalizedKg)` contract require the original pair to survive an untouched answer.

**Fix:** preserve a still-valid original desired pair until the user edits that answer; display conversion alone must not mark
it edited. Test reopening after the latest weight's unit changes, as well as toggling units inside the flow.

### R3 — P3: Label the weight editor and pace slider for accessibility

`WorkoutTracker/Features/GoalSetup/GoalSetupFlow.swift:321–325,481–487`.

The weight field's only title is the placeholder `"0"`; its test identifier does not supply a meaningful spoken
label. The Weight heading and unit are separate elements. The pace slider supplies a value but no label. A user
focusing these controls independently does not receive the quantity being edited. This falls short of the SwiftUI
accessibility guide and the review brief's VoiceOver-label check.

**Fix:** add explicit labels such as `Current weight, lb` (following the active unit) and `Weekly pace`, retaining
the slider's existing value. Check the accessibility elements/announcements; no human VoiceOver run was performed.

## Spec

The independent spec check also found R1/R2 against the ticket's “units as entered” requirement. The following are
additional behavior findings; no unrelated scope expansion was found.

### R4 — P2: Rounded display height weakens the BMI lower bound

`WorkoutTracker/Features/GoalSetup/GoalSetupDraft.swift:55–57,132–134`,
`WorkoutTracker/Domain/GoalSetupStore.swift:82–84`.

The draft calculates the desired-weight range from rounded display height, but commit correctly retains the original
precise height when untouched. An existing user at **180.49 cm / 65 kg** sees **180 cm**, can continue with the
default **60 kg** target, and saves it while retaining **180.49 cm**. The target's actual BMI is **18.4181**, below
D84's **18.5** minimum; the proper lower weight is about **60.2668 kg**. Display rounding therefore changes the
safety rule even without toggling units or editing height.

**Fix:** resolve the full-precision measurement that will actually be stored before computing bounds and the plan.
Use that same resolved input for preview, validation and commit. Add fractional cm/inch cases with a target close
to the lower bound, in both display-unit systems.

### R5 — P2: A valid loss range can contain no selectable target

`WorkoutTracker/Features/GoalSetup/GoalSetupDraft.swift:185–202,208–211`.

For a 30-year-old woman at **171 cm / 54.6 kg**, Moderate activity, Lose is allowed: a pace fits above the calorie
floor and the continuous desired range is **54.09585…54.1 kg**. But no multiple of the **0.5 kg** step lies inside
it. `inside()` first raises 54 to 54.5, then lowers it to 54, returning a value below the BMI line. The desired page
shows **54 kg** with Continue disabled; neither + nor − changes it. The user has to back out and change the goal
or an otherwise valid measurement. This does not fulfill D84's usable bounded goal flow.

**Fix:** calculate the selectable, unit-quantized range before allowing Lose, and explicitly handle an empty range
(or offer an exact valid boundary value). Never return an out-of-range result from `inside()`. Cover narrow ranges
in kg and lb and assert that any admitted goal has a reachable valid desired value.

## Review evidence

Runner: `/tmp/codex-n13/run-r1.sh` (PID **56827**, completed); all verification targets the reviewed HEAD above.

- Independent `build-for-testing`: exit **0**, Xcode **27.2 (27B52)**, WT-Floodlight
  `9E822EF6-DC67-4958-AEA2-D53D2D36D674` (iOS 27). Simulator preparation ran first. Derived data:
  `/tmp/codex-n13/dd`; build log/status: `/tmp/codex-n13/build.log`, `build.status`.
- Independent **Unit** plan: **1320/1320**, no failures or skips, exit **0**. Checked the actual status and
  `xcresulttool get test-results summary`, not only the author's report. Result: `/tmp/codex-n13/unit.xcresult`;
  log/status: `/tmp/codex-n13/unit.log`, `unit.status`.
- Independent **ProfileAI** selection: **32/32**, no failures or skips, exit **0**, two workers.
  `AAAWarmUpUITests` 1, `GoalSetupUITests` 6, `NutritionGoalsUITests` 7, `FloodlightTourUITests` 10,
  `FloodlightAccountUITests` 4, `FloodlightGoogleUITests` 4. Result: `/tmp/codex-n13/ui.xcresult`; log/status:
  `/tmp/codex-n13/ui.log`, `ui.status`; inspected summary: `/tmp/codex-n13/ui-summary.json`.
  No failed cases required a serial rerun.
- Exported and visually inspected all **36** goal-setup PNGs from the four capture tests (welcome plus eight pages,
  light/dark × default/AccessibilityL), alongside the committed captures. Originals and manifest:
  `/tmp/codex-n13/captures/`; readable filenames: `/tmp/codex-n13/captures-named/`; four contact sheets:
  `/tmp/codex-n13/captures/{light,dark}-{default,axl}.png`. The actual keyboard-open captures keep the weight figure
  and Continue above the decimal pad at both sizes. Options and pace stops remain legible at AccessibilityL.
  The lower pace outcome and lower plan macros extend below the initial viewport at AccessibilityL; these tests
  do not capture those blocks after scrolling, so their complete rendered layout is not established by the PNGs.
  Add scrolled captures when updating the visual evidence. Reduce Motion branches were traced in source, not
  exercised with the system setting enabled.
- Additional temporary Swift harness: `/tmp/codex-n13/Repro.swift`, binary `repro`, output `repro.log`.
  It compiles the unchanged checked-in `GoalSetupDraft`, `GoalPlan`, `NutritionGoals`, and extracted supporting value,
  conversion and unchanged-detection code. It reproduces R1/R2/R4/R5: 170 cm / unchanged false; 100.1 lb / unchanged
  false; desired 165 lb / 74.84274105 kg; BMI 18.4181 with preserved height; and 54 kg with Continue false after
  either step button. These are executable draft/arithmetic reproductions; their commit consequences were traced in
  source, not presented as additional SwiftData integration tests.
- Traced the setup save through `ModelContext.didSave` → `HealthNutritionSync.attach/scheduleSync` → `writeWeights`.
  The new app-source weight uses the same observed save path as Personal details. Actual HealthKit receipt on a
  device remains unverified.
- Inspected additive model fields, format fingerprints, the 0.2.0 fixture checks, export v13/v12 compatibility,
  dated-goal updates, override retention, legacy nil-pace behavior, first-launch gating and tour/What's New paths.
  The passing migration test checks fixture format, rows, values and nil new fields. Its comment additionally claims
  that a refresh leaves the migrated goal unchanged, but the test never calls `NutritionGoalStore.update`; that
  specific assertion is not covered and should be added. Save-failure behavior was source-reviewed, not fault-injected.
- `python3 scripts/test-plans.py --check`: exit **0**. Removed N3 setup symbols have no remaining production callers.

## Verification status

Verified: build-for-testing — exit 0, `/tmp/codex-n13/build.log`; Unit — 1320/1320, exit 0,
`/tmp/codex-n13/unit.xcresult`; named ProfileAI UI classes above — 32/32, exit 0,
`/tmp/codex-n13/ui.xcresult`; 36 goal-setup captures inspected; R1/R2/R4/R5 reproduced in the temporary Swift harness.

Not verified: phone installation/Gate S; device HealthKit receipt; human VoiceOver; runtime Reduce Motion;
fault-injected save failure; migrated-goal refresh assertion; below-fold AccessibilityL blocks after scrolling;
full UI suite (outside the requested targeted scope).

Known flaky: none seen in this review's runs.

Standards: 3 findings (2 P2, 1 P3; worst: unintended measurement/target rewrites). Spec: 4 findings (R1/R2 shared
with Standards, R4/R5 additional; all P2; worst: BMI-bound and selectable-range violations). Five distinct findings.

Verdict: not clear

## Round 2

Reviewed 2026-11-12 at `52df69f1866204e3cf3830f89dc2d25b94d20b8e` on the same branch, using
`git diff 967d613c..HEAD` and the round-2 brief. The working tree was clean at the start.

### Resolution of round 1

- **R1 resolved for the reported untouched-toggle cases:** 171 cm and 100 lb now remain their original pairs through
  repeated unit changes; the new integration test also checks no duplicate weigh-in.
- **R2 resolved:** the untouched 75 kg target survives a later weigh-in in lb and reopening/saving. An explicit
  desired-weight step now selects a new entered pair in the displayed unit.
- **R3 resolved:** explicit current-weight/unit and weekly-pace accessibility labels are present.
- **R4 partially resolved:** untouched precise height now gives the correct bound (180.49 cm yields a default
  60.5 kg target), but an explicit height edit can still diverge from what commit stores, as R2-1 demonstrates.
- **R5's original dead end resolved:** the 171 cm / 54.6 kg case is refused on the goal page rather than entering
  an impossible desired-weight page. The kg/lb sweep covers admitted ranges. R2-2 concerns the new off-step behavior.
- The migration test now actually refreshes the migrated goal and checks its identity, calories, nil pace and count.
  Scrolled AccessibilityL captures now include the lower pace and plan blocks.

### Standards

#### R2-1 — P2: Remove the obsolete rounded comparison when committing entered pairs

`WorkoutTracker/Domain/GoalSetupStore.swift:60–71,82–88`, interacting with
`WorkoutTracker/Features/GoalSetup/GoalSetupDraft.swift:80–99,167–178,218–220`.

The draft now correctly carries actual entered values, but the store still decides whether an answer changed by
rounding height to a whole unit and weight to a tenth. That was a display-preservation heuristic; it now discards
explicit edits. Start at **180.49 cm / 65 kg**, move the height wheel to **181**, then **180 cm**, and select Lose.
The draft's answer is 180 cm and it offers **60 kg**. Commit compares `round(180)` with `round(180.49)`, calls them
unchanged, and retains **180.49 cm** while saving the 60 kg target. Its BMI is again **18.4181**, below D84's 18.5
bound. Separately, typing **176.37 lb → 176.36 lb** submits the edited pair, but commit treats both as 176.4 and
records no weigh-in. This contradicts D25/D52 and the new draft's explicit-edit semantics.

**Fix:** compare the canonical entered pairs (or carry explicit edit provenance), so preview, validation and commit
all resolve to the same measurements. Original pairs already survive untouched display conversions. Add store
integration cases for height and weight edits inside one former rounding bucket, and assert the saved measurement
and target BMI. The current R4 test at `WorkoutTrackerTests/GoalSetupTests.swift:358–369` never commits; its birth date
is only 11 days before `now`, so `answers == nil || …` is satisfied by nil and does not check a savable answer.

### Spec

The independent spec check also identified **R2-1**, leaving R4 incomplete. No unrelated scope expansion was found.
The primary reviewer additionally reproduced this smaller regression in the requested `desiredAtLowest` check:

#### R2-2 — P3: Derive the lowest-weight caption from the actual next downward step

`WorkoutTracker/Features/GoalSetup/GoalSetupDraft.swift:259–272`.

`stepDesired` now moves an off-step prefill to the next whole step in the requested direction, but `desiredAtLowest`
still subtracts a full step. With height **180.49 cm**, current weight **143.3 lb**, and a preserved **60.5 kg** target,
the displayed target is **133.3797… lb** and the selectable range starts at **133 lb**. `desiredAtLowest` returns
true, displaying “The lowest healthy weight for your height,” yet pressing minus successfully lowers the target to
**133 lb**, still inside the allowed range. The caption therefore describes a lower bound before it is reached.

**Fix:** use the same candidate-step calculation for the caption and the minus action; show the caption only when
there is no valid lower target. Cover an off-step preserved target immediately above the lowest displayed-unit step.

### Round-2 evidence

Runner `/tmp/codex-n13/r2/run.sh`, PID **76128** (completed); simulator preparation ran first on WT-Floodlight
`9E822EF6-DC67-4958-AEA2-D53D2D36D674`. Rebuilt the current source into `/tmp/codex-n13/dd`.

- **Build-for-testing:** exit **0**, `/tmp/codex-n13/r2/build.log` and `build.status`.
- **Unit:** **1324/1324**, no failures or skips, exit **0**, `/tmp/codex-n13/r2/unit.xcresult`;
  inspected `unit.status` and `unit-summary.json` from `xcresulttool`.
- **Temporary reproduction:** `/tmp/codex-n13/r2/Repro.swift`, `repro`, `repro.log`; unchanged current draft/plan/math
  plus extracted supporting value/conversion/comparison code. Original toggle/target/narrow-range cases now behave
  correctly. Explicit height edit reports `canContinue true`, `commit unchanged true`, BMI 18.4181; explicit weight
  edit reports `commit unchanged true`. The off-step target reports lowest=true before minus reaches valid 133 lb.
  Commit consequences were traced in the store source; these harness runs are not additional SwiftData tests.
- **ProfileAI, named selection:** `AAAWarmUpUITests` + `GoalSetupUITests` — **7/7**, no failures or skips,
  exit **0**, two workers, `/tmp/codex-n13/r2/ui.xcresult`. Checked `ui.status`, the test log and
  `ui-summary.json` from `xcresulttool`; no serial rerun was needed.
- **Captures:** exported 40 PNGs into `/tmp/codex-n13/r2/captures/` (manifest retained), with readable copies in
  `/tmp/codex-n13/r2/captures-named/`. Visually inspected the four new scrolled pace/plan AccessibilityL PNGs in
  light and dark, both committed and from this independent run: the lower calorie outcome, macro values and
  explanatory text are legible. This closes the round-1 below-fold capture gap.
- The other round-1 ProfileAI classes were not rerun in this narrower fix round, as specified by the brief. The
  build and Unit plan were rerun independently rather than relying on the author's results.

Verified: build-for-testing — exit 0, `/tmp/codex-n13/r2/build.log`; Unit — 1324/1324, exit 0,
`/tmp/codex-n13/r2/unit.xcresult`; AAAWarmUpUITests + GoalSetupUITests — 7/7, exit 0,
`/tmp/codex-n13/r2/ui.xcresult`; scrolled AccessibilityL captures; temporary reproductions of R2-1/R2-2.

Not verified: phone installation/Gate S; device HealthKit receipt; human VoiceOver; runtime Reduce Motion;
fault-injected save failure; other UI classes this round/full UI suite. These limits do not account for the
reproduced R2-1/R2-2 findings.

Known flaky: none seen in this round.

Standards: 1 P2 finding (R2-1). Spec: that same P2 plus 1 P3 (R2-2); worst issue on both axes is the saved-measurement
mismatch. Two distinct findings remain.

Verdict: not clear
