# Milestone 2 — Core loop on SwiftData

Revised ticket set (v2, 2026-08-08) incorporating the Codex cross-review (`codex-review.md`).
Superseded first draft in `issues-v1-superseded/`. New decisions from the review: D19–D25 in `docs/DECISIONS.md`.

## Dependency graph

```
01 test-target
├── 02 swiftdata-schema
│   ├── 04 catalog-seeding ──┐
│   └── 05 gyms-unit-pref ───┼── 06 machines-models-exercises
└── 03 unit-conversion-core ─┼──────┐
                             │      ├── 07 core-logging-loop
                             └──────┘        ├── 08 machine-first
                                             ├── 15 templates ── 16 drift
                                             ├── 09 history ── 10 equipment-lifecycle
                                             ├── 11 prefill-layers ──┐
                                             ├── 14 rest-timer      ├── 13 records-in-ui
                                             └── (03) 12 records-core ┘
```

Frontier after 07 lands: 08, 09, 11, 14, 15 in parallel (12 is available even earlier — it only needs 03).
Known accepted risk (pass-2 finding 19): tickets 02, 07, 15 are deliberately larger than one session — execute with WIP commits rather than renumbering the set again. Tickets 08/11/14 all touch the active-workout screen; land them sequentially or on short branches.

## Status legend

Each ticket carries `Status: ready-for-agent | claimed | resolved` per `docs/agents/issue-tracker.md`.
