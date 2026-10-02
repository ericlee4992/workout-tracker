# Ticket 01 — independent Prepare review

Reviewed 2026-10-02 by Codex; Claude implemented. Scope: `git diff bab270b..37efb6c` on
`ericlee4992/beta-01-paid-team`. Verified HEAD `37efb6cc9d196b12a295669234b163882a1056ec`,
local `main` `bab270b986d4258e3a51929f4aca39ab48fa1c3d`. Prepare is implemented but not cleared.
Phases A–E remain device/account work; this review does not claim they have run.

## Standards findings

1. **P2 — The documented installer restores hard-coded signing teams.**

   **Evidence:** `WorkoutTracker.xcodeproj/project.pbxproj:633,668,794,817` now references
   `WT_DEVELOPMENT_TEAM`, but `scripts/install-on-device.sh:233–247` removes every
   `DEVELOPMENT_TEAM` assignment and inserts a literal team beside each automatic-signing block.
   Line 346 calls it unconditionally. `docs/DEVELOPMENT.md:134` still recommends this installer.
   This conflicts with `work-record/public-beta/spec.md:206–208` and the ticket's claim that the
   team now comes only from Local.xcconfig (`issues/01-paid-team-testflight.md:137`).

   **Failure:** running the supported setup path silently undoes this fix. A later change to
   `WT_DEVELOPMENT_TEAM` in Local.xcconfig leaves the target signing with the old literal team.

   **Fix:** update the installer to write the selected team into the ignored Local.xcconfig and
   preserve the project references. Check its resulting settings on a temporary project copy.

2. **P2 — STATE contradicts the completed Prepare work and actual branch.**

   **Evidence:** `docs/STATE.md:35–38` says “nothing implemented” and names
   `ericlee4992/public-beta`; `57–59` lists the config, rehearsal and Support draft as next work;
   `66–68` says no restore has been exercised. The ticket records those implementations and two
   successful rehearsals at `issues/01-paid-team-testflight.md:124–156`. AGENTS' Start/resume and
   checkpoint rules require an accurate current handoff.

   **Failure:** the next session receives the wrong branch/status, can repeat completed work,
   and can miss that WT-Beta01 contains copied personal data pending cleanup (ticket line 156).

   **Fix:** record the exact branch/commit, implemented and verified Prepare scope, outstanding
   review/merge and A–E operations, renewal deadline, evidence locations, and simulator cleanup.
   Keep the installed-phone facts distinct from the new local builds.

## Spec and data-safety findings

