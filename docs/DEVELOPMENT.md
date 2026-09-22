# Development and troubleshooting

Read this for build, test, simulator, device-install, or environment work. Current installed
commit, expiry, and backup facts are in [STATE](STATE.md). Historical incidents and their
original evidence are preserved in the [archive](archive/README.md).

## Verification scope

User-approved 2026-09-20 (T8): choose verification by the changed behavior and its callers.
For new work, this policy supersedes older blanket full-suite gates; past test evidence remains
historical. The implementer selects the smallest set that covers the change and directly affected
flows, records the rationale and named tests in the ticket, and runs them before merge. The
independent reviewer checks whether that scope covers the impact. Routine scope selection does
not need separate user approval.

| Change | Default checks |
|---|---|
| Text, icons, spacing or layout within one screen | Successful build, affected UI flows, real default/AccessibilityL captures of the changed screen |
| Logic, calculations or unit conversions | Relevant unit/integration tests; affected UI flows where the behavior is exposed |
| New feature | Feature tests plus adjacent integration flows and relevant domain tests; captures for changed screens |
| Shared navigation, workout lifecycle, persistence or broad refactoring | Trace affected callers and run broader relevant suites; escalate to full UI when targeted coverage cannot bound the regression risk |
| Documentation, agent rules or skill instructions only | Links, consistency and archive preservation; no app build or app tests |

### When to run the full UI suite

Run it for a major release candidate, broad/uncertain changes whose impact spans core flows and
cannot be covered confidently by targeted checks, or an explicit user request. Also use it for
planned periodic regression checks at stable checkpoints. A routine edit, a new source file,
starting another task, merging, or installing on the personal phone is not itself a trigger.
Record the release, risk or periodic-check reason when selecting a full run; no recurring job
is implied by this policy.

After a failure, reproduce with the focused case and test the fix there first. Re-run affected
checks after subsequent changes; broaden or repeat suites when new failures, wider impact or
unresolved concerns justify it. A docs/evidence-only commit can reuse unchanged tested code's
results. Once the selected checks and independent review are clear, proceed to merge/delivery.

A passing scope means actual successful exits and result summaries, with skipped tests and
untested hardware behavior stated honestly. Successful builds for code changes, independent
review (T6), migration/data-preservation tests where applicable, and DEVELOPMENT's backup,
signing, fresh-binary and launch checks for installation remain required.

## Build and test

Check `xcodebuild -version` when beginning environment work. Simulator builds need no local
signing setup. Device builds use the gitignored `Config/Local.xcconfig`, copied from
`Config/Local.xcconfig.example` with the developer's own team ID and bundle-ID prefix.

```sh
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -sdk iphonesimulator -configuration Debug build

xcodebuild test -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=WT-iPhone' \
  -only-testing:WorkoutTrackerTests

xcodebuild test -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=WT-iPhone' \
  -only-testing:WorkoutTrackerUITests
```

For targeted checks, narrow `-only-testing` to `WorkoutTrackerTests/<Suite>` or
`WorkoutTrackerUITests/<Class>/<testMethod>`, using names from the actual tests. The commands
above show whole-target runs for when that scope is selected. The shared scheme includes both
targets; omitting `-only-testing` runs both and should be deliberate. Source and test
files auto-register through Xcode's synchronized folders. If `WT-iPhone` is absent, inspect
`xcrun simctl list devices available` and available device types/runtimes; create an available
iPhone (for example `xcrun simctl create WT-iPhone 'iPhone 17 Pro'`) or use an existing one.
Screenshot launch environment `PROTO_SCREEN=gyms|exercises` selects the corresponding tab.

