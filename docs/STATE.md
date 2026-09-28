# Current project state

## ACTIVE (2026-09-26, session 2): implementing the Floodlight redesign

Worktree `/Users/ericlee06/orca/workspaces/Health App/redesign-floodlight`, branch
`ericlee4992/redesign-floodlight` (pushed). Read [ticket 01](../work-record/redesign-floodlight/issues/01-implement-redesign.md)
**Progress → Handoff** first: branch/commit map, what is verified, next steps.
Claude implements, Codex reviews (visible Orca terminal, one per ticket). Nothing merged to
`main` (a0364f2); nothing installed. Install blockers unchanged (Xcode Apple ID, expired signing).

- **Ticket 02** (foundation + Workout tab): this branch, **Codex clear after 3 rounds**.
- **Ticket 03** (live workout): stacked branch `ericlee4992/redesign-floodlight-live`
  (pushed `0ca7868`). **Codex clear after 3 rounds** (`codex-review-03c.md`).
- **Ticket 04** (finish receipt): `ericlee4992/redesign-floodlight-finish` (pushed, stacked on
  the live tip). **Codex clear after 3 rounds** (`codex-review-04c.md`).
- **Ticket 05** (History — list/month card/weeks, calendar, detail, edit set, progress chart;
  the heart-rate plate with zones inside, shared with the receipt): branch
  `ericlee4992/redesign-floodlight-history` (pushed, stacked on the finish tip), scratch checkout
  `/tmp/wt-floodlight/history`. **Codex clear after 3 rounds** (`codex-review-05c.md`; tip
  `ericlee4992/redesign-floodlight-history` pushed). Last runs: `history-ui-8` exit 0, earlier
  batches recorded in `issues/05-history.md` Verification. The pre-existing
  History HR test (HeartRateSummary :66) now passes. User decisions 2026-09-27: notes on the
  detail, shown and editable as a MARKED edit (reopens D47 — record with the D54 entry);
  empty History follows the prototype (no calendar until the first workout; Start Lifting).
- **Ticket 06** (Gyms — list, gym page, new machine page, edit gym, model picker, new model,
  deleted machines): branch `ericlee4992/redesign-floodlight-gyms` (pushed, tip `d45d5c5`, stacked
  on the history tip), scratch checkout `/tmp/wt-floodlight/gyms`. **Codex clear after 3 rounds**
  (`codex-review-06c.md`; review terminal closed). Record: `issues/06-gyms.md` on that branch.
  User decisions 2026-09-27: Scan screens split into **ticket 07**; Add Machine… keeps its form
  (restyled). Verification: `gyms-ui-1`..`gyms-ui-5` (final runs exit 0; every targeted test passed
  in final form); captures `captures/06/`. Also fixed: the pre-existing iOS 27 CoreLoop :252
  model-picker failure, and a clean-build failure in ticket 05's progress view.
