# Codex review — soft-redesign S5 (Today's up next)

You are the independent reviewer; Claude implemented. Read AGENTS.md first. Checkout
`/Users/ericlee06/orca/workspaces/Health App/UI_design`, branch `ericlee4992/soft-05-today-up-next` (off `main`
`40b30d6`, where S1–S4 are merged).

Review S5: `git diff 40b30d6..bd09df9` (the first two commits are the ticket, D77 and a separate test-speed ticket —
docs only).

Read first: `work-record/soft-redesign/issues/05-today-up-next.md` (the user's decisions, scope, acceptance, Progress
with the strings and test evidence) and D77 in `docs/DECISIONS.md` (also D68, D52).

Check in particular:
1. **Learned order** (`Domain/UpNext.swift` `learned`): the follower rule, ties, the 42-day window, the fallbacks
   (`TemplateStats.dueNext` among used templates, then all), self-repeats, deleted templates, runs after `now`.
   Does it serve PPL, Upper/Lower A/B, a rarely used template and a never-run AI week as the ticket claims?
2. **My split / Not today** (`MySplit`, `MySplitStore`, `UpNextOverride`, `UpNext.suggestion` / `weekday`): in-order
   wrap, weekday skip and rest days, `pruned`, the override's lifetime (`isCurrent`: same day, until a workout
   finishes), "Choose template…" vs "Next in order", decode of missing/garbage data. These are UserDefaults view
   preferences — confirm no SwiftData/store change (`StoreFormatGuardTests` untouched) and that UI-test launches clear
   them (`WorkoutTrackerApp.swift`).
3. **Today and Train agree** (`Features/Today/UpNextReading.swift`, `TodayView`, `StartWorkoutView.leadTemplate`):
   same template incl. the override; Train during a rest day; `refreshingNow` on both; Resume while a workout runs.
4. **Repeat** (`WorkoutTemplateService.repeatWorkout`, `WorkoutStartRequest.repeating`, `WorkoutStartFlow`): frozen
   history (source untouched), machines only when active at the chosen gym, superset ids remapped, cardio plan,
   the start-while-active dialog path, a deleted source.
