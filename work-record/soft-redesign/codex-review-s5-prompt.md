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
