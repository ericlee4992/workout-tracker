# Codex review — ticket 23, round 3

Reviewed 2026-10-24: `git diff 6fa333c..7e9d06b`, branch
`ericlee4992/beta-19-bug-fixes`, HEAD `7e9d06b1ea92bbbbafcb5872ed5a637b46290b96`.
Read the round-3 prompt and ticket response against the remaining round-2 P3. Working tree
was clean.

## Standards and UI/state

**P3 closed.** `TemplateEditorSheet.swift:914` now synchronizes `picked` whenever the editor's
`pickedMachineIDs` changes. That input is derived from **all current draft rows** (`:115`),
so indicators follow the effective choices rather than accumulating every machine ever tapped.

Checked both cases:

- A superseded machine loses its checkmark and VoiceOver “Added” value when no draft row
  still chooses it.
- If another exercise row still chooses that machine, its ID remains in the derived set
  and its indicator stays. The existing `choosing` logic changes only the matching exercise
  at the matching gym; the previous unit regression also preserves other-exercise choices.

The retained gym state, initial/reopened picker seeding, captions and save behavior are
unchanged. No new standards or UI-state findings.

## Spec and tests

No findings. The expanded UI tests replace the selected station with a second machine for
the same exercise, assert that the old indicator and caption disappear, and verify the saved
detail's exact equipment-label component. They still exercise gym switching and the tab
round trip. The scroll-helper adjustment addresses the navigation-bar overlap seen at
AccessibilityL; it does not alter product behavior.

The “another row still chooses the machine” case was checked through the source data flow
and existing choice-normalization test, not through a new independent UI run. Domain memory,
undo, canonical-row and persistence code did not change in this round. All original findings
remain closed.

## Independent verification

Ran `xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator
-destination 'platform=iOS Simulator,id=47D21838-69A6-4BCB-AE90-B0D9C0AAA70B'
-derivedDataPath /tmp/codex-23/DerivedData -resultBundlePath /tmp/codex-23/build-round3.xcresult build`.

**Exit 0; BUILD SUCCEEDED.** Inspected the actual process exit,
`/tmp/codex-23/build-round3.status` and `build-round3.log`.
`git diff --check 6fa333c..7e9d06b`: **exit 0**.

**Independent UI tests skipped.** Inspected Claude's actual `23-r4.xcresult` and log on
WT-iPhone27, iOS **27.0**: **3 passed, 0 failed, 0 skipped**, no runtime warnings, exit **0**.
These are the default and AccessibilityL template-machine tests plus the cardio warm-up.
The earlier `23-r2` and `23-r3` runs exited 65; they are not counted as whole-run passes.
Their logs record all four `TemplateMachineChoiceTests` passing, and `23-r3` records the
template-detail deletion regression passing. Both template-machine UI cases pass in the final
`23-r4` run after the helper corrections.

No fresh unit run was needed for this three-line UI synchronization change. Round 2's
independent serial result remains applicable to unchanged domain code: **16 passed**, exit 0
(`TemplateMachineChoiceTests` and `EquipmentLifecycleTests`).

Author evidence root:
`/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-beta-19-bug-fixes/5c90b802-2d0b-4541-a832-afac14d838e8/scratchpad/runs/`.

Only this new report was written. I did not commit or push.
Standards: **0 open findings**. Spec: **0 findings**.

Verdict: clear
