# 07 — Immediate template visibility and scanning during setup

Type: task
Status: in-progress

## Request and acceptance

September 22: user generated three templates; the top two were absent even after scrolling to
the top, then appeared after restarting. User authorized implementation after the read-only
investigation. All saved templates must appear and open before restarting, without duplicates.

Rename the Workout entry to **Ask AI for Templates**. Add **Scan Machine** to the routine
equipment section, even when machines already exist. A single camera flow accepts a machine
or label and lets Terra identify it; retain editable confirmation. Save confirmed machines at
the selected gym and return with preferences preserved and available equipment updated.
Repeat scans must work. Without a selected gym, provide a reachable gym selection/add path.
Cancel/error must not lose preferences or add an unconfirmed machine.

## Design

User approved this composition with “lets execute” after the proposed flow; no separate new
screen design is needed. In preferences, the screen exists to describe a week and its available
equipment; Generate week remains the commit action. Scan Machine is secondary in Equipment.
In capture, the photo is dominant and the instruction is “Scan a machine or its label”.
In confirmation, editable identity precedes Use; Add commits a machine to the gym.

```
Workout                       Template preferences
Gym / Start choices           Goals / schedule / optional profile
Templates                     Equipment at selected gym
Ask AI for Templates            saved count / Scan Machine (secondary)
                                supplemental equipment
                              Cardio / consent / Generate week
```

Existing forms, typography and tokens retained. Tells: no new cards, chips, decorative accent,
all-caps labels, equal-weight hero blocks, website sections, or new motion. Metadata dots remain
existing summaries. Scan is secondary; Generate remains the form's primary task. Default and
AccessibilityL captures will check wrapping, hierarchy and reachable controls.

## Verification plan

First run an exact three-template UI regression before product edits. Then run immediate-save
and repeated-save coverage, scanner return/cancel and equipment eligibility, empty gym paths,
existing AI scanner and template flows, relevant AI/domain suites and successful build.
Scope is bounded to routine setup/save presentation and shared machine editor entry. Independent
Claude review required; no phone installation claimed. No schema change planned.

## Progress

- Baseline `5a894da`, branch `ericlee4992/ai-template-followup`; clean main and remote verified.
- User confirms scrolling to the very top did not reveal the missing templates.
- Preparing regression; no root cause established yet.

- Baseline repro running: PID 43060; command/script `../results/followup/repro.sh`, log
  `../results/followup/repro.log`, actual exit `../results/followup/repro.exit`, xcresult
  `../results/followup/repro.xcresult` (all relative to this ticket; ignored).
  Simulator WT-iPhone, Xcode 27.0. Run is isolated and serial; no competing xcodebuild observed.

### Baseline checks

- `repro.sh`: build/test exit **0**, summary **1 passed / 0 failed / 0 skipped**.
  Three short fixture templates all appeared and opened without restart on an initially empty
  list. Exported captures visually inspected; **not a reproduction** of the user's issue.
  Existing invalid-frame runtime warning also present on the baseline.
- Broadened scenario: existing template, AccessibilityL, all three generated templates must
  open before relaunch. First broadened run also covers scan setup default/AccessibilityL:
  PID 52230, `../results/followup/populated-and-scan.{sh,log,exit,xcresult}`.
- Additional rich fixture uses six exercises/day to exercise variable-height tiles. The earlier
  single-exercise stub is insufficient to establish production-sized template rendering.

### Plan review resolutions

Independent [Claude plan review](../claude-followup-plan-review.md) identified ambiguity and
coverage gaps. Resolutions (user approval of the proposed flow already supplied):

1. Baseline was honestly recorded as not reproduced. User further confirms **empty spaces**
   where the two top cards belonged. Add pixel/OCR verification because accessibility existence
   alone cannot detect invisible cells. Test existing templates, selected gym and taller cards.
   Preserve isolated-context atomic saving and duplicate-submit protection.
2. Reuse MachineEditorSheet's existing identity resolution and Add save unchanged. An opt-in
   `startsWithScanner` immediately opens IdentifyEquipmentSheet once when the editor first loads;
   no extra scan tap, no duplicated save/identity implementation. Default callers are unchanged.
3. Gym selection is immediate and remembered through StartWorkoutView.select, matching D1.
   Reuse GymEditorSheet in place with a success callback. Current gym controls both eligibility
   and generatedForGymID; archived gyms/machines excluded. New gym/machine saves are independent
   commits and survive cancelling a routine. D58/SPEC now record these semantics.
4. Copy: Workout button becomes “Ask AI for Templates”; identifier remains askAIRoutine.
   Routine title and AI Settings stay “Ask AI”. Shared scanner instruction becomes
   “Scan a machine or its label”. New equipment controls reuse “Gym”, “No gym”, “Add Gym…”;
   add “Scan Machine” and “Choose or add a gym to save scanned machines.”
