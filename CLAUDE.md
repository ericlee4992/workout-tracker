# Workout Tracker — Agent & Contributor Guide

Private iPhone workout tracker (two developers). **Read `docs/SPEC.md` before making product-behavior changes; record decision changes in `docs/DECISIONS.md`.** Those files — not chat history — are the source of truth.

## Project layout

- `WorkoutTracker.xcodeproj` — Xcode project. Uses **buildable folders** (filesystem-synchronized groups): to add a source file, just create it under `WorkoutTracker/`; never edit `project.pbxproj` to register files.
- `WorkoutTracker/` — app sources.
  - `App/` — entry point, root navigation
  - `Domain/` — value types and (later) SwiftData models, pure logic
  - `Features/<Feature>/` — one folder per screen/feature (SwiftUI)
  - `SampleData/` — in-memory prototype data (milestone 1; removed when SwiftData lands)
- `docs/` — SPEC.md (product spec), DECISIONS.md (decision log)

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

# Prototype screenshots: launch env PROTO_SCREEN=start|active|history|gyms|exercises
# preselects a screen (milestone 1 only).
```

## Workflow

- Short-lived branches off `main`, small PRs, cross-review by the other developer's agent.
- Commits/PRs must not break `xcodebuild build`.
