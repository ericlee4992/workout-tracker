Round 1 (T6) of UI-redesign ticket 03 — the finish summary on the Ink / Amber design system
(which YOU built; Claude built this ticket, so you review). Ticket:
.scratch/ui-redesign/issues/03-finish-summary.md; the plan: .scratch/ui-redesign/spec.md
(ticket 03 and the constraints — copy policy, D52 plain numbers, ids/strings the tests read).
Boundary: fb20b08..HEAD on branch ui-redesign-03 (one commit).

Files: WorkoutTracker/Features/ActiveWorkout/WorkoutFinishedSheet.swift,
Features/History/HeartRateSummarySection.swift (shared with History detail),
Features/Design/ZoneColors.swift (new), Features/Design/StatTile.swift (layout tightened),
Features/ActiveWorkout/HeartRateBar.swift (zone colour now shared),
WorkoutTrackerUITests/HeartRateSummaryUITests.swift (scrolls to the chart).

Scope:
1. D44 — is every figure still OMITTED, never zeroed, when its fact is missing? Trace each tile.
2. D52 — plain numbers, no ≈, no "(estimated)": the units now ride in the value ("12 CAL",
   "600 lb"); the accessibility labels keep "title, value unit". Any regression?
3. Copy policy — any new `Text("…")` beyond numbers/units? ("Nothing to save", "Workout saved",
   "Time in zones", "Heart rate", "Exercises", "Workout details" all pre-exist.)
4. The zone bar: does the width arithmetic hold for one zone, for a zone with 1 s, for the
   `warm` zone; can it divide by zero; is the order stable? Are the colours (ZoneColors) legible
   on the card and distinct from the accent where they should be (zone four IS the accent — is
   that a problem next to amber buttons)?
5. `HeartRateSummarySection` is shared with `WorkoutDetailView` (History, not yet restyled): does
   the card + cleared row look right inside History's grouped List? Any identifier moved?
6. Tests: the receipt test's scroll loop — brittle? Are `summaryMaxHR` / `summaryVolume` worth
   asserting anywhere?
7. Anything the tighter `StatTile` breaks elsewhere (it is used only here so far — check).

Do NOT run xcodebuild or simctl (the simulator is in use). Review by inspection; verification is
in the ticket. Report by severity with file:line, or say "clear" in one paragraph. Do not modify
source files. Write to .scratch/ui-redesign/codex-review-03.md
