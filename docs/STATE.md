# Current project state

Updated 2026-09-18. Read [AGENTS](../AGENTS.md) for the shared workflow. This file holds
current facts and open work; previous handoffs are preserved in the [archive](archive/README.md).

## Active task and next action

- **Cardio implementation active.** User chose B and on 2026-09-18 approved optional devices /
  manual fallback, explicitly requiring indoor distance and pace on supported connected devices
  such as AirPods Pro 3. Outdoor runs/rides with GPS, one saved workout with separate sections,
  and starting/adding either activity remain required. [Ticket](../work-record/cardio/issues/01-implementation.md),
  [spec](../work-record/cardio/spec.md), [API evidence](../work-record/cardio/research/01-indoor-distance-and-pace.md).
- Checkout `/Users/ericlee06/orca/workspaces/Health App/cardio-implementation`, branch
  `ericlee4992/cardio-implementation`, base `14982e7`; committed checkpoint `d0bcb54`.
  N1/N2 fixes now use append-only heartbeat rows and fold stray checkpoints on finish.
  Full unit run `unit-7`: **748 tests / 81 suites passed**, exit 0; `build-9` passes.
  Native visual review required pinned controls, consistent route colour and more state captures;
  those corrections are implemented and the final build/full UI gate are next. Detailed jobs,
  measurements and review findings are in the ticket. No phone install.
- **Distance acceptance:** public live-builder APIs are available; actual AirPods indoor distance
  delivery is not guaranteed by documentation. Implement collection and labeled phone-motion
  fallback; retain real-device treadmill validation as a separate gate, never claim simulator
  fixtures prove AirPods support. Activity-specific HealthKit sessions are consecutive.
- **Design:** reviewed native B prototype source `48608fb`, branch `ericlee4992/cardio-design-prototype`;
  source is reference only, not mergeable. Existing tabs remain. [Design record](../work-record/cardio-design/issues/01-design-discussion.md).
- **Ring report closed:** user confirmed it works; no product change. Product on phone remains
  ticket 17, source `4d70d7d`; facts below unchanged. No phone installation requested yet.
- Graft CLI and prompt hints work; optional AI summaries unbuilt. Completed workspaces sleep;
  keep Hide sleeping and main visible. Preserve all logs/history and personal Codex settings.

## Latest completed work and verification

- Ticket 17: source `4d70d7d`, merged via `39b4c8d`; subsequent commits through `f89dcde` record
  evidence/install only. Debug build passed, summary unit tests **8/8**, full local UI suite
  **72 passed, 0 failed, 0 skipped**, exit 0 (2026-09-17 18:48 EDT). Claude code, default/AXL
  visual and final gate reviews clear. One initial AXL setup keyboard-focus failure passed
  unchanged in isolation and again in the full suite. There are 22 non-failing invalid-frame
  warnings; origin remains uninvestigated. No tests or builds remain running from ticket 17.
- Real before/after captures: [comparison](../work-record/ui-redesign/screenshots/17/selected/comparison.html).
  Logs/result bundles remain in the sleeping implementation worktree; exact paths and process
  history are in ticket 17. These were real app captures, separate from the rejected prototypes.
- Ticket 16, source `0b6515f`: gym and clock with seconds share the header, small neutral sets
  ring, accessibility rest controls stack, VoiceOver speaks seconds. Add Exercise/Skip amber
  treatments are accepted exceptions. [Record](../work-record/ui-redesign/issues/16-active-workout-second-pass.md).
- Rejected A/B/C mockups remain on `ericlee4992/finish-summary-second-pass` (`5a4c1b2`, outcome
  `dea20f4`). The four sleeping worktrees can be shown again by disabling Hide sleeping.
- Templates, muscle maps, History template saving and zone-time cards are shipped. Milestones
  2–4 and 9 are shipped; milestone 5 was dropped (D49); 7/8 have deferred acceptance work below;
  milestone 6 bar mode is shipped, plate math and stack increments remain.
- Earlier detail is preserved in the [pre-checkpoint STATE](archive/STATE-2026-09-17-before-graft-handoff.md)
  and the linked tickets, including [Codex setup](../work-record/codex-setup/issues/01-codex-workflow.md).

## Live phone and backup

| Fact | Last verified value |
|---|---|
| Installed source | `4d70d7d` (built from main `39b4c8d`), installed 2026-09-17 21:43 EDT and launched 21:44 EDT; `devicectl` confirmed install and launch success (PID 15231) |
| Provisioning | Verified in the installed build: app expires **2026-09-24 07:16:18 UTC**, widget **07:16:20 UTC**; same profiles created September 17 |
| Store | Export schema 9; no schema change in tickets 16/17. History snapshots and the user's actual training data are on the phone |
| Latest local backup | Fresh full app-container copy before ticket 17, 2026-09-17: `/Users/ericlee06/WorkoutTracker-Backups/2026-09-17-before-ticket17`; 24 files, SQLite integrity checks passed; SHA-256 manifest beside it. Raw device backup, not the app's CSV/JSON export; restore has not been tested |
| Last reported app export | User's CSV + JSON export to iCloud Drive, 2026-09-04, immediately before D51 reclassification; 18 sets moved on the real store |
| Phone UDID | `00008130-001E10C01E62001C` |
| Bundle ID / team | `com.ericlee4992.workouttracker` / `X68M8SR6NA`; per-developer signing lives in gitignored `Config/Local.xcconfig` |
| Watch | Companion never built/run/installed; separate target is a sketch |
| Environment | Xcode 27.0; test simulator `WT-iPhone`. CoreSimulator and Apple ID sign-in issues from the update were resolved 09-17 |

Re-export after sessions worth keeping. A fresh raw device backup now exists locally; the
latest reported portable CSV/JSON export is still September 4. History newer than the latest
backup is only known to be on the phone. Get a fresh export before risky data operations or installs.

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
| Migration fixture | `Fixtures/LegacyStore.store` was generated at `5239ef2`, older than the live schema. Regeneration from the installed build is still owed; passing it alone does not prove live-store compatibility | [Milestone 7 review](../work-record/milestone-7-heart-rate/codex-review.md) |
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
