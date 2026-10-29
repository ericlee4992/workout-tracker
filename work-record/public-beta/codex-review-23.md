# Codex review — ticket 23

Reviewed 2026-10-24 as Claude's independent reviewer: `git diff 4ceefc7..74adb88`.
Branch `ericlee4992/beta-19-bug-fixes`. Review began at `553a501`; the later concurrent
`b6c8bf8f0957dc35fec67bd2fb9efe780d0fd4ff` changes only STATE. Verified all application, test
and project files still match `74adb88`. Read the ticket, D66/D6/D7, ticket 22 and the
repository's code/design/verification rules. Working tree was clean.

## Standards and UI behavior

1. **P2 — Switching tabs discards the selected gym and machine checkmarks.**
   `WorkoutTracker/Features/Start/TemplateEditorSheet.swift:854` conditionally creates
   `TemplateMachinesTab`, which owns `gymID` and `picked` as local state
   (`TemplateMachinesTab.swift:15–18`). **Scenario:** choose a different gym, pick a machine,
   switch to Exercises, then return to Machines. The view is recreated: the gym resets to
   the Workout-tab preference and the Added marks disappear, although the draft retains
   those additions. This loses the picker context during the same multi-add operation.
   **Fix:** retain gym selection in the stable picker/editor and derive or retain machine
   selection indicators from the staged choices. Cover a two-gym tab round trip with an
   existing pick, checking both the selected gym and Added state.

2. **P2 — Reordering rows changes the effective machine choice.**
   `WorkoutTracker/Features/Start/TemplateEditorSheet.swift:167–172` replays choices in
   current display order. **Scenario:** add the same exercise from machine A, then B, at the
   same gym; drag B's row above A and Save. A is written last and wins, even though B was the
   last machine chosen. Each draft row also retains its different machine caption, while
   both saved rows resolve through the single `(gym, exercise)` memory. Merely changing the
   exercise order thus changes equipment and leaves one caption misleading.
   **Fix:** resolve one effective staged choice per `(gym, exercise)` independently of row
   order, preserving the latest surviving choice rather than replaying visual order. Make
   captions consistent with that effective choice. Test competing picks followed by reorder,
   save and template start.

No additional schema, glyph, menu-affordance or nested-sheet standards findings.

## Spec, persistence and tests

3. **P2 — A failed Save can leak machine choices after the template is discarded.**
   `WorkoutTracker/Features/Start/TemplateEditorSheet.swift:172` mutates shared-context memory
   before the remaining machine fetches and template persistence complete. The catch at
   `:183–184` only displays an error. **Scenario:** a later fetch or save throws, then the
   user cancels/discards the template. The already-modified memory rows remain pending in
   the shared context and can be committed by a later successful save, changing other
   templates' defaults despite the unsuccessful operation. This violates D66's “Cancel
   changes nothing” for the staged machine choices. The UI's `canSave` validation does not
   prevent storage errors after these mutations.
   **Fix:** make template persistence and its memory updates atomic, or restore precisely
   the touched memory rows on failure. Avoid rolling back separately saved machine creation
   or unrelated context changes. Add a failure-then-discard regression asserting the
   previous machine defaults remain unchanged.

4. **P3 — The UI assertion can pass without the editor saving machine memory.**
   `WorkoutTrackerUITests/TemplateMachinesUITests.swift:98–99` accepts any label containing
   “Pec Deck.” The chosen exercise in the actual captures is **“Chest Fly (Pec Deck)”**, so
   the exercise title alone satisfies this assertion even if the editor's memory write is
   removed. Excluding the fixture's already-remembered Rear Delt Fly avoids one false positive
   but not this one. **Fix:** use a distinct machine label absent from the exercise name and
   assert the resolved-equipment field or the started entry's machine. Verify the assertion
   fails when the editor's memory write is disabled. The two domain tests call
   `rememberMachine` directly and therefore do not cover this missing editor integration.

These findings are established by the source paths and, for finding 4, the actual captured
exercise name; tab/reorder scenarios and storage-failure injection were not independently
executed as UI tests.

Other checks:

- The logged-set upsert retains its previous behavior, including nil machine IDs and canonical
  row selection. Normal upserts update the canonical row rather than adding duplicates;
  existing duplicate rows are not removed. The new API refuses archived machines and gyms.
