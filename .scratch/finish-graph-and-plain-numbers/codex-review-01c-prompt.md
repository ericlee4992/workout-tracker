Round 3 (T6) of finish-graph ticket 01. Round-2 review:
.scratch/finish-graph-and-plain-numbers/codex-review-01b.md. Boundary of the
fixes: cb6559f..d4b3ef9 (one commit, d4b3ef9). The response is in
issues/01-apple-shaped-heart-rate-graph.md under "Codex review 01b — response".

Scope: the two medium and two low findings only — the horizon now applied
before `perSlot`/aggregation in `displaySlots` (check `hasRange` still
compares against the FULL arrays, that a horizon of exactly a bucket edge
keeps the right count, and that the two new tests would fail on cb6559f);
`plotExtentSeconds` and the view's `xEnd`; the shared
`WorkoutTrackerStore.fixtureIsEnabled` and the ChartFixture header. And
whether any fix introduced a new defect.

If closed, say "clear" in one paragraph. Otherwise report by severity with
file:line. Do not modify source files. Write to
.scratch/finish-graph-and-plain-numbers/codex-review-01c.md
