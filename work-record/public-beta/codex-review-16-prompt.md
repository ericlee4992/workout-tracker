# Codex review — ticket 16 (Progress tab)

You are the independent reviewer (AGENTS.md T6); Claude designed and implemented this with the user. Review branch
`ericlee4992/beta-16-progress-tab` against `main` (`git diff main...HEAD`; the prototype commits are history — the
reviewed code is the branch tip).

Read first: `work-record/public-beta/issues/16-progress-tab.md` (request, the user's decisions over four design rounds,
build notes, strings, verification), D63 in `docs/DECISIONS.md`, D9/D20/D23/D25/D36/D47/D52 there, SPEC's progress
chart notes, `.claude/skills/ios-design/REVIEW.md`, and AGENTS.md's code rules.

Check in particular:
1. **No second implementation.** `Domain/ExerciseHistory.swift` and `Features/History/LiftProgressValues.swift` were
   moved out of `ExerciseProgressView` — confirm its behaviour is unchanged (history scope, finished-only, snapshot
   fields; plotted/asEntered/change/callout; available metrics) and that a Progress panel draws exactly what the
   exercise chart draws for the same variation and metric (D36: never pooled).
2. **Pins (D63):** `Domain/ProgressPins.swift` — encoding stability (fixed variations stored flat), unknown activity,
   unreadable data, Most used resolution, metric fallback (D20), deleted-exercise hiding, move/remove/change in
   `ProgressTabView` (hidden pins keep their place), and that NOTHING is written to the SwiftData store (no
   store-format change; `StoreFormatGuardTests` unaffected).
3. **Cardio maths** `Domain/CardioProgress.swift`: sessions per workout per activity (multiple segments, unfinished
   workouts, missing distance), unit conversion (D52), rowing pace per 500 m, cycling speed, new-best and change
   direction (pace: faster = smaller; drawn negated), ties, bests earliest-on-tie, heart-rate averaging in the session
   line. No "≈" and no estimate note on indoor distances is the user's explicit decision (D63) — do not flag it.
4. **UI:** `Features/Progress/*` against the ios-design rules (one panel per pin and unlimited pins are the user's
   choice); accessibility labels (a label on a segmented control must not replace its options' names), identifiers,
   AccessibilityL layout (see `work-record/public-beta/captures/16/final/` — look at the PNGs), sheet semantics (Add
   Chart: Cancel/Add; charts: Close), performance (history fetched on appear/after sheets, not per render).
5. **Fixtures/tests:** `-uiTestDesignProgress`, `-uiTestKeepPins`, `-uiTestProgressNoPins` only take effect beside
   `-uiTestReset` and cannot touch a real store or a real user's pins; `WorkoutTrackerTests/ProgressTabTests.swift` and
   `WorkoutTrackerUITests/FloodlightProgressUITests.swift` cover the claims.
6. README / SPEC / D63 match the code.

Run yourself: `xcodebuild … build` and `-only-testing:WorkoutTrackerTests/ProgressPinTests
-only-testing:WorkoutTrackerTests/CardioProgressMathTests -only-testing:WorkoutTrackerTests/ProgressSeriesTests` on an
iOS 27 simulator (WT-Floodlight `9E822EF6-DC67-4958-AEA2-D53D2D36D674`; use your own `-derivedDataPath` and
`-resultBundlePath`), and report exit codes. UI tests are optional (they take minutes); say if you skip them. Do not
modify files other than the report; do not commit or push.

Write `work-record/public-beta/codex-review-16.md`: findings numbered P1/P2/P3 with file:line, failure scenario and fix;
end with exactly `Verdict: clear` or `Verdict: not clear`.

## Round 2

Round 1: [codex-review-16.md](codex-review-16.md), not clear (#1 mixed-distance pace, #2 fetches during render, #3
Reduce Motion). Claude's fixes: the ticket's "round 1 — response" comment and `git diff d6c1f49..HEAD`. Check all three
are closed and nothing regressed; rerun the build and the three unit suites (same rules and paths pattern, a new
result path). Write `work-record/public-beta/codex-review-16b.md`, ending with exactly `Verdict: clear` or
`Verdict: not clear`. Do not commit or push.