The full UI suite took about 51 minutes for 85 tests on 2026-09-20. Launch long tests detached
so a tool timeout does not kill them. Write a script with the complete command, redirect its
output, and append the actual exit code to a status file. Launch it via Python
`subprocess.Popen([script_path], start_new_session=True, stdin=subprocess.DEVNULL,
stdout=log_handle, stderr=subprocess.STDOUT)`; macOS has no `setsid` executable. Use a unique
`-resultBundlePath` for each run. Poll with short foreground waits. Preserve the script, PID,
tested commit, log, and result path in the ticket if handing off mid-run.

Read `** TEST SUCCEEDED **`, the actual exit status, and the summary from
`xcrun xcresulttool get test-results summary --path <result.xcresult>`. A piped `grep` exit 0
does not establish that `xcodebuild` succeeded. A missing shell continuation once turned a
focused run into the entire suite. Avoid broad `pkill` patterns that can kill another run.

Run suites serially on a simulator. Two historical heart-rate tests used to flake under
load due to wall-clock staleness; cardio ticket 06 now injects fixed clocks in them and tests
expiry by advancing time. For new timing failures, rerun affected tests without competing work,
then the selected regression scope before treating them as product failures. Persistent timing
failures need a controlled clock, not a longer arbitrary timeout. A UI failure likewise needs its focused
rerun before diagnosis.

## Simulator and UI-test pitfalls

- Match the simulator runtime to the phone OS in STATE when investigating device-only UI bugs.
  `xcodebuild -showsdks` reports SDKs, not installed runtimes; use `xcrun simctl list runtimes`.
  AI ticket 07's blank template row reproduced on iOS 27 but passed on iOS 26.5. The added
  `WT-iPhone27` simulator provides that regression gate; keep older runtimes for bounded
  compatibility checks. Do not infer phone behavior from an older runtime's green result.
- If a completed test suite stalls while Xcode collects optional `simctl diagnose` output,
  inspect that exact child process separately from xcodebuild. Ticket 07 retained all test
  evidence, stopped only the identified diagnostic child, and used
  `-collect-test-diagnostics never` for subsequent runs. Actual xcodebuild exits and completed
  xcresult summaries remain required; a suite-passed line alone is not a finished run.
- An Xcode update can leave an old CoreSimulator service running. After confirming the stale
  service error, restart that service (2026-09-17: `pkill -9 -f CoreSimulatorService` fixed it).
  Coordinate with other runs before restarting services. Repeated simulator install failures
  after fixing the build may require erasing the dedicated test simulator, which deletes its data.
- UI tests launch with `-uiTestReset` into a disposable store. Without `-uiTestHeartRate`, they
  use `DisabledHeartRateProvider`, preventing HealthKit permission sheets from obscuring tests.
  Fixture flags must also be guarded by `WorkoutTrackerStore.fixtureIsEnabled`.
- SwiftUI list buttons have not responded reliably to synthetic desktop clicks here; use
  XCUITest for interaction and captures. The simulator has no camera; use the scan fixture.
- Picker rows under a keyboard may ignore taps. Tap the row's text; dismiss the keyboard
  with Return and scroll until lazy List content exists. A partly obscured control can be
  `isHittable`: assert its frame above the tab bar or pinned rest bar as appropriate.
- An alert text-field tap positions the cursor where it lands; tap near its trailing edge
  when appending. A Label's identifier in a List can land on the cell. A screen-level
  identifier can replace a safe-area button's identifier.
- A sheet attached directly to a List Section once silently never presented; attach it to a
  row or a stable ancestor. A pushed screen needs its own presentation flow; a dialog attached
  only to the covered Start List may not appear. A deletion `confirmationDialog` once showed
  no Cancel; the shared machine-deletion component uses an alert with both actions.
- `safeAreaInset` already reserves scroll space. A pinned control may still need a
  background-to-clear fade for rows passing underneath it.
- A quantitative-x `BarMark` once drew no bars; captures caught it. `chartXSelection` inside
  a List lost to scrolling; the shipped chart uses an explicit overlay gesture instead.
