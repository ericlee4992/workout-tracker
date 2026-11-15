# Codex review — tester feedback 01, round 1

Reviewed `git diff 4a8fca45..74fbf76d` on `ericlee4992/one-machine-scan` (2026-11-14).
Base: `4a8fca458eea6e92a0189b77574d9128a125c4e0`; HEAD: `74fbf76dcd5aaa6b20da7982a559283ad3b93e93`.

The removal is behaviorally sound in the inspected source and completed tests. One correction is requested in the explicitly reviewed, edited SPEC paragraph; stale comments are a low-priority cleanup. No app/server source, documentation, tests or configuration were changed by this review. No commit or deployment performed.

## Standards

1. **P3 — comments still describe removed code and coverage.** `WorkoutTracker/Features/Gyms/LabelCameraView.swift:13` and `:291` name `MachineLabelOCR`, which this diff deletes; `WorkoutTracker/Features/Gyms/Scan/ScanSteps.swift:247` contrasts the current camera with a still-present Read Label flow; `WorkoutTrackerUITests/FloodlightAIAccessUITests.swift:4` claims New Model suggestion coverage after those tests were removed. These descriptions now direct maintainers to nonexistent code/features. AGENTS requires checking doc comments against callers. **Suggested fix:** describe the shared camera's upright, normalized crop coordinates and current callers; remove the retired flow from the scan/test headers. Nonblocking cleanup; no runtime defect. No actionable baseline code smells introduced.

## Spec

2. **P2 — the edited source-of-truth paragraph still describes the obsolete credential architecture.** `docs/SPEC.md:30` says “Private-trial OpenAI credentials live in the phone Keychain” and “D60 plans that backend.” The current client sends authenticated requests to Stacked's server (`WorkoutTracker/Domain/AIServerClient.swift:67`); `LegacyOpenAIKey.purge()` deletes the old phone key (`:185`, called from `WorkoutTracker/App/WorkoutTrackerApp.swift:37`), while `server/src/ai.ts:652` and `:666` use the Worker secret for OpenAI. A reader following SPEC would infer a phone-held provider key and a backend that has not shipped. **Suggested fix:** replace those two sentences with the current D60 server-mediated flow and server-held key, marking private-trial behavior as historical only if it is retained. This wording predates D88, but remains in the exact paragraph amended and explicitly requested for review; it fails ticket 01's acceptance that “Docs … match the code.” This is a documentation correction, not a newly introduced runtime bug.

Standards: **1 low-priority comment finding**. Spec: **1 requested documentation correction (P2)**. No behavioral findings.

## Scope and source checks

- The form retains Catalog model and one Scan Machine row, with unchanged sign-in/consent and fill-form callbacks. ModelPicker still independently opens AddModelSheet. Correct Model and the guided tour retain their current scan/manual paths.
- No executable references to the removed OCR/matcher/proposer, consent key, launch argument or UI identifiers remain. Shared camera, crop, ScanFixture and scan components still have Scan Machine/Food or test callers. Server `model-exercises` intentionally remains for installed builds; client removal does not remove that endpoint.
- D88 records the user's choices and supersedes the relevant earlier rules. README and CI changes describe the removals accurately. No README screenshot depicts the removed reader. The privacy page retains the earlier-build exercise-suggestion disclosure, does not imply ordinary photos are uploaded, and deliberately retains `[effective date]`; not deployed.
- Test-plan mapping is current. The workflow removes the now-unneeded CI flag without narrowing the Unit plan. Post-merge GitHub verification remains pending; this review did not merge or dispatch CI.
- The author's 73-test scope covers shared scanning, account/profile changes, correction and template-machine flows, but omits the surviving ModelPicker → New Model path. This review adds all four `FloodlightGymsUITests/testCaptureEditors*` cases. They verify navigation and prefilled fields; they do not submit a newly authored model.
- Inspected real default/AccessibilityL machine-form captures from both the author and this review. Review captures: `build/captures/codex-tf01-default/` and `build/captures/codex-tf01-axl/`. The single Scan Machine row and catalog option remain readable.

