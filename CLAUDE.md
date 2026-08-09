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

# Test (unit tests in WorkoutTrackerTests/, Swift Testing; shared scheme has a TestAction)
xcodebuild test -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=WT-iPhone'
```

Device bootstrap: tests target the `WT-iPhone` simulator. If `xcrun simctl list devices`
shows no such device, create it first (any available iPhone device type / latest runtime works):
`xcrun simctl create WT-iPhone "iPhone 17 Pro"`. Alternatively substitute
`name=<first available iPhone>` from `xcrun simctl list devices`. Test files added under
`WorkoutTrackerTests/` auto-register via the synchronized folder — never edit `project.pbxproj`.

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