- A `Menu` label inherits accent tint unless set explicitly. Match `@ScaledMetric` text
  styles to base sizes so icons do not outgrow their tiles at accessibility sizes.
- Canvas artboards have rendered blank from local HTTP even for known-good files. Use a
  plain board HTML for local captures; inline mask assets as data URIs when `file://` blocks
  them. The committed screenshots are the review evidence.

## Real-device installation

The interactive `scripts/install-on-device.sh` is for first-time human setup. For an already
configured phone, use the direct path below. Reinstalling the same bundle ID preserves the
container; say so before installing. Confirm an appropriate export backup before a schema or
history migration. Run `LegacyStoreMigrationTests` for schema changes before touching the
phone; check STATE for whether the fixture matches the installed schema.

```sh
xcrun devicectl list devices
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -configuration Debug \
  -destination 'generic/platform=iOS' -allowProvisioningUpdates \
  -derivedDataPath /tmp/wt-device-build build
# After checking the built product and profile below:
xcrun devicectl device install app --device <device-id> \
  /tmp/wt-device-build/Build/Products/Debug-iphoneos/WorkoutTracker.app
xcrun devicectl device process launch --device <device-id> <bundle-id>
```

Use a generic build destination: targeting a sleeping phone by ID once hung the build for
22 hours waiting for device preparation. Installation still needs the phone. A successful
install does not establish successful launch; a locked phone can refuse remote launch.
Record that distinction in STATE and ask the user to open it when necessary.

- **Transport:** a first disconnected Wi-Fi tunnel may wake on retry. If it remains
  `unavailable`, ask for USB after one retry. Ten minutes of Wi-Fi retries did not fix it.
- **Locked phone:** disk-image mount error 12040 with a connected tunnel can mean the phone
  needs its first unlock since boot (`devicectl device info lockState`). Developer Mode must
  also be enabled and confirmed after reboot; cached device status can be stale.
- **Stale binary:** a failed/timed-out build can leave an old app that installs successfully.
  A background build once returned success but left old assets. Check the product timestamp
  and a new-code symbol/string in `WorkoutTracker.debug.dylib`, or inspect new assets with
  `assetutil --info`. Debug Swift code is in the dylib, not the small launcher executable.
- **Signing account:** Xcode updates have signed the Apple ID out. An absent account makes
  profile minting fail even when a remembered team and old profiles are present. The user
  signs back in through Xcode Settings → Accounts; an agent cannot supply password/2FA.
- **Certificate chain:** missing WWDR G3 can report zero signing identities despite a valid
  development certificate. The setup script checks/repairs the intermediate certificate.

## Provisioning expiry

This project's free-account app and widget have separate seven-day profiles. A rebuild may
reuse an almost-expired profile; reinstalling an existing binary never extends its expiry.
The on-phone symptom has been "this app is no longer available" while the app remains listed
as installed. Remote launch can reveal the signing error.

Profiles on this Mac live under `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`.
Read expiry with `security cms -D -i <profile.mobileprovision> | plutil -extract ExpirationDate raw -`.
Check the built app's `embedded.mobileprovision` and its widget's profile before installing.
For a fresh week before expiry, first ensure Xcode has a signed-in account, back up the two
matching profiles, move them aside, then rebuild with `-allowProvisioningUpdates`. Restore
the backups if minting fails. Verify both new expiration dates; renewing only an expired
profile lets app/widget clocks drift, and the widget can die while the app still launches.

## Plists and extensions

- Changing `INFOPLIST_FILE` requires a clean build and inspection of the resulting plists.
  An incremental success once omitted both HealthKit usage strings and would crash on access.
- `INFOPLIST_KEY_UIBackgroundModes` is silently dropped by generation; background modes live
  in `Config/WorkoutTracker-Info.plist`. Verify HealthKit usage strings and live-activity keys.
- The widget needs `NSExtension` in its partial plist plus version/build keys; missing them
  prevents installation of the entire app. `INFOPLIST_KEY_NSExtensionPointIdentifier` alone
  was silently ignored. Camera usage strings must also be present before presentation.