5. Machine availability is observed through @Query; Generate without extra equipment/cardio
   must become enabled after confirmed scans. Repeated identical-label scans remain distinct.
6. Presentation uses sheets, retaining the covering routine's state. Cancel each level preserves
   preferences; only Add saves. Photo consent remains separate and reachable through this entry.
7. No new stored properties/schema/export change. Transient UI state only.

Design states: without a gym, preferences lets the user choose/add one without losing inputs;
Gym selection is the equipment section's first control. With a gym, the count and secondary
Scan Machine precede supplemental equipment. Capture centers the photo/shutter with the shared
instruction. Proposal leads with editable identity and Use; New Machine's Add is the commit.
The approved one-row addition and reused native forms do not require alternative screen mocks.

Tells: containers on everything absent; decorative chips absent; all-caps labels absent;
metadata dots deliberate existing summaries; decorative accent absent; equal-weight hero blocks
absent; website composition absent; additional top-of-screen content absent (changes stay in
Equipment); picker-as-primary absent; default-only layout prohibited by paired captures.

Named scope: new three-template tests (empty/default, populated default/AccessibilityL), new
routine scan tests default/AccessibilityL, nested consent/error/cancel, existing generic scan,
edited catalog label, weekly routine default/AccessibilityL, TemplateDetailUITests; domain
AIGymTests, WorkoutTemplateTests, EquipmentLifecycleTests. Clean build. Scope may be revised
for actual impact/findings. The entire AI class repeats many unchanged identity/consent screenshots;
use directly affected paths and explicit nested-path tests instead of a blanket full-class run.

### First expanded run (retained failures)

`populated-and-scan`: exit **65**, **0 passed / 3 failed / 0 skipped**. These are test harness
failures, not claimed product regressions: the populated-grid test waited for the offscreen
Ask AI button after save; both scan tests reached successful generation but expected the fixture
exercise “Machine Chest Press” instead of the actual “Seated Chest Press”. Corrected those
assertions and queued focused reruns. Prior steps verified two separate machine saves, updated
counts, cancellation and retained goals at both sizes; complete tests still require passing reruns.
Captured UI inspected: renamed button wraps wholly at AccessibilityL; equipment controls/counts
are whole at both sizes. Captures stay preliminary until passing final runs.

Rich baseline queued/running PID 59680, `../results/followup/rich-grid-baseline.{sh,log,exit,xcresult}`.
It adds selected gym, existing Whole Body template and six-exercise cards, checks all three
open immediately, and OCRs actual screenshot pixels so invisible accessibility elements fail.
No grid/persistence change has yet been made; scanning/copy changes are independent.

### Runtime mismatch found

Read-only devicectl details succeeded; current phone OS recorded in STATE. Existing WT-iPhone
runs iOS **26.5 (23F77)**, whereas the phone runs **27.0**. Xcode 27 provides the new SDK but
had no iOS 27 simulator runtime installed. Downloading the matching-major runtime with
`xcodebuild -downloadPlatform iOS -buildVersion 27.0 -architectureVariant arm64`; PID 63666,
`../results/followup/runtime27.{sh,log,exit}`. No phone mutation/install/API call.

### Preliminary code-review resolutions

[Claude static review](../claude-followup-code-review.md) clears the architecture/copy choices;
final evidence pending. F1: added `testRoutineGymPickerRemembersExistingGymAndNoGym` covering
existing gym selection, no-gym hiding, and both remembered Workout selections. Scan tests also
check Add Gym's callback and independently saved machines surviving routine cancellation.
F2: auto-entry has worked on every scan so far; require passing complete reruns. Cancelling the
scanner returns to New Machine; its Cancel returns to preferences (two explicit task boundaries).
F3: `-uiTestTerraFullRoutine` is a reset-guarded six-exercise fixture for tall-card regressions.
F4: shared GymEditor save errors are now shown in-place rather than asserting/dismissing;
success callback only fires after save. This also affects New/Edit Gym reached from Gyms.
F5: nested photo consent/error/cancel covered by the new named test. No-key entry from routine
setup is gated by the routine's reachable AI Settings before equipment inputs; the shared
scanner's no-key Settings path retains its prior evidence, not claimed newly exercised here.
F8: screenshot OCR has run successfully on tall AccessibilityL tiles in the rich iOS 26.5
baseline; that baseline still does not reproduce the phone's blank cards.

### Environment and build checkpoint

- Rich iOS 26.5 baseline: actual exit **0**, **2 passed / 0 failed / 0 skipped**; both default
  and AccessibilityL rendered/opened all three tall cards. No phone-bug reproduction claimed.
