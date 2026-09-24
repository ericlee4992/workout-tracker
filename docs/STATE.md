# Current project state

Updated **2026-09-24** for the user-requested whole-app redesign **visual proposal**.
Base/main/live remote verified at **a0364f2c93ebb0ebbfd1e28b8847aa79b304d0fd**.
Proposal commit: **a1242db**, committed/pushed on `ericlee4992/redesign-visual-proposal`;
product code remains unchanged. New work is the design artifact and its records; check actual
Git status on resume (later checkpoint commits only update these records). The user wants visuals
before implementation. No native redesign, build/test run, API request, phone connection or install.
Product **9f733a2**, built from source **7e96a82**, remains the last verified September 22 install.
[Pre-redesign STATE](archive/STATE-2026-09-24-before-redesign-proposal.md) is archived byte-for-byte.

## Next action — review the visual direction

Active ticket: [01 — whole-app visual direction](../work-record/redesign-2026/issues/01-visual-direction.md).
The [interactive proposal](../work-record/redesign-2026/visuals/workout-redesign.html) covers 36
screen/state compositions with sample data. Three home structures: Focus (recommended), Library,
Journal. Light/dark and enlarged-text mock layouts are available. Browser checks opened all
36 at regular/narrow widths and enlarged text; actual exit 0, no JS exceptions or horizontal
overflow. Captures and limitations are in the ticket. This is **not** a native AccessibilityL pass.

User chooses/refines direction before product edits. D54 is explicitly reopened for exploration;
the proposed palette, copy and composition are not yet accepted. No independent clearance,
merge or install of the proposal. After selection, complete detailed state designs and native
captures, then implementation tickets, appropriate tests and Claude review. Device acceptance
and signing remain open background work, not actions requested during this design task.

## Outstanding device acceptance

[06 — private device acceptance](../work-record/ai-gym/issues/06-device-acceptance.md) remains open.

