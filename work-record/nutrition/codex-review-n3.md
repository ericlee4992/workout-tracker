# Nutrition N3 — independent Codex review, round 1

Reviewed 2026-11-09. Claude implemented; Codex reviewed **`git diff 6e53446..af1441f`**, target
`af1441fb5deee4516937e77943a7ca443656d4e1`, on `ericlee4992/nutrition-03-goals`. The checkout was initially clean.
Later HEAD `0a89539` changes DEVELOPMENT/STATE only. Follow-up working-tree edits to the affected source, tests and
README appeared during finalization; **those edits are outside this verdict**.

Read the brief, ticket, relevant decisions and project/skill instructions. Spec and Standards were reviewed
independently. Builds and tests used `/tmp/codex-n3/source/`, archived from the target; reviewed production files were
verified byte-identical to that commit. Review-only probes were added to that scratch copy, not the repository.
This reviewer wrote only this report in the repository; no product edits, commit, push or merge.

## Spec

### 1. P2 — Do not silently discard goal edits when shared details become incomplete

**Location:** `WorkoutTracker/Domain/NutritionGoalStore.swift:72–75`;
`WorkoutTracker/Features/Nutrition/NutritionGoalsView.swift:209–218`.
Entry point: `WorkoutTracker/Features/ActiveWorkout/MaxHeartRateSheet.swift:91–97`.

After a goal exists, turning off “Use my date of birth” in the zones sheet clears the shared birth date. The existing
goal and its edit controls remain visible, but `update` returns the old goal before invoking the user's change
closure. A calorie or activity edit therefore closes successfully without applying anything or showing an error.
Changing DOB without clearing it also bypasses goal refresh until the nutrition-goals page is opened. This conflicts
with the editable-goal requirement and D80's common Personal details source.

**Reproduced against production code:** the scratch unit probe creates a complete goal, clears the shared DOB as the
zones sheet does, then requests 2,100 calories and Light activity. The method returns normally with
`change closure ran=false`, calories still **2,759**, activity still **Moderate**, and the override flag still false.

**Fix:** route shared-detail changes through the common Personal details/update path, preserving the existing value
when merely changing zone configuration. Existing-goal edits must either apply using valid stored inputs or clearly
explain the missing requirement; do not silently report success. Cover changing/clearing DOB through the zones entry
point and then editing the nutrition goal.

### 2. P2 — Prefill missing Personal details from the existing training profile

**Location:** `WorkoutTracker/Features/Nutrition/PersonalDetailsView.swift:33–50,65–67`;
`WorkoutTracker/Domain/NutritionGoalStore.swift:28–33`.

The approved ticket says height and weight prefill from the training profile when present. Personal details reads
only the newly added preference fields and BodyWeightEntry rows. There is no account-profile prefill/import path;
an existing tester with saved training measurements sees “Not set” and must enter both again before a goal can be
calculated. The new Ask AI fallback goes in the opposite direction and does not satisfy this requirement.

**Fix:** prefill missing personal fields/drafts from available training measurements, preserving entered units and
never replacing existing Personal details or subsequent user edits. Cover an existing profile, partial measurements
and late profile loading. This finding concerns initial setup; the brief's explicit rule that the training profile
wins within the untouched Ask AI form is not being challenged.

**Spec: 2 P2 findings.**

## Standards

### 3. P2 — Preserve the entered height and precision on an unchanged Save

**Location:** `WorkoutTracker/Features/Nutrition/PersonalDetailsView.swift:94–95`;
`WorkoutTracker/Features/Nutrition/DetailEditorSheets.swift:104,110–117`.

The editor receives only normalized centimetres and the current display-unit preference. Under US preferences it
rounds to whole inches, then Save writes that converted pair back. Opening a stored **180 cm** height and saving
without changing a field replaces it with **71 in / 180.34 cm**. This violates the ticket's entered-pair rule and D52's
separation of display conversions from stored values. Accepted fractional-inch input also loses precision on reopen.

