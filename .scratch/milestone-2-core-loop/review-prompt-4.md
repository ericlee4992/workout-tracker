Independent cross-review. Everything under review was written by Claude agents; you are the second
pair of eyes required by `docs/DECISIONS.md` T6 (solo project — this is the only independent check
that exists). Be adversarial, not agreeable. Terse. No praise.

REVIEW THIS RANGE: `git diff a4d38b7...HEAD` — four commits:
  513342b  Ticket 19: create exercises mid-workout
  5b5ee62  Ticket 20: expand seeded equipment catalog  (24 → 1887 models, 12 → 74 exercises)
  78277a5  Ticket 21: browse and categorize the equipment catalog
  0fea9ab  Docs: correct stale SPEC lines

SPECS: `.scratch/milestone-2-core-loop/issues/19-*.md`, `20-*.md`, `21-*.md`. Every box is ticked;
verify the code earns each tick. BINDING CONTEXT: `docs/SPEC.md`, `docs/DECISIONS.md` — especially
**D23** (snapshot-keyed history), **D24** (seeded rows: fixed catalog UUIDs, allowlisted mutable
fields, user rows untouched), **D27** (reconciliation merges user links rather than overwriting),
and `CLAUDE.md`.

Priorities, in order:

A. **CATALOG DATA INTEGRITY — the highest-stakes thing here.** 1887 models were generated from
   research markdown now in `docs/catalog-sources/` via `scripts/catalog_data.py` +
   `scripts/generate_seed_catalog.py`.
   - Verify the 36 version-1 ids (12 exercises, 24 models) survive byte-identical in
     `SeedCatalog.json`. Any drift orphans already-logged history.
   - Sample entries across manufacturers and check them against the committed research files. Did
     any model name get fabricated, mangled, mis-attributed to the wrong manufacturer, or invented
     by extrapolating a naming pattern? The research explicitly flagged traps — Eleiko sells resold
     Precor, Star Trac lines ship as Nautilus, Matrix `B` suffixes are upholstery variants, Hoist
     RS-1xxx/RS-2xxx are coexisting generations. Were those respected in the shipped JSON, or only
     in prose?
   - Are exercise links sane (a leg press linked to a leg press, multi-exercise stations linked to
     several)? Spot-check widely — a wrong link silently mis-keys the same-model history layer.
   - Duplicates: two ids for the same real machine split its history. Look for near-duplicate
     (manufacturer, modelName) pairs.

B. **Schema and reconciliation.** Ticket 21 added `EquipmentModel.equipmentType` and six optional
   `AppPreferences` fields, and bumped the catalog to version 3. Ticket 20 added a fast path that
   skips reconciliation when version and seeded row COUNTS match.
   - Is the count-based fast path sound? Construct a store where counts match but content is wrong
     (e.g. a seeded row edited, or one deleted and another added) and say whether it heals.
   - Does the version-3 backfill of `equipmentType` reach stores seeded at version 1 and 2?
   - The agent reported a launch crash from a non-optional enum column on an existing store, fixed
     by making the new preference fields optional. Are there other new non-optional additions that
     would fail to materialise on an existing store? This is a real upgrade path — the user has the
     app on their phone with live data.

C. **D23/D24/D27 compliance.** Ticket 21's grouping/filtering is supposed to be display-only.
   Verify no filter or grouping state can reach a logged entry, a snapshot, or a records query.
   Verify user-created models/exercises are never hidden by a filter they lack a category for.

D. **Ticket 19 seams.** Creating an exercise mid-workout and linking it to a *seeded* model mutates
   an allowlisted seeded field. Does D27's merge actually protect it across a version bump — and
   across TWO bumps (1→2→3)?

E. **Performance honesty.** `CatalogModelIndex` rebuilds "when the model count changes". Is that
   invalidation correct if a model is renamed or its type changes without a count change? And does
   any screen build the index on every body evaluation rather than on appearance?

F. **What else is wrong.** Reading as a critical user with 1887 models on a phone: memory, scroll
   performance, first-launch seed cost, anything the ticket authors missed.

OUTPUT: Markdown to stdout. Section 1: per-ticket verdict (19, 20, 21) — earned / partially / not,
with evidence. Section 2: findings by severity (Critical / Important / Minor). Section 3: one line —
is this safe to install on the user's phone over their existing live data?
