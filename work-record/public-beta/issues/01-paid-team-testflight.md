# 01 — Paid team, data move and TestFlight

Type: task
Status: in progress — **Prepare done and Codex clear (4 rounds) 2026-10-02**; merged to `main` (`907b81b`, fast-forward, the
user's go-ahead 2026-10-02); phases B–E wait on Apple's enrollment approval (pending at 2026-10-02); phase A (free renewal) is
due Oct 4, by Oct 5 18:00 EDT at the latest
Blocked by: —
Implementer: Claude (the signing, phone and App Store Connect steps need this session's tooling and the user).
Reviewer: Codex, in a visible Orca terminal, for the config diff **and for this procedure before the delete
step** (D).
Branch: `ericlee4992/beta-01-paid-team` off `main`.
Spec: [spec.md](../spec.md) → *Data safety*, *Name*, *Testers and distribution*. Decision: D60.

## Goal

The app is signed by the paid Apple Developer Program team with the **same bundle IDs**
(`com.ericlee4992.workouttracker`, `.widget`), the developer's phone runs a **TestFlight** build of it named
**Stacked**, and **every row of the developer's data is preserved**. The free-team signing never lapses while
the app is in use: the current profiles expire **2026-10-06 08:45 UTC (04:45 EDT)**.

## Facts this plan rests on (2026-10-02)

- Xcode on this Mac knows only the free Personal Team `X68M8SR6NA`: one identity "Apple Development:
  ericlee4992@gmail.com (D8VDZ3SN79)", profiles `9919493b…` (app) and `ba4e9c29…` (widget), both expiring
  2026-10-06T08:45Z. The paid enrollment is **pending** (user, Q13).
- A bundle ID registered by free provisioning belongs to that Personal Team; another team registering it gets
  "not available". Apple Developer Support can release it (Apple forums threads 80294, 107350). User decision
  (Q1): **keep the ID and wait for Apple Support if refused**; do not switch IDs without asking again.
- iOS will not install a build from a different team over the installed app (application identifier =
  team ID + bundle ID; "application-identifier entitlement does not match … upgrade"). Deleting the app
  deletes its container, so the move is backup → delete → install → restore → verify (spec, *Data safety*).
- `xcrun devicectl device copy to --domain-type appDataContainer --domain-identifier <bundle-id>` writes into
  a development-signed app's container (checked: the option exists in this Xcode 27). Backups so far used
  `copy from` the same domain (2026-09-29, ticket 13 of the redesign).
- The project hard-codes `DEVELOPMENT_TEAM = X68M8SR6NA` in four `project.pbxproj` lines (app and widget,
  Debug and Release) although `Config/Shared.xcconfig` intends the team to come from the git-ignored
  `Config/Local.xcconfig` (`WT_DEVELOPMENT_TEAM`). The main checkout's `Local.xcconfig` holds the team and
  `WT_BUNDLE_ID_BASE = com.ericlee4992.workouttracker`; this worktree has none yet (copy it before a device
  build).
- The Watch app is not embedded in the iPhone app; the archive contains the app and the widget only.

## Plan and stop points

Two gates protect the data. **Neither is waived because the enrollment or the expiry deadline is close**
(Codex review 01). Commands and scripts: DEVELOPMENT → *Container backup and restore*.

**Gate S — stable verified backup** (`~/WorkoutTracker-Backups/<date>-<purpose>/`, mode 0700):
1. No workout in progress (the user finishes or discards it). The user exports JSON (Settings → Export → JSON) and
   **sends it to the Mac** (AirDrop, or Save to Files): the app deletes its copy when the Export screen closes
   (`ExportView.swift:95`, `.onDisappear(perform: dropFile)`), so it is never in a capture (found 2026-10-02, phase
   A). Note the counts on the Export card ("N workouts · M sets").
2. The user swipes the app away; a **successful** `devicectl device info processes` query shows no app process
   (a failed query proves nothing; the widget extension may run: it has no App Group and cannot open the store). **The app stays closed until the gated step is
   done; if it is opened, Gate S starts again.**
3. Capture the container twice (`copy from`). Both pass `verify_container.py`; capture 2 passes `--expect`
   capture 1's report (byte-identical restore set = nothing was writing); capture 1 passes `--export` with the
   export from step 1 (IDs and counts); and **the round trip**: `simulator_export.sh` restores capture 1 into the
   disposable Simulator WT-Backup-01 (a `build-for-testing` of the code the phone runs, real bundle ID) and the app
   exports it; `compare_exports.py <phone export> <round-trip export>` must exit 0 — the only check here that
   proves the capture holds the phone's history values. Record the report paths.

**Gate P — phone copy preflight**, once per phone and Xcode version, on the installed free-team app: build a
probe tree (a file, and a nested directory whose name contains a space, mirroring `Application Support`), `copy to`
the app container's `tmp/`, `copy from` it back, and require `compare_trees.py` exit 0; record the exact working
command forms for the restore (directory to `Library/Application Support`, file to `Library/Preferences`). The
store is not touched. Simulator `cp` and `devicectl --help` do not count as evidence.

### Prepare (no phone, no Apple account changes) — done 2026-10-02, see Progress

1. Config diff: the four `DEVELOPMENT_TEAM` lines → `$(WT_DEVELOPMENT_TEAM)`; app
   `INFOPLIST_KEY_CFBundleDisplayName = Stacked`; `ITSAppUsesNonExemptEncryption = NO` (HTTPS only); the
   installer writes the team into `Local.xcconfig`, never the project. Build number left at 1 — no upload exists
   yet, and App Store Connect needs it unique per version only — each upload passes `CURRENT_PROJECT_VERSION=<n>`
   on the archive command and records `n` **and the exact commit** here (the bridge in E needs that commit).
   Clean build; built plists inspected (DEVELOPMENT → *Plists and extensions*); Release launches in the Simulator.
2. Restore rehearsed on the Simulator (direct restore and the full cycle), with negative checks.
3. Apple Developer Support request drafted ([apple-support-request.md](../apple-support-request.md)).
4. Codex review to "clear".

### A — Safety-net renewal of the free signing (Oct 4; no later than Oct 5 18:00 EDT)

User present, phone unlocked, the paid move (D) not yet done. In order: **Gate S** → **Gate P** → move the two
profiles aside; rebuild `main`'s code on the free team with `-allowProvisioningUpdates`; check **both** new expiry
dates (about Oct 11) → install the same code over the app (same team: an in-place update) → launch and
inspect → **the user closes the app; a successful process query shows it gone** → capture → `compare_stores.py`
against Gate S (rows and preferences). Repeat the renewal weekly while waiting on
Apple, each time behind Gate S.

### B — Paid team (after enrollment approval)

1. The user confirms approval; the paid team appears in Xcode → Settings → Accounts for the same Apple ID.
   Record its Team ID in STATE (not secret) and set `WT_DEVELOPMENT_TEAM` in this checkout's `Local.xcconfig`
   (git-ignored).
2. A development build for the paid team with `-allowProvisioningUpdates` registers the App IDs, the HealthKit
   capability and the phone's UDID. **If refused ("not available"): stop.** **Do not change the bundle ID** (Q1).
   Before the user sends the Support request — which asks Apple to delete App IDs, and Apple states that deleting
   an App ID invalidates its profiles — all of these must hold:
   - Gate P recorded (from A, or run now);
   - Gate S completed **the same day**, and the app kept closed from then on, or the user accepts that anything
     logged after that backup may have to be re-entered;
   - the user's recorded acceptance that the app may stop opening until D is finished.
   Then the user sends it. Apple's answer and timing are not guaranteed (the forum threads report past users'
   experiences, including initial refusals). Continue A's weekly renewals until Apple acts.
3. If the Personal Team's IDs are deleted before D: check whether the free app still launches and whether
   `copy from` still works. If a current Gate S backup can be taken, take it; **if not, stop and ask the user** —
   never silently substitute an older backup.
4. Check the built app and widget: the signed `application-identifier` values themselves (an App ID prefix is not
   always the Team ID, Apple QA1879), HealthKit entitlements, profile expiry about a year out, `get-task-allow`
   true (development).

### C — App Store Connect record

The user (or Claude in Chrome, with the user's go-ahead) creates the app: iOS, name **Stacked** (if taken, ask
the user — do not pick), English (U.S.), the existing bundle ID, SKU `stacked-ios`. An internal TestFlight group
with the developer only. Subtitle and tagline are recorded for ticket 08/09, not needed yet.

### D — Move the data to the paid-team build (irreversible step; ask first)

1. **Gate S immediately before the delete**, to `~/WorkoutTracker-Backups/<date>-before-paid-team/`. Gate P must
   be on record. The user also notes how many of this app's workouts Health shows (Health → Sources), since Health
   records live outside the container.
2. **The user approves the delete** after seeing both gate reports. The user deletes the app on the phone (or
   `devicectl device uninstall app`). The app stays closed throughout.
3. Install the paid-team development build. **Do not launch it.**
4. Copy the restore set from the Gate S capture into the new container with the command forms Gate P proved.
   Capture the container and run `verify_container.py --expect <Gate S report>`: exit 0 before any launch.
5. Launch. Close the app and confirm it is gone with a successful process query; capture;
   `compare_stores.py <Gate S capture> <after>` must exit 0 (every
   row and every preference). The user re-grants Health access, re-enters the OpenAI key (team-scoped Keychain;
   until ticket 06 removes it), and checks Health still lists the workouts noted in 1. Any difference stops the
   ticket for the user.
6. If 3–5 fail: the backup is intact; uninstall the new app (it holds only a copy), reinstall, repeat 4 — or stop
   and ask. Nothing is ever deleted from the backup folder.

### E — TestFlight

1. Release archive on the paid team from a recorded commit; upload to App Store Connect (`xcodebuild
   -exportArchive` with an `app-store-connect` export and upload destination, or Xcode Organizer). Record the
   build number and commit. Compare the archived app's signed `application-identifier` with the development
   build's: they must be equal, or the TestFlight install will not update in place — stop.
2. **Gate S** (the last container backup a development build allows), then install from TestFlight with the app
   closed. If the TestFlight app offers only delete-and-install, stop.
3. Launch; Export JSON; the export's counts equal Gate S's. In TestFlight, **turn off Automatic Updates** for
   Stacked (a later build must never install before its backup).
4. **Prove the backup bridge once:** build a development build from **the same commit** as the TestFlight build;
   with the app closed, install it over the TestFlight build **without launching**; if installation needs a
   delete, stop (the TestFlight build and its data stay). Capture; `verify_container.py --export` with step 3's
   export must pass. Then reinstall the same TestFlight build from the TestFlight app, launch, check counts. This
   establishes the rule in DEVELOPMENT; until it passes, the rule is unproven.
5. The Live Activity and widget appear in a short workout; the home-screen name reads "Stacked".

## Progress

### Prepare — 2026-10-02 (Claude)

Branch `ericlee4992/beta-01-paid-team` from `main` `bab270b`. Derived data and logs in this session's scratchpad
(`…/scratchpad/b01/`, ephemeral); exit codes below are the commands' own (no pipeline masking).

- **Config diff:** `project.pbxproj` — the four `DEVELOPMENT_TEAM = X68M8SR6NA` → `"$(WT_DEVELOPMENT_TEAM)"`; app
  Debug and Release `INFOPLIST_KEY_CFBundleDisplayName = Stacked`. `Config/WorkoutTracker-Info.plist` —
  `ITSAppUsesNonExemptEncryption = false` (with the reason). No code reads the app's name (checked app, widget and
  tests). `Config/Local.xcconfig` copied from the main checkout (git-ignored; still the free team).
