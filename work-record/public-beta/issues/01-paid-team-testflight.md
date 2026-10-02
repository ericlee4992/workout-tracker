# 01 — Paid team, data move and TestFlight

Type: task
Status: needs-info — waiting on Apple's enrollment approval (paid, pending at 2026-10-02); phase A can run
without it
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

### Prepare (now; no phone, no Apple account changes)

1. Config diff on the branch: the four `DEVELOPMENT_TEAM` lines → `$(WT_DEVELOPMENT_TEAM)`; app
   `INFOPLIST_KEY_CFBundleDisplayName = Stacked`; `ITSAppUsesNonExemptEncryption = NO` (HTTPS only);
   `CURRENT_PROJECT_VERSION` raised for the first upload. Clean build; inspect the built app's and widget's
   Info.plist (DEVELOPMENT → *Plists and extensions*): display name, encryption key, HealthKit and camera usage
   strings, `NSExtension`, background modes. Release build launches in the Simulator; UI-test fixture flags
   (`AskAI.fixtureIsEnabled`, `TerraAccess.fixture`) are off without their launch arguments.
2. **Rehearse the restore on the Simulator:** seed a store, `simctl` copy the data container out, uninstall,
   reinstall without launching, copy the container in, launch, compare row by row. Records the exact file set
   (`Library/Application Support` store and `-wal`/`-shm`, `Library/Preferences/<bundle-id>.plist`, `Documents`)
   and proves the store opens from restored files.
3. Draft the Apple Developer Support request (release `com.ericlee4992.workouttracker` and
   `com.ericlee4992.workouttracker.widget` — and `.watchkitapp` if registered — from Personal Team `X68M8SR6NA`
   to the paid team) so it can be sent the moment a refusal appears. The user sends it; an agent cannot.
4. Codex reviews the diff and this procedure (B–E) to "clear".

### A — Safety-net renewal of the free signing (Oct 4; no later than Oct 5 18:00 EDT)

Skip only if D has already finished. User present, phone unlocked. DEVELOPMENT → *Provisioning expiry*: fresh
full container backup with verification (SHA-256 manifest, integrity check on copies, row counts); move the two
profiles aside; rebuild `main`'s code on the free team with `-allowProvisioningUpdates`; check **both** new
expiry dates (about Oct 11); install; launch; preservation check. Repeat weekly while waiting on Apple. If
Apple Support releases the IDs, the free profile can stop working before D — the phone keeps the data, and the
latest backup stands ready.

### B — Paid team (after enrollment approval)

1. The user confirms approval; the paid team appears in Xcode → Settings → Accounts for the same Apple ID.
   Record its Team ID in STATE (not secret) and set `WT_DEVELOPMENT_TEAM` in this checkout's
   `Local.xcconfig` (git-ignored).
2. A development build for the paid team with `-allowProvisioningUpdates` registers the App IDs, the HealthKit
   capability and the phone's UDID. **If refused ("not available"): stop.** The user sends the support request
   from Prepare 3; continue A's weekly renewals until the IDs are free; then retry. **Do not change the bundle
   ID** (Q1).
3. Check the built app and widget: team prefix in `application-identifier`, HealthKit entitlements, profile
   expiry about a year out, `get-task-allow` true (development).

### C — App Store Connect record

The user (or Claude in Chrome, with the user's go-ahead) creates the app: iOS, name **Stacked** (if taken, ask
the user — do not pick), English (U.S.), the existing bundle ID, SKU `stacked-ios`. An internal TestFlight group
with the developer only. Subtitle and tagline are recorded for ticket 08/09, not needed yet.

### D — Move the data to the paid-team build (irreversible step; ask first)

1. Fresh full container backup of the installed free-team app to `~/WorkoutTracker-Backups/<date>-before-paid-team/`
   (mode 0700), verified as on 2026-09-29: SHA-256 manifest, SQLite `integrity_check` on the copies, counts of
   workouts, sets and templates, zero unfinished workouts.
2. **The user approves the delete** after seeing the backup's verification. The user deletes the app on the
   phone (or `devicectl device uninstall app`).
3. Install the paid-team development build. **Do not launch it.**
4. Copy the backup's container files into the new app's container (`devicectl device copy to …
   --domain-type appDataContainer --domain-identifier com.ericlee4992.workouttracker`), the file set from the
   rehearsal. Copy the container out again and compare checksums with the backup before launching.
5. Launch. The user re-grants Health access and re-enters the OpenAI key (team-scoped Keychain; until ticket
   06 removes it). Copy the container out and run the row-by-row preservation comparison of every table
   against the backup (the 2026-09-29 method). Expect no differences except launch-time bookkeeping already
   seen on 09-29; any other difference stops the ticket for the user.
6. If 3–5 fail: the backup is intact; reinstall and repeat 4, or stop and ask. Nothing is deleted from the
   backup folder.

### E — TestFlight

1. Release archive on the paid team; upload to App Store Connect (`xcodebuild -exportArchive` with an
   `app-store-connect` export and upload destination, or Xcode Organizer). Wait for processing; the internal
   group receives the build.
2. Before installing it over the development build: a last full container backup (Q14 — TestFlight builds cannot
   be copied from).
3. The user installs from the TestFlight app. It must update in place (same team, same identifier). Launch;
   check the visible counts (History) and run an in-app Export; compare the export's workouts, sets and
   templates with the backup counts.
4. The Live Activity and widget appear in a short workout; the home-screen name reads "Stacked".

## Acceptance

- [ ] Config diff merged after Codex clear; clean build; built plists checked; Release launch in Simulator.
- [ ] Restore rehearsed on the Simulator with a passing row-by-row comparison.
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
