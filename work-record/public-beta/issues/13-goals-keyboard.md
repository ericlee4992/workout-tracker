# 13 — Ask AI Goals: the keyboard traps the step

Type: bug
Status: in progress (reported by the user 2026-10-16, on TestFlight build 5, iPhone on iOS 27)
Blocked by: —
Implementer: Codex (visible Orca terminal); Reviewer: Claude, to "clear".
Branch: `ericlee4992/beta-13-goals-keyboard` off `ericlee4992/beta-08-testers` (`f3828c5` = `main` + 08 notes).
Ships in: build 6. Related: Floodlight ticket 10 (the stepped Ask AI flow); [08](08-external-testers.md).

## Report (the user, 2026-10-16)

"For Ask AI for template feature, when i actually type the goals, i can't get rid of the keyboard for a while, and the
next button doesn't appear immediately." Then: "the done button on the keyboard doesn't appear." The keyboard Done in a
workout's set rows **does** appear on the same phone.

## What Claude found

- `WorkoutTracker/Features/Templates/AIRoutine/AIGoalsStep.swift`: the goal field is `TextField(axis: .vertical)` with
  no newline handling, so **Return adds a line** (probe: value became "Get stronger\n"). Tapping outside the field does
  not end editing. The bottom bar with **Next is shown only while `focus == nil`** (deliberate in ticket 10: "the
  keyboard's Done takes the thumb zone"), so Next waits for the keyboard to go.
- The only ways out are the `ToolbarItemGroup(placement: .keyboard)` Done (`dismissRoutineKeyboard`) and an interactive
  scroll. On the iOS 27 simulator (WT-iPhone27) the Done exists and works (probe: Done hittable 2.3 s after focusing;
  after Done, Next hittable in 0.34 s; a scroll-down drag dismisses in 0.24 s). **On the user's phone it does not
  appear** — not reproduced in the simulator. Difference from the set rows: the Ask AI sheet's `NavigationStack` hides
  its navigation bar (`AIRoutineSheet.swift` `.toolbar(.hidden, for: .navigationBar)`).
- The probe was a throwaway UI test (not committed); its screenshots are in Claude's scratchpad only.

## Decision (Claude's recommendation, option A; the user did not object — confirm at review)

Do not depend on the keyboard toolbar on this step:

1. **Next stays visible while typing**, riding above the keyboard (the bottom `safeAreaBar` no longer hidden by focus).
   Tapping Next ends editing and advances (as now); tapping the disabled Next still focuses the goal field.
2. **Return ends editing** in the goal field (same pattern as the session name in `AIDayEditor.swift`: strip the
   newline, clear focus; `.submitLabel(.done)`). Long goals still wrap; pasted newlines become spaces or are removed —
   choose and say which.
3. **Tapping outside a field ends editing** on the Goals step (covers the number-pad height/weight fields, which have
   no Return key). It must not swallow taps on chips, tiles, the day picker, the minutes control or Next.
4. Keep the keyboard Done (harmless where it appears) unless it causes duplicates.
5. Check the other screens whose only number-pad exit is a keyboard-toolbar Done inside a hidden-navigation-bar
   container: `AIDayEditor.swift`, `TrainingProfileEditor.swift`, `IdentifyEquipmentSheet.swift`. Where a field has
   no Return key and the Done may be missing, add the same tap-outside fallback; report what you changed and why.
   Leave `LiveSetRow.swift` alone (works on the phone).

## Acceptance

- [ ] On the Goals step, with the keyboard up, Next is visible and tappable; one tap advances to Equipment.
- [ ] Return in the goal field closes the keyboard and leaves no newline in the goal.
- [ ] Tapping empty space closes the keyboard (goal and height/weight fields); chips/tiles/controls still respond to the
      first tap.
- [ ] Layout at Default and AccessibilityL, light and dark: Next above the keyboard does not hide the focused field
      (capture both sizes with the keyboard up; ios-design skill).
- [ ] Existing Ask AI UI tests updated where they relied on Next being hidden or on the toolbar Done; a UI test covers
      Return-dismiss and Next-while-typing.
- [ ] `xcodebuild build` succeeds; targeted tests per DEVELOPMENT → Verification scope (AskAIUITests,
      FloodlightAIRoutineUITests, FloodlightProfileUITests, plus any touched screen's tests) on **WT-iPhone27
      (`47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`, iOS 27.0)**.
- [ ] Confirmed on the user's phone in build 6.

## Progress

### Implementation checkpoint — 2026-10-16 (Codex)

Branch `ericlee4992/beta-13-goals-keyboard`; starting HEAD `2dd305c` (the implementation prompt), regression tests
committed as `db63d37`. The ticket's existing simulator probe already isolates focus-gated Next and Return inserting
a newline; a new general hypothesis search is unnecessary. The two UI regressions exercise those actual paths.

Planned implementation: keep the existing bottom action bar above the keyboard; Return dismisses Goals editing and
replaces pasted line breaks with spaces. Tap-outside uses the noninteractive background rather than a gesture that
consumes a field/control's first tap. TrainingProfileEditor needs the same fallback for its number/decimal pads.
AIDayEditor uses steppers, not numeric text fields, and its name already handles Return. IdentifyEquipmentSheet has
only text keyboards, no number pads; leave it and LiveSetRow unchanged.

**Design:** while typing Goals, the screen lets the user advance in one tap; Next is the dominant action in the thumb
zone, above the keyboard. The session-count figure remains content lower in the scrolling form. The nonediting
composition is unchanged. This is the ticket's chosen one-element visibility correction, so no alternative mock is
needed before implementation. Existing copy and identifiers stay; the keyboard return label becomes Done.

```text
Ask AI / Cancel; Goals — Equipment — Your week       [existing top chrome]
Goals field, wrapping                              [focused field remains visible]
Phrase chips; experience; days/minutes; measures    [scrolling form]
Next →                                             [one primary action, above keyboard]
Keyboard (+ existing toolbar Done when available)
```

**Design tells:** existing cards group related form inputs (deliberate); chips select goal phrases (deliberate);
repeated all-caps labels absent; middle-dot metadata unchanged; violet marks the sole Next action and selection
states (deliberate); equal competing command blocks absent; website-style hero/dead space absent; focused field and
Next must remain in the keyboard viewport; pickers retain their control treatment; Default/AccessibilityL will be
captured in both appearances. No new palette, type or motion treatment.

Verification scope: simulator build, focused red/green keyboard regressions, then the requested AskAIUITests,
FloodlightAIRoutineUITests and FloodlightProfileUITests. No domain/SwiftData changes, server calls, phone install or
merge. Baseline build and red-test artifacts: `/tmp/wt-beta13-20261016-r1/`; derived data `/tmp/wt-beta13-dd`.
Baseline `xcodebuild … -sdk iphonesimulator -configuration Debug -destination
'platform=iOS Simulator,id=47D21838-69A6-4BCB-AE90-B0D9C0AAA70B' -derivedDataPath /tmp/wt-beta13-dd build`:
**exit 0, BUILD SUCCEEDED** (`build-unrestricted.log`, `build-unrestricted.status`, `build-unrestricted.xcresult`).
The first sandboxed attempt could not connect to CoreSimulator (exit 70); the authorized retry above passed.
The pre-fix two-case run completed as exec session `86827` (`xcodebuild` PID `68945`), with
`red.log`, `red.status`, `red.xcresult` in the same artifact directory. It selects
`FloodlightAIRoutineUITests/testGoalsReturnDismissesWithoutANewline` and
`FloodlightAIRoutineUITests/testGoalsNextAdvancesWhileTyping`, serially.

**Red result:** exit **65**, `TEST FAILED`, **2 tests / 2 failures / 0 unexpected**, confirmed in both log and
`xcresulttool get test-results summary`. Next was absent after typing; Return left the keyboard open. The suite
finished in 66.5 s, then optional `simctl diagnose` stalled; inspected the exact child of xcodebuild and terminated
only that diagnostic child (PID 71403), as DEVELOPMENT directs. The completed result bundle is retained. Subsequent
runs use `-collect-test-diagnostics never`.

**Implemented checkpoint `7d80502` (pushed):** Next remains in its bottom safe-area bar; Return/Done dismisses the
Goals field, with pasted newline runs joined by spaces and surrounding whitespace trimmed. Blank-space background
taps dismiss without attaching a consuming gesture to the form controls. Chips, experience/day choices, minutes
changes and the save-profile toggle also end editing while preserving their action. TrainingProfileEditor gets the
same background and choice-control fallback for its number/decimal pads; its existing multiline profile-goal
semantics are unchanged. AIDayEditor and IdentifyEquipmentSheet were inspected and left unchanged for the reasons
above; AIRoutineSheet, AIRoutineComponents, LiveSetRow and all Domain/SwiftData files are unchanged.

AskAIUITests now uses Return instead of locating the possibly absent/stale floating Done, and its scroll helper
respects both the keyboard and the now-visible pinned bar. Added Return/Next regressions, empty-Next focus,
tap-outside/first-chip, height/weight number-pad dismissal, profile-editor number-pad dismissal, and four Goals
keyboard-up capture cases. README's AI overview now names typed goals as well as the optional saved profile; the
existing README screenshots show different states and need no replacement.

**Post-fix build:** `/tmp/wt-beta13-20261016-r2/build.{log,status,xcresult}` — exit **0**, `BUILD SUCCEEDED`.
Focused five-case UI verification (`focused.{log,status,xcresult}` in that directory; exec session `4801`, xcodebuild
PID `77990`) finished **exit 65, TEST FAILED, 5 tests / 2 failures** (log and xcresult read). Return, Next-while-typing
and blank-space/first-chip passed; the Goals number-pad check exposed
that the filled measurement panel intercepted taps before the outer background. The follow-up adds dismissal
backgrounds inside both screens' filled panels, below their controls. Keep this failed approach/result as evidence.
The other failure was a test query: both the underlying profile and its editor expose a Height label. The updated
test taps the empty gap beside the field, also directly testing the requested blank-space fallback.

Checkpoint **`e26c776` pushed** (panel correction `6182045`): `/tmp/wt-beta13-20261016-r3/` contains another successful
build (**exit 0, BUILD SUCCEEDED**) and the two affected number-pad tests (**exit 0, TEST SUCCEEDED, 2 tests / 0
failures**, log and xcresult read). The capture cases also show the height number pad at Default/AccessibilityL in
both appearances, with bounds assertions against Next.

Next run: `/tmp/wt-beta13-20261016-r4/full.{log,status,xcresult}`, the complete requested selection, including captures:

```sh
xcodebuild test -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,id=47D21838-69A6-4BCB-AE90-B0D9C0AAA70B' \
  -derivedDataPath /tmp/wt-beta13-dd -resultBundlePath /tmp/wt-beta13-20261016-r4/full.xcresult \
  -parallel-testing-enabled YES -parallel-testing-worker-count 3 -collect-test-diagnostics never \
  -only-testing:WorkoutTrackerUITests/AskAIUITests \
  -only-testing:WorkoutTrackerUITests/FloodlightAIRoutineUITests \
  -only-testing:WorkoutTrackerUITests/FloodlightProfileUITests
```

Each focused run used this same project/scheme/SDK/configuration/destination/derived-data selection, serial UI
execution, its own result path, and only the named regression methods above. No physical hardware or service API was
used. Next: read the full result, export/look at the eight keyboard captures, and prepare the Claude review handoff.

The full run completed as exec session **39408**, from pushed checkpoint **`e0848cb`** (product/test code `e26c776`),
using **Xcode 27.1 (27A9275)** and the required iOS 27.0 simulator. Do not start another test run against these workers
while it is active. Result/status/log are the `r4/full.*` paths above.

Running process: xcodebuild PID **86636**, three workers under Xcode's private `XCTestDevices` set (not the default
simctl device set). Parallel per-test output is buffered in the main log; live worker logs are under
`full.xcresult/Staging/1_Test/Diagnostics/**/StandardOutputAndStandardError.txt`.
Full result: **exit 65, TEST FAILED, 59 tests: 58 passed / 1 failed / 0 skipped**, personally checked in the main log,
worker logs and xcresult summary (wall time 3,124.2 seconds). AskAIUITests: **31/32**; FloodlightAIRoutineUITests:
**16/16**; FloodlightProfileUITests: **11/11**. All keyboard regressions and four new capture cases passed.
`AskAIUITests.testAllThreeGeneratedTemplatesAppearWithoutRestart` failed at the immediate
post-typing assertion (`"Build"` instead of `"Build strength"`). Other goal-entry cases and the previously known
reorder/save case passed. Do not label this pre-existing or fixed without the result/serial rerun. Next after the
full run: inspect the failure recording and rerun it serially, then inspect/export the new Goals captures.
The run also logged missing app-animation-completion notifications; XCTest waited 60 seconds at a time and then
continued (the passing Goals number-pad test took 654.8 seconds versus 45.6 seconds in the focused run). Do not
confuse those test-driver waits with a measured phone response time. Invalid-frame runtime warnings also appeared
in the pre-fix run and are unchanged.

Next verification: `/tmp/wt-beta13-20261017-r5/serial.{log,status,xcresult}`; same destination/derived data and
`-collect-test-diagnostics never`, with `-parallel-testing-enabled NO -test-iterations 2
-test-repetition-relaunch-enabled YES -only-testing:WorkoutTrackerUITests/AskAIUITests/testAllThreeGeneratedTemplatesAppearWithoutRestart`.
No code change is being made on the strength of a single parallel typing failure.

**Serial rerun:** r5 finished **exit 0, TEST SUCCEEDED**, two repetitions with a fresh test process each time:
**1 test / 0 failures** in each iteration (60.8 s and 55.3 s), with no production-code change. Keep the original
parallel failure visible; its cause is not established.

**Visual QA caught an environment gap:** the eight r4 captures showed a focused field and the floating Done accessory
but no software keys (hardware-keyboard mode). Those captures do **not** establish the requested phone keyboard
layout and must be replaced. Capture tests now require real key elements and keyboard height >200 pt, not merely a
`Keyboard` element. Host Simulator preference `ConnectHardwareKeyboard` was originally **unset**; temporarily set
to false for the corrected captures. **Restore it by deleting that key after verification.** No product-code change
is needed for this test-environment correction unless the real-keyboard layout exposes a failure.

R6 (`/tmp/wt-beta13-20261017-r6/keyboard.*`) passed its one default/dark capture test with software keys and a >200 pt
keyboard, but visual review found the focused height field missing. R7 tightened the capture to require hittable,
nonzero focused-field bounds above Next and included the exact-value-wait correction for the transient AX text.
R7 (`/tmp/wt-beta13-20261017-r7/focused.*`) **exit 65, TEST FAILED: 2 tests / 1 failure**: the typing case passed;
the capture failed because height was at y=669…713 while Next was at y=465…521. Full-screen and app screenshots also
disagreed about keyboard rendering, so keep both during the diagnostic capture. Do not accept the earlier rectangle
comparison alone as visibility evidence.

Next hypothesis test: a native bottom `safeAreaInset` reserves the command's space for ScrollView keyboard avoidance.
If this does not keep the focused measurement visible, investigate focus-scroll timing after keyboard resizing;
keep a simulator snapshot mismatch as a third possibility. No domain/model changes. R8 artifacts will be under
`/tmp/wt-beta13-20261017-r8/`.

R8: build **exit 0, BUILD SUCCEEDED**; the visibility probe **exit 65, TEST FAILED, 1 test / 1 failure**. The native
inset reserved more room but height still ended at y=596…640, below Next at y=465…521. Keep the inset for the command's
scroll-space reservation and add explicit focus anchoring: stable field IDs and ScrollViewReader scroll to the
focused field after `keyboardDidShow`, and when switching fields while the keyboard is visible. No delay timer or
domain state is involved. R9 will verify this against the same strict software-keyboard probe.

## Comments
