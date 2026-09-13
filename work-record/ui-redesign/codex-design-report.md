# Codex design — Ink / Amber

Scope: design system, active workout, and the optional Start screen. Built independently in `ericlee4992/ui-redesign-codex`, using only this worktree. No external dependencies. Implementation source commit: `0eeaf65`.

## Palette

| Token | Hex | Use |
| --- | --- | --- |
| AccentColor | `#FFB45E` | Amber actions, completion, progress, selection |
| OnAccent | `#15110B` | Dark text on amber |
| SurfaceBackground | `#0B0D10` | Ink screen background |
| SurfaceCard | `#171B21` | Graphite exercise and gym cards |
| SurfaceElevated | `#222831` | Rest dock |
| SurfaceFill | `#2B323C` | Fields and secondary buttons |
| Hairline | `#FFFFFF` at 7% | Quiet card outlines |
| TextPrimary | `#F6F3EC` | Warm white |
| TextSecondary | `#B5B9C2` | Supporting information |
| TextTertiary | `#7F8793` | Previous performance and table headings |
| Danger | `#FF6B76` | Heart rate and failure sets |
| Warmup | `#E9D875` | Warmup marker |
| Drop | `#B8A1EE` | Drop-set marker |
| UnitKg | `#97C7EE` | kg chip |
| UnitLb | `#A8CDBF` | lb chip |
| UnitMixed | `#B8A1EE` | Mixed-unit chip |

Muscle colours are categorical data, independent of the action accent: Chest `#F4939C`, Shoulders `#E6CF88`, Triceps `#C1A9EB`, Back `#8ABCE5`, Biceps `#A5B0F1`, Forearms `#A5B7C9`, Core `#80CABE`, Quads `#A5CF9A`, Hamstrings `#C8D595`, Glutes `#DDA7CB`, Calves `#9BCFBA`, Hips `#D4B395`, Neck `#B3ADC6`, Full Body `#F6F3EC`. Unknown groups use TextTertiary and a dumbbell symbol.

## Design choices

The direction pairs warm amber with slightly blue graphite surfaces. Large rounded elapsed-time figures create a clear focal point; quieter typography handles the equipment and previous performance. Cards have 24-point corners, inner controls 16-point corners, and fields 10-point corners. The surface changes and 1-point outlines define depth without shadows or blur.

The completed/total ring gives the header a second visual anchor. Heart rate sits in its own compact card with a coloured number, live heart symbol, calories, and the existing five-step zone meter. Every exercise starts with a muscle-group symbol in a tinted square.

Weight and its unit share a single input surface. In bar mode, the total appears inside that same surface below the plates input, retaining the existing `= 135 lb` caption and the history formula `45 + 45 × 2 = 135 lb`. PREVIOUS remains a single, subdued Text element. Presets move beneath the set rows immediately above Add Set, with a 44-point target height.

Completed sets get an amber numbered circle, amber checkmark, and a light amber wash on top of the opaque card background. The completion tick springs into place and triggers an impact haptic. The rest dock has an animated ring, large remaining time, and distinct +15s / Skip buttons. Completion and ring motion respect Reduce Motion. Rest-expiry feedback is triggered from the persistent workout screen, so removing the dock does not remove the feedback trigger.

The elapsed-time header contracts while the keyboard is visible. Screenshot testing exposed an overlap between the keyboard's Done toolbar and the taller bar-mode row; the compact header restores input space. Accessibility text sizes use stacked, labelled weight and reps controls, and move title actions below the full exercise name.

Start has a separate gym card, a full-width amber hero button, muscle icons on template cards, and an outlined resume card. Settings navigation remains in its current location because moving it belongs to a later ticket.

## Files