**Evidence:** `/tmp/codex-n3/probes/height-roundtrip.swift` executes extracted production method bodies with stand-in
state. It reproduces both `180 cm → 71 in / 180.34 cm` and `71.5 in → 72 in / 182.88 cm`, **exit 0**. This is an
arithmetic/state reproduction, not a claimed UI tap sequence.

**Fix:** pass the original entered value/unit, preserve precision and unchanged input, and make any unit conversion
an explicit edit. Add a regression that changes the app's unit preference, opens an existing height and saves without
editing; assert the stored pair and normalized value remain unchanged.

### 4. P3 — Update the public overview for the implemented feature

**Location:** `README.md:54–56,68–70` (unchanged in the reviewed diff).

The overview describes forthcoming nutrition data/screens but does not describe N3's usable Nutrition goals,
Personal details, editable calculated targets or optional first-time setup. AGENTS requires the README to change
on the same branch when behavior changes.

**Fix:** describe these features as unreleased and distinguish them from the remaining food-logging work. Update any
README screenshot whose depicted screen actually changed; do not imply this is already in TestFlight.

**Standards: 1 P2 and 1 P3 finding.**

## Checks without additional findings

- Formula constants, activity factors, goal adjustments, approved floors (including 1,350), macro resolution and
  whole-number rounding match the ticket. The supplied calculation tests and independent Unit plan pass.
- Review controls confirm that an unchanged next-day refresh creates no extra goal, same-day changes retain the
  current goal, later-day changes preserve the previous day's result, and populated height/unit/cm/sex preference
  fields round-trip through export v12. Keeping v12 for these optional, unreleased additions is consistent with N2.
- Height fields are optional, `HeightUnit` is pinned, and the approved fingerprint deliberately changes. A fresh
  rehearsal below covers this added-column migration rather than treating N2's earlier table-only rehearsal as proof.
- Ask AI's existing training measurements take priority, missing measurements use Personal details, and the
  first-user-edit guard remains in place, as the brief specifies. No separate AI-priority finding is reported.
- The onboarding pending flag distinguishes Welcome-originated setup from Profile → Show Tour; existing goals
  suppress the offer. The Skip/setup flow and pending activity choice pass. The after-Welcome-tour offer was inspected
  in source; the ordinary tour UI tests do not enable that new step.

## Verified

Independent runs used **WT-iPhone27** `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`, iOS 27.0. Preparation ran first,
exit 0. Artifacts and commands are under **`/tmp/codex-n3/`**. Main runner `verify.sh` PID `12690`, UI xcodebuild
`14900`, serial runner `48043`, probe runner `51935`, and rehearsal `53044` have completed. The existing Orca progress
tab was reused; no new terminal was opened.

| Scope | Actual result |
|---|---|
| Build for testing | **exit 0**, succeeded, 0 errors, 31 warnings; `build.xcresult`, `build-summary.json` |
| Unit plan, serial | **1178/1178**, no failures/skips, **exit 0**; `unit.xcresult`, `unit-summary.json` |
| Requested 70-case UI scope | **65 passed / 5 failed / 0 skipped**, **exit 65**; `ui.xcresult`, `ui-summary.json` |
| All five failed/interrupted cases + warm-up, serial | **6/6**, no failures/skips, **exit 0**; `ui-serial.xcresult`, `ui-serial-summary.json` |
| Focused review probes | Build **exit 0**; **4/4 completed, exit 0**; `probe-unit.xcresult`, `probe-unit.log` |
| Migration rehearsal and restoration | **exit 0**; `rehearsal/result.json` and comparison reports |

The requested UI scope is recorded in `ui-scope.json`: AAAWarmUp, NutritionGoals, FloodlightSettings, FloodlightTour,
FloodlightProfile, AskAI, and the named heart-rate-zone test. The initial run used the brief's three workers, started
before the two-worker policy update. The resumed work ran serially, with no concurrent heavy runs. Serial UI tests
used a five-minute per-test execution limit and completed without hitting it. Counts/exits were inspected directly
from xcresults and shell-status files, not inferred from the progress display.

