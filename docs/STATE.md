# Current project state

Updated **2026-09-22** for a fresh session. Main/remote checkpoint **9d84c1d** includes the
installation record; product code **9b0a61a** was delivered at **0c87a6f** and installed September 20.
Documentation handoff branch: `ericlee4992/session-handoff-sep22` (standard fast-forward-to-main
workflow). Verify actual HEAD/remote on resume; later documentation commits do not change the
installed binary. User explicitly waived Claude review for this handoff only.
The [pre-AI handoff](archive/STATE-2026-09-20-before-ai-gym.md) is preserved byte-for-byte.

## Next action

Software implementation, verification, independent review, installation and remote launch are
complete. Active ticket: [06 — private device acceptance](../work-record/ai-gym/issues/06-device-acceptance.md).

1. Ask whether the user has entered the existing OpenAI key in the phone's Settings and tried
   the new features. Key entry and post-update visual history confirmation are **not reported**.
   The user was shown how to open `~/.config/workouttracker/openai.env` on the Mac and copy
   only the value after `OPENAI_API_KEY=`. Never print the secret or ask for it in chat.
   Credits were already added and live Terra requests succeeded; do not repeat billing setup
   unless a new actual API error warrants it. The Mac key is not bundled/provisioned to the phone.
2. Collect actual gym recognition and routine-generation feedback under ticket 06, preserving
   the separate open cardio hardware checks. No new feature or public backend work is requested.
3. Signing expires **September 24 at 03:16 EDT (07:16 UTC)**. If continuing on/after that date,
   check expiry first; renewal/reinstallation follows [DEVELOPMENT](DEVELOPMENT.md#provisioning-expiry)
   with a fresh backup if workouts have changed. Reinstalling the existing binary does not renew it.

No local build/test job remains active (rechecked September 22). This handoff did not reconnect
to or change the phone, call the API, renew profiles, or start another agent session.

[Verification and delivery record](../work-record/ai-gym/issues/05-verification-review.md),
[final independent clearance](../work-record/ai-gym/claude-final-review-addendum.md), and
[54 real UI captures](../work-record/ai-gym/gallery.html).

## AI scope — implemented, tested, independently reviewed and merged

[Specification and six tickets](../work-record/ai-gym/spec.md), decisions **D56–D58**:
- GPT-5.6 Terra only, private trial. One consented photo of a label or whole machine proposes an
  editable identity and exercises. Generic/ambiguous identity stays model-less and gym-local;
  exact catalog resolution and user confirmation preserve physical-machine history. Explicitly
  edited names survive catalog defaults. Manual/on-device entry remains available offline.
- Secondary **Ask AI** below Templates opens a separate flow for an editable weekly set of
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
| Signed iPhone build | `/tmp/wt-ai-device/Build/Products/Debug-iphoneos/WorkoutTracker.app`; build exit 0; fresh Terra/routine symbols, app/widget signatures and profiles reverified; installed and remote launch exit 0 September 20 |

Actual exit files and xcresult summaries were read. The 0-test discovery attempt, simulator
Busy/preflight failure and interrupted overlapping test jobs are not passing evidence. Non-failing
invalid-frame warnings remain uninvestigated, as in prior work. Hosted CI investigation stays deferred.

## Installed phone and backup

- Installed source **0c87a6f**, product **9b0a61a**, September 20 at approximately 14:11 EDT.
  Install and remote launch both exit 0; app process **9606** observed then from the new bundle.
  Before updating, user confirmed the old app opens and old workouts are present.
- Earlier AirPods Pro 3 indoor distance and outdoor map feedback applies to an earlier cardio
  build; pause/reconnect, phone-position accuracy and background GPS remain unverified.
  [Cardio acceptance](../work-record/cardio/issues/02-device-acceptance.md).
- Phone: iPhone 15 Pro Max, `00008130-001E10C01E62001C`; bundle
  `com.ericlee4992.workouttracker`, team `X68M8SR6NA`. App/widget profiles expire
  **2026-09-24 07:16:18 / 07:16:20 UTC**. Xcode 27.0; simulator WT-iPhone; signing config ignored.
- Installed export schema **11**. After-launch phone-store copy passes integrity; every old row,
  attribute and relationship across 15 app tables matches the fresh pre-install backup, excluding
  internal Z_OPT counters and normalizing Z_ENT through entity names. All 23 workouts/335 sets
  preserved. Visual post-update history confirmation and backup restore remain unverified.
- Fresh private backup `/Users/ericlee06/WorkoutTracker-Backups/2026-09-20-140830-before-ai`:
  24 raw files /26,745,283 bytes; database integrity and SHA-256 verified, master hashes unchanged
  after comparison; all 24 master hashes reverified September 22. No fresh portable JSON/CSV export claimed. September 18 backup and its
  JSON/CSV remain. Last reported in-app iCloud CSV/JSON export was September 4.
- Prior accepted UI remains: amber side-by-side Start capsules when labels fit, responsive stacking;
  maps only in finished Summary/History; no duplicate automatic indoor-source row; app unit system
  affects only new cardio activities. Watch companion has never been built/run/installed; cardio
  on Watch remains outside this release.

## Workspace and remaining work

- Main: `/Users/ericlee06/orca/projects/Health App`. Implementation/results:
  `/Users/ericlee06/orca/workspaces/Health App/ai-gym-and-routines`; ignored
  `work-record/ai-gym/results/` contains scripts, actual exits/logs/xcresults and signed-build checks.
  Mac credential is in the private `~/.config/workouttracker/openai.env` (0600), outside Git.
  File existence/permissions rechecked September 22 without reading its contents.
- Current install/launch logs and actual exits are in main's ignored
  `work-record/ai-gym/results/device-install-20260920/`; private copies/comparison report stay
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