- Clean simulator build: PID 67987, `../results/followup/clean-build.{sh,log,exit}`, actual
  exit **0**, BUILD SUCCEEDED. Scanning implementation builds; final UI gates pending.
- iOS 27 runtime install exit **0**, runtime 24A434. Created WT-iPhone27 / iPhone 15 Pro Max,
  UDID `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`. Existing WT-iPhone left intact.
- Same-major/same-device baseline starts at PID 69979,
  `../results/followup/ios27-baseline.{sh,log,exit,xcresult}`. Grid/save still baseline code.

### Exact reproduction on iOS 27

`ios27-baseline.sh` at product/test checkpoint **51da414**: actual exit **65**, **0 passed /
1 failed / 0 skipped**. Command selects
`AskAIUITests/testAllThreeGeneratedTemplatesInPopulatedListDefault` on WT-iPhone27. It saves
three six-exercise templates into a selected gym with existing Whole Body, scrolls to the top,
then cannot find Day 1. Capture [blank first row](../screenshots/followup/ios27-before-blank-grid.png)
visually matches user feedback: first two cards are blank space, Day 3 and Whole Body appear.
The isolated UI-test SQLite store contains all four names and 24 TemplateItems; read-only
check saved in `../results/followup/ios27-store-check.txt`. No loss of saved templates.

Ranked falsifiable hypotheses shared with user: (1) nested LazyVGrid drops first-row rendering,
so replacing only its laziness restores cards; (2) stale @Query, so layout-only change will not
restore missing results; (3) incomplete save, refuted by independent SQLite rows/items.
Test case is three-day user scenario; OS runtime is the decisive controlled variable so far.
The loop takes about 2–3 minutes because it drives real XCUITest UI, not a seconds-long unit
seam; the screenshots are necessary to establish this rendering bug.

One-variable fix experiment: replace the LazyVGrid inside the single List row with eager,
equal-width VStack/HStack rows. Same one/two columns, spacing, buttons and template cells;
no query, save or schema change. `ios27-eager-grid.{sh,log,exit,xcresult}`, PID 74925, focused
regression pending. Parent List still virtualizes the collection row. Apple's
[LazyVGrid documentation](https://developer.apple.com/documentation/swiftui/LazyVGrid) recommends
starting with eager construction unless measured collection size makes that too costly; this
personal template collection does not require nested laziness.

### Final-scope selection and capture equivalence

The unchanged parent Start screen is captured by `scanDuringRoutine` as `followup-start` at
both text sizes with the **same** empty fixture, and populated template rows by the rich
three-template tests at both sizes with the **same** selected-gym/four-template state. These
are the Start capture pairs for this change; repeating RedesignScreenshotUITests' differing
historic fixtures would not add coverage. TemplateDetailUITests covers delete/cancel row
identity after the layout change. Existing weekly tests cover edit/save/start/planned-cardio.
The exact populated-default regression is not repeated in final-scope after its focused fix
passes; unchanged code reuses that evidence. Remaining final scope is 3 domain suites +
11 UI cases. Chain PID 77596 launches final-scope only if focused fix exit is 0; paths
`../results/followup/verification-chain.{py,log}`, `../results/followup/final-scope.{sh,log,exit,xcresult}`.
After iOS 27 checks, run a bounded iOS 26.5 smoke (populated layout and default scanner) to
validate supported earlier runtime; no need to duplicate all iOS 27 UI cases there.

### Xcode diagnostic collection delay

Focused eager-grid XCTest case passed (151.315 s, zero test failures). After test teardown,
Xcode waited on optional `simctl diagnose` PID 79632 (`--timeout=600`) for over 2m40s, despite
suite completion. Sent SIGTERM only to that exact verified diagnostic process; xcodebuild
74926 and the test result remained intact. Future runs use documented
`-collect-test-diagnostics never`; results and screenshot attachments remain enabled.
Actual xcodebuild exit and completed xcresult still required before calling the run successful.
No app/simulator data erased and no broad process kill.

### Focused fix verified

`ios27-eager-grid`: actual **exit 0**, completed xcresult **1 passed / 0 failed / 0 skipped**.
The same iOS 27 case that failed at 51da414 now draws/opens all three cards, with no query/save
change. [After capture](../screenshots/followup/ai-immediate-template-1-default.png) opened and
visually checked: Day 1 and Day 2 are fully rendered; existing two-column design preserved.
This isolates the failure to nested lazy-grid rendering after insertion on iOS 27. Eager rows
fix that boundary. The prior invalid-frame warning is still reported; not claimed resolved.
Optional diagnostic collection interruption is documented above; it did not interrupt tests,
and xcodebuild finalized normally with TEST SUCCEEDED.

Final selected checks now running against this product code; no merge/install until reviewed.
