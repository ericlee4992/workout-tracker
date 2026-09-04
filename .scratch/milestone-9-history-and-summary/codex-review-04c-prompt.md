Round 3 (T6) of milestone 9, ticket 04, branch milestone-9-history-and-summary.
Round-2 review: .scratch/milestone-9-history-and-summary/codex-review-04b.md;
response appended to issues/04-dumbbell-exercises.md. Boundary: 23e004c..2207bd7.

Scope: only whether the three round-2 findings are closed.
1. Preset re-homing now uses ExercisePresets.isDuplicate / cleanedName -- can
   it still create a duplicate the app itself would refuse?
2. The gate: the response says the tag cannot be pushed into the predicate
   and finished barbell source rows still pass the count. Verify the claim
   (try the predicate yourself if you doubt it), judge whether the stated
   ceiling is acceptable under D51's "cheap" wording or whether D51 should be
   amended to say what is actually true, and check propertiesToFetch is used
   correctly (mutating a partially-fetched object).
3. split carries supersetGroupID only when Supersets.isGrouped -- correct for
   the valid-group and stale-singleton cases, and does pruneOrphanGroups
   still run in both?
If closed and nothing new was introduced, say "clear" in one paragraph;
otherwise report by severity with file:line. Write to
.scratch/milestone-9-history-and-summary/codex-review-04c.md
