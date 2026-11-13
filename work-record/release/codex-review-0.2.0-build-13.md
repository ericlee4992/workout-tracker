# Codex release review — 0.2.0 (13)

Reviewed **2026-11-13** on `ericlee4992/release-0.2.0-13`, implementation HEAD
`4304004c0da5d0460f321bb9ccaaa287b2e3576e`, using `git diff 92d77be0..4304004c`, the release record, DEVELOPMENT's
TestFlight checklist and the build-12 review format. Starting checkout was clean. Separate standards/spec passes
completed. Evidence root: `/tmp/codex-r13/`. Only this report changes; no archive, upload, deployment or push to main.

## Standards

No findings. All **10/10** native-target/configuration pairs have **CURRENT_PROJECT_VERSION 13** and
**MARKETING_VERSION 0.2.0**: app, widget, Watch, unit tests and UI tests, each Debug/Release. Parsed audit in
`versions.json`. No version override was found in Config. The rebuilt simulator app, widget, unit-test bundle and
UI-test bundle plists also report **0.2.0 (13)** (`binary-versions.json`). Watch configuration was checked; no Watch
binary or Release archive was built.

The tests add build 13 while retaining assertions for the older entries. UI checks still require reachable Continue,
the complete last item above it, dismissal, reopening from Profile, and no automatic sheet in ordinary UI-test
launches. The changed item count reflects the approved two-item page; it does not weaken its visibility assertion.

## Spec

No findings. The title **New: Korean foods** and both lines match the user-approved release record exactly. Build
12's entry remains unchanged. The user explicitly chose a separate small page knowing that only the newest unseen
entry appears; showing build 13 alone to someone updating from build 11 or earlier is therefore intentional.

Executed a temporary probe using the current `WhatsNew.swift` and isolated UserDefaults
(`WhatsNewRepro.swift`, `whatsnew-repro.log`, exit **0**): last-seen nil/7/10/11/12 with installed build 13 selects
entry 13; last-seen 13 selects nothing; a fresh install records baseline 13 without notes; an active workout defers
without recording; dismissal at 13 prevents repeat presentation. The app's unchanged on-dismiss caller records the
shown entry's build.

The approved **What to Test** note describes actual N12 behavior: Korean queries use MFDS, Korean barcode lookups
have additional sources, candidates can be confirmed, and logging the choice links it to the barcode. Missing-macro
notes use source metadata when a found result is opened. The existing limits still apply: online lookup requires
sign-in; candidates require a source-provided name and matching results; later local reopening intentionally has no
missing-macro note under amended D86. The concise wording is not a guarantee that every barcode resolves.

### Stored format / Gate S

**No additional Gate S for build 12 → 13.** Audited `f56bf476..HEAD`: only FoodDatabase, WhatsNew and the four food
UI/access files change within the app. All model/schema-bearing source paths are unchanged, including `Models.swift`,
`Nutrition.swift`, `WorkoutSensorSample.swift` and `Cardio.swift`; export collection is unchanged too
(`schema-audit.json`). No persisted model/enum, migration or schema-registration change was introduced. The note is
transient, with no side-store writes. This does not waive Gate S for users still upgrading across an earlier
stored-format change from an older build.

### Production server

The freshly built app's `WTServerURL` is **`https://stacked-server.stacked-server.workers.dev`**, matching
`Config/Shared.xcconfig`. Read-only Cloudflare inspection independently confirms latest deployment
`ea415e2c-d712-4bd4-b467-cc20e3f8fd99`, created **2026-11-13 06:26:42 UTC**, routes **100%** to version
**`16f93322-b3ee-4ee7-9ef9-ccf404a61bc6`**, matching the release record.

`wrangler deployments list --json` and `wrangler versions view 16f93322-b3ee-4ee7-9ef9-ccf404a61bc6 --json` both
exited **0**. Version metadata confirms `MFDS_API_KEY`, `FOODSAFETY_API_KEY` and `USDA_API_KEY` are `secret_text`
bindings. Only names/types were inspected for this check; no secret values were printed or changed. Evidence:
`deployments.json`, `worker-version.json`, `deployment-audit.json`.

Public read-only requests also succeeded: `/v1/health` returns `{"ok":true}` and `/privacy` includes **November 13,
2026** and the Korean ministry/source wording (`health.json`, `privacy.html`, curl exits **0**). This establishes
deployment/configuration and public reachability; a signed-in Korean search/barcode through the deployed route is
still a phone/live acceptance step, not claimed here. Archive-time signing and `WTServerURL` verification remain
part of the later TestFlight checklist.

