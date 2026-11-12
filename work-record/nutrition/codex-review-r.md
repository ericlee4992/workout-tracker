# Release R independent review — round 1

Reviewed by Codex on 2026-11-11. Clean checkout on `ericlee4992/release-r`, HEAD
`7fa84cd9db4b3ab0c98beca93a2bc25da274145b`. Reviewed `3ad9dca..7fa84cd` and the complete proposed privacy/support page,
including `git diff 0191b3f 7fa84cd -- server/src/pages.ts` against the supplied live-policy baseline. Read AGENTS,
STATE, the release ticket, relevant decisions and the TestFlight checklist; applied the review/design/Swift guidance
and official OpenAI documentation for the retention check. Separate standards and spec passes completed.

This reviews release preparation, not completion of the release checklist. Only this report changes the checkout.
No commit, push, deployment, migration, upload, App Store Connect change, credential access or physical-phone install.

## Spec

### S1 — P3: Privacy/support directions still point to the retired Settings screen

`server/src/pages.ts:55,91,122,152,183,192–197`.

The pages tell users to reach exports, feedback, account deletion and permission controls through Settings. This
branch puts those entry points on Profile; the former settings screen is now Preferences. A reader following
“Settings → Send Feedback” or “Settings → Export” cannot follow the stated route, and the deletion instructions
refer to an account card that is on Profile, not Preferences.

Source: `Features/Settings/ProfileTabView.swift:56–64,186–194,223–226`,
`SettingsView.swift:21`, and `ExportBackupView.swift:47–55`.

**Fix:** update the Stacked directions consistently: Profile → Send Feedback; Profile → Ask AI; Profile → Export &
backup → Export; and Profile → the account card → Delete Account. Keep the separate **iOS Settings → Apple Account**
instruction for revoking Sign in with Apple—it refers to the operating system and is still appropriate.

### S2 — P3: Support says accounts are needed only for AI features

`server/src/pages.ts:193`.

That statement is no longer true after N8. Both online food search and barcode database lookup authenticate the
request (`server/src/index.ts:171–174,190–194`), and Scan food/search provide sign-in gates. A signed-out reader can
reasonably expect non-AI barcode/search access from the support text, then encounters a sign-in requirement.

**Fix:** include online food database features in the account requirement, while preserving the distinction that
local food logging and the core workout logger work without an account. Do not imply all food logging requires sign-in.

### S3 — P3: Export/deletion guidance omits the new nutrition data

`server/src/pages.ts:55–61`.

The export paragraph describes a file of workout data, but JSON now also contains food entries, saved foods/meals,
nutrition goals, body weights and associated personal fields, including height, date of birth and sex. A reader
preparing to share a “workout” JSON export is not told about those additional categories. The uninstall exception
also names only workouts saved to Apple Health, even though this release writes body-weight and food-nutrition samples
there too.

Source: `Domain/ExportCollector.swift:144–158,212–226,544–550` and
`Domain/HealthNutritionSync.swift:35–39,120–137`.

**Fix:** describe the JSON categories accurately and keep CSV's narrower sets/cardio scope explicit. Extend the Health
retention/deletion exception to data saved there, including workouts, body weight and food nutrition, so the new
Health writes are covered. Do **not** say meal-photo bytes are in JSON: `ExportSnapshot.swift:536–539` deliberately
exports item data/`hasPhoto`, not the image.

These are publication-copy corrections against the branch's behavior; no additional app defect is asserted.

## Standards

No additional P1/P2/P3 standards findings.

- Build 10's What's New title, four items and symbols match the approved ticket wording exactly. The approved What
  to Test text is preserved in the ticket. These texts contain no prohibited AI wording, and their claimed food,
  goals, body-weight/Health and Profile feedback paths exist on this branch.
- `WhatsNewTests` retains build 7's approved entry and checks the new build 10 entry. The existing decision tests
  retain the fresh-install, future-build, already-seen and active-workout gates.
- Inspected all six fresh What's New captures: light/dark at Default and AccessibilityL, with the two scrolled AXL
  views. All four items are readable; the fourth is wholly above Continue after scrolling, and Continue remains
  reachable. No layout finding.
- Inspected `docs/readme/today.png`: current dark Today layout, synthetic food/goals data, consistent with its alt
  text. README's nutrition/safety-copy “not yet in TestFlight” marks remain accurate. The server README describes the
  implemented N6/N8 routes. No screenshot or release-status finding is asserted.
- `WorkoutNameUITests.closeReceipt()` follows the established `HistoryEditingUITests` sequence: wait for the receipt's
  Done button, tap it, then require dismissal before navigating. It preserves both workout-name assertions and does
  not hide a failed dismissal. The author's failed rerun hierarchy still contains `finishedDone` and “Workout saved,”
  with Train selected, while the test is waiting for a History row; this supports the diagnosis that the receipt was
  still blocking navigation. Both corrected tests pass in the fresh reviewer run.

## Privacy and release-state assessment

The new processing descriptions otherwise match the traced code: meal/label images are re-encoded, food requests send
only the selected image/note or description, logged meal photos are locally owned and cascade-delete with their entry,
Health-derived weights are excluded from automatic training-profile prefill, and the server stores accounting metadata
rather than food-request contents. N8's shared cache, hashed query keys, daily counts and deletion/pruning paths match
the stated behavior. No additional content-logging defect was found.

