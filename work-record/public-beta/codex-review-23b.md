# Codex review — ticket 23, round 2

Reviewed 2026-10-24: `git diff 553a501..6fa333c`, branch
`ericlee4992/beta-19-bug-fixes`, HEAD `6fa333c3a2032334f5fdedc5965886fd76e8bd19`.
Read the round-2 prompt and ticket response against all four round-1 findings. Working tree
was clean. STATE/review-record updates were distinguished from the implementation changes.

## Standards and UI/state

1. **P3 — Superseded choices retain their “Added” indicator in the open picker.**
   `WorkoutTracker/Features/Start/TemplateEditorSheet.swift:908–910` initializes the picker's
   independent `picked` set only on appearance. `TemplateMachinesTab.swift:112–114` then only
   inserts IDs into it. **Scenario:** pick single-exercise machine A, then B for the same
   exercise at the same gym. The corrected editor changes every corresponding draft row
   to B, but `picked` still contains A and B. A retains its checkmark and VoiceOver “Added”
   value even when no draft row chooses it. Closing and reopening the picker removes that
   stale indicator because it reloads the actual draft IDs.
   **Fix:** derive machine indicators from the current draft choices, or synchronize `picked`
   whenever `pickedMachineIDs` changes. Add a regression checking that A loses its indicator
   when B supersedes its last remaining draft choice; retain A's indicator if another exercise
   still chooses it. This affects feedback, not the now-correct saved machine selection.

Original **P2 #1 is otherwise closed**: gym selection and picks now live in the stable picker
and are passed by binding, so switching tabs retains them. Opening the picker again seeds
the current editor's choices, including picks made while editing a template. Stored templates
remain generic and do not acquire per-row machine fields.

Original **P2 #2 is closed**: `choosing` replaces prior choices/captions for the same exercise
and gym, leaving other gyms/exercises alone. Save deduplicates those effective choices, so
reordering rows no longer changes which machine wins. The remaining indicator issue above
comes from keeping a separate append-only set after this normalization.

## Spec, persistence and test closure

Original **P2 #3 is closed**. The editor now completes machine fetches before mutating memory,
stages the updates, and invokes the undo on errors from template persistence. The undo restores
an existing row's machine ID and timestamp and deletes a newly inserted row. It does not roll
back separately saved machines or unrelated context edits.

Reviewed the repeated-touch case: restore actions execute in reverse order. Two updates to one
row therefore unwind to its original values; an insert followed by an update restores the
inserted row's intermediate values before deleting it. Each action captures the actual row
modified, so canonical selection and existing duplicate rows remain consistent. The direct
test covers update/insert restoration and saving afterward; repeated-touch behavior was
source-reviewed, not independently added to the test suite. The logged-set path still performs
the same upsert and simply ignores the new change-description return value.

Original **P3 #4 is closed**. The UI test identifies `templateExercise.<name>` and requires
“Pec Deck” as a complete equipment component of its combined label. Inspected Claude's
`23-negative.xcresult`: removing the editor memory write makes this exact assertion fail on
“Chest Fly (Pec Deck), 3 sets · 10, 10, 10 reps.” The unmodified run passes. The exercise's
name no longer satisfies the equipment assertion by itself.

No additional domain/persistence defects found. Existing archived-machine/gym guards and
the stored format remain unchanged.

## Independent verification

Both commands used `WorkoutTracker.xcodeproj`, scheme `WorkoutTracker`, SDK `iphonesimulator`,
destination `platform=iOS Simulator,id=47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`
(**WT-iPhone27, iOS 27.0**, as authorized), and `-derivedDataPath /tmp/codex-23/DerivedData`.

| Check | Result | Evidence under `/tmp/codex-23/` |
|---|---|---|
| `xcodebuild … build` | **Exit 0; BUILD SUCCEEDED** | `build-round2.log`, `build-round2.status`, `build-round2.xcresult` |
| `xcodebuild test … -parallel-testing-enabled NO -collect-test-diagnostics never -only-testing:WorkoutTrackerTests/TemplateMachineChoiceTests -only-testing:WorkoutTrackerTests/EquipmentLifecycleTests` | **Exit 0; 16 passed, 0 failed, 0 skipped; TEST SUCCEEDED** | `unit-round2.log`, `unit-round2.status`, `unit-round2.xcresult` |
| `git diff --check 553a501..6fa333c` | **Exit 0** | No whitespace errors |

Inspected actual process exits, status files, log success markers and the xcresult summary;
no runtime warnings. This completes the equipment-suite verification left incomplete in
round 1. Also inspected Claude's `main-eq-serial` result/log: the unchanged baseline passed
12 tests, with the test-library run taking 179.322 seconds. The earlier interrupted runs
were incomplete measurements of a notification-service wait, not evidence of a product
regression or a proven permanent deadlock.

**Independent UI tests skipped.** Inspected Claude's `23-r1.xcresult` and log: 21 passed
(16 unit + 5 UI), zero failures/skips, exit 0, including both template-machine UI cases,
template-detail deletion and editor-superset startup. Its UI cases verify the gym/tab round
trip and strict equipment assertion, but not replacement of machine A by B in the open picker.
The negative run exited 65 with the intended equipment assertion failure and a passing warm-up.

Author evidence root:
`/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-beta-19-bug-fixes/5c90b802-2d0b-4541-a832-afac14d838e8/scratchpad/runs/`.

Only this new report was written. I did not commit or push.
Original findings: **all four closed**. Remaining standards/UI finding: **1 P3**.
Spec/persistence: **0 open findings**.

Verdict: not clear
