# Codex release review — Stacked 0.2.0 (15)

Reviewed `git diff d0b589f8..0bcbd5e6` on `ericlee4992/release-0.2.0-15`, HEAD `0bcbd5e6b9dda0a20b3a95286290496c92a455b0`, against DEVELOPMENT's TestFlight checklist steps 1–3 and `work-record/release/0.2.0-build-15.md`. No source/document changes other than this report; no commit, merge, deploy or archive performed.

## Standards

No blocking findings. All five targets—WorkoutTracker, WorkoutTrackerWidget, WorkoutTrackerWatch, WorkoutTrackerTests and WorkoutTrackerUITests—have **CURRENT_PROJECT_VERSION 15** and **MARKETING_VERSION 0.2.0** in both Debug and Release (**10/10 configurations**). Verified by parsing the project target → configuration mapping, not merely counting matching text. The independently built simulator app and embedded widget Info.plists also contain **0.2.0 (15)**.

## Spec and release record

1. **P3, nonblocking — describe the planned deployment in future tense.** `work-record/release/0.2.0-build-15.md:17–18` says “Deployed with the user's go,” while the evidence block correctly marks deployment unverified. Change this to “Deployment approved; planned after this branch's review,” then record the actual outcome after deployment. This is a wording inconsistency, not a production-state claim supported by this review. It does not block release clearance because the record's explicit verification section correctly leaves deploy/archive/upload pending. Refresh the pre-approval STATE handoff at the release checkpoint as well.

No other findings. The user-approved What to Test note matches the cleared behavior: one signed-in Scan Machine flow, manual catalog selection retained, Train's populated gym menu and empty-state Add Your Gym row, and the newly created gym selected/remembered. The choice of **no What's New** is recorded and consistent with the user's instructions.

The privacy page retains its earlier-build exercise-suggestion disclosure and the server still supports `model-exercises`; this client no longer exposes it. The machine-reader sentence and feature-list removals match ticket 01. The release branch changes only the approved effective date/comment in that page, to **November 15, 2026**. `npm run predeploy` passes; that is guard verification, **not deployment**.

Standards: **0 blocking findings**. Spec/record: **1 nonblocking P3 wording note**.

## Readiness and Gate S

- Both tester-feedback tickets' final reviews are clear (01 round 3; 02 round 4). Their reviewed commits `39e71a48` and `9fd6b713` are ancestors of release base `d0b589f8`; the release branch contains their merged implementations. The release record contains the user's approval of version/build, tester note, no What's New, and privacy wording/date.
- **No Gate S for the build-14 → build-15 update:** inspected `git diff 20634c0f..d0b589f8`, including changed-file inventory and startup changes. Models.swift, Nutrition.swift, StoreGate.swift, SafetyCopy.swift, BarWeightStoreRepair.swift and Config are unchanged; no model/schema/migration or stored-enum change appears elsewhere. The sole app-initializer change removes resetting an obsolete consent flag under UI-test reset. It does not rewrite phone preferences at normal launch. GymCreation writes existing model types only when the user adds a gym; it is not a migration or launch-time rewrite.
- The server delta since build 14 is privacy-page text only; no routes, D1 schema or migrations changed. Keeping the legacy endpoint avoids breaking installed older clients. The record's no-D1-export statement is consistent with server README's migration/risky-change backup scope for this page-only deploy.
- This is checklist steps **1–3** clearance. Production deployment, release archive/signing checks, upload, App Store Connect processing and phone verification remain future steps, with their own evidence required.

## Independent verification

Xcode **27.2 (27B52)**; WT-Floodlight, iOS 27.0, UDID `9E822EF6-DC67-4958-AEA2-D53D2D36D674`. Own derived data `build/dd-codex`. No UI tests run, as requested; the previously cleared ticket UI evidence is unchanged.

| Check | Exit | Result / evidence |
|---|---:|---|
| `scripts/prepare-test-simulator.sh` | 0 | Ready/booted |
| `git diff --check d0b589f8..0bcbd5e6` | 0 | Clean |
| Target/configuration version audit | 0 | All 10 settings 0.2.0 (15); built app/widget match |
| Independent `xcodebuild … build` | 0 | BUILD SUCCEEDED; `build/logs/codex-r15-build.log` |
| Independent Unit plan | 0 | **1297/1297**, 0 failed/skipped; `build/results/codex-r15-unit.xcresult` |
| `cd server && npm run predeploy` | 0 | Approved date passes guard; `build/logs/codex-r15-predeploy.log` |
| `cd server && npx vitest run` | 0 | **341/341**, 10 files; `build/logs/codex-r15-server.log` |
| `cd server && npm run typecheck` | 0 | Clean; `build/logs/codex-r15-typecheck.log` |

Actual process exits are in `build/logs/codex-r15-{build,unit,predeploy,server,typecheck}.status`. The independent Unit xcresult summary was read directly with `xcrun xcresulttool get test-results summary --path build/results/codex-r15-unit.xcresult` (inspection exit 0), and saved to `build/logs/codex-r15-unit-summary.json`. Also inspected the author's `build/results/r15-unit.xcresult`: **1297/1297**, 0 failed/skipped; inspection exit 0. The record's build/test counts are supported.

Exact independent simulator commands (runner `build/codex-r15-run.py`, PID **19553**, completed):

```sh
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' -derivedDataPath build/dd-codex build

xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' -derivedDataPath build/dd-codex test -testPlan Unit -parallel-testing-enabled NO -resultBundlePath build/results/codex-r15-unit.xcresult -collect-test-diagnostics never
```

**Verified:** release versions, build-14 schema/startup comparison and no-Gate-S rationale; notes/privacy against the cleared code; independent build, Unit **1297/1297**, server **341/341**, typecheck and predeploy, all exit **0**.

**Not verified:** deployment, archive, signing/production settings inside an archive, upload, App Store Connect, phone behavior; no UI tests rerun. No claim that build 15 is already distributed.

**Known flaky:** no failures observed in these runs. The prior gym-name and Ask AI goal-typing UI flakes remain historical and were not exercised this round.

Verdict: clear
