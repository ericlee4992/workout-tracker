Re-review (T6, round 2) of milestone 9, ticket 04, branch
milestone-9-history-and-summary. Round-1 review:
work-record/milestone-9-history-and-summary/codex-review-04.md; response appended
to issues/04-dumbbell-exercises.md; the design is now docs/DECISIONS.md D51.
Boundary for the fixes: 94a0652..23e004c.

Verify each round-1 finding is closed, not merely addressed. In particular:
1. D51: does the decision as written actually license what the code does,
   no more and no less? Is anything the code does NOT covered by it?
2. Preset re-homing: find-or-create by case/diacritic-insensitive name on
   the target. Can it create a duplicate of an existing target preset
   (whitespace, ExercisePresets.cleanedName rules)? Does `nextOrder` get the
   right existing list? Does the snapshot id move for an entry whose live
   preset is nil but snapshotPresetName is set? Is the source's preset left
   intact for its own barbell history?
3. Every-launch run: trace both paths in CatalogSeeder.reconcile (fast path
   and full pass). Is the count-query predicate correct and cheap (does
   `sourceIDs.contains($0.snapshotExerciseID)` compile to SQL)? Can the
   move run BEFORE the target rows exist on a fresh store? Does a no-op
   launch after the first leave the preferences row untouched (no save churn)?
4. Provenance fields: set on every moved row? Exported on both paths of the
   collector (frozen/draft context)? CSV column 37 position and header tests
   consistent (37) everywhere including docs/SPEC.md and the milestone-3 spec?
5. Superset carry-through in split: correct for the equipment-split case too,
   and does pruneOrphanGroups ever now remove a group it should keep?
6. Disabled counterpart row: is a disabled Button inside a List the right
   UX, and does the UI test still pass?
7. Anything the fixes introduced; round two's worst finding here has before
   now been a defect from round one's fix.
Report by severity with file:line. Write to
work-record/milestone-9-history-and-summary/codex-review-04b.md