## Independent verification

Xcode **27.2 (27B52)**; iOS **27.0**, WT-Floodlight (iPhone 15 Pro Max), UDID `9E822EF6-DC67-4958-AEA2-D53D2D36D674`. Own derived data: `build/dd-codex`. Simulator runs did not overlap; primary UI and supplemental editors use at most two workers; Unit and gym rerun are serial.

| Command / scope | Exit | Result / evidence |
|---|---:|---|
| `scripts/prepare-test-simulator.sh` | 0 | WT-Floodlight ready/booted |
| `python3 scripts/test-plans.py --check` | 0 | No unmapped/stale plan entries |
| `git diff --check 4a8fca45..74fbf76d` | 0 | Clean |
| `xcodebuild … build` | 0 | BUILD SUCCEEDED; `build/logs/codex-tf01-build.log` |
| `xcodebuild … test -testPlan Unit` | 0 | **1291/1291 passed**, 0 failed/skipped; `build/results/codex-tf01-unit.xcresult` |
| Primary focused UI (73 named cases below) | 65 | **72 passed, 1 failed, 0 skipped**; `build/results/codex-tf01-ui.xcresult` |
| Serial `GymsFlowsUITests` rerun | 0 | **4/4 passed**, 0 failed/skipped; `build/results/codex-tf01-gyms-rerun.xcresult` |
| Additional four editor tests | 0 | **4/4 passed**, 0 failed/skipped; `build/results/codex-tf01-editors.xcresult` |
| `cd server && npx vitest run` | 0 | **341/341**, 10 files; `build/logs/codex-tf01-server.log` |
| `cd server && node --test scripts/feedback-args.node-test.mjs` | 0 | **4/4**, no failures/skips |
| `cd server && npm run typecheck` | 0 | `tsc --noEmit` clean; `build/logs/codex-tf01-typecheck.log` |

Counts above were read from actual xcresult summaries (`xcrun xcresulttool get test-results summary --path …`, exit 0) and process status files, not inferred from another agent's report. Summary JSONs and status files are in `build/logs/codex-tf01-*`. Author results were also inspected: 1291 Unit and 73 UI passed, but do not substitute for this review's runs.

**Intermittent failure:** primary run failed `GymsFlowsUITests/testMachinePageEditsApplyAndDeleteCloses` at `WorkoutTrackerUITests/GymsFlowsUITests.swift:134`: immediately after deleting the name and submitting, the test read placeholder `Name` instead of restored `Seated Row`. Both the test and `MachineDetailView.swift` are byte-for-byte unchanged from the base. Per DEVELOPMENT, the entire class was rerun alone/serially: all four passed, including blank-name restoration, rename, unit change and deletion. No code/test change was made. Record this intermittent test for follow-up; the precise timing cause was not proven. It is not evidence of a D88 regression.

## Exact simulator commands

Primary runner: `build/codex-tf01-run.py` (PID 28751, completed). Serial rerun driver: `build/codex-tf01-postfailure.py` (PID 48600, completed); supplemental editor command: `build/codex-tf01-editors.sh`. Per-run logs/status are `build/logs/codex-tf01-{build,unit,ui,gyms-rerun,editors}.{log,status}`.

