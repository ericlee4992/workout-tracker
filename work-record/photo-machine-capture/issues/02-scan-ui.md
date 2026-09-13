# 02 — Scan UI: "Scan label…" in the New Machine sheet

Status: resolved
Blocked by: 01

## Files

- `WorkoutTracker/Features/Gyms/ScanMachineLabelSheet.swift` — capture → reading → candidates.
- `WorkoutTracker/Features/Gyms/ImagePicker.swift` — `UIImagePickerController` representable
  (camera, or photo library when there is no camera).
- `WorkoutTracker/Features/Gyms/GymsView.swift` — the "Scan label…" row in `MachineEditorSheet`,
  and prefill parameters on `AddModelSheet`.
- `INFOPLIST_KEY_NSCameraUsageDescription` in the app target's build settings (the project
  generates its Info.plist from these keys — this is the project's own idiom, not file
  registration, which stays out of `project.pbxproj` per CLAUDE.md).

## Behavior

- New Machine sheet grows one row under Catalog model: **Scan label…** (camera icon).
- Camera when the device has one; otherwise straight to the photo library, with the reason stated
  rather than a dead button. A photo taken earlier is a legitimate input.
- While Vision runs: a progress state, no frozen sheet.
- Result: the recognised text, then candidates ranked with percentages, the top one preselected
  when it clears the confident bar (D33 — preselected, never auto-applied). Actions: **Use This**
  and **None of these — create new**.
- Create-new opens the existing New Model sheet **prefilled** with the manufacturer and model
  guesses, still fully editable, and links it to the machine on save.
- Nothing readable in the photo → say so plainly and offer create-new (with the raw text, if any)
  or retake. Never a silent dismissal.
- The image is released as soon as the reading is produced (D34).

## Acceptance criteria

- [x] Accessibility identifiers: `scanMachineLabel`, `scanUseCandidate`, `scanCreateNew`,
      `scanCandidate.<modelName>`, `scanReadingText`, `scanStatus`.
- [x] Accepting a candidate fills Catalog model in the editor and defaults the label exactly as
      picking a model by hand already does (D3) — no second code path for naming.
- [x] Camera permission denied, no camera, and an unreadable photo are all handled with a stated
      reason and a way forward.
- [x] No photo is written to disk or into the store (D34).
- [x] Vision runs off the main actor; the sheet stays responsive.
- [x] A launch argument (`-uiTestScanFixture`) substitutes a rendered fixture label for the
      camera, so ticket 03 can drive the flow on a Simulator that has no camera. Test-only path,
      gated exactly like `-uiTestReset`.

## Resolution (2026-08-11)

`Features/Gyms/ScanMachineLabelSheet.swift` and `ImagePicker.swift`; `MachineEditorSheet` grew a
"Scan label…" row and `AddModelSheet` grew prefill parameters. Camera and photo-library usage
strings added as `INFOPLIST_KEY_*` build settings (the project generates its Info.plist, so this
is its own idiom — no file registration touched).

Accepting a scanned model assigns the same `model` state a hand-picked one does, so the D3 label
default has exactly one implementation. `-uiTestScanFixture` renders a name plate in place of the
camera, because the Simulator has none and the flow was otherwise undrivable by XCUITest.

## Codex cross-review round 1 (2026-08-11)

Fixed here: orientation is passed to Vision and `CIImage`-backed photos are rendered rather than
called unreadable (finding 5); camera availability *and* authorization are resolved before
anything is presented, with the reason stated and Settings / photo-library / by-hand routes
offered (finding 6); below the create-new floor the create-new **action** leads rather than just
the wording (finding 8); and the Vision adapter moved to `Features/Gyms`, since `Domain/` is value
types and pure logic (finding 12).

## Codex cross-review round 2 (2026-08-11)

Capture availability was still lossy on the transitions that matter (finding 6): a picker
cancelled after a permission denial dismissed the whole scanner instead of explaining; `.restricted`
was folded into `.denied` and offered a Settings route that cannot help; and a "Try the camera
again" button opened the photo library. Availability is now re-resolved on cancellation, the two
blocked states are distinct, Settings appears only where it is a remedy, and actions are labelled
by what they actually open. `CaptureAvailabilityTests` covers every state — including the ones a
Simulator cannot reproduce.