5. **UI** (`TodayPieces.swift`: `TodayUpNextCard`, `TodayNotTodayMenu`, `TodayRestDayCard`, `TodayNoTemplateCard`;
   `Features/Train/MySplitSheet.swift`): identifiers (a container id must not hide children's), spoken labels,
   AX sizes, the strings list.
6. **Tests:** `UpNextTests`, `WorkoutTemplateTests.repeatStartsTheCapturedStructureWithoutATemplate`,
   `TodayUpNextUITests`, and the `trainStartButton(_:)` helper that replaced 36 uses of `startEmptyWorkout` /
   `startCardio` — any test whose meaning changed (e.g. one that asserted Today's buttons)?

Run on **WT-iPhone27** `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B` (Claude uses WT-Floodlight), paths under
`/tmp/codex-s5/`: `build-for-testing`; unit `-only-testing:WorkoutTrackerTests/UpNextTests
-only-testing:WorkoutTrackerTests/WorkoutTemplateTests -only-testing:WorkoutTrackerTests/TemplateDueNextTests`; UI
serially (`-parallel-testing-enabled NO`): the warm-up
`WorkoutTrackerUITests/CardioUITests/testSavedDistanceEditorKeepsEnteredUnitsAndUntouchedMeasurements` (known to fail
since 2026-11-08 02:00 on `main` too — still run it first), then `WorkoutTrackerUITests/TodayUpNextUITests` and
`WorkoutTrackerUITests/CoreLoopUITests`. Show progress in the existing Orca tab "Test progress (Claude r2)"
`term_ac1339dc-202d-4c10-bab3-b528de726cbd` once it is back at its prompt — do not open a new terminal. Inspect the
captures. Do not modify files other than the report; do not commit or push.

Write `work-record/soft-redesign/codex-review-s5.md`: findings P1/P2/P3 with file:line, failure scenario and fix; end
with exactly `Verdict: clear` or `Verdict: not clear`.

## Round 1 result and round 2 (the implementer's note)

Round 1 (`codex-review-s5.md`): 3 × P2, all accepted and fixed in `25f1aea` (tests only after it):
1. **Finish advances Up next** — `UpNextReading.make(…, now:, clock: .now)` uses `max(now, clock)`: the SwiftData query
   re-renders Today/Train when a workout finishes, and that render's clock admits the new run.
   Test: `UpNextReadingTests.aWorkoutFinishedThisSessionAdvancesTheSuggestion` (in-memory store; snapshot an hour old).
2. **Choose → Next continues from the choice** — new `UpNext.resolve(templates:runs:split:now:override:lastFinishedAt:)`:
   chosen + skip ≥ 1 appends the chosen template as a virtual run and skips `skip - 1`; a weekday split steps through
   its days; Today's "Next in order" keeps `chosen`, "Choose template…" resets `skip` to 0.
   Tests: `UpNextTests.nextInOrderAfterAChoiceContinuesFromTheChoice` (in order incl. wrap, learned, no choice);
   `TodayUpNextUITests.testLearnedTemplateAndNoStartButtonsOnToday` now does Choose Leg Day → Next → Push Day.
3. **Expiry on a real completion** — `UpNextOverride.isCurrent(now:lastFinishedAt:)` ignores completions later than
   `now`; the reading passes the latest `finishedAt` ≤ now (not `startedAt`).
   Test: `UpNextTests.aChoiceExpiresOnARealFinishNotOnFutureHistory`.

Also: your note that the ticket said 11 Today UI tests — it is 9 methods (+ warm-up = 10 in a run); the ticket's count
is corrected in this round.

Claude's evidence (WT-Floodlight): unit `UpNextTests`, `UpNextReadingTests`, `WorkoutTemplateTests`,
`TemplateDueNextTests` exit 0, **28/28**; UI serial warm-up + `TodayUpNextUITests` exit 0, **10/10**.

Round 2: review `git diff bd09df9..5248d44 -- WorkoutTracker WorkoutTrackerTests WorkoutTrackerUITests`; on WT-iPhone27
(paths `/tmp/codex-s5/round2/`) `build-for-testing` and unit `UpNextTests`, `UpNextReadingTests`. Per the
testing-workflow ticket's rule (approved by the user 2026-11-08, `work-record/dev-speed/issues/01-testing-workflow.md`
item 7), rerun UI only if you find a UI-behaviour concern; Claude's UI evidence is above. Write
`work-record/soft-redesign/codex-review-s5b.md` ending with exactly `Verdict: clear` or `Verdict: not clear`. Your
round 1 report stays as written. Do not commit or push.

## Round 2 result and round 3 (the implementer's note)

Round 2 (`codex-review-s5b.md`): #1 and #3 closed; #2's no-history case open. Fixed in `5ae5b83`: `UpNext.suggestion`
`.off` builds the "Next in order" chain so each step shows a template not yet shown in that chain (the learned
candidate when new, else `TemplateStats.dueNext` over the not-yet-shown templates with REAL last runs), resetting
after every template has had its turn; `resolve` passes the chosen template as `alreadyShown`. Established rhythms are
unchanged (their learned steps are already new). Test: `UpNextTests.nextInOrderWalksEveryTemplateWithoutHistory`
(no history Legs → Pull → Push → Legs; history outside the window gives three different templates; chose Pull → Legs →
Push). Claude (WT-Floodlight): unit `UpNextTests`, `UpNextReadingTests`, `WorkoutTemplateTests`, `TemplateDueNextTests`
**29/29**; UI serial warm-up + `TodayUpNextUITests` **10/10**.

Round 3: review `git diff 5248d44..5ae5b83 -- WorkoutTracker WorkoutTrackerTests`; rerun your
`/tmp/codex-s5/round2/spec-repro.swift` against it; on WT-iPhone27 build and unit `UpNextTests`, `UpNextReadingTests`
(paths `/tmp/codex-s5/round3/`). UI only if you find a UI-behaviour concern. Write
`work-record/soft-redesign/codex-review-s5c.md` ending with exactly `Verdict: clear` or `Verdict: not clear`. Do not
commit or push.
