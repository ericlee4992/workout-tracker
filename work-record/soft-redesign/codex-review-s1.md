# S1 independent review — Soft look app-wide

Reviewed 2026-11-07 by Codex. Implementation: Claude.

## Scope and checkout

- Requested diff: `git diff fc2390c..44043c5` (38 files); implementation commits `75460c2` and `44043c5`.
- Branch: `ericlee4992/soft-01-look`. Tested HEAD: `ff371681c10db2a8469d5e5b212ff898c8c1eb83`; its only addition beyond `44043c5` is `work-record/soft-redesign/codex-review-s1-prompt.md`. App, widget and tests therefore match the requested implementation tip.
- Working tree was clean at review start. Only this report was added; no implementation edits, commits or pushes.
- Read AGENTS, S1 ticket, Soft spec, D59/D67 including the icon/grey amendment, and DEVELOPMENT verification guidance. Compared the approved tag `design/soft-approved-2026-11-07` Soft tokens, font roles, surface branches, live-look construction and Mono accent. Earlier design proposals were not treated as requirements. The ios-design skill was not used.

## Findings

No actionable P1, P2 or P3 findings in the reviewed diff. This is clearance for the requested source/build/unit-test review, not a claim that the deferred visual and core-flow acceptance has been completed.

## Standards

No documented-standard violations identified in the changed code. Mechanical font changes preserve expressions, control flow, strings and accessibility identifiers. Domain files and `StoreFormatGuardTests.swift` are unchanged. The `WorkoutActivityContent` look substitution retains the same structural `.floodlight` id and formatting behavior.

Source searches found no remaining Expanded, Black, serif or rounded font declarations or old violet action literals in app/widget source. Remaining `.heavy` occurrences do not reintroduce Expanded/Black faces; most style SF Symbols, with isolated existing compact labels. No unrelated modernization or file splitting is required for S1.

Checked Mono foreground/background use in shared buttons, rest controls, settings switches, native-list tint and widget controls. They use corresponding `onAction`, `onLive`, `onDone` or inverse foregrounds rather than retaining violet-era fixed text colours. AccentColor has both appearance variants.

## Spec

No material spec violation identified. Soft grounds, surfaces, font roles, radii/spacing, light lifted cards and warm wash match the prototype; deeper secondary/tertiary greys are explicitly authorized by D67. Muscle-family colours/assets, heart-rate and destructive colours, and the live yellow highlighter remain. Screen/navigation restructuring from later tickets was not imported.

The rest-slab path is correctly bounded:

- `FinalLook.swift:133` provides the flood `liveOnSlabOverride` for live lifting.
- `LiveWorkoutPieces.swift:399` and `LivePieces.swift:859` set slab context for Paper/Carbon.
- `Rings.swift:269–278` chooses `liveOnSlab` only in Paper/Carbon slab context; `.floodlight` retains its normal live/done colours.
- `LivePieces.swift:901–908` changes Skip's action and on-action only for Paper/Carbon with the override. +15s uses the existing inverse foreground. Time, next-set text and the best band use slab foregrounds. The light `.floodlight` glass bar does not receive the inverse override.

Inspected all three app-icon PNGs with the image viewer. Default is ink/grey on white; Dark is flood/grey with alpha; Tinted remains unchanged from the base. `sips` confirms all three are 1024×1024, Default without alpha and Dark/Tinted with alpha. Renderer geometry is unchanged and its palette agrees with D67 and the catalog filenames. A supplemental in-memory pixel-reproduction check could not run because the default Python lacks Pillow; no package was installed and no icon was regenerated.

## Nonblocking observations and coverage limits