- **Clean device build** (Debug, generic iOS, free team from `Local.xcconfig`, no `-allowProvisioningUpdates`):
  exit 0, CLEAN and BUILD SUCCEEDED. Built app: `CFBundleIdentifier` com.ericlee4992.workouttracker, display name
  **Stacked**, `ITSAppUsesNonExemptEncryption` false, 0.1.0 (1), `NSSupportsLiveActivities`, Health and camera
  usage strings, `UIBackgroundModes` [audio, workout-processing, location]; entitlements
  `X68M8SR6NA.com.ericlee4992.workouttracker`, HealthKit ×3, `get-task-allow`. Widget: `.widget`, "Workout",
  `com.apple.widgetkit-extension`, same team. Profiles unchanged (2026-10-06T08:45:50Z / :48Z).
  `codesign --verify --deep --strict` ok. So the team now comes only from `Local.xcconfig`.
- **Simulator Release build with no team** (`WT_DEVELOPMENT_TEAM=` and the example bundle ID, as CI builds):
  exit 0; installed on the new simulator **WT-Beta01** `A3D88C6F-6426-427A-9A0E-CF11A93798B1` (iPhone 17 Pro Max,
  iOS 27.0); launched and stayed running (PID 71448); empty Workout tab rendered. The AI fixtures need two launch
  arguments together (`WorkoutTrackerStore.fixtureIsEnabled`), which a TestFlight install cannot pass.
