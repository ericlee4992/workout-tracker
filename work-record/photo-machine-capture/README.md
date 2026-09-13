# Photograph a machine's name plate to identify it

User-requested feature (2026-08-11), outside the numbered v1 milestones. Spec in `spec.md`,
tickets in `issues/01..03`, strictly sequential.

The one thing to keep straight while working here: a scan **proposes** a catalog model and the
user confirms it (D33). D23 keys history, prefill and PRs on the model UUID, so a confident wrong
match splits the user's own training history — the same failure mode that made duplicate catalog
identities a critical finding in codex-review-4.

## Status legend

Each ticket carries `Status: ready-for-agent | claimed | resolved` per `docs/agents/issue-tracker.md`.
