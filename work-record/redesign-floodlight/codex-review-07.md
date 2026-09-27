# Ticket 07 — independent Codex review

**Not clear: three medium findings.** No critical or high findings identified.

Reviewed `ericlee4992/redesign-floodlight-gyms..HEAD`, base `d45d5c5`, head
`b5a93ea6fea1c83857bfb20c4accd8bd38629c7c`, on
`ericlee4992/redesign-floodlight-scan` in `/tmp/wt-floodlight/scan`.
Claude implemented; Codex reviewed. Findings below are established by source tracing;
no new app execution is claimed.

## Medium

### 1. Clearing either identity field removes the controls needed to finish correcting it

**Location:** `WorkoutTracker/Features/Gyms/Scan/ScanResultStep.swift:126–131`
(`showsMakerFields`), with the editable bindings at `:324–328`.

On a specific result, select all text in Manufacturer or Model and delete it before
typing the replacement. `EquipmentIdentityResolution.resolve` returns `.generic` when
either field is empty (`Domain/EquipmentIdentification.swift:65–66`), so this predicate
immediately removes **both** fields. The generic toggle also disappears because that
resolution is not restorable (`ScanResultStep.swift:263–278`). The user cannot complete
the correction in this result and must retake/cancel or accept a model-less machine.
The old sheet kept these fields whenever the proposal's identity was specific.

This breaks ticket 07's “kept editable — D56's editable proposal.” Keep editor visibility
independent of temporary field validity; resolving to generic can still control what Add
saves. Verify clearing and retyping each field, including a model edit that temporarily
becomes a movement-only name.

### 2. Changing the catalog identity can make form mode replace the name shown at confirmation

**Location:** `WorkoutTracker/Features/Gyms/IdentifyEquipmentSheet.swift:305–313`
(one-time prefill), `WorkoutTracker/Domain/ScanMachine.swift:32–44` (confirmation), and
`WorkoutTracker/Features/Gyms/MachineEditorSheet.swift:161–166,226–234` (handback/default).

Start with the specific Life Fitness chest-press result, whose Name is “Seated Chest
Press.” Replace Model in one edit with “Insignia Series Shoulder Press,” leaving Name
untouched. The identity and exercises resolve to the shoulder-press catalog row, but Name
stays “Seated Chest Press”: prefill only ran when the AI answered. Direct Add saves that
visible name. In form mode, confirmation retains `labelWasEdited == false`; the form
assigns that name to both `label` and `modelDerivedLabel`, then its model-change observer
runs `applyModelDefaultLabel()` and replaces it with “Machine Shoulder Press.” Thus the
same confirmed answer produces different names in the two modes.

Ticket 07 requires the field to show what is saved in both modes. Reconcile automatic
prefill when identity changes and/or preserve the confirmed visible label on handback,
while keeping deliberately edited names. Add coverage for changing the catalog identity
without editing Name; the existing label tests only exercise initial prefill and explicit
name edits.

### 3. Correction UI tests pass without proving the history boundary

**Location:** `WorkoutTrackerUITests/FloodlightScanUITests.swift:320–354`.

`testPastCorrectionAsksThenApplies` checks the scope description, confirmation, and sheet
dismissal, but never checks the machine's new model or any rewritten snapshot. It passes
if confirmation merely dismisses, or applies `.futureOnly`. The future-only test checks
the live model but never verifies that historical snapshots stayed unchanged, so it also
passes if that action rewrites history. Cancelling the confirmation is likewise checked
only for keeping the sheet open (`:311–315`).

Ticket 07 promises “asks first and rewrites; future-only leaves history,” and DEVELOPMENT
requires verification of affected callers. Assert a known historical entry before and
after future-only, cancellation, and confirmed past correction, including the stored model
identity. Existing lifecycle unit tests verify the helper's scopes, not that these new
controls invoke the right scope. Source inspection currently shows correct scope wiring;
this finding concerns the claimed regression coverage.

## Review scope and evidence

Read the ticket/user decisions, relevant SPEC/DECISIONS, design review/reference material,
prototype source and captures, changed source/tests, and old sheets at the base. Inspected
actual default/AccessibilityL captures in light/dark. No additional concrete finding in
consent/request cancellation, in-memory photo handling, direct-add/manual routing, routine
counts/preferences, Read Label's unchanged framing and D33/D53 behavior, or correction
impact selection. The impact query matches the lifecycle rewrite predicate and includes
snapshot entries in a running workout. The named motion effects have Reduce Motion gates
in source; captures do not establish runtime VoiceOver or Reduce Motion behavior.

Read existing `.exit` files and logs under `/tmp/wt-floodlight/results/`: both build runs
succeeded; `scan-unit-3` exited 0 with 66 tests; `scan-ui-2` ran 19 tests with two failures,
whose correction cases passed in `scan-ui-4`; subsequent focused reruns cover the recorded
test-mechanics fixes, including `scan-ui-7` (exit 0). The two outstanding AX routine-form
tests also fail in `scan-baseline-1` on the base, consistent with the ticket's limitation.
Targeted verification is appropriate for this ticket; the whole-redesign release still
owns its full-suite gate. Finding 3 and regression checks for findings 1–2 remain needed.

No `xcodebuild` or `simctl` commands were run. Only this report was modified.