3. **P1 — Requesting App-ID deletion has no fresh-backup prerequisite.**

   **Evidence:** `work-record/public-beta/apple-support-request.md:27–32` asks Support to delete
   or release the IDs; `39–41` assumes a verified backup is ready. Ticket B2
   (`issues/01-paid-team-testflight.md:77–79`) sends this request before D1's fresh backup
   (`92–94`). A is scheduled later and might not have run. The spec requires “full container
   backup and verification → delete” (`spec.md:182–185`). Apple explicitly states that deleting
   an App ID invalidates its provisioning profiles.
   [Apple: Delete an App ID](https://developer.apple.com/help/account/identifiers/delete-an-app-id/).

   **Failure:** Support acts while the September 29 backup is still the latest usable copy.
   The free app can stop launching, renewal under the deleted ID is no longer a dependable
   fallback, and neither post-invalidation container access nor recovery of subsequent edits
   has been established. The ticket acknowledges launch failure but does not gate the request
   on protecting the current data first.

   **Fix:** before sending a request that authorizes deletion, take and verify a fresh container
   backup and JSON export, complete the device-copy preflight, and record the user's acceptance
   of possible interruption. Refresh backups while waiting if the app remains in use. If the ID
   is released before D, explicitly reassess launch/container access and stop if a current D1
   backup cannot be obtained; do not silently substitute an older backup. Treat Support's
   release and timing as pending confirmation. The cited forum threads describe past users'
   experiences, including initial refusals, rather than a guaranteed service commitment.
   [Thread 80294](https://developer.apple.com/forums/thread/80294),
   [thread 107350](https://developer.apple.com/forums/thread/107350).

4. **P1 — The device restore preflight can be bypassed, and its proposed check ignores the probe.**

   **Evidence:** ticket `63–68` places the phone copy test in A, which can be skipped after D;
   D's delete gate at `92–100` does not require its result. DEVELOPMENT `226–227` explicitly
   calls the path forms unconfirmed and says to round-trip a harmless file in `tmp/` and check
   it with the scripts. However, `verify_container.py:29–35,102–110` excludes `tmp/` from
   `--expect`; `compare_stores.py:38–42` only reads the store.

   **Failure:** early enrollment approval can lead through B–D before A's scheduled preflight.
   Even if A runs, a missing or changed probe can pass the stated script checks. I reproduced
   this: changed `tmp/probe.txt` between otherwise identical containers, then ran `--expect`;
   exit **0**, `ok: true`, no mismatches. A single file also does not establish directory nesting
   semantics for the Application Support restore command.

   **Fix:** make successful, recorded device preflight an unconditional prerequisite to both
   Support deletion authorization and D2. Round-trip a file and a small nested directory under
   `tmp/`, check their exact returned paths and SHA-256 hashes directly, and record the working
   commands. Do not use the restore-set filter to validate a probe outside that set. Simulator
   `cp` evidence and `devicectl --help` establish neither device path nor directory semantics.

5. **P1 — Raw database backups are not required to come from a stopped, stable app.**

   **Evidence:** `docs/DEVELOPMENT.md:213–224` and ticket D1/D5 (`92–104`) copy files without
   requiring termination or preventing subsequent writes before deletion. The verifier hashes
   the captured files and checks their recovered SQLite state (`verify_container.py:52–79,93–110`);
   the comparator uses that same captured baseline (`compare_stores.py:88–99`). The ticket's goal
   is “every row of the developer's data is preserved” (line 17).

   **Failure:** writes or a WAL checkpoint during a recursive copy can produce an incomplete
   capture; edits after the backup can also be lost at deletion. SQLite integrity and matching
   restored bytes do not prove the capture includes every committed transaction.
   [SQLite's backup guidance](https://www.sqlite.org/howtocorrupt.html#_backup_or_restore_while_a_transaction_is_active)
   requires a consistent backup method or no transactions during a raw copy.

   **Reproduction on temporary copies:** checkpointed the copied real store, committed a rep
   change only to its WAL, then truncated the captured WAL to its 32-byte header. The incomplete
   capture passed `verify_container.py` with **24 workouts / 343 sets / 2 templates / 0 unfinished**.
   Restoring that capture passed `--expect` and `compare_stores.py`, all exit **0**, despite losing
   the committed edit. Comparison against the complete WAL capture correctly exited **1**.

   **Fix:** finish/save current work, record a fresh logical baseline, stop the app and confirm
   it stays stopped, then copy the complete database/sidecars and preferences. Verify capture
   completeness, integrity and current baseline before authorizing deletion; keep the app closed
   through that step. Apply the stable-copy rule to post-launch captures too. Document explicitly
   that integrity/counts plus comparison against the same backup cannot detect omitted history
   in the original capture. Add this negative case to the script/procedure evidence.

6. **P1 — The TestFlight backup bridge can run the risky code before making its backup.**

   **Evidence:** `docs/DEVELOPMENT.md:230–232` says to install a same-team development build,
   take the backup, then continue, without selecting a revision or prohibiting launch. The normal
   device-install recipe at `140–148` ends by launching. `spec.md:190–192` and D60
   (`docs/DECISIONS.md:215`) require this backup before a risky update. Store creation and repair
   already execute during app initialization (`WorkoutTracker/App/WorkoutTrackerApp.swift:16–24`;
   `WorkoutTracker/Domain/Models.swift:877–883`).

   **Failure:** a future schema-change session follows the standard installation path with the
   new development build. Its first launch opens/migrates/repairs the live store before the full
   backup, defeating the backup rule. An arbitrary older development build can also be incompatible
   with the currently installed store.

   **Fix:** retain and identify the currently deployed TestFlight revision/schema, use its compatible
   development build for the bridge, install without launching, then copy and verify the container
   before any new code opens it. Prevent automatic updates during the operation. Record the actual
   application identifiers and prove the in-place bridge on disposable data; if installation asks
   for deletion, stop. Carry the clarified rule into the spec/D60/STATE pointers.

## Other review results

- **Config:** the four variable references inherit Shared.xcconfig through project Debug/Release
  configurations (`project.pbxproj:509,572`). Shared supplies blank/generic defaults and optionally
  includes Local.xcconfig (`Config/Shared.xcconfig:14–18`). CI disables signing
  (`.github/workflows/tests.yml:131`). No additional literal signing team was found in the tracked
  project/config; finding 1 covers the remaining writer. Display name changes leave the executable,
  product, scheme and TEST_HOST names intact (`project.pbxproj:710,728`). No runtime lookup of the
  display name was found. The HTTPS-only encryption declaration matches the current code's use of
  system services; no custom encryption implementation was found.
- **Storage inventory:** production uses one default persistent container
  (`Models.swift:869–883`, `WorkoutTrackerApp.swift:16–21`). Additional preview containers are
  in-memory; the caches-directory store is gated by `-uiTestReset` (`Models.swift:887–913`). The
  restored Application Support directory covers the store and sidecars. Standard preferences cover
  consent, appearance, exercise grouping and export state (`SettingsView.swift:18–20`,
  `ExercisesView.swift:20`, `AskAISettingsSheet.swift:23–25`, `ExportRecord.swift:19–32`). No App Group
  entitlement, shared defaults suite, second production store or external-storage attribute was found.
  Export files are temporary share artifacts (`ExportFile.swift:29–31,52–77`); saved external exports
  are not the live store. No missing app-container user-data directory was identified.
- **Outside the container:** the OpenAI key uses the default Keychain access group
  (`AskAIKeyStore.swift:9–10,32–36,45–49`), so re-entry is appropriate after an identifier-prefix change.
  The app also saves workouts to the system Health store (`HealthKitHeartRateProvider.swift:132–150`).
  Those Health records are outside this backup and its comparisons; preserve them through the move
  and check access again afterward. App history's sensor summaries are stored locally
  (`Models.swift:328–367`), so they do not depend on re-querying old Health data. Re-granting Health
  permissions is not a restore of Health records.
- **Comparison rules:** all 15 entity tables in the copied current schema are selected. The excluded
  `Z_` tables are metadata/model cache/primary-key bookkeeping; no excluded relationship join table
  exists in this schema. `ACHANGE`, `ATRANSACTION` and `ATRANSACTIONSTRING` are history bookkeeping;
  no app history-token consumer was found. Ignoring `Z_OPT`, normalizing `Z_ENT` by name, and matching
  `Z_PK` are appropriate for this same-schema physical restore. This is not a general schema-migration
  comparator. Value comparisons happen before display truncation, including BLOB values. Added rows,
  columns and tables deliberately allow exit 0 and still require human inspection; exit 0 does not
  mean no differences. Post-launch preferences/files are outside the store comparison and need their
  own settings check. Checksum verification covers them before launch.
- **Claims and pending evidence:** the Simulator rehearsal supports store restoration, not paid signing,
  phone copy commands, or the TestFlight/development round trip. The same-identifier in-place update
  is a reasonable expected path, but the actual paid artifacts and install behavior remain unverified.
  Compare signed `application-identifier` values rather than inferring them solely from Team ID:
  [Apple QA1879](https://developer.apple.com/library/archive/qa/qa1879/_index.html) explains that App ID
  prefix and Team ID are not invariably identical. The development-build backup rule is consistent
  across ticket/spec/D60/DEVELOPMENT; finding 6 addresses its unsafe missing details. Neither
  TestFlight container-copy restrictions nor post-revocation access were exercised in this review.

## Verification evidence

All new executions used copies under `/tmp/wt-beta01-codex-review/` (directory mode 0700).
No phone, Apple account or `~/WorkoutTracker-Backups` operation was performed. Only this report was
written in the repository; the pre-existing untracked review prompt was left untouched.

- Independently inspected Claude's build artifacts under
  `/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-public-beta/d61f90bf-e3f8-44b7-845e-3831238bedab/scratchpad/b01/`.
  `results/device-build-free.exit` is **0**; its log contains CLEAN and BUILD SUCCEEDED.
  Debug and Release Simulator logs contain BUILD SUCCEEDED. Inspected actual device/Release
  Simulator app/widget plists: Stacked, expected bundle IDs, encryption false, Health/camera strings,
  all three background modes and widget NSExtension are present. No new build or launch was needed.
  Independent signature verification was not established: the standards review's sandboxed
  `codesign` check returned `CSSMERR_TP_NOT_TRUSTED`; this was not treated as a source defect.
- Inspected R1/R2 prelaunch and comparison reports and reran checks on a copy of R2's baseline.
  Baseline integrity, identical-store comparison and matching restore set exited **0**; 15 tables,
  24 workouts, 343 sets, 2 templates, zero unfinished. Source-copy hashes stayed unchanged.
- Deleted set, changed reps, missing table and removed column: comparison exit **1** each.
  Changed preferences byte: `--expect` exit **1**. Changes limited to `Z_OPT`, consistent `Z_ENT`
  renumbering, or A-table history: comparison exit **0**, as intended. Added row: exit **0** with
  the addition reported. Changed preferences alone: store comparison exit **0**, confirming its scope.
- WAL false-pass reproducer and per-command exits: `/tmp/wt-beta01-codex-review/run_checks.py`,
  `results.json`, and named `.stdout`/`.stderr` files. Probe false-pass evidence:
  `probe_changed_expect.stdout`. No original database was opened by SQLite.

Safer sequence: establish stable fresh backups and a verified device-copy preflight before Support can
invalidate provisioning; renew the free profiles while possible; prepare and inspect the paid build;
repeat the current-data backup gate immediately before the separately approved deletion; install without
launch, restore/check bytes, then launch and compare rows/settings. Take the final development backup before
TestFlight and establish the compatible, no-launch bridge for later backups. Do not waive failed gates
because the enrollment or expiry deadline is close.

Summary: Standards — 2 findings, worst P2. Spec/data safety — 4 findings, worst P1.

Verdict: not clear
