# 02 — Project surgery: iOS 26, HealthKit entitlement, watchOS target

Status: resolved
Blocked by: —

The structural change, isolated in one ticket so a mistake here is reviewable on its own. This is
the ticket that edits `project.pbxproj`, which T4 exists to avoid — adding a *target* leaves no
choice, so it is done with the `xcodeproj` gem (a dev-machine tool, installed 2026-08-22; it is
not a runtime dependency and nothing ships with it) rather than by hand.

## What to build

- `IPHONEOS_DEPLOYMENT_TARGET` 17.0 → **26.0** everywhere (D42), and SPEC's "iOS 17+" updated.
- `WorkoutTracker/WorkoutTracker.entitlements` with `com.apple.developer.healthkit`,
  `.access`, and `.background-delivery`, wired via `CODE_SIGN_ENTITLEMENTS` in
  `Config/Shared.xcconfig` — not hard-coded per-target, so the gitignored local config keeps
  owning per-developer signing.
- `INFOPLIST_KEY_NSHealthShareUsageDescription` / `...UpdateUsageDescription` as **build
  settings**, because this project generates its Info.plist — a missing usage string is a crash on
  first access, not a prompt (the same trap the camera hit; see STATE gotchas).
- A **watchOS app target** `WorkoutTrackerWatch`, bundle id `<base>.watchkitapp`, its own
  entitlements, and a shared scheme so `xcodebuild` can build it headlessly.
- Both targets share the domain sources they need. Prefer a shared *folder* over per-file
  membership so ticket 01's files stay buildable-folder-friendly (T4).

## Acceptance criteria

- [ ] `xcodebuild -list` shows the watch target and its scheme; the iOS app still builds for the
      simulator with no signing.
- [ ] A device build signs with the free personal team and the embedded profile carries all three
      HealthKit entitlements (the 2026-08-22 probe proved the team can; this proves the project
      does).
- [ ] The watch app builds for `watchsimulator` and for the device.
- [ ] `git diff project.pbxproj` is reviewable: no reordering churn, no file-reference deletions,
      no `IPHONEOS_DEPLOYMENT_TARGET` left at 17.
- [ ] The existing 362 unit + 14 UI tests still pass unchanged.
- [ ] `scripts/install-on-device.sh` still works, or is updated in the same ticket if the extra
      target breaks it.

## Notes

Free-account signing applies to the watch app too: **7-day expiry, and a second bundle id.** Free
accounts are limited to 10 App IDs per 7 days, so do not churn the watch bundle id casually.

## Progress (2026-08-22)

**Stage A — done and green.** Deployment target 17.0 → 26.0 across the project and all three
targets (D42); `Config/WorkoutTracker.entitlements` with all three HealthKit keys, wired via
`CODE_SIGN_ENTITLEMENTS` on the app target only (a project-level xcconfig would have applied it to
the test targets too); Health usage strings as `INFOPLIST_KEY_*` build settings, because this
project generates its Info.plist and a missing string is a crash rather than a prompt. 386 unit
tests still pass.

The entitlements file lives in `Config/`, **not** under `WorkoutTracker/` — that folder is a
buildable folder (T4), so a file placed there is swept into the target as a resource as well as
being read as entitlements.

The `xcodeproj` gem's diff was reviewed rather than trusted: it adds empty `exceptions = ()` to
each `PBXFileSystemSynchronizedRootGroup` and drops empty `packageProductDependencies = ()` from
each target. Both are cosmetic — no file references, groups or settings were lost.

**Stage B — written, reverted, and waiting on a download.** `add-watch-target.rb` (kept beside
this ticket) creates the watchOS target, its scheme, the shared `WatchLink.swift` compiled into
both targets, and the Embed Watch Content phase. It ran correctly and produced the target.

Then it broke the iOS build:

```
This scheme builds an embedded Apple Watch app.
watchOS 26.5 must be installed in order to run the scheme
```

**No watchOS platform SDK is installed on this Mac at all** — not just the simulator runtime. And
because the phone app now embeds and depends on the watch app, the phone app stopped building
entirely. That is a worse state than not having the target, so stage B was reverted to keep
`main`-line builds working, and `xcodebuild -downloadPlatform watchOS` was started.

**Stage B — resolved after the download.** `xcodebuild -downloadPlatform watchOS` pulled watchOS
26.5 (3.96 GB) and the script re-applied cleanly. It is idempotent from a clean `project.pbxproj`,
which is how it was re-run four times while the next three problems were found — each one only
visible *after* the previous was fixed:

1. **The product was named `.app`.** The gem does not set `PRODUCT_NAME`, and the build failed as
   `Multiple commands produce .../.app` — an error naming nothing useful. Fixed in the script with
   `PRODUCT_NAME = $(TARGET_NAME)`.
2. **No shared scheme.** `xcodebuild -scheme WorkoutTrackerWatch` synthesised one that pulled the
   companion iOS app in and tried to compile `Vision` and `CoreImage` for watchOS. It reads like a
   broken target; it is a missing scheme. The script now writes a shared scheme explicitly.
   (`-target` built fine throughout, which is what isolated it.)
3. **Embedding the watch app broke every test run.** With an "Embed Watch Content" phase, the iOS
   app refuses to install on a simulator with no *paired* watch:
   `_performCompanionWatchAppValidationForWatchApp` → `Unable to Install "WorkoutTracker"`. That
   killed the whole unit suite locally and would kill CI, whose runner pairs nothing. **The watch
   app is therefore not embedded**; `WKCompanionAppBundleIdentifier` still establishes the
   companion relationship. Cost: the watch app installs by building its own scheme, rather than
   riding along with the phone — a per-install chore for one developer, against breaking every
   test run for everyone.

Verified after the final apply: watch scheme builds for `watchsimulator`, iOS app builds, **386
unit tests pass**, and both schemes are shared.

Also worth knowing for whoever picks this up: the watch app cannot be meaningfully *run* without a
paired watch simulator, and a real optical sensor cannot be simulated at all (ticket 04).