## Verification

Xcode 27.2; simulator WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`, iOS 27.0. Prepared before the first run,
built the changed app/test sources into `/tmp/codex-n12-r1/dd`, then ran the requested named unit/UI scopes. The
workspace's existing Test progress terminal was reused. All requested cases have passing evidence across the initial
run and unchanged serial rerun; the original parallel failure remains recorded below.

| Check | Command / scope | Result |
|---|---|---|
| Simulator | `scripts/prepare-test-simulator.sh 47D21838-69A6-4BCB-AE90-B0D9C0AAA70B` | exit **0**, `prepare.log` |
| Build | `xcodebuild build-for-testing -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=47D21838-69A6-4BCB-AE90-B0D9C0AAA70B' -derivedDataPath /tmp/codex-n12-r1/dd` | exit **0**, `build.log` |
| Unit | `test-without-building`, same project/scheme/destination/derived data, `-only-testing:WorkoutTrackerTests/WhatsNewTests -parallel-testing-enabled NO -resultBundlePath /tmp/codex-r13/unit.xcresult` | **8/8**, no failures/skips, exit **0**, `unit-summary.json` |
| UI | Same test base, `-only-testing:WorkoutTrackerUITests/AAAWarmUpUITests -only-testing:WorkoutTrackerUITests/FloodlightWhatsNewUITests -parallel-testing-enabled YES -maximum-concurrent-test-simulator-destinations 2 -parallel-testing-worker-count 2 -resultBundlePath /tmp/codex-r13/ui.xcresult` | **5/6**, 1 failure, no skips, exit **65**, `ui.log`, `ui-summary.json` |
| Affected UI capture, serial | Prepared simulator again; same test base with `-only-testing:WorkoutTrackerUITests/AAAWarmUpUITests -only-testing:WorkoutTrackerUITests/FloodlightWhatsNewUITests/testCaptureDarkAccessibility -parallel-testing-enabled NO -resultBundlePath /tmp/codex-r13/ui-serial.xcresult` | **2/2**, no failures/skips, exit **0**, `ui-serial.log`, `ui-serial-summary.json`; unchanged source/binary |
| Consistency | `git diff --check 92d77be0..HEAD`; `python3 scripts/test-plans.py --check` | both exit **0** |
| Audits / gate probe | Parsed project/plists/model diff; `swift /tmp/codex-r13/WhatsNewRepro.swift` | exit **0** |

The initial failure was `FloodlightWhatsNewUITests.testCaptureDarkAccessibility` at line **37**, waiting for
`whatsNewSheet` to exist after launch. It happened before the title/layout assertions or screenshot. The warm-up,
other three capture cases, and Continue → Profile → reopen → ordinary-launch case passed. The failed capture passed
with warm-up in the serial rerun. `ui-failure.json` preserves the original details. This supports an intermittent
launch/presentation failure, not a demonstrated copy/layout defect; its precise cause was not diagnosed here.

Exported both bundles' attachments (exit **0**) into `attachments/` and `serial-attachments/`. Inspected all **six**
What's New PNGs: light/dark Default plus each AccessibilityL initial/scrolled pair. The title and both approved items
are whole at both sizes, including the Korean examples; the final item sits above Continue, which remains reachable.
No layout finding. Manifest files map readable capture names to PNG IDs. The `whatsnew-14` filename prefix is the
historical ticket name; the displayed content and built metadata are build **13**.

Verified: independent build and WhatsNewTests 8/8, exit 0 (`unit.xcresult`); version consistency, exact approved copy,
gating probe and no-new-schema audit; live Worker deployment/bindings metadata and public health/privacy checks;
UI 5/6, exit 65 (`ui.xcresult`), then 2/2, exit 0 (`ui-serial.xcresult`), with all six distinct requested cases covered;
all light/dark Default/AccessibilityL captures inspected. Evidence `/tmp/codex-r13/`.

Not verified: Release archive, signing, upload, App Store Connect processing, Watch binary, phone installation,
signed-in Korean requests through the deployed route, full Unit/UI suites; root cause of the initial UI timeout.

Known flaky: the dark AccessibilityL capture's initial sheet-appearance timeout passed unchanged serially. Preserve
both bundles; launch-instability follow-up is dev-speed 02, although a shared cause with its scan-entry cases is not
established. Those N12 scan cases were not rerun for this release-copy change.

Standards: 0 findings. Spec: 0 findings.

Verdict: clear
