# Current project state

Updated 2026-09-18 for a new session. Start with [AGENTS](../AGENTS.md). This checkpoint was
verified against clean `main` / `origin/main` at **b845a3a**; the handoff changes are docs only.
Earlier STATE is preserved in the [archive](archive/STATE-2026-09-18-before-cardio-handoff.md).
The [independent handoff review](../work-record/cardio/handoff-review.md) is clear.

## Next session: cardio device acceptance

1. Read [ticket 02](../work-record/cardio/issues/02-device-acceptance.md), then check actual Git
   branch/HEAD/status. **The cardio build is already installed.** First establish whether the
   user can open WorkoutTracker and see their history. The previous remote launch failed
   because the phone was locked, then disconnected after unlocking; this is not an app-crash
   diagnosis. If tool verification is needed, connect the unlocked phone by USB and launch the
   existing installation. Reinstalling is unnecessary solely for the connection failure.
   App/widget profiles expire **September 24, 2026 at 07:16 UTC**; if resuming near/after that
   deadline, follow DEVELOPMENT signing checks before treating a launch failure as a code bug.
2. Continue ticket 02's physical checks: AirPods Pro 3 indoor walk/run (phone carried and
   stationary), pause/disconnect/recovery, and outdoor GPS while backgrounded/locked.
   Automatic indoor distance is established by actual readings, not an HR connection.
3. Record observed results in ticket 02 and update this file. Simulator fixtures prove code
   paths, not AirPods delivery or GPS accuracy. Watch cardio remains outside this release.

The old pending input prompt asked the user to unlock the phone for launch verification.
It is not an unanswered design decision or another install approval. The user has not yet
reported a successful app opening. Install authorization was already given and acted on.

## Completed and verified

- **Cardio:** direction B accepted; start Lifting or Cardio and add either mid-workout; one app
  workout with separate sections, optional devices/manual fallback, indoor distance/pace and
  outdoor routes. [Spec](../work-record/cardio/spec.md),
  [implementation/review trail](../work-record/cardio/issues/01-implementation.md),
  [29 native default/AccessibilityL captures](../work-record/cardio/gallery.html).
- Product source **03ada3d**, tests **306acf4**, merged via **b0a8de9**. Installed build is from
  clean main **c847ef3**; commits through **b845a3a** document evidence/install only. Prototype
  `cardio-design-prototype` is reference-only; the selected design is already implemented.
- Debug build passed; full units **748**, targeted units **13**, focused cardio UI **7**, full
  UI **79**, and actual-store/legacy migration checks **10** all passed with exit 0. Full UI
  completed September 18 at 03:58 EDT. Claude code, visual and
  [final merge review](../work-record/cardio/claude-final-clearance.md) are clear.
- **Installed, launch unverified:** devicectl install succeeded September 18 at 08:32 EDT.
  Current phone/backup details below. No fresh phone launch, store-migration or hardware success
  is inferred from the offline checks. The installation was authorized after the merge review.
- **No local build/test jobs running** at this checkpoint. Implementation, research, prototype and
  review checkouts were clean before handoff edits; temporary private migration test removed.
  Preserve the ignored artifacts: main `work-record/ui-redesign/results/cardio-install/` holds
  device build/install/launch logs; `cardio-implementation/work-record/ui-redesign/results/cardio/`
  holds unit/UI/migration logs, exit files and xcresults. Private backup data stays outside Git.
- **Known limits:** 24 non-failing invalid-frame warnings (same known class as ticket 17; origin
  uninvestigated);
  accepted low code/UI findings remain listed in ticket 01. Ring report is closed: user said
  it works. Previous lifting work/verification is retained in the archive and
  [ticket 17](../work-record/ui-redesign/issues/17-finish-summary-second-pass.md).

## Tooling and workspace continuity

