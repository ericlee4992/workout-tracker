# Codex release review — 0.2.0 (11)

Reviewed 2026-11-12 on `ericlee4992/release-0.2.0-11`, HEAD
`edb2ccb8dd10d1f40da060deebcc0d965e6cd0d5`, using `git diff 6dfbcb9f..HEAD` and
`work-record/release/0.2.0-build-11.md`. The checkout was clean at the start.

## Standards

### R11-1 — P3: Update active release documentation to the chosen version

`README.md:58,101`; active handoff in `docs/STATE.md:3,15–16`.

README still labels export v13 and goal setup “Coming in 0.2.1,” and STATE's current next action/Gate S wording also
names 0.2.1. The release record now explicitly schedules these changes for **0.2.0 (11)**. Readers and the next
session therefore receive conflicting release instructions. AGENTS requires README release-status changes on the
same branch and STATE to reflect current user decisions.

**Fix:** update the current README and STATE release references to the planned **0.2.0 (11)** release and its Gate S
requirement. Preserve historical 0.2.1 planning records as history; do not imply archive, upload or installation has
already completed.

## Spec / requested version audit

### R11-2 — P3: The Watch target does not meet the requested marketing-version check

`WorkoutTracker.xcodeproj/project.pbxproj:778,846`.

Both Watch configurations still have `MARKETING_VERSION = 1.0`, although their build numbers are now 11. The explicit
review request requires **0.2.0 everywhere, including Watch**, so that check does not pass. This is a **pre-existing**
marketing-version discrepancy, not a newly introduced iPhone regression. The Watch target is neither embedded in nor
a dependency of the iPhone scheme; consequently this discrepancy does not by itself block the iPhone archive.

**Fix:** set the Watch target's Debug and Release marketing versions to **0.2.0** to meet the requested all-target
release consistency.

### Version results

Parsed the project by target/configuration, rather than counting unassociated occurrences:

| Target | Debug build / version | Release build / version |
|---|---|---|
| WorkoutTracker | 11 / 0.2.0 | 11 / 0.2.0 |
| WorkoutTrackerWidget | 11 / 0.2.0 | 11 / 0.2.0 |
| WorkoutTrackerTests | 11 / 0.2.0 | 11 / 0.2.0 |
| WorkoutTrackerUITests | 11 / 0.2.0 | 11 / 0.2.0 |
| WorkoutTrackerWatch | 11 / **1.0** | 11 / **1.0** |

All ten `CURRENT_PROJECT_VERSION` settings are 11. Eight marketing-version settings are 0.2.0; the two exceptions
are identified above. The generated simulator app, widget and unit-test bundle plists also report **0.2.0 (11)**.
The Watch binary was not built. Audit output: `/tmp/codex-r11/versions.json`.

### What's New and tests

No behavior or approved-copy findings:

- At build 11, last-seen **10** selects entry 11. Dismissal calls `markSeen(11)` through the app's `onDismiss`, and
  subsequent launches suppress it. As before, quitting before dismissal can show it again.
- A fresh install records baseline **11** without presenting notes; after setup, last-seen 11 continues to suppress
  them. An active workout defers notes without marking them seen.
- A tester upgrading from **9 to 11** receives all eight items. All four build-10 strings survive byte-for-byte in
  entry 11, so replacing entry 10 loses none of that content. The entry's identity/title change is intentional, and
  manual What's New already displays the latest entry rather than a historical list.
- The new title and all four added strings exactly match the approved release record. The four prior lines match
  both the base source and the approved release-R record. The content test pins all eight items; the UI tests now
  assert eight rows and allow enough scrolling to bring the last row above Continue.
- Ran a temporary executable using the checked-in `WhatsNew.swift`, isolated UserDefaults and assertions for
  last-seen 9/10, dismissal to 11, fresh-install baseline and active-workout deferral. All passed:
  `/tmp/codex-r11/WhatsNewRepro.swift`, `whatsnew-repro`, `whatsnew-repro.log`. No repository tests were modified.

## Verification

Simulator preparation ran first on WT-Floodlight `9E822EF6-DC67-4958-AEA2-D53D2D36D674`.
Runner `/tmp/codex-r11/run.sh`, PID **94019**, completed; current source rebuilt in `/tmp/codex-n13/dd`.

- Independent `build-for-testing`: **exit 0**, `/tmp/codex-r11/build.log` and `build.status`.
- Independent **Unit** plan: **1326/1326**, no failures or skips, **exit 0**, `/tmp/codex-r11/unit.xcresult`.
  Inspected the actual status file and xcresult summary (`/tmp/codex-r11/unit-summary.json`).
- **Inspected the author's UI run; did not rerun**, as requested: `/tmp/r11-wn.xcresult` records
  `AAAWarmUpUITests` + `FloodlightWhatsNewUITests` **6/6**, no failures or skips. The log has
  `TEST EXECUTE SUCCEEDED`; the release record reports exit 0 (no standalone shell-status file was supplied).
  Summary retained at `/tmp/codex-r11/author-ui-summary.json`. Inspected `/tmp/r11-wn.png`: the eight items fit above
  Continue at default size, and the AccessibilityL captures show the upper and scrolled lower content legibly.
- Checked version settings, generated bundle versions, decision/dismissal callers, approved strings and
  `git diff --check`. No reason found to repeat the UI run.

Verified: independent build — exit 0; independent Unit — 1326/1326, exit 0, `/tmp/codex-r11/unit.xcresult`;
author UI artifact inspected — 6/6 passed, `/tmp/r11-wn.xcresult`; version/copy audit and temporary decision checks.

Not verified: Release archive/upload, App Store Connect processing, phone installation/Gate S, Watch binary,
independent UI rerun or full UI suite. Build 11's stored-format change still requires Gate S before phone installation.

Known flaky: none seen in the independent run or inspected UI result.

Standards: one P3 documentation finding. Requested version consistency: one P3 pre-existing Watch exception.
What's New behavior and copy: clear. Two consistency findings remain.

Verdict: not clear
