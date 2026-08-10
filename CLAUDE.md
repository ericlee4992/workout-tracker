# Workout Tracker — Agent & Contributor Guide

Private iPhone workout tracker (solo developer, working with coding agents). **Read `docs/SPEC.md` before making product-behavior changes; record decision changes in `docs/DECISIONS.md`.** Those files — not chat history — are the source of truth: every agent session starts cold and loads context from them.

## Project layout

- `WorkoutTracker.xcodeproj` — Xcode project. Uses **buildable folders** (filesystem-synchronized groups): to add a source file, just create it under `WorkoutTracker/`; never edit `project.pbxproj` to register files.
- `WorkoutTracker/` — app sources.
  - `App/` — entry point, root navigation
  - `Domain/` — SwiftData models (`Models.swift`) plus value types and pure logic (units, records, rest timer, templates, drift, history), free of UI imports
  - `Features/<Feature>/` — one folder per screen/feature (SwiftUI): ActiveWorkout, Exercises, Gyms, History, Settings, Start, Templates
  - `Resources/` — `SeedCatalog.json`, the versioned seeded catalog (D24)
  - `Assets.xcassets` — app icon and colors
- `WorkoutTrackerTests/` — unit tests (Swift Testing)
- `WorkoutTrackerUITests/` — XCUITest UI tests (XCTest) that drive the app end to end. They launch with `-uiTestReset`, which makes the app open a throwaway store wiped at launch, so runs start from an empty database. Views expose `.accessibilityIdentifier`s (`startEmptyWorkout`, `addByMachine`, `gymPicker`, `finishWorkout`, `setRow.*`, …) for querying.
- `docs/` — SPEC.md (product spec), DECISIONS.md (decision log), `agents/` (agent skill docs)

## Conventions

- Swift 5 / SwiftUI, iOS 17+, iPhone-only, portrait. No third-party runtime dependencies.
- SwiftData models: CloudKit-compatible — UUID ids, optional relationships, **no** `@Attribute(.unique)`.
- Units: never convert silently. Stored weights keep `(value, unit)` as entered plus `normalizedKg`. Converted display values are marked (≈).
- PR/volume logic must respect exercise `loadType` (assisted: lower is better) and exclude warmups.
- Pure logic (unit math, PR computation, fallback selection) lives in `Domain/` free of UI imports, unit-tested.

## Build & run

```sh
# Build (simulator SDK, no signing)
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -sdk iphonesimulator -configuration Debug build

# Screenshot deep links: launch env PROTO_SCREEN=gyms|exercises preselects a tab.

# Test (WorkoutTrackerTests/ unit tests + WorkoutTrackerUITests/ XCUITests; shared scheme's
# TestAction runs both. Add -only-testing:WorkoutTrackerTests to skip the slow UI tests.)
xcodebuild test -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=WT-iPhone'
```

Simulator bootstrap: tests target the `WT-iPhone` simulator. If `xcrun simctl list devices`
shows no such device, create it first (any available iPhone device type / latest runtime works):
`xcrun simctl create WT-iPhone "iPhone 17 Pro"`. Alternatively substitute
`name=<first available iPhone>` from `xcrun simctl list devices`. Test files added under
`WorkoutTrackerTests/` auto-register via the synchronized folder — never edit `project.pbxproj`.

### Running on a real iPhone

```sh
./scripts/install-on-device.sh
```

Guided setup + install: attaches an Apple ID signing identity, writes
`DEVELOPMENT_TEAM` into the project, enables Developer Mode on the phone, then
builds, installs, and points at the trust step. Safe to re-run — every stage
detects work already done and skips it.

Re-run it whenever the build stops launching: a **free** Apple account signs
builds for **7 days only**. A paid Developer Program account lasts a year.
Bundle ID `com.ericlee4992.workouttracker` must stay globally unique across
Apple's system.

## Workflow

- Short-lived branches off `main`, small changes, **cross-reviewed by a different agent than the one that wrote them** (Claude ↔ Codex). Solo means no second pair of human eyes — the cross-review is the only independent check, so don't skip it on load-bearing work.
- Commits/PRs must not break `xcodebuild build`.

## Agent skills

### Issue tracker

Local markdown under `.scratch/` — no GitHub remote is configured yet. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five canonical roles (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`), unchanged. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context — `CONTEXT.md` and `docs/adr/` at the repo root (created lazily by `/domain-modeling` as terms/decisions resolve). See `docs/agents/domain.md`.
