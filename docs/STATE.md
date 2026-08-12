# Where the project is right now

Updated 2026-08-11. **Read this after `CLAUDE.md`** — SPEC and DECISIONS say what the product is
and why; this says what has actually happened and what to do next. Keep it current; it is the one
file that goes stale fastest.

## Status

Milestone 2 (core loop on SwiftData) is **complete and installed on the developer's iPhone**.
Tickets 01–21 are all resolved (`.scratch/milestone-2-core-loop/issues/`).

**Milestone 3 (CSV/JSON export) is merged to `main`** (`798372c`) — all three tickets resolved
(`.scratch/milestone-3-export/`), decisions D28–D32 recorded, Codex cross-review (T6) done
(`codex-review.md`: three high findings, all real, all fixed; D30/D31 amended rather than
reinterpreted). Suite: **250 unit + 10 UI tests green**. **Not on the phone yet** — the install
still runs `ce32158`, and the user deliberately deferred reinstalling until more features land,
so their training data still has no way off the device.

**Machine-label scanning is merged to `main`** (`64188e2`): photograph a
machine's name plate when adding a machine, and the app ranks the catalog against what Vision
reads and offers the matches for confirmation, or prefills a user-space model when nothing fits
(D33–D35, `.scratch/photo-machine-capture/`). **Two Codex cross-review rounds** (T6) found four
critical and several high-severity ways to preselect a *wrong* catalog UUID — all fixed, all
regression-tested against the shipped 1877-row catalog in `CatalogMatcherAdversarialTests`.
Suite: **296 unit + 12 UI tests**.

The app is being **dogfooded in real gym sessions** — that is the current activity. Feedback from
those sessions outranks new features.

## The live install (facts you cannot rediscover from the code)

| Thing | Value |
|---|---|
| Installed commit | `64188e2` (2026-08-11) — export **and** label scanning are on the phone |
| iPhone UDID | `00008130-001E10C01E62001C` |
| Apple Team ID | `X68M8SR6NA` (already in `project.pbxproj`) |
| Signing | **Free** Apple account → builds expire **7 days**, so ~**18 Aug 2026**. Each reinstall resets the clock |
| Bundle ID | `com.ericlee4992.workouttracker` |
| Test simulator | `WT-iPhone` (create per CLAUDE.md if missing) |

**Reinstalling** preserves the user's data — same bundle ID keeps the container. Say so before an
install; that phone holds the only copy of the training history until an export is saved off it.

The wizard (`./scripts/install-on-device.sh`) is interactive and meant for a human. With the
signing identity and Developer Mode already in place, the direct path is three commands:

```sh
xcrun devicectl list devices                      # confirm udid 00008130-…, transport, tunnel state
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -configuration Debug \
  -destination 'platform=iOS,id=00008130-001E10C01E62001C' -allowProvisioningUpdates \
  -derivedDataPath /tmp/wt-device-build build
xcrun devicectl device install app --device 00008130-001E10C01E62001C \
  /tmp/wt-device-build/Build/Products/Debug-iphoneos/WorkoutTracker.app
```

Gotchas seen doing exactly this on 2026-08-11: the phone pairs over **localNetwork**, and its
tunnel reads `disconnected` until something asks for it — the first install attempt died with
`NWError 60 - Operation timed out` and the identical retry succeeded. Do not conclude the phone is
unreachable from one timeout. `devicectl device process launch` additionally needs the phone
**unlocked**, and fails with `FBSOpenApplicationErrorDomain error 7` when it is not; that says
nothing about whether the install worked.

## What to do next, in priority order

1. **Act on gym feedback.** Anything the user reports from a real session beats the backlog.
2. **Finish machine-label scanning**: Codex cross-review (T6), then commit and merge
   `photo-machine-capture`. The matcher's thresholds (0.85 confident / 0.35 create-new) are tuned
   against the shipped catalog and rendered plates — no *photographs* have been through it yet, so
   expect to retune once the user has scanned a few real machines. Known conservative trade: a
   plate that does not name its manufacturer never preselects (95% of clean brand+model readings
   do; 0% of model-name-only readings), because a wrong model UUID splits history (D23).
3. **Ask whether the export actually works on real data.** Both features are now on the phone
   (`64188e2`) but neither has met the user's real gym: the export has never run over their full
   history, and the scanner has never seen a real name plate. Those two answers should shape what
   comes next more than the backlog does.
4. Milestones 4–6: progress charts, Strong CSV import, plate calculator.

## Decisions the user has NOT made yet

- **Apple Developer Program ($99/yr)** — needed for TestFlight, which is the only sane way to get
  the app to other testers and would also end the 7-day expiry. The user asked about it, weighed a
  free 2–3 family-member pilot first (possible, but every phone must be cabled to the Mac weekly).
  Prep work not started: app icon (**none exists** — App Store Connect rejects uploads without
  one), export-compliance key, upload script.
- **Catalog gaps worth closing** if the user hits them: Atlantis (dealer-sourced only), Titan and
  Sorinex (barely researched), Life Fitness Signature Series (discontinued but still on gym floors
  — the most commercially significant gap). See `docs/catalog-sources/README.md`.

## Environment gotchas that cost real time

- **Certificate chain.** Apple issues development certs from the WWDR **G3** intermediate. A Mac
  carrying only the original WWDR intermediate (expired 2023-02-07) reports "0 valid identities"
  and `codesign` fails with `errSecInternalComponent` — which reads as *no certificate* when the
  certificate is fine. Fix: install `AppleWWDRCAG3.cer`. Already done here; the install wizard now
  detects and repairs it.
- **Developer Mode** must be ON *and* confirmed after the phone restarts. `devicectl`'s
  `developerModeStatus` can report a stale `disabled` — attempt the build; it is authoritative.
- **Computer-use cannot drive this app.** Synthetic clicks reach the Simulator's UIKit tab bar but
  **not SwiftUI list buttons**. Use the XCUITest target (`WorkoutTrackerUITests/`) instead — that is
  why it exists.
- **UI tests take ~7 minutes** and occasionally flake under load. A single red run is not
  automatically a real failure; re-run the failing test alone before believing it.
- **The Simulator has no camera.** Anything camera-driven needs a fixture path to be testable at
  all — hence `-uiTestScanFixture`, which renders a name plate in place of the picker. And a
  missing `INFOPLIST_KEY_NSCameraUsageDescription` is a *crash* on presentation, not a prompt;
  the project generates its Info.plist, so usage strings live in build settings.
- **A `.sheet` attached to a `Section` inside a `List` never presents.** No error, no warning —
  the state flips and nothing happens. Hang presentation off a row *inside* the section. Cost an
  export that silently did nothing (milestone 3, ticket 02); caught only by the XCUITest.

## Working agreements learned the hard way

- **Verify independently.** Twice, an agent reported the suite green and an independent re-run
  failed — once a genuine race (`CONTINUATION MISUSE` from an unfiltered `didSave` observer,
  fixed in `ce32158`). Run the suite yourself before believing a summary.
- **Cross-review is not optional** (T6). Codex reviews of Claude's work have caught, among others:
  template data loss on an empty templated workout, D23 violations where history read live rows,
  and ten duplicate catalog identities that would have split the user's own history. Reviews live
  in `.scratch/milestone-*/codex-review*.md`. Milestone 3's pass caught an export that dropped a
  draft entry's equipment and a CRLF-quoting bug that would have corrupted the CSV — both invisible
  to a green suite.
- **Locked decisions get reopened deliberately** — D26 (drop sets) reopened D12 rather than drifting.
- The user prefers **seeing the UI** (screenshots from the simulator) over descriptions of it.
