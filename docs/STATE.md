# Where the project is right now

Updated 2026-08-11. **Read this after `CLAUDE.md`** — SPEC and DECISIONS say what the product is
and why; this says what has actually happened and what to do next. Keep it current; it is the one
file that goes stale fastest.

## Status

Milestone 2 (core loop on SwiftData) is **complete and installed on the developer's iPhone**.
Tickets 01–21 are all resolved (`.scratch/milestone-2-core-loop/issues/`).

**Milestone 3 (CSV/JSON export) is built on branch `milestone-3-export`** — all three tickets
resolved (`.scratch/milestone-3-export/`), decisions D28–D32 recorded, and the Codex
cross-review (T6) is done: `.scratch/milestone-3-export/codex-review.md`, three high findings,
all real, all fixed on the branch (D30/D31 amended rather than reinterpreted). Suite:
**250 unit + 10 UI tests green**. The change is **uncommitted**, not merged, **and not on the
phone** — the install still runs `ce32158`, so the user cannot export their real data until a
reinstall happens.

The app is being **dogfooded in real gym sessions** — that is the current activity. Feedback from
those sessions outranks new features.

## The live install (facts you cannot rediscover from the code)

| Thing | Value |
|---|---|
| Installed commit | `ce32158` (2026-08-11) |
| iPhone UDID | `00008130-001E10C01E62001C` |
| Apple Team ID | `X68M8SR6NA` (already in `project.pbxproj`) |
| Signing | **Free** Apple account → builds expire **7 days**, so ~**17 Aug 2026** |
| Bundle ID | `com.ericlee4992.workouttracker` |
| Test simulator | `WT-iPhone` (create per CLAUDE.md if missing) |

**Reinstalling** (`./scripts/install-on-device.sh`, or build + `xcrun devicectl device install app`)
**preserves the user's data** — same bundle ID keeps the container. Say so before an install; the
user has real training data on that phone and **the export is not installed yet**, so it is still
the only copy.

## What to do next, in priority order

1. **Act on gym feedback.** Anything the user reports from a real session beats the backlog.
2. **Finish milestone 3**: commit and merge `milestone-3-export` (reviewed, green, awaiting the
   user's go-ahead), then **reinstall on the phone** — until that happens the export exists only
   in the repo, and the real training data still has no way off the device. That last step is the
   whole point of the milestone; do not treat it as done at merge.
3. Milestones 4–6: progress charts, Strong CSV import, plate calculator.

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