- **Scripts** `scripts/container-tools/verify_container.py` and `compare_stores.py` (DEVELOPMENT → *Container
  backup and restore*). Validated on the 09-29 backup: 27 files, 26,725,362 bytes, 24 workouts / 0 unfinished /
  343 sets / 2 templates, 15 tables — as recorded on 09-29; backup vs after-launch reports exactly the known
  `ZAPPPREFERENCES` gym pick (exit 1, correctly). The original store's SHA-256 was unchanged afterwards.
- **Restore rehearsal R1** (Debug Simulator build with the real bundle ID, installed, never launched; the 09-29
  backup's restore set copied in): pre-launch `--expect` check exit 0 (4 files, none mismatched or extra);
  launched — the user's gym, Pull/Push templates shown; compare backup vs after-launch: **15 tables, no
  differences, every old row preserved**, exit 0.
- **Rehearsal R2, the full phase-D cycle:** back up the installed app (verify exit 0) → uninstall → install
  (new container) → restore → pre-launch check exit 0 → launch → compare exit 0, no differences.
- **Negative checks:** one set row deleted from a copy → compare exit 1 naming `ZSETRECORD` row 32; one byte
  appended to the preferences plist → `--expect` exit 1.
- **Apple Support draft:** [apple-support-request.md](../apple-support-request.md) (placeholders for name, email
  and the paid team ID; the repository is public).
- The simulator (renamed **WT-Backup-01** in round 2; the round trip's disposable Simulator) holds copies of the
  user's 09-29 data: **erase it (`xcrun simctl erase`) when the review is clear and after every later use**.

### Phase A — 2026-10-02 ~02:40–03:50 EDT (Claude, with the user at the phone)

Phone `00008130-001E10C01E62001C` available (paired), unlocked since boot; installed app 0.1.0 (1) = `522c157`'s code
(its app code is identical to `main`'s; only the name, team setting and compliance key differ). Backup folder
`~/WorkoutTracker-Backups/2026-10-02-phase-a/` (0700; JSON reports 0600).

- **Gate S — passed.** Export card: **25 workouts · 355 sets**. First process query: query exit 0 but the app
  **was running** → the user swiped it away → query exit 0, only the widget extension. Captures 1–2 taken (exit 0
  each), but the app's export was not in `tmp/` (it is deleted when the Export screen closes) → **procedure
  corrected** (send the export to the Mac); those captures moved to `superseded/`. The user AirDropped a new export
  (`workout-tracker-2026-10-02-0342.json`) and closed the app; one process query **failed** (CoreDevice 4000,
  connection) and was not counted; the retry succeeded with no app process. Fresh captures 1–2 (exit 0):
  27 files, 25,393,815 bytes, integrity `ok` ×3, **25 workouts / 0 unfinished / 355 sets / 2 templates**;
  `--export` exit 0 (0 missing workouts or sets, counts equal); capture 2 `--expect` capture 1 exit 0 (4 files
  identical). Superseded vs fresh capture: `compare_stores.py` exit 0 (sharing changed no row or preference).
  **Round trip** on WT-Backup-01: `simulator_export.sh` exit 0, card "25 workouts · 355 sets";
  `compare_exports.py` **exit 0, equal**. Simulator erased afterwards (exit 0).
- **Gate P — passed.** Directory form to `tmp/gateP/Library/Application Support`, file form to
  `tmp/gateP/Library/Preferences/probe.plist`, `copy from --source tmp/gateP` — all exit 0; `compare_trees.py` exit 0
  (3 files, none missing, extra or different). Working forms recorded in DEVELOPMENT. The probe stays in the app's
  `tmp/` (iOS clears it).
- **Renewal — blocked: Xcode has no account.** Old profiles copied to `old-profiles/`, moved aside; the clean
  `-allowProvisioningUpdates` build failed (exit 65: "No Accounts: Add a new account in Accounts settings", no
  profiles for app or widget). Profiles moved back; `cmp` identical to the copies; expiry still 2026-10-06 08:45 UTC.
  Nothing was installed. **Waiting on the user to sign in to Xcode.** The app must stay closed until the
  renewed build is installed and compared against this Gate S.

## Codex review 01 — response (round 1)

Review: [codex-review-01.md](../codex-review-01.md) — not clear (2 P2, 4 P1). All six accepted; fixes below,
verified on Simulator/rehearsal copies (scratchpad `…/b01/rehearsal/`). No phone or Apple-account step was taken.

1. **P2 installer writes a literal team** — `scripts/install-on-device.sh` `write_team_id` now upserts
   `WT_DEVELOPMENT_TEAM` in `Config/Local.xcconfig` (adds `WT_BUNDLE_ID_BASE` only if absent) and never touches
   the project; the bundle-ID notes no longer suggest editing the project. Tested on a temporary directory: new
   file created; an existing file's team replaced in place, bundle ID kept, idempotent on a second run; the
   project file byte-identical. `bash -n` ok. `-showBuildSettings` still resolves `DEVELOPMENT_TEAM = X68M8SR6NA`
   from this checkout's `Local.xcconfig`.
2. **P2 STATE stale** — STATE now names the branch, what is implemented and verified, review status, phases A–E
   not done, the deadline, the evidence location and the WT-Beta01 clean-up; phone facts kept separate.
3. **P1 Support request before a fresh backup** — B2 now requires Gate P on record, a same-day Gate S with the app
   kept closed (or the user's acceptance of re-entry), and the user's acceptance that the app may stop opening;
   B3 handles IDs deleted before D (check launch and copy access; fresh Gate S or stop — never an older backup).
   The Support draft carries the same preconditions, cites Apple's App ID deletion page, and no longer promises
   Apple's answer.
4. **P1 device preflight bypassable / probe unchecked** — Gate P is now unconditional before B2's request and
   D2's delete, round-trips a file **and** a nested directory with a space in its name, and is checked with the
   new `compare_trees.py` (exact paths and hashes), not `--expect`. Tests: identical trees exit 0; a changed byte,
   a missing file and an extra file each exit 1 (below).
5. **P1 backups not from a stopped, stable app** — Gate S: no workout in progress, a JSON export first, the app
   swiped away and absent from the process list, two captures that must be byte-identical (`--expect`), and the
   new `verify_container.py --export` cross-check against the app's own export (every workout and set ID present,
   counts equal). DEVELOPMENT states what integrity/comparison cannot prove. Evidence with a **real export written
   by the app** (a throwaway UI test, deleted, never committed, tapped Export → JSON on the rehearsal store; the card
   read "24 workouts · 343 sets"): capture passes `--export` (exit 0; IDs matched, so the UUID byte order is right);
   a second capture passes `--expect` the first (exit 0); a capture missing one set fails (exit 1, names set
   `954C5A24-…`, sets 343 vs 342) — the shape of Codex's truncated-WAL case; an empty store fails cleanly (exit 1,
   no traceback).
6. **P1 TestFlight bridge could run new code first** — the bridge is now: Automatic Updates off; a development
   build of the **exact commit of the installed TestFlight build** (each upload records its commit); installed over
   it **without launching**; stop if a delete is demanded; Gate S captures with `--export`. E4 proves it once on
   the phone; E1 compares the archived and development `application-identifier` values (QA1879). Spec and D60 carry
   the rule. Also from the review's notes: D1/D5 add the Health records check (they live outside the container),
   and `compare_stores.py` now compares the preferences plist key by key (a launch changed no key in the
   rehearsals; a flipped consent fails, exit 1; a missing plist fails, exit 1).

## Codex review 01b — response (round 2)

Review: [codex-review-01b.md](../codex-review-01b.md) — 1–4 and 6 resolved, 5 partly; two new findings.

- **R2.1 P1 — `--export` passes a lost edit.** Accepted; the response to finding 5 overclaimed. Added the value
  check Codex suggested second: `scripts/container-tools/simulator_export.sh` restores a capture into the disposable
  Simulator **WT-Backup-01** (refuses any simulator not named `WT-Backup*`) and runs the new
  `WorkoutTrackerUITests/BackupExportUITests` (skipped unless the runner has `WT_BACKUP_EXPORT=1`) so the app
  exports it; `compare_exports.py` compares that export with the phone's value by value (`exportedAt` ignored,
  timestamps as instants, `appVersion`/`schemaVersion` must match). Gate S now requires it.
  `verify_container.py`'s description now says `--export` checks IDs and counts only. **Codex's exact case
  reproduced** on copies of the rehearsal capture: set Z_PK 32 checkpointed with a stale 27 reps, the correct 20
  committed only to the WAL (4,152 bytes) while the connection stayed open; captures copied with the full WAL and
  with the WAL cut to its 32-byte header. Results (scratchpad `…/rehearsal/wal-case/`):

  | Capture | `--export` (IDs, counts) | round trip + `compare_exports.py` |
  |---|---|---|
  | clean rehearsal capture | exit 0 | exit 0, equal |
  | full WAL | exit 0 | exit 0, equal (the app reads the WAL on restore) |
  | WAL cut off | **exit 0** (the blind spot) | **exit 1**: `workouts[F6A7AB07…].entries[12CDF0DA…].sets[CE7203A7…].reps` phone 20, round trip 27 |

  Every round trip: `simulator_export.sh` exit 0, the card "24 workouts · 343 sets". The guard refused
  WT-Floodlight (exit 2). Without the variable the test reports "skipped" (`xcodebuild` exit 0), which the script
  treats as a failure. `build-for-testing` exit 0.
- **R2.2 P2 — phase A captured a running app.** A now reads launch and inspect → the user closes the app → a
  successful process query → capture → compare; D5 says the same; DEVELOPMENT states that every raw capture after a
  launch follows this rule and that a failed process query proves nothing (also in Gate S step 2).

## Codex review 01c — response (round 3)

Review: [codex-review-01c.md](../codex-review-01c.md) — R2.1 and R2.2 resolved (Codex reran its own lost-edit
case through WT-Backup-01: complete WAL equal, truncated WAL fails with reps 20 vs 120). One new P2.

- **P2 — date-shaped user text was normalized.** Accepted. `compare_exports.py` no longer normalizes by string
  shape: only the export schema's timestamp fields (`TIMESTAMP_PATHS`, taken from every `dateFormat` call in
  `ExportCollector.swift`; JSON keys equal the Swift property names — no `CodingKeys`) are compared as instants;
  notes, names and every other string are literal; an unparseable value in a timestamp field stays literal instead
  of raising. A timestamp field missing from the list can only cause a false failure, never hide a change. Cases on
  copies of the real app export, all as required: identical exit 0; Codex's notes `2026-10-02T08:00:00-04:00` vs
  `2026-10-02T12:00:00Z` **exit 1**; identical notes `2026-99-02T08:00:00Z` **exit 0** (no traceback); equivalent
  offsets exit 0 for `startedAt`, a set's `completedAt`, `preferences.birthDate`, a cardio segment's `startedAt` and
  an interval's `end`; a changed `startedAt`, a changed gym name and a changed `appVersion` exit 1; a changed
  `exportedAt` exit 0. The real round trips still give: clean 0, full WAL 0, truncated WAL 1.

