# Exercise presets

Spec in `spec.md`, tickets in `issues/01..04`, strictly sequential.

The one thing to keep straight: **a preset splits records** (D36). It is part of the entry's D23
snapshot, so switching it after a set is logged starts a new entry — exactly as switching equipment
does (D19). Every question about "should X be per preset?" resolves the same way: if two sets are
not comparable, they do not share a record table.

## Status legend

Each ticket carries `Status: ready-for-agent | claimed | resolved` per `docs/agents/issue-tracker.md`.