```sh
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' -derivedDataPath build/dd-codex build

xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' -derivedDataPath build/dd-codex test -testPlan Unit -parallel-testing-enabled NO -resultBundlePath build/results/codex-tf01-unit.xcresult -collect-test-diagnostics never

xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' -derivedDataPath build/dd-codex test -testPlan Full -parallel-testing-enabled YES -parallel-testing-worker-count 2 -resultBundlePath build/results/codex-tf01-ui.xcresult -collect-test-diagnostics never -only-testing:WorkoutTrackerUITests/FloodlightScanUITests -only-testing:WorkoutTrackerUITests/ScanFoodUITests -only-testing:WorkoutTrackerUITests/GymsFlowsUITests -only-testing:WorkoutTrackerUITests/TemplateMachinesUITests -only-testing:WorkoutTrackerUITests/FloodlightAIAccessUITests -only-testing:WorkoutTrackerUITests/FloodlightAccountUITests -only-testing:WorkoutTrackerUITests/FloodlightProfileUITests/testCaptureProfileLightDefault -only-testing:WorkoutTrackerUITests/FloodlightProfileUITests/testCaptureProfileLightAccessibility -only-testing:WorkoutTrackerUITests/FloodlightProfileUITests/testCaptureProfileDarkDefault -only-testing:WorkoutTrackerUITests/FloodlightProfileUITests/testCaptureProfileDarkAccessibility -only-testing:WorkoutTrackerUITests/AskAIUITests/testGenericScanConfirmsBeforeSavingDefault -only-testing:WorkoutTrackerUITests/AskAIUITests/testGenericScanConfirmsBeforeSavingAccessibility -only-testing:WorkoutTrackerUITests/AskAIUITests/testScanFailureAndRescanRemainUsable -only-testing:WorkoutTrackerUITests/AskAIUITests/testRescanDropsLateAIResponse -only-testing:WorkoutTrackerUITests/AskAIUITests/testScanMachinesDuringRoutineSetupDefault -only-testing:WorkoutTrackerUITests/AskAIUITests/testScanMachinesDuringRoutineSetupAccessibility -only-testing:WorkoutTrackerUITests/AskAIUITests/testRoutineScannerConsentAndFailureKeepPreferences -only-testing:WorkoutTrackerUITests/AskAIUITests/testEditedProposalLabelSurvivesCatalogSelection -only-testing:WorkoutTrackerUITests/AskAIUITests/testSpecificIdentityDefault -only-testing:WorkoutTrackerUITests/AskAIUITests/testSpecificIdentityAccessibility -only-testing:WorkoutTrackerUITests/AskAIUITests/testNewModelIdentityDefault -only-testing:WorkoutTrackerUITests/AskAIUITests/testNewModelIdentityAccessibility -only-testing:WorkoutTrackerUITests/AskAIUITests/testAmbiguousIdentityDefault -only-testing:WorkoutTrackerUITests/AskAIUITests/testAmbiguousIdentityAccessibility -only-testing:WorkoutTrackerUITests/AskAIUITests/testUncertainIdentityDefault -only-testing:WorkoutTrackerUITests/AskAIUITests/testUncertainIdentityAccessibility -only-testing:WorkoutTrackerUITests/AskAIUITests/testPhotoConsentDefault -only-testing:WorkoutTrackerUITests/AskAIUITests/testPhotoConsentAccessibility

xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' -derivedDataPath build/dd-codex test -testPlan Full -parallel-testing-enabled NO -resultBundlePath build/results/codex-tf01-gyms-rerun.xcresult -collect-test-diagnostics never -only-testing:WorkoutTrackerUITests/GymsFlowsUITests

xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' -derivedDataPath build/dd-codex test -testPlan Full -parallel-testing-enabled YES -parallel-testing-worker-count 2 -resultBundlePath build/results/codex-tf01-editors.xcresult -collect-test-diagnostics never -only-testing:WorkoutTrackerUITests/FloodlightGymsUITests/testCaptureEditorsLightDefault -only-testing:WorkoutTrackerUITests/FloodlightGymsUITests/testCaptureEditorsLightAccessibility -only-testing:WorkoutTrackerUITests/FloodlightGymsUITests/testCaptureEditorsDarkDefault -only-testing:WorkoutTrackerUITests/FloodlightGymsUITests/testCaptureEditorsDarkAccessibility
```

**Verified:** build; Unit 1291/1291; primary UI 72/73 followed by the affected class 4/4 serially; server 341 + 4 tests and typecheck; test-plan mapping; default/AccessibilityL form captures. Additional ModelPicker → New Model editor checks 4/4, exit 0.

**Not verified:** live signed-in camera/network behavior on a phone; actual new-model submission through the manual editor (the added cases cover navigation/prefill); deployed privacy page (intentionally not deployed); post-merge GitHub Tests run.

