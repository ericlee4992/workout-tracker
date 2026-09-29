# 13 — Floodlight: release-candidate pass

Type: task (part of [01](01-implement-redesign.md), plan step 4; then step 5, the install)
Status: claimed — in progress
Implementer: Claude. Reviewer: Codex (for any code fix).
Branch: `ericlee4992/redesign-floodlight-cardio` (scratch checkout `/tmp/wt-floodlight/cardio`). Tested tip:
**`796ffe5`** (ticket 12, Codex clear; tickets 02–12 stacked beneath it, each Codex clear). Nothing merged to
`main` (`a0364f2`, an ancestor of the tip); nothing installed.

## Scope

DEVELOPMENT → *When to run the full UI suite*: **a major release candidate** — the whole-app Floodlight redesign
(tickets 02–12: every screen area, the Look tokens, `Theme` and `Legacy*` deleted, shared navigation, the live
workout lifecycle's views, the Live Activity). Targeted runs per ticket cannot bound the combined regression risk.

1. **Full unit suite** — `WorkoutTrackerTests` on `796ffe5`.
2. **Full UI suite** — `WorkoutTrackerUITests` on `796ffe5` (229 test methods at the start of the pass).
3. Each failure: rerun alone (and note the load); a failure that repeats alone is diagnosed; a code fix gets a
   focused test, then its affected checks, then a Codex review in a visible Orca terminal.
4. Default + AccessibilityL captures: already taken per ticket (`../captures/02/` … `../captures/12/`); this pass
   does not retake them unless a fix changes a screen.
5. Then the one install (ticket 01 step 5, DEVELOPMENT *Real-device installation* / *Provisioning expiry*):
   fresh full backup, signing renewal, install, launch, data-preservation check. **Blocked** until the user adds
   their Apple ID in Xcode → Settings → Accounts; app and widget profiles expired 2026-09-24. Ask the user
   before merging to `main` or touching the phone.

Known flakes under load (tickets 06–12): the Gyms model picker (CoreLoop), a typed value losing a character in
FloodlightLive, a launch that stayed on the Workout tab.

Not exercised by this pass (carried from tickets 08–12): VoiceOver by a person, Reduce Motion at runtime, real GPS
and sensors, a real device (the install covers launch and data only).

## Environment

Xcode 27.0 (27A266a). Simulator **WT-Floodlight** `9E822EF6-DC67-4958-AEA2-D53D2D36D674` (iOS 27). Runner
`/tmp/wt-floodlight/cardio-run.sh <name> build|test …` (derived data `/tmp/wt-floodlight/dd-cardio`); logs,
`.exit` files and result bundles `/tmp/wt-floodlight/results/rc-*`. Other sessions keep four more simulators
booted (WT-iPhone, WT-Redesign, -2, -3); load at the start: 23.6 / 21.4 / 15.8 on 10 cores, no other xcodebuild.

## Runs

| Run | Commit | What | Load at start | Exit | Result |
|---|---|---|---|---|---|
| `rc-build-1` | `796ffe5` code (`dfa8062`) | build-for-testing | 15.5 / 19.6 / 15.4 | 0 | TEST BUILD SUCCEEDED |
| `rc-unit-1` | same | `WorkoutTrackerTests` (whole target) | 14.2 / 19.2 / 15.3 | 0 | **919/919** passed, 0 failed, 0 skipped (xcresult summary); 94 s |

## Failures and causes

## Fixes

## Progress

- 2026-09-29: resumed from STATE (`1794867`) and tickets 01 / 12; branch map verified against `origin` (every
  ticket tip as STATE lists; the cardio checkout clean at `796ffe5`). Ticket opened.
