Re-review (T6, round 2) of milestone 9, ticket 01, on branch
milestone-9-history-and-summary. Your round-1 review is at
.scratch/milestone-9-history-and-summary/codex-review-01.md; the response is
appended to issues/01-chart-per-equipment-and-history-chart.md. Review
boundary for the fixes: 18d76ec..75a280f (the fix commit is 75a280f).

Verify each round-1 finding is actually closed, not merely addressed:

1. ProgressEquipment (Domain/ProgressSeries.swift): is the derivation from
   (machineID, freeWeightTag) total and correct for every RecordSetInput the
   app can produce? Can a set have BOTH a machineID and a tag, and if so which
   wins and is that what RecordGroupKey does? Does the chart now agree with
   the exact-machine and tag record groups about the best set for a given
   variation?
2. The picker in empty/single states, and the "always in the list" rule for
   the current variation: can the appended 0-day row ever be a variation with
   NO entries at all (e.g. a stale initialVariation after a history delete)?
   What does the user see then?
3. rankedVariations: is the order genuinely total (no two distinct keys
   compare equal)? Does the view use it unmodified?
4. Naming: unrecorded equipment is unnamed when a preset exists. Is there a
   case where two picker rows now render with the SAME label?
5. Anything the fixes broke: the fixture gained a warmup-only session — does
   any other UI test index History rows by position?
6. New code with no caller, or a claim in the response that is not true.

This is a re-review after fixes; the second round's worst finding in this
repo has before now been a defect INTRODUCED by the first round's fix. Look
for that. Report by severity with file:line. Write to
.scratch/milestone-9-history-and-summary/codex-review-01b.md