## Codex review 01d — clear (round 4)

[codex-review-01d.md](../codex-review-01d.md): all findings of 01, 01b and 01c resolved, no new ones; all 22
timestamp paths checked against `ExportCollector.swift`/`ExportSnapshot.swift`; 63 targeted checks with the expected
exit codes. The clearance covers Prepare and the reviewed procedure, not phases A–E. Afterwards: WT-Backup-01 erased
(`xcrun simctl erase`, exit 0); the review terminal closed. Copies of the user's 09-29 data remain only in this
session's scratchpad (`…/b01/`) and Codex's `/tmp/wt-beta01-codex-review*/` (mode 0700), both ephemeral.

## Acceptance

- [x] Config diff merged after Codex clear — clear 2026-10-02; fast-forwarded into `main` `907b81b`.
- [x] Restore rehearsed on the Simulator with a passing row-by-row comparison.
- [ ] The app never stopped opening because of an expired profile.
- [ ] Paid team ID recorded; App IDs registered on it **with the original bundle IDs**.
- [ ] App Store Connect record "Stacked" (or the user's chosen fallback); internal group with the developer.
- [ ] Data move: backup verified; user approved the delete; restore checked by checksums before launch;
      preservation comparison clean after launch.
- [ ] TestFlight build installed in place on the phone; counts match; "Stacked" on the home screen.
- [ ] STATE records the team ID, the installed build (version/build number, TestFlight), the backups, and the
      new backup procedure for TestFlight builds; DEVELOPMENT updated (paid-team signing, the move procedure,
      TestFlight upload, backups on TestFlight builds; the 7-day expiry section marked historical).

## Verification scope

Config only plus phone operations: clean `xcodebuild build`, built-plist inspection, a Release launch smoke in
the Simulator, the restore rehearsal, and the phone checks above. No UI suite: no screen changes except the
home-screen name. Record every command's exit code and result here.

## Comments
