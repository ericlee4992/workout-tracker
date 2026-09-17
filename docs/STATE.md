# Current project state

Updated 2026-09-17. Read [AGENTS](../AGENTS.md) for the shared workflow. This file holds
current facts and open work; previous handoffs are preserved in the [archive](archive/README.md).

## Active task and next action

- **Codex setup is complete.** [Ticket](../work-record/codex-setup/issues/01-codex-workflow.md):
  shared AGENTS, short Claude entry point, preserved history, current-only STATE, DEVELOPMENT
  runbook, and Codex design-skill discovery. Claude cleared the changes after two rounds;
  archive, link, and configuration checks passed. Personal settings use an 872K context window,
  780K compaction threshold, and context-usage footer, verified in a fresh Codex session.
  Restart existing Codex sessions to load these defaults.
- **This is the archived design-exploration branch.** The user selected the shipped finish
  screen with only metric reordering. Implementation is on `ericlee4992/finish-summary-order`,
  source `4d70d7d`, in `/Users/ericlee06/orca/workspaces/Health App/finish-summary-order`.
  Resume that worktree's STATE and ticket 17; its tests/review/merge state supersedes this
  exploration. A/B/C remain here as historical comparison artifacts.
- Gym feedback on ticket 16 still remains welcome; it has not been supplied in this session.

## Latest shipped work and verification

- [Ticket 16: active workout](../work-record/ui-redesign/issues/16-active-workout-second-pass.md)
  is merged and pushed. App source is `0b6515f`; main reached `9b9feef` with documentation only
  afterward. Gym and clock (including seconds) share the header; the sets indicator is a small
  neutral ring. Rest-bar controls stack at accessibility sizes; VoiceOver speaks seconds.
  The user said the capture looks good. Add Exercise and Skip staying amber are accepted exceptions.
- Codex cross-review cleared in two rounds. The full UI suite on that source finished
  2026-09-17 03:53 EDT: **72 passed, 0 failed, 0 skipped**, exit 0. All 72 declared methods
  appeared in the log; the old handoff's expected 73 was a counting error. Focused gates:
  27 UI tests; after fixes, formatter 4/4 and accessibility capture 1/1. The result bundle
  contains 22 non-failing invalid-frame warnings; origin not investigated. Evidence is in the ticket.
- Templates, muscle-map icons, save-as-template from History, and History zone-time cards are
  also shipped; records are in [UI redesign](../work-record/ui-redesign/) and
  [History templates/zones](../work-record/history-templates-and-zones/).
- Milestones 2–4 and 9 are shipped; milestone 5 (Strong import) was dropped by D49. Milestones
  7/8 are merged but still have deferred acceptance work below. Milestone 6's bar mode is
  shipped; plate calculation and selectorized stack increments remain.

## Live phone and backup

| Fact | Last verified value |
|---|---|
| Installed source | `0b6515f`, installed 2026-09-17 03:17 EDT; launch reported in the prior handoff (`a49c8d1:docs/STATE.md`); no reinstall needed for these documentation changes |
| Provisioning | Fresh profile recorded through **2026-09-24 07:16 UTC**; check app and widget separately before the next install |
| Store | Export schema 9; no schema change in ticket 16. History snapshots and the user's actual training data are on the phone |
| Last reported backup | User's CSV + JSON export to iCloud Drive, 2026-09-04, immediately before D51 reclassification; 18 sets moved on the real store |
| Phone UDID | `00008130-001E10C01E62001C` |
| Bundle ID / team | `com.ericlee4992.workouttracker` / `X68M8SR6NA`; per-developer signing lives in gitignored `Config/Local.xcconfig` |
| Watch | Companion never built/run/installed; separate target is a sketch |
| Environment | Xcode 27.0; test simulator `WT-iPhone`. CoreSimulator and Apple ID sign-in issues from the update were resolved 09-17 |

Re-export after sessions worth keeping: the phone is the only known copy of history newer than
the last reported backup. Get a fresh export before risky data operations or installs.

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