`server/src/ai.ts:487` sends `store: false`. Official documentation distinguishes saved response state from default
abuse-monitoring retention, which can last up to 30 days and has policy exceptions. The draft already acknowledges
provider retention and links its policy; “normally up to 30 days, subject to that policy” would be a precision
improvement, not a separate finding here. [Official OpenAI data controls](https://developers.openai.com/api/docs/guides/your-data).

The food provider requests construct their own limited headers instead of forwarding incoming client headers. This
was checked against Cloudflare's current distinction between forwarded headers on external subrequests and cross-zone
Worker traffic; no contrary header-forwarding code was found. This is source/documentation review, not a deployed
network trace. [Cloudflare HTTP headers](https://developers.cloudflare.com/fundamentals/reference/http-headers/).

The effective date remains `[effective date]`, intentionally pending the user's approval. Running **only**
`npm run predeploy` confirmed that the placeholder guard refuses with **exit 1**; no deployment command ran.
The project still has build number **9** in all ten settings; the ticket explicitly leaves the bump to 10, archive,
upload and rollout pending. The What's New UI tests request the latest entry via their fixture flag; they do not
establish that a build-10 archive exists or is installed.

Privacy approval/date, D1 backup/migration/Worker secret and deployment, App Privacy confirmation, Gate S, version bump,
archive/upload and phone checks remain release steps. Their pending status is recorded, not treated as an unexpected
finding in this preparation review.

## Verification

Xcode **27.2**, WT-iPhone27 **`47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`**, iOS **27.0**. Prepared the simulator first,
built fresh into `/tmp/codex-r/dd`, ran Unit serially, then the three named UI classes with **two workers**.
Evidence root: **`/tmp/codex-r/`**; commands/process identity: `run.py`, `runner.pid/.log`, `tested-head.txt`,
`*.command.json`.

| Fresh reviewer check | Result | Evidence under the root |
|---|---|---|
| Build-for-testing | exit **0** | `build.log/.status` |
| Unit plan | **1,284/1,284**, no failures/skips, exit **0** | `unit.xcresult`, `unit-summary.json`, `unit.log/.status` |
| Named UI, two workers | **8/8**, no failures/skips, exit **0** | `ui.xcresult`, `ui-summary.json`, `ui.log/.status` |
| Test-plan consistency / diff whitespace | both exit **0** | `test-plans.log/.status`, `diff-check.log/.status` |
| Placeholder predeploy guard | expected refusal, exit **1** | `predeploy-guard.log/.status` |

UI breakdown: `AAAWarmUpUITests` **1/1**, `FloodlightWhatsNewUITests` **5/5**, `WorkoutNameUITests` **2/2**. No reviewer
failures required a serial rerun. Exported What's New captures and manifest are in `attachments/`. Representative pairs:
`40D3AC05-2E3B-4075-98F1-55A7DEEB56C1.png` / `3D70E168-6ACD-43A2-B933-649B12E3C6AD.png` (Default), and
`40EC2DCB-FCE8-4FAF-88DA-A625675471A3.png` / `4EA40B8E-61DA-4C11-A1F7-FECDFF0A1EC2.png` (AXL scrolled).

### Full-suite evidence inspected, not rerun

Read the supplied xcresults directly and saved summaries/test details as `author-*.json`:

| Author bundle | Observed result |
|---|---|
| `r-full.xcresult` | **381 passed, 3 failed, 2 skipped / 386** |
| `r-rerun.xcresult` | **2 passed, 1 failed / 3**, no skips |
| `r-name.xcresult` | **2/2 definitions passed**, **6 test executions** with repetition, no failures/skips |
| `r-wn.xcresult` | **13/13 passed**, no failures/skips (unit + UI scope) |

The full run and serial rerun fail the same old WorkoutName assertion at `:57`, waiting for a History row. The other
full-run failures are the completed-set edit (`102.` instead of `102.5`) and Create meal's second-serving assertion;
both pass in `r-rerun`. The receipt hierarchy inspected from the author's `rerun-att/` is preserved as
`author-name-failure-hierarchy.txt`; failure details are in `author-r-full-name-failure.json` and
`author-r-rerun-name-failure.json`. `r-name` verifies the subsequent test fix, and `r-wn` verifies the later new notes.
The full suite predates that notes addition; the focused fresh run covers both later changes.

The two skips are explicit opt-ins: `BackupExportUITests.testExportTheInstalledStoreAsJSON` (backup-tooling export)
and `FloodlightFeedbackUITests.testSmokeSendsToTheBuildsServer` (configured-server feedback smoke). Neither was run
against real data/a server here. The author logs contain the corresponding failed/succeeded completion markers;
separate numeric shell-exit files were not supplied, so their recorded exit numbers are not presented as independently
captured reviewer exits. The fresh reviewer commands above have exact captured exits.

Spec: **three P3 findings** (S1–S3). Standards: **no additional findings**. No P1/P2 findings.

Verified: fresh build exit **0**; Unit **1,284/1,284**, exit **0**, `/tmp/codex-r/unit.xcresult`; named UI **8/8**,
exit **0**, `/tmp/codex-r/ui.xcresult`; full-suite/follow-up bundles inspected with failures and skips retained;
fresh light/dark Default/AccessibilityL captures and README image inspected; consistency/diff checks exit **0**;
placeholder guard refused as expected, exit **1**.

Not verified: a new full-suite run; opt-in installed-store export or real-server feedback; physical-phone upgrade,
Gate S or Health permissions; live provider/Cloudflare account configuration or runtime outbound headers; current
billing/quotas; server deployment, App Privacy submission, archive, TestFlight upload or installed build 10. User privacy
approval and an effective date remain pending. Public documentation checks do not establish account-specific settings.

Known flaky: none observed in the fresh focused run. The author's parallel completed-set typing and Create meal
second-serving failures passed serially unchanged. The old WorkoutName failure was corrected in test synchronization
and passes both the repeated author run and the fresh reviewer run; its failed bundles remain preserved.

Verdict: not clear
