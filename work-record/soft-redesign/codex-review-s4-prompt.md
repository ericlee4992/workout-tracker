# Codex review — soft-redesign S4 (History journal, Progress training metrics)

You are the independent reviewer; Claude implemented. Read AGENTS.md first. Checkout
`/Users/ericlee06/orca/workspaces/Health App/UI_design`, branch `ericlee4992/soft-04-history-progress` (stacked on S3;
S1–S4 are not in `main`).

Review S4 only: `git diff 55831f0..1e298e3` (`55831f0` is S3's cleared tip; `b7b3083` in the range is a STATE-only
handoff commit).

Read first: `work-record/soft-redesign/issues/04-history-and-progress.md` (scope, acceptance, Progress with the new
strings and test evidence), `work-record/soft-redesign/spec.md`, D52/D63 and D67–D76 in `docs/DECISIONS.md`. The
approved prototype is at tag `design/soft-approved-2026-11-07`: `…/Screens/Soft/SoftProgressBoard.swift`,
`SoftProgressScreen.swift`, `SoftRound3Screens.swift` (the journal). Use `git show <tag>:DesignPrototype/…`.

Check in particular:
1. **Pin compatibility** (`Domain/ProgressPins.swift`): the hand-written `Subject` Codable writes exactly the JSON the
   synthesised coding wrote for `lift` / `cardio` (pins saved by builds 8–9 read unchanged); a training pin is written
   as `{"cardio":{"activity":"training.<metric>"}}` with placeholder metric `time`. Confirm against `main`'s
   `ProgressPins.swift` / `ProgressTabView.swift` that an older build decodes it, hides it, and keeps it when it
   re-saves the list (Move Up / Remove / Add save from the full decoded list). Any path that would drop every pin?
2. **Weekly math** (`Domain/TrainingProgress.swift`): week boundaries follow `Calendar.current` (locale first
   weekday); empty weeks are 0; ≤ 12 weeks from the metric's own first week; future-dated workouts; `inputs` uses
   only finished, non-deleted workouts; volume = `HistoryWorkoutFacts.volumeKg` (warmups out, assisted/bodyweight out
   — the receipt's figure); running distance = indoor + outdoor run `distanceMeters` (check what that property
   returns for each entered unit, D52).
3. **Reading and views** (`ProgressPanel.swift` `ProgressReading.training`, `TrainingProgressView.swift`): the figure
   is this week so far, the caption "This week · last week N <unit>", no change badge; unit conversion for display
   only (lb/kg, km/mi); the empty state; the "…" menu for a training pin (no metric options; Move/Remove); the
   detail's weeks list (axis-label formatting of large volumes).
4. **History journal** (`HistoryOverview.swift` `journal` / `dayTitle`, `HistoryView.swift`, `HistoryPieces.swift`):
   a workout belongs to its local start day; Today / Yesterday / "Friday, Nov 6" / the year in another year; month
   breaks and the month card unchanged; rows without the date column (`.hidden`) and their spoken labels still giving
   the date somewhere for VoiceOver; the tour anchor `tour.historyList`; the `historyDay` identifier on a combined
   element; workout detail, edit and delete (tickets 19–20) unchanged; anything left referring to the removed week
   header.
5. **Add Chart**: the third segment "Training", search prompt "Charts", one tap adds and dismisses.
6. Tests: `HistoryJournalTests`, `TrainingProgressTests` (does the legacy-shape test really model the old decoder?),
   the new `FloodlightProgressUITests.testTrainingCharts*`, and the ticket's strings list.

Run on **WT-iPhone27** `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B` (Claude uses WT-Floodlight), paths under
`/tmp/codex-s4/`: `build-for-testing`; unit `-only-testing:WorkoutTrackerTests/HistoryJournalTests
-only-testing:WorkoutTrackerTests/TrainingProgressTests -only-testing:WorkoutTrackerTests/HistoryOverviewTests
-only-testing:WorkoutTrackerTests/ProgressPinTests`; then UI **serially** (`-parallel-testing-enabled NO`), starting
with the warm-up `WorkoutTrackerUITests/CardioUITests/testSavedDistanceEditorKeepsEnteredUnitsAndUntouchedMeasurements`,
then `WorkoutTrackerUITests/FloodlightProgressUITests` and `WorkoutTrackerUITests/HistoryEditFlowsUITests`. Report exit
codes and xcresult counts. The full capture/core-flow run stays deferred (the user). Do not modify files other than
the report; do not commit or push.

Write `work-record/soft-redesign/codex-review-s4.md`: findings P1/P2/P3 with file:line, failure scenario and fix; end
with exactly `Verdict: clear` or `Verdict: not clear`.
