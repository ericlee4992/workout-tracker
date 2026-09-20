# Current project state

Updated 2026-09-20 for a fresh session. Audit baseline: clean `main` / `origin/main`
**6102b5d**. Reviewed handoff **e9803e0**, prepared on `ericlee4992/session-handoff-sep20`,
is merged/pushed to `main` with this records checkpoint. The
[handoff ticket](../work-record/codex-setup/issues/03-session-handoff.md) records clearance and checks.
Previous STATE is preserved byte-for-byte in the [archive](archive/README.md).

## Current implementation — AI equipment and routines

User authorized full build with tickets and Claude review on September 20. Working branch
`ericlee4992/ai-gym-and-routines` from main `17e42a0`, separate Orca checkout
`/Users/ericlee06/orca/workspaces/Health App/ai-gym-and-routines`.
[Spec and ticket index](../work-record/ai-gym/spec.md); implementation starts with
[ticket 01](../work-record/ai-gym/issues/01-api-and-consent.md). GPT-5.6 Terra only;
private trial; optional Ask AI below Templates; weekly lifting/cardio routines; no weight
estimates or guides. Key saved outside Git; first live request failed 429/credit_balance_exhausted.
User asked to fund API billing; fixture work may proceed, live verification pending.
No new product code, tests, merge or install claimed at this checkpoint.

## Previous next action — still pending physical acceptance

The latest app is **installed; launch and existing-history preservation remain unverified**.
First obtain confirmation that WorkoutTracker opens and old workouts are intact, then continue
[cardio physical acceptance](../work-record/cardio/issues/02-device-acceptance.md). User confirmed
AirPods Pro 3 indoor distance and outdoor map rendering on an earlier cardio build; this does
not establish latest-build launch, phone-position accuracy, pause/reconnect or background GPS.
No code change, rebuild or reinstall is needed merely to resume. Remote launch failed because
the phone was Locked, not an established app crash. Signing expires **September 24, 07:16 UTC**.