- **Contrast helper:** `SoftLookContrastTests.swift:11–18` reads RGB via `UIColor.getRed`, ignores the returned success flag and does not composite alpha. The colour pairs currently passed to `contrast` are opaque, so this does not invalidate those passing measurements; the transparent shadow is tested separately via alpha. Future translucent-pair coverage should assert successful colour resolution and composite over an explicit background before computing luminance.
- **Rendered contrast remains to be checked:** `SoftLookContrastTests.swift:29–34` covers flat ground/surface/raised colours, not the radial wash, translucent glass, pressed states or every consumer. For example, the theoretical maximum warm wash over light ground produces approximately 4.44:1 against tertiary `#6C6C72`; this is not evidence of a particular rendered text failure because actual gradient coverage and text placement matter. Check those locations during the deferred light captures rather than treating these tests as proof of universal contrast. The test named `softUsesNoExpandedOrVioletTokens` checks colour neutrality, not font descriptors; the font check here was source inspection.
- **Tiny prototype-literal difference:** `FinalLook.swift:128–135` uses Soft's `#111114` / `#F5F5F7` actions with dark `#000000` on-action, whereas the prototype's live Mono adapter uses `#0B0C0E` / `#F4F6F8` with dark `#060708` on-action. Both preserve the approved Mono appearance and strong contrast; this is not a material visual defect.
- **Existing build warnings:** the successful build reports 14 warnings and zero errors. They concern untouched statements (including widget `Text` concatenation, a Google sign-in initializer, imports, preview unused results and concurrency diagnostics). Modernization belongs outside this styling diff.
- STATE and the ticket/spec opening statuses still describe proposed/no-code work; the ticket's Progress section and Git show implementation. Refresh the handoff when recording this review and the deferred verification. No merge/install status was inferred from those stale headers.

## Independent verification

Xcode **27.2 (27B52)**. Destination **WT-iPhone27**, `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`, iPhone 15 Pro Max, iOS Simulator **27.0 (24A434)**. WT-Floodlight was not used.

| Check | Exit / result | Evidence |
|---|---|---|
| Initial sandboxed build | Exit **70**; CoreSimulator service unavailable inside sandbox, not a source compilation failure | `/tmp/codex-s1/build.log`, `/tmp/codex-s1/build.xcresult` |
| Build rerun outside sandbox | Exit **0**, `BUILD SUCCEEDED`; xcresult build status `succeeded`, **0 errors**, **14 warnings** | `/tmp/codex-s1/build-retry.log`, `/tmp/codex-s1/build-retry.xcresult` |
| Three requested unit suites, serial | Exit **0**, `TEST SUCCEEDED`; summary **10 passed / 0 failed / 0 skipped** | `/tmp/codex-s1/targeted.log`, `/tmp/codex-s1/targeted.xcresult` |
| Diff whitespace check | Exit **0** | `git diff --check fc2390c..44043c5` |

Test breakdown: `SoftLookContrastTests` **4 test functions** (three parameterized over two values, **7 executions**), `MuscleMapAssetTests` **2**, `StoreFormatGuardTests` **4**. The xcresult top-level total is **10 tests**; its device count is **13 executions**, reflecting parameterized cases. All passed. Results were read directly using `xcresulttool get test-results summary` and `get test-results tests`, not inferred from the implementer's report.

Commands (build/test logs were redirected to the paths above):

```sh
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,id=47D21838-69A6-4BCB-AE90-B0D9C0AAA70B' \
  -derivedDataPath /tmp/codex-s1/DerivedData \
  -resultBundlePath /tmp/codex-s1/build-retry.xcresult build

xcodebuild test -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,id=47D21838-69A6-4BCB-AE90-B0D9C0AAA70B' \
  -derivedDataPath /tmp/codex-s1/DerivedData \
  -resultBundlePath /tmp/codex-s1/targeted.xcresult \
  -parallel-testing-enabled NO \
  -only-testing:WorkoutTrackerTests/SoftLookContrastTests \
  -only-testing:WorkoutTrackerTests/MuscleMapAssetTests \
  -only-testing:WorkoutTrackerTests/StoreFormatGuardTests
```

## Deferred acceptance

Skipped capture suites and core-flow UI tests as explicitly requested. Before S1 merges, the ticket still requires the combined Phase 1 run and review of real default/AccessibilityL captures in light and dark: `Floodlight*UITests`, `RedesignScreenshotUITests`, `CodexScreenshotUITests`, plus CoreLoop, Cardio, History edit, Templates and Settings flows. Relevant existing classes include `CoreLoopUITests`, `CardioUITests`, `HistoryEditingUITests`, `HistoryEditFlowsUITests`, `HistoryTemplateUITests`, `TemplateDetailUITests`, `TemplateMachinesUITests` and `FloodlightSettingsUITests`. Include live rest/Skip and new-best states in both appearances, large-text set rows, native sheets/menus/toggles, and the activity gallery. This review neither runs those suites nor waives their merge gate. No device installation or new screen captures were performed.

Standards: **0 actionable findings**. Spec: **0 material findings**. Deferred visual/core-flow verification remains open.

Verdict: clear
