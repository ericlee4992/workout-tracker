# Codex release review — 0.2.0 (14)

Reviewed **2026-11-13** on `ericlee4992/release-0.2.0-14`, HEAD
`324a5ae5aca1c1b07f8906fde869f5557fef5fcb`, using `git diff 6dbaa303..HEAD`, the release record, DEVELOPMENT's
TestFlight checklist, and the build-13 review format. Starting checkout was clean. Separate standards/spec passes
completed. Evidence root: `/tmp/wt-r14-codex-review/`. Only this report changes; no archive, upload, deployment or push.

**Final report — release review clear. Independent build and Unit verification pass.**

## Standards

No findings. Parsed all **10/10** native-target/configuration pairs: app, widget, Watch, unit tests and UI tests,
each Debug/Release, all **CURRENT_PROJECT_VERSION 14**, **MARKETING_VERSION 0.2.0** (`versions.json`). No version
override was found in Config. Rebuilt simulator app, embedded/standalone widget, unit-test bundle and UI-test bundle
plists all report **0.2.0 (14)** (`binary-versions.json`). Watch configuration was checked; no Watch binary or Release
archive was built. The app's built `WTServerURL` remains `https://stacked-server.stacked-server.workers.dev`.

The release-only diff changes the ten build-number settings and adds the release record/brief. It does not alter
product behavior or tests. Diff whitespace and test-plan consistency checks pass.

## Spec

No findings. The user explicitly chose version 0.2.0 and no new What's New page for this update. The unchanged
`WhatsNew.entries` remains `[7, 12, 13]`; Profile still offers entry 13, “New: Korean foods”.

Executed a probe made from the current `WhatsNew.swift` at **currentBuild 14**, with isolated UserDefaults
(`WhatsNewProbe.swift`, `whatsnew-probe.log`, exit 0):

- last-seen nil/7/10/11/12 selects entry 13;
- last-seen 13/14 selects no entry;
- fresh onboarding shows no notes and records baseline 14;
- an active workout defers presentation without recording anything;
- marking entry 13 seen prevents repeat presentation, and the seen build never moves backwards.

The release record's build-12/build-13 wording describes the usual already-seen state. Strictly, the recorded
last-seen entry controls presentation: a build-13 user who never dismissed those notes can still see entry 13 on
build 14. That is existing behavior, consistent with “no new page for build 14”; no release blocker.

The What to Test draft matches the merged features: the live exercise's chart opens over the workout, available
last-time sets lead it, machine choices use recorded history, and bookmarks save log entries/items or scanned meals
to the stated destinations. Last time requires prior history, and All machines requires at least two machines with
eligible sets under the same load type/preset; the concise note reasonably omits these conditions.

Both feature implementation tips (`6b3912b3`, `e572db5a`) are ancestors of release base `6dbaa303`, and both final
independent reviews are clear. Inspected the changes since build 13 (`f6faa31f`): the intervening product changes
are the two reviewed tickets and their fixes. No additional release blocker was found. There are 15 commits in
that range including build 13's upload-record commit; the remaining 14 cover the subsequent work/release.

### Stored format / Gate S

**No additional Gate S for build 13 → 14.** Audited all changed app files, not just Models.swift/Nutrition.swift.
Model/schema-bearing paths are unchanged: `Models.swift`, `Nutrition.swift`, `Cardio.swift`,
`WorkoutSensorSample.swift`, and `ExportCollector.swift` (`schema-audit.json`). No persisted model, relationship,
schema registration or migration changes were introduced. The new chart equipment option is transient; existing
pin serialization remains unchanged. Food saving uses existing fields and relationships; the user explicitly kept
photo-item/meal content matching without new link fields. This finding is scoped to the build-13 baseline.

### Server

No changes under `server/` or `Config/` since build 13. No server deployment is required for these two features.
The simulator binary retains the production URL. No live deployment or signed-in server request was tested in this
release review; archive-time production URL and signing checks remain part of the later upload checklist.

## Verification

Xcode 27.2 (`27B52`). Simulator: WT-Redesign-2 `EB4328A1-87BD-4850-A3B2-A6E604701F1C`; prepared before build/tests. Derived data
`/tmp/wt-r14-codex`. Logs/exits/results `/tmp/wt-r14-codex-review/`.

| Check | Scope | Result |
|---|---|---|
| Build | `build-for-testing`, WorkoutTracker scheme, iOS Simulator | exit 0, `build.log` / `build.exit` |
| Unit | `test-without-building -testPlan Unit -parallel-testing-enabled NO` | **1370/1370**, no failures/skips, exit **0**, `unit.log` / `unit.exit` / `unit.xcresult` |
| Version/schema audits | Parsed project + built plists + baseline diff | passed, `versions.json`, `binary-versions.json`, `schema-audit.json` |
| What's New | Current source, explicit build 14, isolated defaults | exit 0, `whatsnew-probe.log` |
| Consistency | `git diff --check 6dbaa303..HEAD`; `python3 scripts/test-plans.py --check` | both passed |

Directly inspected existing xcresult summaries: author's release Unit **1370/1370**, N15 TodayTrain **72/72**,
live-workout HistoryProgress **46/46**, Workout **78/79**. The Workout failure is the already-reviewed 3-second
New Best band disappearance wait; both its passing independent reruns and timing analysis remain in the feature
review reports. No full UI repetition is justified by this release's metadata-only diff and unchanged notes.

Verified: independent build exit 0; all target/configuration and built-plist versions; no-new-schema/server audit;
Unit 1370/1370, exit 0 (`/tmp/wt-r14-codex-review/unit.xcresult`, summary inspected); What's New build-14 probe;
feature ancestry and existing area-plan results inspected.
Not verified: Release archive/signing; Watch binary; upload/processing; phone
              installation; live server requests; full UI suite this round.
Known flaky: `FloodlightLiveUITests.testMakingAFreshBestAWarmupTakesTheBandAway` — previously assessed automation
             timing, preserved in the live-workout ticket and review evidence; not rerun for this metadata change.

Standards: 0 findings. Spec: 0 findings. This clears the reviewed source and release metadata, not an archive or
upload that has not been performed. The later archive/upload checklist remains applicable.

Verdict: clear
