Cross-review (T6) of milestone 8 tickets 01 and 04, on branch
milestone-8-history-and-charts. Boundary: e15f9e5..8e7f438 (commits b1019c8,
e009e46, 8e7f438). Read .scratch/milestone-8-history-and-charts/spec.md,
issues/01-*.md, issues/04-*.md, and docs/DECISIONS.md — especially the NEW D48
and the AMENDED D24, plus D20, D23, D25, D30, D36, D47.

Note: b1019c8 is my fix commit for YOUR previous review of tickets 02 and 03.
Verify those fixes actually hold; do not assume they do.

## What was built

Ticket 01 — progress charts. Domain/ProgressSeries.swift (pure) plus
Features/History/ExerciseProgressView.swift (Swift Charts). Delegates
eligibility, ranking direction, volume and e1RM to RecordsMath rather than
reimplementing them.

Ticket 04 — supersets. ExerciseEntry.supersetGroupID (optional UUID),
Domain/Supersets.swift, grouping UI on the exercise card, rest gated in
ActiveWorkoutView.updateRest, template round-trip with remapped ids, export
(JSON + CSV column 35), schema version 5.

## Attack these specifically

1. **THE D48 INVARIANT.** Grouping must not change records, PRs or volume. Can
   any path make a superset set rank differently from the same set logged
   alone? Check RecordsMath grouping keys and PreviousPerformance too.
2. **Rest gating.** ActiveWorkoutView.updateRest returns early for a non-last
   superset member. Can that strand a rest that is already running? What about
   un-completing, deleting the last member mid-rest, minimising, or the D43
   heart-rate rest? Does skipping/extending still behave?
3. **Adjacency vs id.** Supersets.runs groups by adjacency. Can reordering or
   deleting entries produce a stale group id, a "superset of one" badge, or two
   runs sharing an id? Is pruneOrphanGroups actually CALLED anywhere — this
   repo has shipped the absence-of-a-caller bug four times now.
4. **Template round-trip.** Ids are remapped per start. Does drift detection
   (TemplateDriftService) still work with grouping? Can a template lose its
   grouping on update() as opposed to create()?
5. **Charts.** Does ProgressSeries agree with the records screen in every case
   — assisted direction, warmups, mixed units, bodyweight with nil weight? Is
   the confidence gate (one session = no line) actually enforced in the VIEW,
   not just the model? Any crash on empty/one/huge series?
6. **Export/migration.** Schema 5 adds three optional fields across three
   tickets. Does a v4 file still decode? Does LegacyStoreMigrationTests still
   open the fixture, and would the user's REAL store migrate? Is the CSV column
   genuinely appended, not inserted?
7. **D24 amendment.** I amended locked D24 rather than contradicting it. Is the
   amendment honest and complete, and does the code match what it now says?

Report by severity with file:line. Say plainly if any claim in the tickets,
commit messages or decisions is false. Do not soften. Write to
.scratch/milestone-8-history-and-charts/codex-review-2.md
