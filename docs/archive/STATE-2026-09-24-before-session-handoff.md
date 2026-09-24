# Current project state

Updated **2026-09-22** after user-authorized installation. Verified product **9f733a2** from
source **7e96a82** is now installed and launch-verified on the phone (September 22, ~02:50 EDT).
Main/remote contain source delivery **7e96a82**; later docs-only commits record installation.
Installation-record branch: `ericlee4992/install-ai-followup-sep22` (standard fast-forward workflow).
The [pre-install handoff](archive/STATE-2026-09-22-before-followup-install.md) is archived byte-for-byte.

## Next action

Active ticket: [06 — private device acceptance](../work-record/ai-gym/issues/06-device-acceptance.md).
Software follow-up [07](../work-record/ai-gym/issues/07-template-visibility-and-scanning.md) is
implemented, verified, independently cleared, merged and pushed. No build/test job remains active.

1. Collect real machine/routine feedback, verify new templates remain visible without restart,
   and obtain visual confirmation of old history after this update. User already reports actual AI template creation; do not repeat key/billing setup.
   Keep the separate [cardio physical checks](../work-record/cardio/issues/02-device-acceptance.md) open.
2. Signing expires **September 24 at 03:16 EDT (07:16 UTC)**. Check expiry before any install;
   renewal needs a newly signed build. This installation reused the still-valid profiles;
   it did not extend their expiry.

Completed follow-up: reproduced the blank first two template cards on iOS 27 (older 26.5 passed),
then fixed the nested lazy-grid rendering while preserving save/query logic. **Ask AI for Templates**
now includes gym selection/addition and **Scan Machine**, using one AI label/whole-machine photo
flow with editable confirmation. Preferences survive scan/cancel; confirmed machines update
eligibility immediately and persist independently of cancelling an unsaved routine.

Verification: **42 domain tests, 14 distinct iOS 27 UI cases**, two iOS 26.5 compatibility cases,
clean/final simulator builds, **26 real captures**. Passing runs have actual exit 0 and zero
failed/skipped tests. [Claude clearance](../work-record/ai-gym/claude-followup-final-review.md),
[gallery](../work-record/ai-gym/followup-gallery.html), and ticket 07 retain failed attempts and
actual result paths. No schema change or new live API call. Installation is recorded below.
The prior non-failing invalid-frame warning and hosted CI investigation remain deferred.

[Verification and delivery record](../work-record/ai-gym/issues/05-verification-review.md),
[final independent clearance](../work-record/ai-gym/claude-final-review-addendum.md), and
[54 real UI captures](../work-record/ai-gym/gallery.html).

## AI scope — implemented, tested, independently reviewed and merged

[Specification and tickets](../work-record/ai-gym/spec.md), decisions **D56–D58**:
- GPT-5.6 Terra only, private trial. One consented photo of a label or whole machine proposes an
  editable identity and exercises. Generic/ambiguous identity stays model-less and gym-local;
  exact catalog resolution and user confirmation preserve physical-machine history. Explicitly
  edited names survive catalog defaults. Manual/on-device entry remains available offline.
- Secondary **Ask AI for Templates** below Templates opens a separate flow for an editable weekly set of
  lifting/cardio templates. Goals, experience, schedule, optional height/weight, saved gym
  machines and confirmed extra equipment constrain the request. No AI weight guesses or guides.
- Planned cardio/rest/reps are separate from performed data. Explicit cardio Start, atomic week
  save, cancellation/consent and schema-11 JSON export are implemented. Existing manual templates
  keep their startup behavior; an AI-created template at its original gym can use the sole
  compatible machine when there is no remembered active choice.
- OpenAI key is device-only Keychain; three revocable local consents. No key in Git or binaries.
  Whole-machine classification remains fallible (g010 sample); no physical accuracy pass claimed.
  Backend/shared-key public access, App Store release and visual guides remain deferred.

## Verification and build

| Evidence | Result |
|---|---|
| Simulator build | Successful, including clean build and built camera/photo permission-string inspection |
| Full domain suite | **773/773 passed**, exit 0, zero failed/skipped; later AI/template follow-up **29/29**, edited-name/final preservation suites **23/23** each; final polish domain **30/30** |
| UI scope | **36 distinct cases have passing evidence**, including adjacent logging, cardio, history/template, export and offline scanner flows; final polish **13/13** passed, zero failed/skipped; initial failures/reruns retained in ticket 05 |
| UI captures | [54 real Default/AccessibilityL captures](../work-record/ai-gym/gallery.html), same fixtures per pair, including consent, identity states, routine editing, templates and active plans |
| Independent review | Claude spec, code, final evidence/UI reviews and addendum clear product `9b0a61a` for private-trial merge; no blocking findings |
| Live API | Terra key/model verified after user funded API credits; production-format photo and 3-/7-day routine requests completed. Seven-day request: 10.14 s. Recognition limitations remain explicit |
| Migration | Synthetic store generated from installed-era `8c71d27`; additive migration preserves old history/templates/units and new-field defaults. Prior legacy fixtures also passed |
| Signed iPhone build | `/tmp/wt-ai-followup-device-20260922/Build/Products/Debug-iphoneos/WorkoutTracker.app`; build exit 0; new eager-grid/scanner symbols and entry strings, app/widget signatures, bundle IDs, usage strings and profiles verified; installation and launch exit 0 September 22 |

