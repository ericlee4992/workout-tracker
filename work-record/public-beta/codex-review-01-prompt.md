You are the independent reviewer (AGENTS.md T6) for public-beta ticket 01, Prepare phase. Claude implemented it.
Repository: /Users/ericlee06/orca/workspaces/Health App/public-beta, branch ericlee4992/beta-01-paid-team.
Diff under review: `git diff bab270b..37efb6c` (main is bab270b).

Read first: AGENTS.md; work-record/public-beta/issues/01-paid-team-testflight.md (the plan, phases A–E, and the
Progress → Prepare evidence); work-record/public-beta/spec.md → "Data safety on the developer's phone";
D60 in docs/DECISIONS.md; docs/DEVELOPMENT.md → "Real-device installation", "Provisioning expiry", and the new
"Container backup and restore"; work-record/public-beta/apple-support-request.md.

Context: the user's iPhone holds the only copy of their history (24 workouts, 343 sets). Signing moves from the
free Personal Team X68M8SR6NA to a paid team (enrollment pending) while keeping bundle ID
com.ericlee4992.workouttracker. iOS refuses to upgrade across team IDs, so phase D is: verified container backup
→ user deletes the app → install the paid-team development build without launching → copy the restore set into
its container → checksum check → launch → row-by-row comparison. Free profiles expire 2026-10-06 08:45 UTC.

Review, with concrete file:line evidence:
1. The config diff (project.pbxproj DEVELOPMENT_TEAM → "$(WT_DEVELOPMENT_TEAM)", CFBundleDisplayName = Stacked,
   ITSAppUsesNonExemptEncryption in Config/WorkoutTracker-Info.plist): correct for device, Simulator and CI
   builds? Anything that still hard-codes the team, or that depends on the app's name?
2. scripts/container-tools/verify_container.py and compare_stores.py: correctness of the WAL/SHM handling on
   copies, the restore set (is anything that holds user data or settings missing — e.g. other SwiftData/stores,
   App Group containers, Keychain, HealthKit, files the app writes elsewhere? check the app's code), the
   comparison rules (Z_OPT ignored, Z_ENT by name, A* tables skipped, Z_PK matching), and exit codes. Could
   either script report success when data was lost or changed?
3. The phase A–E procedure: ordering, stop points, the irreversible step, the unconfirmed devicectl path forms,
   the TestFlight-over-development claim, the backup-on-TestFlight rule, and what happens if Apple Support
   deletes the Personal Team App IDs. Is any claim stated as fact without evidence? Is there a safer order?
4. Consistency between the ticket, spec, D60, DEVELOPMENT and STATE.

Rules: do not modify any file except the report; do not touch the phone, Apple accounts or
~/WorkoutTracker-Backups (reading is fine, but run the scripts only on copies outside that folder). You may
build or run the scripts on copies in /tmp. Write the report to
work-record/public-beta/codex-review-01.md: numbered findings with severity (P0 data loss … P3 nit), file:line,
the failure scenario, and a suggested fix; then a last line that is exactly "Verdict: clear" or
"Verdict: not clear".