**Known flaky:** `GymsFlowsUITests/testMachinePageEditsApplyAndDeleteCloses` — one blank-name restoration assertion failed in the parallel run, passed in the full serial class rerun; follow-up suggested above. No other failures observed.

Verdict: changes requested


## Round 2

Reviewed `git diff 74fbf76d..ec2faa8e` at HEAD `ec2faa8ef55dd5968beceda3a04bf3a0eadbbd12`, branch `ericlee4992/one-machine-scan`. The checkout was clean before appending this section. This revision changes documentation/comments and records round 1; no runtime or test logic changed.

### Standards

1. **R2-1, P3 — the replacement camera comment describes a consumer that does not exist; the old region payload is now unused.** `WorkoutTracker/Features/Gyms/LabelCameraView.swift:13` says `CapturedLabel.region` is the box that `LabelCrop` crops for Scan Food; the revised comment at `:291` repeats that claim. However, Scan Machine consumes only `requestID` and `image` (`IdentifyEquipmentSheet.swift:102`), and Scan Food explicitly computes its own taller framing region from its capture snapshot (`FoodScanFlow.swift:587–595`). No caller reads `CapturedLabel.region`. The field at `LabelCameraView.swift:15`, its calculation at `:305`, and its fixture argument at `FoodScanFlow.swift:574` remain from the retired reader. This is missed removal cleanup exposed by the revised comment, not a camera behavior failure. **Suggested fix:** remove the unused payload field, its calculation, the now-unused `pending` box/view-size storage, and the fixture argument; describe the remaining capture payload accurately. Preserve Scan Food's independent region calculation and the shared `LabelFramingBox`/`LabelCrop` helpers. This addresses ticket 01's explicit no-dead-code acceptance and AGENTS' requirement that comments match callers. The ScanSteps and UI-test header corrections are accurate.

### Spec

Round-1 finding 2 is **resolved**. `docs/SPEC.md:30` now correctly describes signed-in requests through Stacked's server and the server-held provider key. Verified against `AIServerClient.request` (`AIServerClient.swift:56`), `TerraAccess.client` (`TerraAccess.swift:36`), the server's authenticated route and `proxyAI` (`server/src/ai.ts:652,666`), and normal-launch `LegacyOpenAIKey.purge()` (`WorkoutTrackerApp.swift:37`, `AIServerClient.swift:185`). No remaining Spec finding in the revised sentence.

Standards: **1 low-priority cleanup finding**; Spec: **0 remaining findings**. The remaining change request is the unused camera payload and inaccurate replacement comment above.

### Verification

- Inspected the complete round-2 diff and `git diff --check 74fbf76d..ec2faa8e` (exit **0**). All Swift changes in this revision are comments.
- Inspected the author's `build/logs/tf01-r2-build.log`: command is `xcodebuild build -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' -derivedDataPath build/dd`; the log ends with `** BUILD SUCCEEDED **`. Author-reported exit **0**; no separate exit-status file is present. No additional build was necessary for this documentation-only round.
- **No Unit, UI or server tests rerun**, as requested. Re-read actual prior xcresult summaries with `xcrun xcresulttool get test-results summary --path …` (each inspection exit **0**) and their original status files: Unit **1291/1291**, original exit **0**; primary UI **72/73**, original exit **65**, one failure and no skips; serial gym class **4/4**, exit **0**; extra editors **4/4**, exit **0**. Existing round-1 evidence remains applicable to unchanged executable code.

**Verified:** revised SPEC against actual request/key/purge code; two corrected comment locations; author build-success log; docs-only diff and whitespace check; prior test artifacts inspected.

**Not verified:** no new execution of tests this round; the live-device, manual-model-submit, undeployed-policy and post-merge CI limits recorded in round 1 remain unchanged.

**Known flaky:** the round-1 machine-name assertion failed once in parallel and passed in the serial class rerun; no new execution or causal claim this round.

Verdict: changes requested