Actual exit files and xcresult summaries were read. The 0-test discovery attempt, simulator
Busy/preflight failure and interrupted overlapping test jobs are not passing evidence. Non-failing
invalid-frame warnings remain uninvestigated, as in prior work. Hosted CI investigation stays deferred.

## Installed phone and backup

- Installed source **7e96a82**, product **9f733a2**, September 22 at approximately 02:50 EDT.
  Install and remote launch exit 0. Confirmation launch exit 0; app process **17112** observed
  running from the new bundle `B3D551F5-560C-46B0-906B-A4B7489D58B9` after launch.
  Before installation, app was not running and the verified backup had no unfinished workout.
- Earlier AirPods Pro 3 indoor distance and outdoor map feedback applies to an earlier cardio
  build; pause/reconnect, phone-position accuracy and background GPS remain unverified.
  [Cardio acceptance](../work-record/cardio/issues/02-device-acceptance.md).
- Phone: iPhone 15 Pro Max, iOS **27.0 (24A437)** (read-only device-info check September 22), `00008130-001E10C01E62001C`; bundle
  `com.ericlee4992.workouttracker`, team `X68M8SR6NA`. App/widget profiles expire
  **2026-09-24 07:16:18 / 07:16:20 UTC**. Xcode 27.0; simulator WT-iPhone; signing config ignored.
- Installed export schema **11**, unchanged. After-launch phone-store copy passes integrity;
  every old row, attribute and relationship across 15 app tables matches the fresh backup,
  excluding internal Z_OPT counters and normalizing Z_ENT through entity names. All **24 workouts,
  343 sets and 2 templates** preserved. Visual history confirmation and backup restore remain unverified.
- Fresh private backup `/Users/ericlee06/WorkoutTracker-Backups/2026-09-22-before-ai-followup`:
  **27 raw files /31,286,447 bytes**; access-restricted, all three SQLite databases pass integrity
  on verification copies, SHA-256 master hashes unchanged after preservation comparison.
  September 20 and September 18 backups retained. No fresh portable JSON/CSV export claimed;
  last reported in-app iCloud CSV/JSON export was September 4.
- Prior accepted UI remains: amber side-by-side Start capsules when labels fit, responsive stacking;
  maps only in finished Summary/History; no duplicate automatic indoor-source row; app unit system
  affects only new cardio activities. Watch companion has never been built/run/installed; cardio
  on Watch remains outside this release.

## Workspace and remaining work

- Follow-up implementation/results: `/Users/ericlee06/orca/workspaces/Health App/ai-template-followup`;
  ignored `work-record/ai-gym/results/followup/` holds scripts, actual exits/logs/xcresults. Review
  checkout `ai-template-followup-review` retained. UI regression simulator **WT-iPhone27** is
  iPhone 15 Pro Max / iOS 27.0 (24A434), UDID `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`;
  older WT-iPhone / iOS 26.5 retained for compatibility. Graft structural index refreshed.
- Main: `/Users/ericlee06/orca/projects/Health App`. Prior AI implementation/results:
  `/Users/ericlee06/orca/workspaces/Health App/ai-gym-and-routines`; ignored
  `work-record/ai-gym/results/` contains scripts, actual exits/logs/xcresults and signed-build checks.
  Mac credential is in the private `~/.config/workouttracker/openai.env` (0600), outside Git.
  File existence/permissions rechecked September 22 without reading its contents.
- Current install/launch logs and actual exits are in main's ignored
  `work-record/ai-gym/results/device-install-20260922/`; private copies/comparison report stay
  beside the fresh backup outside Git. Device installation changed no product code; existing
  independent clearance and verified build/domain/UI results apply.
- Preserve the implementation, baseline and independent-review checkouts. Existing cardio install
  evidence remains in main `work-record/ui-redesign/results/*-install/`; unit/UI artifacts in
  `cardio-units-and-sources`, original cardio/migration artifacts in `cardio-implementation`.
- Prior completed worktrees/terminal histories and their ignored artifacts remain. Actual Orca
  workspace Sleep is still unverified after earlier menu/focus failures. The three old untracked
  review-copy sets remain documented in the [prior handoff ticket](../work-record/codex-setup/issues/03-session-handoff.md).
- [Deferred work](../work-record/deferred-work.md) preserves all scanner, picker, lifting/history,
  calculation, supersets, precision, migration, HR, Watch, catalog, App Store and CI follow-ups.
  Consult the list rather than starting everything. 35 project-local skills remain installed;
  personal Codex settings unchanged. Graft structural index refreshed; optional AI summaries unbuilt.
