Round 3 (T6) of milestone 9, ticket 01, branch milestone-9-history-and-summary.
Your round-2 review: work-record/milestone-9-history-and-summary/codex-review-01b.md.
Response appended to issues/01-chart-per-equipment-and-history-chart.md.
Boundary for the fixes: 75a280f..32cb547 (32cb547).

Scope is the two fixes only:
1. rankedVariations now includes loadType. Is the order total over every
   field of ProgressVariationKey? Is the new test actually sensitive to the
   omission it claims to pin?
2. ProgressSeriesMath.labels(for:). Can two DISTINCT keys still receive the
   same string? Consider: the escalation loop raising only colliding rows and
   thereby creating a NEW collision with an untouched row; a preset name that
   itself contains " · "; two machines with equal label and equal gym; nil
   gym; more than two rows in one collision. Is the ordinal floor correct
   when three rows collide?
Also: the response says Codex could not run tests last round; you may try
once, and if the simulator fails again say so and review statically.
Write to work-record/milestone-9-history-and-summary/codex-review-01c.md.