- **Matt Pocock skills:** 35 project-local skills are recorded in `skills-lock.json` and present
  under `.agents/skills/`; Codex exposes relevant skills including research, tdd, code-review,
  grilling and domain-modeling. This is not a global installation. [Verification](../work-record/codex-setup/issues/01-codex-workflow.md#2026-09-18-project-skill-check).
- Graft structural graph was rebuilt in main/implementation. Optional AI summaries remain
  unbuilt. Follow AGENTS/DEVELOPMENT for graph precedence; preserve personal Codex settings.
- Completed cards are marked completed. Actual workspace Sleep remains unverified: UI reads
  recovered during this handoff, but menu/focus actions did not put the three cardio workspaces
  to sleep. Preserve their worktrees, logs and resumable terminals; finish Sleep cleanup when
  UI interaction is reliable, with Hide sleeping and main visible.

## Live phone and backup

| Fact | Last verified value |
|---|---|
| Installed source | Cardio product `03ada3d`, built from clean main `c847ef3`; installed 2026-09-18 08:32 EDT, devicectl exit 0/success. Remote launch initially blocked by Locked, then CoreDevice 4016/disconnected after unlock. Install succeeded; launch/on-phone migration unverified |
| Provisioning | Verified in the installed build: app expires **2026-09-24 07:16:18 UTC**, widget **07:16:20 UTC**; same profiles created September 17 |
| Store | Cardio code exports schema 10; on-phone migration awaits launch verification. Offline migration of a fresh actual-store copy passed, preserving all existing values/relationships across 13 tables |
| Latest local backup | `/Users/ericlee06/WorkoutTracker-Backups/2026-09-18-before-cardio`: fresh raw container, 26 files, integrity and SHA-256 checks passed. JSON/CSV generated with app exporters from an isolated migrated copy alongside it; private, outside Git. Restore not tested |
| Last reported app export | User's CSV + JSON export to iCloud Drive, 2026-09-04, immediately before D51 reclassification; 18 sets moved on the real store |
| Phone UDID | `00008130-001E10C01E62001C` |
| Bundle ID / team | `com.ericlee4992.workouttracker` / `X68M8SR6NA`; per-developer signing lives in gitignored `Config/Local.xcconfig` |
| Watch | Companion never built/run/installed; separate target is a sketch |
| Environment | Xcode 27.0; test simulator `WT-iPhone`. CoreSimulator and Apple ID sign-in issues from the update were resolved 09-17 |

Re-export after sessions worth keeping. The September 18 raw backup and locally generated
CSV/JSON include the current pre-install data. The last user-reported in-app export to iCloud
remains September 4; no newer iCloud export is claimed.

Before build/test/install or troubleshooting, read [DEVELOPMENT](DEVELOPMENT.md), including
binary freshness, migration-fixture limitations, profile renewal, and detached tests.

## Open work retained from the previous handoffs

These are unresolved or deferred items, not instructions to start them all. Confirm current
reproduction and scope before implementation; detailed history is in the linked records.

| Area | Remaining work or evidence | Record |
|---|---|---|
| Scanner on the phone | User report on framing/crop alignment, sharpness, speed, enlarged box, Ask AI and exercise proposals; key entry on the phone remains unconfirmed | [Scanner tickets](../work-record/scanner-accuracy/issues/) |
| Scanner backlog | Read-quality ticket 04, on-device brand prior/chip ticket 07; ROC-IT → Hoist alias and a floor against a single generic word scoring highly. Read prior matcher reviews before changes | [Scanner record](../work-record/scanner-accuracy/) |
| Machine picker | Model-less machine did not push an exercise picker in the simulator; confirm on the phone before opening a fix. Get delete/restore feedback at the gym | [Machine deletion](../work-record/machine-deletion/issues/01-delete-machines.md) |
| Real-workout UX | Bar plates-per-side vs total, PREVIOUS total vs plate input, missing bar presets, preset-chip reachability; export correctness over real history | [Archived questions](archive/STATE-2026-09-17-before-codex-setup.md#what-to-do-next-in-priority-order) |
| Real history / summary | Real hour-long heart-rate graph density/range, variation naming, history edits/deletes, load-type correction, calendar, workout naming, and the moved session’s “Reclassified from …” line; new summary/zone/template flows on the phone | [Milestone 9](../work-record/milestone-9-history-and-summary/), [finish graph](../work-record/finish-graph-and-plain-numbers/) |
| Bar/stack calculation | Milestone 6's plate loading math and selectorized stack increments | [SPEC](SPEC.md) |
| Supersets | Deliberate within-group reordering; grouping in History; stronger D48 invariant test derived through production operations | [Supersets ticket](../work-record/milestone-8-history-and-charts/issues/04-supersets.md) |
| Coverage / catalog | Drag is confirmed on phone but lacks a drag UI test; milestone-8 load-type catalog audit remains undone | [History ticket](../work-record/milestone-8-history-and-charts/issues/03-edit-history.md), [load-type ticket](../work-record/milestone-8-history-and-charts/issues/02-load-type-editable.md) |
| Weight precision | `Format.weight` rounds to one decimal; a prefilled 62.25 kg row can commit 62.3. Known, deliberately deferred; bar mode seeds via `WeightMath.displayNumber` | [Archived bug](archive/STATE-2026-09-17-before-codex-setup.md) |
| Migration fixture | The legacy fixture predates the pre-cardio phone schema; both synthetic fixtures passed. Migration of a fresh copy of the actual phone store also passed (10 checks, all existing values across 13 tables preserved). On-phone migration and backup restore remain unverified | [Cardio acceptance](../work-record/cardio/issues/02-device-acceptance.md) |
| Heart-rate verification | DOB setup toggle lacks UI coverage; revised zone boundaries need current gym feedback; recovery-vs-cap sound distinction and background early-recovery behavior remain unverified. Live AirPods HR, zones, screen-off timed beep, and HR rest timer have been confirmed | [Archived verification](archive/STATE-2026-09-17-before-codex-setup.md#what-to-do-next-in-priority-order) |
| Watch experiment | Wear the watch with no companion installed and inspect the source label before investing in it. Pairing, streaming, rest mirroring, and phone-triggered wake remain unverified; revisit D41 only with evidence | [Watch ticket](../work-record/milestone-7-heart-rate/issues/04-watch-companion.md) |
| Catalog gaps | Atlantis dealer-only coverage; Titan/Sorinex gaps; Life Fitness Signature Series | [Catalog sources](catalog-sources/README.md) |
| App Store / collaborators | Privacy policy, usage-string review, export-compliance/upload setup, paid Developer Program decision. An app icon already shipped. Reopen D5/T6 deliberately if a human collaborator joins; branch protection and review policy then need a decision | [DECISIONS](DECISIONS.md) |
| CI | Hosted unit job investigation intentionally deferred by user on 2026-09-04; local suites are the gate | [DEVELOPMENT](DEVELOPMENT.md#ci-scanner-tooling-and-time-based-behavior) |

Other deferred product decisions (including our JSON restore path) remain in
[DECISIONS — Deferred / open](DECISIONS.md#deferred--open). The archive also preserves their
original context. Resolved items must not be revived from old handoffs: chart preset scoping
was fixed, the template caption was accepted, the rest-bar wrap was fixed in ticket 16, and
App Store icon groundwork is already shipped. Queued-alarm ducking is deliberately absent.
