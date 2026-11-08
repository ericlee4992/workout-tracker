# Codex review — soft-redesign S3 (workout refinements)

You are the independent reviewer; Claude implemented. Read AGENTS.md first. Checkout
`/Users/ericlee06/orca/workspaces/Health App/UI_design`, branch `ericlee4992/soft-03-workout` (stacked on S2; S1–S3
are not in `main`).

Review S3 only: `git diff a1ec954..4e6e887` (`a1ec954` is S2's cleared tip; `70cdd8a` in the range only adds
`scripts/test-progress.sh`, a dev helper — glance at it, no deep review).

Read first: `work-record/soft-redesign/issues/03-workout-refinements.md` (scope, acceptance, Progress with the new
strings and test evidence), `work-record/ui-evolution/spec.md` Direction A, D44/D52/D64/D67 in `docs/DECISIONS.md`.
The approved prototype is at tag `design/soft-approved-2026-11-07`: `…/Screens/Workout/WorkoutHomeScreen.swift` and
`ProposedHomePieces.swift`, `…/Screens/Finish/ProposedFinishPieces.swift` and `FinishSummarySheet.swift` (~140–160),
`…/Screens/Cardio/CardioLivePanel.swift` (tray ~970–1070), `…/Screens/Templates/TemplateDetailScreen.swift` (~60–110,
~255–270), `…/Screens/Live/LiveBottomDock.swift` (`axLayout` ~145–170). Use `git show <tag>:DesignPrototype/…`.

Check in particular:
1. **Train**: `TemplateStats.dueNext` ordering and its use in Today and Train (same template in both); the live
   state (no lead while a workout runs; Resume); the tour anchors (`tour.templates` on the card when it is the only
   template; `tour.start`; `tour.askAI`); the card sharing `templateTile.<name>` (any query that now matches two
   elements or a test that reads a tile-only property).
2. **Finish**: the receipt's figures and omissions match the old tiles exactly (D44/D52), identifiers and spoken
   labels; `isShownAtFinish` edges; the order (bests → receipt → actions); VoiceOver order; the List rows.
3. **Cardio**: Pause/End layout at default/AX; "End" vs the spoken label; the Finish Workout slot's condition (only
   after the activity ended, not for a workout that also has lifting while not in cardio focus?) and that it runs
   the same finish path (drift dialog, discard of an empty workout).
4. **Template detail**: the menu (`templateMore`), confirmation unchanged, disabled when the template is gone; the
   machine-name comparison.
5. **AX rest slab**: `ViewThatFits` fallback, heart-rate rests (`axTimeReplacement`), the spoken label still
   carrying Next.
6. Tests (`TemplateDueNextTests`, `FinishComparisonRuleTests`, UI test edits) and the ticket's strings.

Run on **WT-iPhone27** `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`, paths under `/tmp/codex-s3/`: `build-for-testing`;
unit `-only-testing:WorkoutTrackerTests/TemplateDueNextTests -only-testing:WorkoutTrackerTests/FinishComparisonRuleTests`;
then UI **serially** (`-parallel-testing-enabled NO`), starting with the warm-up
`WorkoutTrackerUITests/CardioUITests/testSavedDistanceEditorKeepsEnteredUnitsAndUntouchedMeasurements`, then
`WorkoutTrackerUITests/TemplateDetailUITests` and `WorkoutTrackerUITests/FloodlightFinishUITests`. Report exit codes and
xcresult counts. The full capture/core-flow run stays deferred (the user). Do not modify files other than the report;
do not commit or push.

Write `work-record/soft-redesign/codex-review-s3.md`: findings P1/P2/P3 with file:line, failure scenario and fix; end
with exactly `Verdict: clear` or `Verdict: not clear`.
