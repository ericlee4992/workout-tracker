# Codex review — ticket 22

Reviewed 2026-10-23 as Claude's independent reviewer. Scope: `git diff 2ab1711..8657703`.
Branch `ericlee4992/beta-19-bug-fixes`, HEAD `92e150892584c4cd43a6886dce1d708a4c04eda8`.
The later commit only records the review range; product, test and project files match `8657703`.
Working tree was clean. Read the ticket, D65/D7, milestone 2 ticket 17's D1, the relevant
design/verification rules and the affected callers.

## Standards and visual finding

1. **P3 — The Machines header sends a custom glyph name to an SF Symbols renderer.**
   `WorkoutTracker/Features/ActiveWorkout/AddByMachineSheet.swift:82` passes `LookIcon.machine`
   to `LookSectionLabel`. That constant is the custom sentinel `"lookicon.machine"`
   (`Features/Design/Look/Glyphs.swift:34`), while the label uses `Image(systemName: symbol)`
   (`Features/Design/Look/NativeLists.swift:50`). **Failure scenario:** opening the Machines tab
   shows “Machines at Iron Temple” without the intended machine glyph at both default and
   AccessibilityL sizes. This is visible in the final `22-final` captures, not merely inferred
   from older captures. **Fix:** render the header symbol through `LookIcon(symbol, style:
   .footnote)` or pass a supported SF Symbol. Recapture the header at both sizes after the fix.

No other standards findings. The switch uses the existing accessible pills, and the live add
block retains its established primary/secondary hierarchy. README documents the combined entry
point; D65 explicitly reopens the old layout while retaining D7 and D1's discoverability rule.

## Spec and behavior

No functional spec defects found:

- The live block has Add Exercise and Add Cardio only. Add Exercise remains primary unless
  resting or in cardio focus; Add Cardio is full-width secondary. The obsolete block parameters
  and separate sheet state have no remaining callers. The per-entry machine picker is untouched.
- `AddExerciseSheet` starts on Exercises. Each branch retains its own NavigationStack and
  sheet dismissal environment. Single-exercise machines still add with the machine; stations
  use the existing chooser; the no-link fallback uses the full catalog. Add Machine and
  confirmed archival are unchanged.
- The pushed chooser calls its parent's add-and-dismiss function. Inline New Exercise still
  clears its creation state before adding and dismissing. Switching tabs recreates the picker,
  resetting exercise search/scroll state; no retention requirement was specified. A pushed
  chooser or creation form does not expose the mode switch, so it cannot discard unfinished
  form input through that switch.
- With no gym, Machines remains selectable and displays `addByMachineUnavailable`; the branch
  contains no Add Machine button. Exercises remains available. History passes no mode binding
  and retains its original exercise picker.
- `SegmentedPills` preserves the Exercises/Machines labels, selected trait, scaled hit areas and
  Reduce Motion behavior. Capture tests scope the pills by `addExerciseMode`, avoiding the
  unrelated Exercises tab-bar button.
- UI helper changes target the workout's Add Exercise → Machines path. The preset suite's
  Gyms/Add Machine helper no longer contains the erroneous Machines tap. No obsolete user-facing
  “Add by Machine” instructions were found in the current tour, What's New or SPEC. The retained
  conditional standalone-sheet title and historical comments are not stale live instructions.

## Independent verification

Ran `xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator
-destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674'
-derivedDataPath /tmp/codex-22/DerivedData -resultBundlePath /tmp/codex-22/build.xcresult build`.

**Exit 0; BUILD SUCCEEDED.** Inspected the actual process exit, `/tmp/codex-22/build.status`
and `build.log`. `git diff --check 2ab1711..8657703`: **exit 0**.

**Independent UI tests skipped**, as permitted. Inspected Claude's actual `22-final.xcresult`:
**21 passed (7 UI + 14 unit), zero failures/skips**, WT-iPhone27, iOS **27.0**. Its log records
`TEST SUCCEEDED`, exit **0**. It covers both list-end/picker captures, no-gym cancellation,
machine deletion, both preset flows and the warm-up. The bundle also reports three invalid-frame
runtime warnings; no associated test failed, and this review does not claim they were resolved.

Inspected `22-ui-2`'s test-result tree and the `22-ui-3/4/5`, `22-base`, and `22-final` logs.
All 17 targeted cases plus the warm-up have a passing run across those artifacts; not all ran
again on the final header revision. The preset helper rewrite and ambiguous Exercises query
were actual test defects corrected before the final run. Earlier keyboard-focus/launch failures
passed serially; Add Set passed alone in `22-ui-4` and three repetitions in `22-ui-5`. Those
results support the ticket's flakiness assessment but do not independently prove machine load
as the cause. No blanket claim that `22-ui-2` or `22-ui-3` passed is made (both exited 65).

Exported all six final list-end/Exercises/Machines attachments from `22-final.xcresult` to
`/tmp/codex-22/captures/` and visually inspected both default and AccessibilityL. The two add
buttons, mode labels, visible exercise/machine names and Add Machine control remain readable;
finding 1 is the missing header glyph. Final Machines evidence:

- Default: `8E6C2153-F353-4CDA-B409-4716542426D0.png`.
- AccessibilityL: `DA8F9859-5EF1-4CE5-8AF9-F897C91A5DDE.png`.

`captures/manifest.json` records the attachment/test mapping. Live VoiceOver traversal and
additional manual chooser/tab-switch scenarios were not independently exercised.

Author evidence root:
`/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-beta-19-bug-fixes/5c90b802-2d0b-4541-a832-afac14d838e8/scratchpad/runs/`.

Only this report was written in the repository. No commit or push.
Standards/visual: **1 finding (P3)**. Functional spec: **0 findings**.

Verdict: not clear