1. Recorded app/widget profiles **expired September 24 at 03:16:18 /03:16:20 EDT
   (07:16:18 /07:16:20 UTC)**; current time checked at 07:18 UTC. No renewal or fresh phone check.
   Before device use/install, follow [renewal](DEVELOPMENT.md#provisioning-expiry) for both
   profiles, a newly signed build and backup as needed. Reinstalling the old binary does not renew signing.
2. Collect post-update phone feedback: all newly generated templates visible without restart;
   Scan Machine inside template setup; preserved preferences/equipment updates; visual confirmation
   of old history. These checks have **not been reported since the September 22 installation**.
   AI template generation was already reported before that update; key/billing setup is working.
   Do not ask for the secret in chat or repeat funding/key setup without a new actual error.
3. Continue actual gym recognition/routine feedback under ticket 06. Keep the separate
   [cardio hardware checks](../work-record/cardio/issues/02-device-acceptance.md) open. No new
   backend or App Store work is requested. No build/test job remains active.

## Delivered software and verification

[07 — template visibility and scanning](../work-record/ai-gym/issues/07-template-visibility-and-scanning.md)
is implemented, tested, independently cleared, merged, pushed and installed:

- iOS 27 blank first template row reproduced with saved data intact; eager rows replace the
  nested lazy grid. The same original case passed on iOS 26.5: match the phone runtime for UI work.
- **Ask AI for Templates** includes gym selection/addition and **Scan Machine** at any saved-machine
  count. One AI photo flow accepts a label or whole machine and retains editable confirmation.
  Preferences survive scan/cancel; confirmed machine saves persist independently of routine cancellation.
- **42 domain tests, 14 distinct iOS 27 UI cases**, two iOS 26.5 compatibility cases, clean/final
  simulator builds; **26 real Default/AccessibilityL captures**. Passing runs have actual exit 0,
  zero failed/skipped tests. Actual exits and xcresult summaries re-read September 24; no new tests run.
- [Claude clearance](../work-record/ai-gym/claude-followup-final-review.md) covers product **9f733a2**,
  capture/evidence **dcf445f**, documentation **1ff72d1**. [Gallery](../work-record/ai-gym/followup-gallery.html).
  Failed attempts, screenshot/OCR corrections and optional-diagnostic interruption remain in ticket 07.

D56–D58 and the [AI spec](../work-record/ai-gym/spec.md) remain authoritative: Terra only, private
trial, device-only Keychain key and three revocable consents; no starting-weight guesses; explicit
cardio Start; atomic template-week save; schema-11 export. Generic recognition stays gym-local and
model-less, preserving physical-machine history. Whole-machine recognition is fallible (g010 miss);
no physical accuracy pass claimed. Manual/offline entry remains. Prior full-AI verification and
migration evidence are retained in [ticket 05](../work-record/ai-gym/issues/05-verification-review.md)
and the archived STATE; do not confuse those prior full suites with the targeted follow-up scope.

## Last verified installation and backup

- **September 22 ~02:50 EDT:** source **7e96a82**, product **9f733a2**. Fresh device build, install,
  launch and confirmation launch all exit 0; process **17112** observed then from the new bundle
  `B3D551F5-560C-46B0-906B-A4B7489D58B9`. This is historical launch evidence, not a fresh phone check.
- Phone last checked: iPhone 15 Pro Max, iOS **27.0 (24A437)**, UDID `00008130-001E10C01E62001C`;
  bundle `com.ericlee4992.workouttracker`, team `X68M8SR6NA`. App/widget profile expiry is above.
  Prepared binary still exists at `/tmp/wt-ai-followup-device-20260922/Build/Products/Debug-iphoneos/WorkoutTracker.app`;
  it needs fresh signing after expiry. Config/Local.xcconfig is ignored.
- Before install, app was not running and store had no unfinished workout. After-launch integrity
  and comparison preserved every old row, attribute and relationship across **15 app tables**:
  **24 workouts, 343 sets, 2 templates** (ignore Z_OPT; normalize Z_ENT through entity names).
  This verifies data preservation; visual history acceptance and tested restore remain outstanding.
- Private backup: `/Users/ericlee06/WorkoutTracker-Backups/2026-09-22-before-ai-followup`;
  **27 raw files /31,286,447 bytes**, mode 0700. Three databases passed integrity on copies;
  all 27 original SHA-256 hashes reverified unchanged September 24. Comparison report retained beside it.
  Older September 20/18 backups remain; no new portable JSON/CSV export claimed. Last reported
  in-app iCloud CSV/JSON export was September 4.

## Evidence locations and remaining work

- Main: `/Users/ericlee06/orca/projects/Health App`; current install logs/JSON/actual exits:
  ignored `work-record/ai-gym/results/device-install-20260922/`.
- Follow-up worktree: `/Users/ericlee06/orca/workspaces/Health App/ai-template-followup`;
  ignored `work-record/ai-gym/results/followup/` holds builds, tests, raw captures and actual exits.
  UI regression simulator **WT-iPhone27**, iPhone 15 Pro Max / iOS 27.0 (24A434),
  `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`; WT-iPhone / iOS 26.5 retained for compatibility.
- Earlier AI, schema-baseline, cardio implementation and independent-review checkouts/artifacts
  remain. The initial 31-checkout read-only audit found no tracked modifications; four reviewer checkouts
  retain untracked reports (details in ticket 06). Do not clean them or discard terminal histories.
- Mac credential `~/.config/workouttracker/openai.env` exists, mode 0600 rechecked; contents not read.
  It is not bundled/provisioned to the phone. This handoff did not change personal settings or skills.
- All scanner/picker, history/calculation, supersets, precision, migration/restore, HR, Watch,
  catalog, public launch and CI follow-ups remain in [deferred work](../work-record/deferred-work.md).
  Cardio: earlier indoor distance/outdoor-map feedback does not verify pause/reconnect,
  phone-position accuracy, background GPS or mixed-session behavior. Watch companion has never
  been built/run/installed and remains outside this release. Non-failing invalid-frame warnings,
  hosted CI investigation and actual Orca workspace Sleep remain unresolved/deferred.
- Graft structural index was refreshed at delivery; optional AI summaries remain unbuilt.
