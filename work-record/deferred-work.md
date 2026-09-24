# Deferred work and outstanding device feedback

Audited 2026-09-24; current next action and installed build live in [STATE](../docs/STATE.md).

These are unresolved or deferred items, not instructions to start them all. Confirm current
reproduction and scope before implementation; detailed history is in the linked records.

| Area | Remaining work or evidence | Record |
|---|---|---|
| AI device trial | Post-update template visibility, scan-in-setup, preserved preferences, actual label/whole-machine recognition and exercise proposals; visual history acceptance. AI routine creation/key funding already works. Check signing expiry in STATE first | [AI acceptance](ai-gym/issues/06-device-acceptance.md), [delivered follow-up](ai-gym/issues/07-template-visibility-and-scanning.md) |
| Scanner backlog | Older on-device read-quality ticket 04 and brand prior/chip ticket 07 remain deferred for the explicit offline path; D56 AI recognition supersedes the former OCR-first default. Physical framing/sharpness/speed feedback remains open; ROC-IT → Hoist alias and a floor against a single generic word scoring highly. Read prior matcher reviews before changes | [Scanner record](scanner-accuracy/) |
| Machine picker | Model-less machine did not push an exercise picker in the simulator; confirm on the phone before opening a fix. Get delete/restore feedback at the gym | [Machine deletion](machine-deletion/issues/01-delete-machines.md) |
| Real-workout UX | Bar plates-per-side vs total, PREVIOUS total vs plate input, missing bar presets, preset-chip reachability; export correctness over real history | [Archived questions](../docs/archive/STATE-2026-09-17-before-codex-setup.md#what-to-do-next-in-priority-order) |
| Real history / summary | Real hour-long heart-rate graph density/range, variation naming, history edits/deletes, load-type correction, calendar, workout naming, and the moved session’s “Reclassified from …” line; new summary/zone/template flows on the phone | [Milestone 9](milestone-9-history-and-summary/), [finish graph](finish-graph-and-plain-numbers/) |
| Bar/stack calculation | Milestone 6's plate loading math and selectorized stack increments | [SPEC](../docs/SPEC.md) |
| Supersets | Deliberate within-group reordering; grouping in History; stronger D48 invariant test derived through production operations | [Supersets ticket](milestone-8-history-and-charts/issues/04-supersets.md) |
| Coverage / catalog | Drag is confirmed on phone but lacks a drag UI test; milestone-8 load-type catalog audit remains undone | [History ticket](milestone-8-history-and-charts/issues/03-edit-history.md), [load-type ticket](milestone-8-history-and-charts/issues/02-load-type-editable.md) |
| Weight precision | `Format.weight` rounds to one decimal; a prefilled 62.25 kg row can commit 62.3. Known, deliberately deferred; bar mode seeds via `WeightMath.displayNumber` | [Archived bug](../docs/archive/STATE-2026-09-17-before-codex-setup.md) |
| Migration / restore | Prior legacy and installed-era synthetic migrations passed; September 18 actual-store migration passed 10 checks across 13 tables. September 22 on-phone comparison preserved all existing values across 15 tables. Future schema changes need a fixture matching the then-installed schema. Visual history confirmation and backup restore remain unverified | [Cardio acceptance](cardio/issues/02-device-acceptance.md), [AI verification](ai-gym/issues/05-verification-review.md), [AI acceptance](ai-gym/issues/06-device-acceptance.md) |
| Heart-rate verification | DOB setup toggle lacks UI coverage; revised zone boundaries need current gym feedback; recovery-vs-cap sound distinction and background early-recovery behavior remain unverified. Live AirPods HR, zones, screen-off timed beep, and HR rest timer have been confirmed | [Archived verification](../docs/archive/STATE-2026-09-17-before-codex-setup.md#what-to-do-next-in-priority-order) |
| Watch experiment | Wear the watch with no companion installed and inspect the source label before investing in it. Pairing, streaming, rest mirroring, and phone-triggered wake remain unverified; revisit D41 only with evidence | [Watch ticket](milestone-7-heart-rate/issues/04-watch-companion.md) |
| Catalog gaps | Atlantis dealer-only coverage; Titan/Sorinex gaps; Life Fitness Signature Series | [Catalog sources](../docs/catalog-sources/README.md) |
| App Store / collaborators | Privacy policy, usage-string review, export-compliance/upload setup, paid Developer Program decision. An app icon already shipped. Reopen D5/T6 deliberately if a human collaborator joins; branch protection and review policy then need a decision | [DECISIONS](../docs/DECISIONS.md) |
| CI | Hosted unit job investigation intentionally deferred by user on 2026-09-04; local suites are the gate | [DEVELOPMENT](../docs/DEVELOPMENT.md#ci-scanner-tooling-and-time-based-behavior) |

Other deferred product decisions (including our JSON restore path) remain in
[DECISIONS — Deferred / open](../docs/DECISIONS.md#deferred--open). The archive also preserves their
original context. Resolved items must not be revived from old handoffs: chart preset scoping
was fixed, the template caption was accepted, the rest-bar wrap was fixed in ticket 16, and
App Store icon groundwork is already shipped. Queued-alarm ducking is deliberately absent.