- Memory is not written merely by picking or cancelling without a Save attempt. Templates
  remain generic: no machine field was added to stored template items, and other gyms retain
  their own defaults. No stored-format change or new unique constraint occurs.
- Previous performance and prefill derive from completed sets, not the memory timestamp, so
  choosing a machine does not create training history. Template detail/AI resolution and
  export consume the remembered machine without inventing logged sets. README and D66
  document “last used or chosen.”
- The initial gym selection, archived-gym exclusion, no-gym explanation, empty-machine state,
  Add Machine form and station/full-catalog chooser are wired. Machines navigation is outside
  the lazy Exercises container. Existing Edit Template rows have no staged machine; re-picks
  use the multi-add path. The new UI tests open Add Machine and verify Scan equipment is
  offered, but cancel that form: actual machine creation/scanning, gym switching and the
  state/reorder cases above are not proved by those tests.

## Independent verification

Used `WorkoutTracker.xcodeproj`, scheme `WorkoutTracker`, SDK `iphonesimulator`, and
`-derivedDataPath /tmp/codex-23/DerivedData`.

| Check | Result | Evidence under `/tmp/codex-23/` |
|---|---|---|
| `xcodebuild … build`, WT-Floodlight `9E822EF6-DC67-4958-AEA2-D53D2D36D674` | **Exit 0; BUILD SUCCEEDED** | `build.log`, `build.status`, `build.xcresult` |
| Both requested suites, WT-Floodlight, serial | Stalled on first equipment test; **exit 65** after simulator shutdown | `unit.log`, `unit.status`, `unit.xcresult` |
| Same selection after Floodlight restart | Stalled again; **exit 75** after interruption | `unit-retry.log`, `unit-retry.status`, `unit-retry.xcresult` |
| Both suites on user-authorized WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`, serial | Stalled on the same test; **exit 75** after interruption | `unit-iphone27.log`, `unit-iphone27.status`, `unit-iphone27.xcresult` |
| `TemplateMachineChoiceTests` alone on WT-iPhone27, iOS **27.0**, serial | **Exit 0; 2 passed, 0 failed, 0 skipped; TEST SUCCEEDED** | `unit-choice.log`, `unit-choice.status`, `unit-choice.xcresult` |

The combined commands selected
`-only-testing:WorkoutTrackerTests/TemplateMachineChoiceTests` and
`-only-testing:WorkoutTrackerTests/EquipmentLifecycleTests`, with
`-parallel-testing-enabled NO -collect-test-diagnostics never`. Each attempt has its own
result path. Inspected actual exits, status files, logs and the successful xcresult summary.
`git diff --check 4ceefc7..74adb88`: **exit 0**.

**EquipmentLifecycleTests did not complete independently.** The first run's stack sample
(`test-host-sample.txt`) shows `makeFixture → WorkoutSession.finish → RestTimerService.skip →
UserNotificationScheduler.cancel`, blocked awaiting a synchronous UserNotifications XPC reply.
The subsequent attempts stopped on the same first test. No equipment assertion failure was
reported before interruption. Claude's earlier `22-final` log shows 14 passing unit tests with
cases running concurrently; I retained the repository's serial-unit-test rule. This review
does not substitute that earlier result for an independent pass or prove the stall's root cause.

**Independent UI tests skipped.** Inspected Claude's `23-ui-1.xcresult` (5 passed; log exit 0)
and `23-ui-2.xcresult` (4 passed: two template UI cases and two unit tests; one cardio warm-up
snapshot timeout, overall exit 65). No claim that the latter run passed as a whole.
Opened the Machines and Add Machine AccessibilityL captures, and both final editor captures
in `shots23b`: the machine caption/glyph wraps readably, and Scan equipment is visible in
the nested form. Live VoiceOver and real scanning were not exercised.

Author evidence root:
`/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-beta-19-bug-fixes/5c90b802-2d0b-4541-a832-afac14d838e8/scratchpad/runs/`.

Only this report was written in the repository. I did not commit or push.
Standards/UI: **2 P2 findings**. Spec/tests: **1 P2 and 1 P3 finding**.

Verdict: not clear
