# Codex review — ticket 17 (cardio-only pause clock)

You are the independent reviewer (AGENTS.md T6); Claude implemented this. Review branch
`ericlee4992/beta-17-cardio-pause` against `main` (`git diff main...HEAD`).

Read first: `work-record/public-beta/issues/17-cardio-pause-clock.md` (the user's report and decisions, plan, build
notes, verification), D64 in `docs/DECISIONS.md`, the cardio spec's timer rule (`work-record/cardio/spec.md`),
D23/D44/D46 there, and AGENTS.md's code rules.

Check in particular:
1. **The rule (D64).** `Workout.isCardioOnly`, `cardioActiveSeconds(at:)`, `trainingSeconds(at:)`
   (`Domain/Cardio.swift`) and `Workout.duration` (`Domain/HistoryRendering.swift`): live = cardio and no exercise
   entry; finished = recorded cardio and no completed set. Is that consistent everywhere a cardio-only workout is
   decided (History facts' `hasLifting`/`hasCardio`, `historyStatsLine`, the detail's hero, finish's clean-up,
   history editing that deletes sets)? Running/paused/ended/multiple segments, the gap before the first segment,
   a workout finished while a segment records, `finishedAt` capping.
2. **Every consumer of the workout's time.** History rows, the week card, the month total, template stats, the finish
   and History time tile (`WorkoutSummary.workoutTime`), while the heart-rate chart's axis stays wall time
   (`summary.duration`). Look for any consumer still using wall time for a cardio-only workout, or one that now
   wrongly uses active time (exports, HealthKit, heart-rate series, anything keyed to wall clock).
3. **Live UI.** `LiveHeaderLine` (`elapsedAt`, `showsClock`; hidden only in cardio focus with one segment),
   `WorkoutResumeCapsule`, `TemplateStartCapsule`: a deleted workout must not be touched; TimelineView cost.
4. **Live Activity.** `WorkoutActivityAttributes.WorkoutClock` (Codable shared with the widget; an old payload
   without the field must still decode), `WorkoutActivityContent.workoutClock` (fixed `since` while recording so the
   2-second tick does not push a new card; `.hidden` / `.stopped`), the header view.
5. **Pill.** "Paused" only; `CardioReadout.pausedSeconds` removed with no remaining caller.
6. **Tests.** `WorkoutTrackerTests/CardioOnlyTimeTests.swift`, the changed `CardioReadoutTests`, the new/changed
   assertions in `WorkoutTrackerUITests/FloodlightCardioUITests.swift` cover the claims.
7. No stored-format change (no Gate S): confirm nothing persisted changed shape.

Run yourself: `xcodebuild … build` and `-only-testing:WorkoutTrackerTests/CardioOnlyTimeTests
-only-testing:WorkoutTrackerTests/CardioReadoutTests -only-testing:WorkoutTrackerTests/CardioTests
-only-testing:WorkoutTrackerTests/WorkoutActivityContentTests -only-testing:WorkoutTrackerTests/WorkoutSummaryTests`
on an iOS 27 simulator (WT-Floodlight `9E822EF6-DC67-4958-AEA2-D53D2D36D674`; your own `-derivedDataPath` and
`-resultBundlePath`), and report exit codes. UI tests are optional; say if you skip them. Do not modify files other
than the report; do not commit or push.

Write `work-record/public-beta/codex-review-17.md`: findings numbered P1/P2/P3 with file:line, failure scenario and fix;
end with exactly `Verdict: clear` or `Verdict: not clear`.
