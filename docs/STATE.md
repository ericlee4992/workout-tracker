# Current project state

Updated 2026-09-20 for AI delivery. Product code **9b0a61a** on
`ericlee4992/ai-gym-and-routines`; independently cleared and fast-forwarded into **main** at
**5895103**, with final documentation checkpoints following. Verify actual HEAD/remote on resume.
The [pre-AI handoff](archive/STATE-2026-09-20-before-ai-gym.md) is preserved byte-for-byte.

## Next action

Software implementation, verification and independent review are complete. Follow
[private device acceptance](../work-record/ai-gym/issues/06-device-acceptance.md): confirm the
currently installed app opens and old workouts are intact, obtain a fresh export/container backup,
then install and launch the signed schema-11 build under DEVELOPMENT. The phone needs the OpenAI
key entered in Settings; the Mac tooling key is not bundled. Profiles expire **September 24,
07:16 UTC**. No new phone installation has occurred. No local build/test job remains active.

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
| Signed iPhone build | `/tmp/wt-ai-device/Build/Products/Debug-iphoneos/WorkoutTracker.app`; build exit 0; fresh Terra/routine symbols, app/widget signatures and profiles verified; **not installed** |

Actual exit files and xcresult summaries were read. The 0-test discovery attempt, simulator
Busy/preflight failure and interrupted overlapping test jobs are not passing evidence. Non-failing
invalid-frame warnings remain uninvestigated, as in prior work. Hosted CI investigation stays deferred.

## Installed phone and backup — unchanged

- Installed source **8c71d27**, September 20 at 01:04 EDT. Install exit 0/success; remote launch
  exit 1 because **Locked**, not an established crash. No later manual launch/history confirmation.
- Earlier AirPods Pro 3 indoor distance and outdoor map feedback applies to an earlier cardio
  build; pause/reconnect, phone-position accuracy and background GPS remain unverified.
  [Cardio acceptance](../work-record/cardio/issues/02-device-acceptance.md).
- Phone: iPhone 15 Pro Max, `00008130-001E10C01E62001C`; bundle
  `com.ericlee4992.workouttracker`, team `X68M8SR6NA`. App/widget profiles expire
  **2026-09-24 07:16:18 / 07:16:20 UTC**. Xcode 27.0; simulator WT-iPhone; signing config ignored.
- Installed export schema **10**; new code exports **11**. September 18 actual-store-copy cardio
  migration preserved values/relationships across 13 tables. On-phone preservation/restore remain unverified.
- Private backup `/Users/ericlee06/WorkoutTracker-Backups/2026-09-18-before-cardio`: 26 raw files,
  integrity/SHA verified September 18; JSON/CSV alongside. No newer backup claimed. Last reported
  in-app iCloud CSV/JSON export was September 4, before D51 reclassification moved 18 real-store sets.
- Prior accepted UI remains: amber side-by-side Start capsules when labels fit, responsive stacking;
  maps only in finished Summary/History; no duplicate automatic indoor-source row; app unit system
  affects only new cardio activities. Watch companion has never been built/run/installed; cardio
  on Watch remains outside this release.

## Workspace and remaining work

- Main: `/Users/ericlee06/orca/projects/Health App`. Implementation/results:
  `/Users/ericlee06/orca/workspaces/Health App/ai-gym-and-routines`; ignored
  `work-record/ai-gym/results/` contains scripts, actual exits/logs/xcresults and signed-build checks.
  Mac credential is in the private `~/.config/workouttracker/openai.env` (0600), outside Git.
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
