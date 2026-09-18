# 02 — Cardio physical-device acceptance

Type: task
Status: open — physical evidence outstanding

Software merged via **b0a8de9**, product `03ada3d`; build, 748 full units, 13 final targeted units,
7 focused UI and 79 full UI passed. [Implementation and review evidence](01-implementation.md).
These simulator results do not establish AirPods Pro3 distance delivery or locked-screen GPS.
Phone now has the cardio build from c847ef3 (product `03ada3d`); first launch is not yet verified,
so the on-phone store migration is not yet confirmed. Cardio exports schema10. Follow current
[STATE](../../../docs/STATE.md) and [DEVELOPMENT](../../../docs/DEVELOPMENT.md) for fresh export,
raw backup, migration, signing, binary freshness and launch checks before an install.

## Acceptance work

The user-authorized installation is complete. First confirm the app opens and the existing
history is intact; remote launch was not verified because of lock/connectivity errors. Then
record device OS/AirPods firmware and:

1. Indoor Walk and Indoor Run with AirPods Pro 3: compare distance/average pace to treadmill
   readings, first carrying the phone, then leaving it on the console. Record which source
   label appears and whether HealthKit distance actually arrives; HR alone is not a pass.
2. Pause/resume, lock/unlock, and disconnect/reconnect: active time excludes pauses; cumulative
   distance does not double; old totals survive a quiet stream; fresh pace returns only with
   new measurements. Where distance never arrives, the source must remain unavailable or
   honestly labelled Phone motion, with manual entry available.
3. Indoor cycle/rower: verify HR/calories and any genuinely supplied machine distance; otherwise
   enter machine distance. AirPods are not a universal bike/rower distance sensor.
4. Outdoor walk/run/ride: grant location, record a short route while locked, pause/move/resume,
   then finish and inspect History. No line or distance bridges the pause; stop tracking at End.
5. Lift → cardio → lift → Finish: one app History item, distinct segments and typed Health
   workouts, no overlapping energy totals. Force-quit/relaunch once to check paused recovery.


Watch companion cardio remains outside this release. If HealthKit supplies no indoor distance,
record that result as unavailable with labelled phone-motion/manual fallback; do not call it
verified AirPods distance support. Record actual device/firmware and results here.

## Installation — user authorized 2026-09-18

User asked “can you install”. Fresh generic-iOS build from clean main **c847ef3**, product
**03ada3d**, `/tmp/wt-cardio-device-20260918`, exit 0. Verified current dylib timestamp and
CardioRecorder symbol, same app/widget bundle identities, code signatures, and built Health,
motion, location and camera usage strings plus background location. Profiles reused: app
expires **2026-09-24 07:16:18 UTC**, widget **07:16:20 UTC**.

Stopped the old app (PID15829) for a consistent backup; its store had no unfinished workout.
Fresh full container at `/Users/ericlee06/WorkoutTracker-Backups/2026-09-18-before-cardio`,
26 files /23,745,974 bytes, SHA-256 manifest, integrity `ok`, access-restricted outside Git.
Master backup hashes unchanged after verification. No private data committed.

Before installing, ran production container migration and JSON/CSV exporters on an isolated
copy of the **actual phone store**. Private probe plus legacy migration tests: **10 passed,
0 failed/skipped, exit 0**. Both databases pass integrity; every pre-existing attribute, row,
ID and relationship across 13 tables matches after normalizing Core Data numeric Z_ENT tags
through their entity names (the only changed old column). Portable CSV/JSON exports saved
beside the raw backup from that migrated copy, JSON round-trip verified. This is stronger
than the synthetic fixture, but not a tested restore. Temporary probe source archived in the
private backup and removed from the test tree; its private simulator files removed.

Installed 2026-09-18 08:32 EDT successfully: devicectl exit 0 /outcome success, same bundle ID preserves
the app container; installation UUID **615FA1ED-A116-408B-B03C-FD43A5654A54**.
Remote launch returned Locked (FBSOpenApplicationErrorDomain7), exit 1, no app process running.
Asked user to unlock so launch can be verified. **Installed, not yet launch-verified.**

Build/install/launch logs and JSON: main `work-record/ui-redesign/results/cardio-install/`.
Migration result/log: implementation `work-record/ui-redesign/results/cardio/private-migration-install.*`.
Physical AirPods/GPS acceptance remains outstanding even after successful launch.

Follow-up: lockState later reported unlocked (`passcodeRequired: false`), but remote launch
attempts 2/3 returned CoreDevice 4016 (no trusted connectivity/services). One reconnect retry
was attempted; the phone then listed unavailable. Installation remains successful; no launch
or on-phone migration success is inferred. Next: user opens WorkoutTracker manually, or
reconnects unlocked via USB for tool verification. No reinstall is needed merely for this
connection failure.

## New-session checkpoint — 2026-09-18

Current main at audit: **b845a3a**, remote matched, working tree clean. Product/test code is
unchanged from reviewed `03ada3d` / `306acf4`. Re-read actual exit files and result summaries:
748 full units, 79 full UI and 10 migration checks passed; targeted 13 / focused 7 exit 0; device
build/install exit 0; all three remote launch attempts exit 1. No local xcodebuild/xctest job active.
Rechecked all 26 raw-backup SHA-256 entries and the offline migration report; exports exist.
The temporary private test and its simulator files were removed; no private data is in Git.

Next session begins with launch/history confirmation, then the physical acceptance work above.
No source changes or rebuild are required just to resume this handoff. The old unlock prompt
is context for this unfinished verification, not a new design/install approval.
