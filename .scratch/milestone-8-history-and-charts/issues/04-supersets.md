# 04 — Super / compound sets

Status: open
Blocked by: 03 (editing must understand grouped sets before grouping exists, or edit will orphan them)
Covers user ask **4**. Reopens SPEC's post-v1 deferral of "RPE/supersets".

## The questions to settle before building

- Is a superset a **group of exercise entries** performed alternately, or a **tag on sets**?
  The former matches how people train (A1/B1, A2/B2); the latter is less schema churn. Decide
  deliberately and record it — this is a shape that is painful to change once real data exists.
- **Rest behaviour.** A superset's rest normally comes after the *last* exercise in the group, not
  between its members. D22's rest precedence (override → global) needs a rule for groups.
- **PRs and volume** must be unaffected: a set is still a set. Grouping is presentation and rest
  behaviour, not a new kind of load.

## What to build

- Group two or more exercise entries in an active workout into a superset.
- The workout screen shows the grouping and cycles through it.
- Rest applies to the group per the rule decided above.
- Templates round-trip supersets (`WorkoutTemplates`, drift detection) — a template that loses its
  grouping silently is template data loss, which a past review already caught once in this repo.
- History and export represent the grouping.

## Acceptance criteria

- A superset can be created, reordered and ungrouped without losing sets.
- Rest fires per the decided rule, and D43's heart-rate rest still applies.
- PRs and volume are identical to the same sets logged ungrouped (assert with a test).
- Template save → start → drift-prompt round-trips grouping.
- Export includes grouping; schema version bumped if the JSON shape changes (D28–D32).
- `LegacyStoreMigrationTests` opens the fixture store after the schema change.
- Unit + UI suites green.