**Verification policy T8 is already merged:** use targeted checks by change risk;
full UI is reserved for the escalation cases in [DEVELOPMENT](DEVELOPMENT.md#verification-scope).
This supersedes blanket full-suite wording in older tickets/skills. Docs-only handoffs use
link/consistency checks. [Policy ticket and review](../work-record/codex-setup/issues/02-verification-policy.md).

## Latest accepted behavior — implemented and merged

- Start Lifting / Start Cardio use the original amber icon-disc capsules, **side by side without
  arrows** when full labels fit; responsive stacking for large text/narrow widths. The earlier
  text-only and always-stacked designs are superseded. [Ticket 05](../work-record/cardio/issues/05-compact-start-and-outdoor.md).
- Outdoor routes record during the workout, but maps appear only in finished Summary / History.
  The duplicate live GPS/distance section is removed; main metrics and location errors remain.
- Automatic indoor distance/pace stay in the main metrics without a duplicate source/estimate
  row, including phone-motion readings. No-data/manual entry and correction after End remain.
  Automatic zero/low readings also hide that row; this consequence was explicitly accepted.
- Settings **Metric (kg/km)** / **U.S. customary (lb/mi)** affect **new cardio activities only**.
  Active/saved cardio units and entered values stay unchanged. Existing kg/lb preference storage
  is reused; no schema migration. Lifting machine → gym → app precedence remains.
  [Ticket 06 and review](../work-record/cardio/issues/06-unit-system-and-indoor.md).

## Verification and installed build

| Evidence | Verified result |
|---|---|
| Product / unit-test code | `dc08ea8`; build exit 0, 753 unit tests and 32 focused clock/unit tests passed |
| UI-tested tip | `cda7fd4`; 7 focused Cardio cases plus corrected 2 Settings cases passed; full UI **85/85**, exit 0, zero failed/skipped |
| Independent feature review | [Claude final clearance](../work-record/cardio/claude-units-review.md), authored `46ad211` |
| Installed source | Clean main **8c71d27**, fresh signed build; installed **2026-09-20 01:04 EDT**, devicectl exit 0 / success |
| Launch | Remote launch exit 1, **Locked**; no main app process afterward (widget extension only). User manual-open confirmation pending |
| Later changes | Install records `4a7cbc1`, policy `ad519c3` / `6102b5d`, and this handoff are documentation only |

Actual exits and xcresult summaries were re-read for this handoff. Initial timing/navigation
failures remain in ticket 06; final passing runs supersede them. Full UI finished normally after
stopping only its hung optional simulator-diagnostics collector; auxiliary diagnostics may be
incomplete. 24 non-failing invalid-frame warnings remain uninvestigated. No build/test job active.
Original cardio/migration evidence and accepted low findings remain in
[ticket 01](../work-record/cardio/issues/01-implementation.md).

## Phone and backup

| Fact | Last verified value |
|---|---|
| Provisioning | Installed app expires **2026-09-24 07:16:18 UTC**, widget **07:16:20 UTC** |
| Store | Cardio export schema 10; actual-store-copy migration passed, preserving old values/relationships across 13 tables. On-phone history preservation and backup restore remain unverified |
| Local backup | `/Users/ericlee06/WorkoutTracker-Backups/2026-09-18-before-cardio`: 26 raw-container files; integrity/SHA-256 verified September 18. Exported JSON/CSV beside it. Directory/exports still present at this handoff; no newer backup claimed |
| Last reported in-app export | CSV + JSON to iCloud Drive, September 4, before D51 reclassification (18 real-store sets moved) |
| Phone / identity | iPhone 15 Pro Max; UDID `00008130-001E10C01E62001C`; bundle `com.ericlee4992.workouttracker`; team `X68M8SR6NA` |
| Environment | Xcode 27.0; simulator `WT-iPhone`; local signing in ignored `Config/Local.xcconfig` |
| Watch | Companion never built/run/installed; cardio outside this release |

Before any future install, follow [DEVELOPMENT](DEVELOPMENT.md) for backup/migration, signing,
freshness and launch checks. Re-export after sessions worth keeping; private backup stays outside Git.

## Evidence and workspace continuity

- Main checkout: `/Users/ericlee06/orca/projects/Health App`. Latest ignored install evidence:
  `work-record/ui-redesign/results/cardio-units-install/` (build, binary verification, install,
  launch and process list). Earlier install evidence remains in the sibling `*-install/` folders.
- Feature checkout: `/Users/ericlee06/orca/workspaces/Health App/cardio-units-and-sources`;
  `work-record/ui-redesign/results/cardio-units/` has scripts, logs, exit files and xcresults.
  Original cardio/migration artifacts remain in the `cardio-implementation` checkout's
  `work-record/ui-redesign/results/cardio/`. Preserve these ignored artifacts and resumable terminals.
- [21 selected unit/indoor captures](../work-record/cardio/screenshots/units-and-indoor/),
  [original cardio gallery](../work-record/cardio/gallery.html). Prototype is reference-only.
- Prior Orca cards are completed. Three old review checkouts contain untracked report copies
  already preserved in main (details in handoff ticket); no unique work is lost. Actual workspace
  **Sleep remains unverified** after earlier menu/focus failures. Keep main visible and preserve
  worktrees; finish Sleep cleanup when UI interaction is reliable.
- 35 project-local skills installed; personal Codex settings unchanged.
  [Setup record](../work-record/codex-setup/issues/01-codex-workflow.md).
  Graft structural graph rebuilt; optional AI summaries remain unbuilt.

## Other open work

The complete [deferred-work and device-feedback list](../work-record/deferred-work.md) preserves
scanner, machine picker, lifting/history UX, calculation, supersets, precision, migration, HR,
Watch, catalog, App Store and CI items. These are not a request to start them all. Consult it
when choosing the next task; keep resolved items closed. Product rationale remains in
[SPEC](SPEC.md) and [DECISIONS](DECISIONS.md).
