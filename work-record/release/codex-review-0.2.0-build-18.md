# Release review — Stacked 0.2.0 (18)

Independent Codex review, 2026-11-21. Branch `ericlee4992/release-0.2.0-18`, reviewed HEAD `5abb1bca62f5ef9407f50fdf8c76559f28205335`. Release diff: `08234d89..5abb1bca`; contents since build 17: `8812bfda..08234d89`. Followed the release brief, AGENTS.md, review-round rules, and testflight-release step 6. Only this report was edited by the reviewer.

## Findings

No actionable findings in the release diff or record.

## Checks

- **Versions:** parsed the Xcode project and checked all five targets (app, widget, Watch, unit tests, UI tests), both Debug and Release: all **10** `CURRENT_PROJECT_VERSION` settings are **18**, and all **10** `MARKETING_VERSION` settings remain **0.2.0**. The release project's only changes are the ten 17 → 18 replacements; no configuration override changes were introduced.
- **Contents:** the eleven changed app source files since `8812bfda` exactly match the release record's N16 list. No widget, Watch, Config, or server source changed. An exact tree diff from the previously cleared N16 fix commit `9b87bc23` through this release HEAD shows no changes to app, widget, Watch, configuration, server, or test source. The N16 clear verdict applies to these same sources; Git ancestry confirms the fix was included in `main` before this release branch. Other intervening changes are tooling, tests, documentation, and captures.
- **Stored format and launch:** models, schema-related guard/fingerprint tests, configuration, and app launch setup are unchanged since build 17. The approved fingerprint remains `016aa14c5d14bc707a3b7019c7c692484efd1560fd9889908774c9a8bd53c06b`. N16's picked day is view state; its changed writes happen on explicit logging actions. No new first-launch row/preference rewrite or migration was introduced.
- **Gate S:** no additional Gate S is required for the phone reported by the user to have build 17 installed, as explicitly recorded in the current release brief and record. This conclusion uses that newer user confirmation, rather than the older pending-install text still in pre-release STATE. It is not a general exemption for phones skipping the build-17 format change.
- **Server:** the diff under `server/` is empty; no deployment is required for this release.
- **Release wording:** the What to Test note matches the reviewed implementation: choose past days, show their food/workouts and dated goals, add/edit/delete food, return through today's ring, and navigate earlier weeks. The usual empty/no-goal state remains as documented in N16. “No What's New” is consistent with unchanged `WhatsNew.swift` and the user's choice. Archive/upload are correctly left pending, not claimed as completed.
- **Secrets/data:** manually inspected the two new release records for credentials and personal/tester content; no such content found. `scripts/check-secrets.sh --all` passed. The records contain release metadata and the installation premise needed for Gate S, not personal nutrition/Health data.
- **CI evidence:** independently fetched [Tests run 44868191869](https://github.com/ericlee4992/workout-tracker/actions/runs/44868191869): `completed`, `success`, on `main` SHA `08234d89969e8d9bf48d57f26c5ae4ecc570b910`, matching the release record. This supports, but does not replace, the local release checks.

## Verification

Ran `scripts/prepare-test-simulator.sh EB4328A1-87BD-4850-A3B2-A6E604701F1C` first, then independently built and selected the full Unit plan on **WT-Redesign-2**, using `-derivedDataPath /tmp/wt-r18-codex`. No competing author xcodebuild was running.

- Reviewer `xcodebuild build-for-testing -testPlan Unit`: **exit 0**, `/tmp/r18-codex-build.log` (Xcode 27.2, build 27B52).
- Reviewer `xcodebuild test-without-building -testPlan Unit -parallel-testing-enabled NO`: **1345/1345 passed, 0 failed, 0 skipped, exit 0**, `/tmp/r18-codex-unit.xcresult`, `/tmp/r18-codex-unit.log`. Read the completed xcresult summary and observed the actual process exit code; this is not a reuse of the author’s run.
- All-target/configuration version assertions: **exit 0**. Also read the built simulator app and its embedded widget Info.plists: both **0.2.0 (18)**; assertions exit 0. This verifies simulator products, not the as-yet-unmade distribution archive.
- `scripts/check-secrets.sh --all`: **exit 0**.
- `git diff --check 08234d89..HEAD`: **exit 0**.
- Inspected the author's completed `build/results/r18-unit.xcresult` via `xcresulttool`: **1345/1345 passed, 0 failed, 0 skipped**. The release record reports exit 0.
- UI tests are not rerun for this build-number/record-only release diff. The unchanged code was independently verified in N16 round two: TodayPickDayUITests + ScanFoodUITests **22/22, exit 0**, `/tmp/n16b-codex-ui.xcresult`; the broader author TodayTrain evidence is recorded in the N16 ticket.

Verified: independent build-for-testing exit 0; Unit plan 1345/1345, exit 0 (`/tmp/r18-codex-unit.xcresult`); all ten version/build settings and built app/widget Info.plists agree; secret scan and diff whitespace checks exit 0; author's Unit bundle and cited CI result independently inspected. HEAD stayed `5abb1bca62f5ef9407f50fdf8c76559f28205335` throughout verification.

Not verified: distribution archive, signing/export, upload, App Store Connect processing, physical-phone installation, and device-only Health/camera behavior. Those remain later release steps or recorded device checks. No phone, account, backup, deployment, merge, or upload action was performed during this review.

Known flaky: none seen in this review's build or Unit run.

Verdict: clear