The four scratch probes include **one assertion of the reproduced defect**, not four claims of correct behavior;
the other three are history/noise-row/export controls. No production source was modified for them.

**Migration:** installed executable and dylib hashes matched the built products. A fresh shipped-format fixture was
opened by N3 and by a baseline binary built from `c452791`, whose product source is identical to `6e53446` (only
documentation differs). Each made one safety copy; N3's copied primary store is byte-identical to the fixture, and an
ordinary subsequent N3 launch made no extra copy. Both before→after comparisons exit 1 solely for the already-known
unfinished-workout checkpoint: `Z_PK 19` gains maximum bpm 185 and estimated flag 0. Baseline-after→N3-after exits
**0**, comparing 21 entity tables with no changed/missing old rows. The four new AppPreferences columns are nil,
existing SQL-column definitions are unchanged, and nutrition tables remain empty. The same-schema comparison tool
was used only for this bounded additive check, with the new columns inspected separately.

The original simulator Application Support, Preferences and Documents were restored to the current app container
while shut down. File/hash equality passed **before and after reboot**. The N3 binary remains installed but was not
launched against the restored original data.

**Author evidence inspected:** in scratchpad
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/f473a23d-3eaa-41a2-9817-2ebe24bda24e/scratchpad/`,
`n3-unit` has 1177 passes (before the added TrainingProfile test); `n3-ui1` 37 passes; `n3-ui2` 38 passes;
`n3-ui3` 23 passes and two failures (warm-up AX-server error and onboarding's missing fresh-Welcome fixture flag);
`n3-onb` passes 2/2 after that fixture fix. Result bundles were read directly. Separate author numeric shell-status
files were absent; numeric exits in the ticket remain author-reported.

**Captures:** inspected the supplied n3-caps2/3/4 contact sheets and full-resolution latest goals/details/protein-editor
renders, plus independent light AccessibilityL goals (top and scrolled), dark AccessibilityL Personal details, and
light Default onboarding empty/filled captures exported to `captures/`. Text fits in the inspected states; the earlier
details-summary wrapping is corrected in n3-caps3. No additional confirmed visual defect is reported.

## Not verified

No phone installation/migration, actual TestFlight container, CloudKit sync, live Health/API integration, human
VoiceOver session, or full UI suite beyond the named scope. Onboarding dark/AccessibilityL captures and keyboard-aware
height/weight/birth-date editor captures are absent; the supplied onboarding images are only light Default, despite
the ticket's broader wording. Close those coverage gaps with the fixes. The birth-date defect probe exercises the
production store API; its UI consequence follows the inspected editor callbacks, not an additional manual UI trace.
The height probe is arithmetic/state evidence. Follow-up working-tree fixes require their own review and verification.

## Known flaky / interrupted verification

The original run spanned a disconnected stream and two hung XCTest workers. Samples showed framework waits in
`testAllThreeGeneratedTemplatesInPopulatedListDefault` and `testScanMachinesDuringRoutineSetupDefault`; only those
owned worker PIDs were terminated so the same xcodebuild run could continue. Their recorded signal-TERM failures are
**intentional recovery actions, not spontaneous product crashes** (`runner-interruption.json`,
`resume-runner-interruption.json` and stack samples).

The other failures were an app-launch process error in `testAskAIFollowsTheAccount`, a Train→Templates assertion in
`testAPhoneWithWorkoutsNeverSeesTheWelcome`, and an event-synthesis timeout in
`testRoutineScannerConsentAndFailureKeepPreferences`. All five cases passed unchanged in the clean serial run;
none is claimed as a reproduced N3 product regression. Unit results contain 55 runtime warnings, initial UI five,
and serial UI one (audio-session/invalid-frame warnings). Probe tests contain none. The four findings above remain
independent of this test-runner instability.

Spec: **2 P2 findings**. Standards: **1 P2 and 1 P3 finding**. Resolve and re-review the follow-up changes.

Verdict: not clear