- **Ticket 07** (Scan — Scan Machine sheet, Read Label, Correct Model): branch
  `ericlee4992/redesign-floodlight-scan` (pushed, tip `7655aa7`, stacked on the gyms tip
  `d45d5c5`), scratch checkout `/tmp/wt-floodlight/scan`. **Codex clear after 2 rounds**
  (`codex-review-07b.md`; review terminal closed). Record: `issues/07-scan.md` on that branch.
  User decisions 2026-09-27: Scan Machine (gym page, routine setup) **adds directly** with an
  Added step (the form's own scan still fills the form); photo consent stays **before** the
  camera; ambiguous stays D56 (listed, no pick); no picker Scan pill / scope alert. Verification:
  `scan-unit-3` (66/66, fresh derived data), FloodlightScan 19/19 + 3 flows, AskAI /
  ScanMachineLabel / CoreLoop / GymsFlows / MachineDeletion; captures `captures/07/` (90).
  Fixed along the way: a correction-timeline layout loop at AX sizes (also in the prototype).
  **Open, not ticket 07's:** two AX AI-routine-form AskAI tests fail identically on the gyms tip
  (`scan-baseline-1`) — for the AI routine area or the release-candidate suite. Record user
  decision 1 (scan confirmation moves to the sheet's Add) with the D54 entry before merge.
- **Ticket 08** (Exercises, E01–E05): branch `ericlee4992/redesign-floodlight-exercises` (pushed, tip
  `bf4363b`, stacked on the scan tip `7655aa7`), scratch checkout `/tmp/wt-floodlight/exercises`. **Codex
  clear after 2 rounds** (`codex-review-08b.md`; review terminal closed). Record: `issues/08-exercises.md`
  on that branch. User decisions 2026-09-27: Exercise Detail (new) opens from the tab AND the machine page's
  exercise rows; presets keep reordering (Edit); Load Type takes the prototype's shortened copy; New Exercise
  gets Body area and refuses a taken name — record these with the D54 entry before merge. Verification:
  unit 20/20 (`exercises-unit-4`), the whole `FloodlightExercisesUITests` class (`-ui-13` 9/10 + `-ui-14`),
  neighbours (ProgressChart, Tooltip, GymsFlows, ExercisePreset, CoreLoop creation, RedesignScreenshot
  05–07); captures `captures/08/` (91). Shared changes: `WrapLayout` 0.5 pt slack, `SearchFieldView`
  identifier, `ExercisesSheetHeader` Done = `sheetDone`. Not exercised: VoiceOver by a person, runtime
  Reduce Motion, the drag-reorder gesture (release-candidate pass).
- **Ticket 09** (Settings, X01–X03): branch `ericlee4992/redesign-floodlight-settings` (pushed, tip `c286b59`,
  stacked on the exercises tip `bf4363b`), scratch checkout `/tmp/wt-floodlight/settings`. **Codex clear after
  2 rounds** (`codex-review-09b.md`; review terminal closed). Record: `issues/09-settings.md` on that branch.
  User decisions 2026-09-28: last export recorded only when the share sheet completes (per-device
  `@AppStorage`, not SwiftData/export format); Export opens the share sheet at once and keeps a file card with
  Share; the saved key shows its last 4 characters; the Ask AI disclosure paragraph is dropped — record these
  with the D54 entry before merge. Verification: unit 33/33 (`ExportRecordTests` 10, `ExportTests` 23), the
  whole `FloodlightSettingsUITests` class (`settings-ui-5` 11/11 on the round-1 code; round 2 `-ui-6` 11/12 +
  `-ui-7` 6/6 for the one typing case), neighbours (Export, AskAI key settings ×2, HR zones, Appearance, unit
  system ×2, test05); captures `captures/09/` (50). Not exercised: VoiceOver by a person, runtime Reduce
  Motion, a real device (release-candidate pass).
- **Ticket 10** (Ask AI for Templates, A01–A05): IN PROGRESS (2026-09-28, same session as ticket 09 at the
  user's request). Branch `ericlee4992/redesign-floodlight-ai-routine` (pushed, stacked on the settings tip
  `c286b59`), scratch checkout `/tmp/wt-floodlight/ai-routine`, runner `/tmp/wt-floodlight/ai-run.sh`
  (derived data `dd-ai`). Record: `issues/10-ai-routine.md` on that branch (progress, verification, next step).
  User decisions 2026-09-28: generating shows the prototype's timed percentage/stages (holds at 90 % until
  the reply); a Saved step after Save templates; leaving any unsaved week asks first; the optional profile
  follows the unit setting — record with the D54 entry before merge. Prototype captured into
  `reference/prototype-ai/{dark,light}/` (76 PNGs, all with content).
- User decisions 2026-09-26: New bests one line per exercise (record scope) as in the prototype;
  zones under the heart-rate chart; AX New best replaces the Rest text (prototype). Recorded
  in tickets 03/04.
- Pre-existing iOS 27 UI failures: all four known ones are fixed (three by `revealedSearchField()`
  in ticket 03, History HR in ticket 05, the Gyms model picker in ticket 06).

Updated **2026-09-24** for a new session. Main/remote were verified at **40f3f65** before this
docs-only handoff; verify actual Git HEAD on resume. Product **9f733a2**, built from source
**7e96a82**, was installed September 22. Later documentation commits do not change that binary.
Handoff branch: `ericlee4992/session-handoff-sep24`; user explicitly waived Claude review for
this handoff only. [Prior STATE](archive/STATE-2026-09-24-before-session-handoff.md) is archived
byte-for-byte. No product edits, API requests, phone connection, renewal or reinstall in this handoff.

## Next action — signing first, then device acceptance

Active ticket: [06 — private device acceptance](../work-record/ai-gym/issues/06-device-acceptance.md).

1. **Check the current time against signing expiry before assuming the app can launch.** App and
   widget profiles expire **September 24 at 03:16:18 /03:16:20 EDT (07:16:18 /07:16:20 UTC)**.
   Embedded profiles were re-read today; at the 05:08 UTC audit they were still valid but due
   within hours. If expired on resume, follow [provisioning renewal](DEVELOPMENT.md#provisioning-expiry)
   for both profiles and a newly signed build, with a fresh backup if phone data has changed.
   Reinstalling the existing binary does not renew signing. No renewal has been performed.
2. Collect post-update phone feedback: all newly generated templates visible without restart;
   Scan Machine inside template setup; preserved preferences/equipment updates; visual confirmation
   of old history. These checks have **not been reported since the September 22 installation**.
   AI template generation was already reported before that update; key/billing setup is working.
   Do not ask for the secret in chat or repeat funding/key setup without a new actual error.
3. Continue actual gym recognition/routine feedback under ticket 06. Keep the separate
   [cardio hardware checks](../work-record/cardio/issues/02-device-acceptance.md) open. No new
   feature, public backend or App Store work is requested. No build/test job remains active.

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
