Two things in one round (T6), branch history-14-zone-times (off history-13-save-as-template):
main..HEAD = 06c0274 (ticket 13) + the new commit (13's fixes + ticket 14).

A) Ticket 13, round 2 — your two P3s: (1) design record: steps 1/4 in
work-record/history-templates-and-zones/issues/13-save-as-template-from-history.md and captures
screenshots/history-13-{menu,alert,confirmation}(-axl).png; (2) the finish-sheet save path is
now tested: HistoryTemplateUITests.testTheFinishSheetStillSavesATemplate (prefilled name, Save,
the confirmation replacing the button; screenshots/history-13-finish-sheet-saved.png). 3/3.
Confirm or say what is missing.

B) Ticket 14, round 1 — time in heart-rate zones in History. The user: "In history I also want to
be able to see time spent in hr zone, either when you click the graph or just below the graph."
Ticket: issues/14-time-in-zones-in-history.md (below the graph, no tap). Files:
WorkoutTracker/Features/Design/ZoneTimeCard.swift (the finish sheet's private zoneCard lifted out;
rows now one accessibility element each), Features/ActiveWorkout/WorkoutFinishedSheet.swift (uses
it), Features/History/WorkoutDetailView.swift (a Section under the graph when any zone has time,
`historyZoneCard`), Domain/HeartRateHistoryFixture.swift (zoneSeconds(of:intervalSeconds:) against
a 185 max so the seeded hour has zones), tests (HeartRateSummaryUITests, RedesignScreenshotUITests
test05_historyHeartRate + test05_historyHeartRateLargeText). Captures
screenshots/14-05-detail-heart-rate(-zones)(-axl).png. Gates 51 unit + 10 UI green.
Review against REVIEW.md items 1, 3, 6, 9, 11, 12: is the zone card a card of a group under a
card of a group (the graph) — two peer cards in one list, fine, or a stack of cards where a
list should be? Do the zone colours still carry their meaning only? Does the fixture's zone
math (each bucket's MEAN classified; a 0 bucket counts nothing) match how the app folds zones
at finish (WorkoutSummary) closely enough for a capture fixture? Anything the finish sheet lost
in the extraction (diff the old zoneCard against ZoneTimeCard)? The full UI suite is running now;
its count goes in the tickets before merge. Do NOT run xcodebuild or simctl. Do not modify
source files. Report by severity with file:line, or say "clear" for each of A and B.
Write to work-record/history-templates-and-zones/codex-review-14.md