| File | Change |
| --- | --- |
| `Features/Design/Theme.swift` | Semantic colours, type, radius and spacing tokens; RGB initializer for muscle data |
| `Features/Design/MuscleGroupStyle.swift` | All 14 muscle styles, fallback, reusable MuscleIcon |
| `Features/Design/CardStyle.swift` | Standard/elevated card fills and hairlines |
| `Features/Design/Chip.swift` | Selected/neutral chips and exact-label unit chips |
| `Features/Design/StatTile.swift` | Reusable stat tile with combined accessibility label and identifier |
| `Features/Design/ProgressRing.swift` | Clamped progress, rounded stroke, reduced-motion support |
| `Features/Design/ButtonStyles.swift` | Primary and secondary styles, disabled/pressed states |
| `Features/Design/EmptyState.swift` | SF-Symbol illustration using caller-supplied existing copy |
| `Features/Design/Haptics.swift` | Set, rest and workout-start sensory presets |
| `Assets.xcassets` | Replaces teal AccentColor and adds semantic colour sets |
| `App/WorkoutTrackerApp.swift` | Forces dark appearance at the window root |
| `App/RootView.swift` | Applies the amber tint |
| `Features/ActiveWorkout/ActiveWorkoutView.swift` | Hero header, completion ring, background, action styles, keyboard compaction, rest-expiry feedback |
| `Features/ActiveWorkout/ExerciseEntryCard.swift` | Muscle icon, card/field styling, preset placement, unified bar input, completed row animation/haptic, accessible layout |
| `Features/ActiveWorkout/RestTimerBar.swift` | Elevated rest dock, ring, type and actions |
| `Features/ActiveWorkout/HeartRateBar.swift` | Card, heart-rate type/colour, shared zone chip retaining the meter |
| `Features/Start/StartWorkoutView.swift` | Gym, start, resume and template styling; UnitBadge delegates to UnitChip |
| `Features/History/HistoryView.swift` | Only the shared mixed-unit badge delegates to Chip |
| `WorkoutTrackerTests/ThemeTests.swift` | Catalog coverage and SF Symbol resolution |
| `WorkoutTrackerUITests/CodexScreenshotUITests.swift` | Real UI screenshot fixtures, fake heart-rate feed, barbell and large-text flows |
| `work-record/ui-redesign/tools/` | Repeatable class-by-class test runner and manifest-based PNG export |
| `.gitignore` | Keeps local result bundles and raw exports out of commits |

Paths beginning with `Features/`, `Assets.xcassets`, or `App/` are relative to `WorkoutTracker/`; test and effort paths are relative to the repository root. No domain model or persistence logic changed. The swipe gesture implementation, 88-point delete width, 14-point threshold, List, `.onMove`, and clear list row backgrounds remain. Existing accessibility identifiers and product copy are retained. The protected specification, decision, state and CLAUDE files were not edited.

## Verification

The final screenshot build passed **699 unit tests in 70 suites** and **3 screenshot tests** on iPhone 17 Pro / iOS 26.5, using the dedicated `WT-iPhone-Codex` simulator. The project continues to target iOS 26.0.

The first visual pass exposed a keyboard-toolbar overlap in bar mode; the real input flow failed twice before the compact-header fix and passed afterward. Large-text captures led to the stacked input layout. One simulator launch stalled and was interrupted; restarting only the Codex simulator restored normal testing. The final screenshot result bundle is `results/codex.xcresult`.

| Check | Tests | Result |
| --- | ---: | --- |
| WorkoutTrackerTests | 699 | Passed |
| CodexScreenshotUITests | 3 | Passed |
| BarbellUITests | 2 | Passed |
| ExercisePresetUITests | 2 | Passed |
| HeartRateUITests | 5 | Passed |
| WorkoutNameUITests | 2 | Passed |
| DumbbellCounterpartUITests | 1 | Passed |
| CoreLoopUITests | 9 | Passed |

**All 699 unit tests, 21 required UI regression tests, and 3 screenshot tests passed.** The first CoreLoop attempt received SIGTERM during its second test; the full class was rerun and all nine tests passed with zero failures.

Each UI class is run using its own `-only-testing:WorkoutTrackerUITests/<class>` invocation. Existing regression test classes were not changed. Haptic wiring compiles and completion flows are exercised; physical haptic feel requires an iPhone.

## Screenshots

The final PNGs were exported using `xcresulttool export attachments`, then copied by attachment name using the generated manifest. Each was visually inspected.

- [Root](screenshots/codex/codex-01-root.png)
- [Active workout](screenshots/codex/codex-02-active-workout.png)
- [Active workout with rest](screenshots/codex/codex-02-active-workout-rest.png)
- [Bar mode](screenshots/codex/codex-02-bar-mode.png)
- [Start with gym and template](screenshots/codex/codex-04-start.png)
- [Accessibility Large, scrolled to set controls](screenshots/codex/codex-02-accessibility.png)

Three additional initial-state comparison PNGs are in `screenshots/codex-before/`: root, Start, and active workout. The original baseline rest capture was obscured by a first-use notification prompt and is excluded from the review gallery. Final screenshot fixtures handle that prompt before capturing.

## Reproduce

```sh
xcodebuild test -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -destination 'platform=iOS Simulator,name=WT-iPhone-Codex' \
  -parallel-testing-enabled NO \
  -only-testing:WorkoutTrackerTests \
  -only-testing:WorkoutTrackerUITests/CodexScreenshotUITests \
  -resultBundlePath work-record/ui-redesign/results/codex.xcresult

xcrun xcresulttool export attachments \
  --path work-record/ui-redesign/results/codex.xcresult \
  --output-path work-record/ui-redesign/screenshots/codex-raw
python3 work-record/ui-redesign/tools/export-codex-screenshots.py
bash work-record/ui-redesign/tools/run-codex-gates.sh
```

Use fresh result-bundle paths when rerunning; Xcode will not overwrite an existing bundle.
