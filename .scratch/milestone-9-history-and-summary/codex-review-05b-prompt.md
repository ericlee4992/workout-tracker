Re-review (T6, round 2) of milestone 9, ticket 05, branch
milestone-9-history-and-summary. Round-1 review:
.scratch/milestone-9-history-and-summary/codex-review-05.md; response appended
to issues/05-finish-summary-heart-rate-graph.md. Boundary: 1f8f1bf..70c654a.

Verify each round-1 finding is closed, not merely addressed:
1. The replacement path: trace StartWorkoutView.startNew, the drift-resolution
   variant, and coordinator.monitor(for:) with a different workout. Is
   `end(previous)` reached in every order these can happen, and is
   `currentWorkout` (weak) still alive at that moment? Can end() be called
   twice for one workout and double-capture? Is the environment injection at
   the TabView correct for every tab that might need it, and does the
   full-screen cover's own injection still hold?
2. summarySamples: is "strictly inside a dominant gap > maxAttributedGap"
   the right rule? Consider a dominant source that stops for good mid-workout
   (no later dominant sample: the tail is not "inside" a gap and is dropped);
   is that acceptable, or should the trailing outage count when the other
   sensor kept reporting for a long stretch? Does the codex-review-2 #6
   regression still hold by construction?
3. refreshEnergy at the finish boundary; the truncating cap; durationSeconds
   in the chart -- confirm each with the tests, and check the x-domain when
   duration < interval.
4. Anything the fixes introduced.
Report by severity with file:line. Write to
.scratch/milestone-9-history-and-summary/codex-review-05b.md
