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
The pre-fix two-case run is active as exec session `86827` (`xcodebuild` PID `68945`), with
`red.log`, `red.status`, `red.xcresult` in the same artifact directory. It selects
`FloodlightAIRoutineUITests/testGoalsReturnDismissesWithoutANewline` and
`FloodlightAIRoutineUITests/testGoalsNextAdvancesWhileTyping`, serially. Next: inspect the actual result, then fix.

## Comments