## Persistence and export lessons

- Capturing an enum in a SwiftData `#Predicate` caused a launch crash here, including an optional
  enum. Exercise the actual fetch/launch path when changing predicates; a successful build is insufficient.
- A one-shot version gate misses history arriving later. Data repair/migration gates need an
  idempotent per-launch check where later data must also be handled (D51); test repeat execution.
- Reusing an existing export column for a new meaning silently changes the backup format.
  Append fields and record the schema change rather than repurposing old columns.
- A test green in a full suite can depend on execution order. Run changed test classes in
  isolation as well when shared state or fetch order could affect their result.

## CI, scanner tooling, and time-based behavior

- CI needs a runner/toolchain capable of the iOS 26 APIs (`macos-26`; `macos-15` failed).
  Local tests are the pre-merge gate. The hosted unit job has historically hung; the user
  deferred investigation. If reopened, inspect its uploaded log and set a bounded step timeout.
- Anaconda's old Brotli decoder broke the Anthropic tooling client with
  `process() takes no keyword arguments`. `llm_reader.py` uses `Accept-Encoding: identity` to
  bypass it. The tooling key in `Config/anthropic.key` is distinct from the phone's keychain key.
- Shell details: zsh does not word-split `$VAR`; use arrays for argument lists. Quote heredoc
  delimiters in review prompts so backticks and substitutions are not executed.
- For agent reviews in Orca, follow the version-matched `orca-cli` guide. A report file's
  completion/content is stronger evidence than a TUI-idle wait after an agent finishes.
- Read the archived background-alarm incident before changing timed background behavior.
  A scheduled notification does not prove app code executed. The working rest alarm queues
  a pre-rendered silence-plus-beep track; it avoids needing CPU at a chosen future instant.
  Ducking is deliberately absent from that queued beep; early recovery plays live when the
  app runs, with the queued cap as a floor. Check actual callers and delivery, not just receivers.

## Local Codex preferences

Personal preferences live in `~/.codex/config.toml`, outside Git. On 2026-09-17 the user chose
an 872,000-token window (the installed Astra catalog's maximum), auto-compaction at 780,000,
and context used/remaining/window size in `tui.status_line`. The original config was backed
up beside it. The CLI reserves context headroom, so an effective budget can be smaller than
the configured window. Restart Codex to load changed settings; check the footer and `/status`.
These settings do not replace the checkpoint workflow in AGENTS. Model limits can change;
inspect the current model metadata before changing the window or switching models.

## Graft code navigation

Graft is development tooling, separate from the iPhone app. After the AGENTS startup reads,
use `graft map`, `graft ask "<task or symbol>" --source`, `graft skeleton <file>`, and
`graft callers <symbol>` for orientation. Confirm relevant source and callers before editing;
the static map is not proof that every SwiftUI callback, SwiftData-generated member or runtime
dispatch edge was found. Use `rg` and direct reads when the index lacks detail.

`graft check` checks the current checkout. If absent/stale, `graft build` rebuilds its structural
index without an LLM key. The generated `graft/` cache is gitignored; `.ignore` makes only its
readable cards searchable and excludes internal `.cache/` / `.graph/` data. Each checkout may
need its own build. A structural-only installation reports the deep/meaning layer as not built
or pending; this alone is not a failure and does not call for `--deep`.

`graft init` can rewrite its fenced AGENTS section. Preserve the project-specific precedence
paragraph outside that fence. Inspect `graft init --help` / `--dry-run` before changing wiring:
`agents` selects Codex/AGENTS.md; user-level Codex MCP and hook settings affect all repositories.
Actual installed configuration and the distinction between configured hooks and a verified
fresh-session load are recorded in the [Graft setup ticket](../work-record/graft-setup/issues/01-graft-handoff.md).
