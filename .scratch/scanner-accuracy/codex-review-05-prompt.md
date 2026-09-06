Round 1 (T6) of scanner-accuracy ticket 05, "Ask AI" — an escalation path that sends the
plate crop to Claude when the on-device scanner could not place it. Ticket:
.scratch/scanner-accuracy/issues/05-ask-ai-escalation.md (what to build, acceptance criteria,
resolution). Background: .scratch/scanner-accuracy/issues/llm-reader-experiment.md and D53 /
the D34 amendment in docs/DECISIONS.md. Boundary: 8e0da6d..HEAD on branch ask-ai (two commits;
the first is only the framing box's size).

Files: WorkoutTracker/Domain/PlateTranscription.swift, Domain/LabelCrop.swift,
Features/Gyms/AskAI.swift, Features/Settings/AskAISettingsSheet.swift, the edits to
Features/Gyms/ScanMachineLabelSheet.swift and Features/Settings/AppSettingsSection.swift,
WorkoutTrackerTests/PlateTranscriptionTests.swift, WorkoutTrackerUITests/AskAIUITests.swift.

Scope, by what could actually hurt the user:
1. The on-device-first invariant: can a network call happen before the shutter's Vision read
   finished without a preselection? Can it happen without a tap? Can it happen twice for one
   tap, or after a rescan, or after the sheet is dismissed? Trace `ask(_:)` and the
   `crop` identity check.
2. D33: can the AI reading preselect something the camera reading could not have — is the
   preselection rule applied identically (`present(_:in:source:crop:)`)? Can the model's
   text reach the create-new prefill or the reading echo in a way that invents a name?
3. D34/D53: what bytes leave the phone — trace `LabelCrop.pixelRect` and `LabelCrop.jpeg`
   for the shutter path (region set, EXIF-oriented UIImage from `AVCapturePhoto`) and the
   library path (region nil). Is the crop the box in the UPRIGHT photo? Is the whole frame
   ever sent from the shutter path? Is anything written to disk?
4. The key: keychain attributes, never logged, never shown back, never in the binary; the
   UI-test in-memory slot cannot leak into a real launch (`WorkoutTrackerStore.isUITestReset`).
5. Fail-closed: offline, timeout, 401, refusal, malformed each leave the sheet usable; no
   background retry. Error mapping of `URLError` codes.
6. Fixtures obey `WorkoutTrackerStore.fixtureIsEnabled` (a fixture flag ALONE must do nothing).
7. Tests: do the unit tests pin what the ticket claims? Do the UI tests prove the path or
   only its happy surface?

Report by severity with file:line, or say "clear" in one paragraph if nothing needs to
change. Do not modify source files. Write to .scratch/scanner-accuracy/codex-review-05.md
