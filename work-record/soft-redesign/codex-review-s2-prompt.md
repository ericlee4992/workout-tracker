# Codex review — soft-redesign S2 (five tabs)

Same session and rules as S1 (you are the independent reviewer; Claude implemented). Checkout
`/Users/ericlee06/orca/workspaces/Health App/UI_design`, branch `ericlee4992/soft-02-tabs` (stacked on S1's
`ericlee4992/soft-01-look`; neither is in `main`).

Review S2 only: `git diff 64401d2..5c97a55` (`64401d2` is S1's tip).

Read first: `work-record/soft-redesign/issues/02-five-tabs.md` (scope, acceptance, progress — including the new
strings), D68 and D63 in `docs/DECISIONS.md`, ticket 02 of public-beta (the guided tour; `Tour.swift`'s header), and
the prototype's layout A: `git show design/soft-approved-2026-11-07:DesignPrototype/Sources/App/RootView.swift`
(`softTabs`), `…/Screens/Soft/SoftRound3Screens.swift` (`SoftTrainScreen`), `…/Screens/Soft/SoftTodayScreen.swift`
and `SoftTodayTop.swift` (round 5 day rings). Deliberate differences: the native `TabView` (not the prototype's drawn
tab bar); Today shows only its training parts until nutrition N5; Train's internal order is S3's.

Check in particular:
1. **Navigation and state**: every former route still reaches its screen — History's empty-state Start Lifting
   (`startLiftingRequest` now consumed when Templates appears), the finish sheet's View in History, Today's rows,
   the launch routes, the Live Activity / lock-screen commands, What's New, the tour (each step's tab and Train
   part; the `onAppear` that applies the first step; the snap-back when a tab is changed under the tour). Anything
   that relied on the old Workout tab being the launch tab or being alive.
2. **TrainView**: only the chosen part exists — what state is lost on a switch (pushed pages, sheets, a start flow in
   progress, StartWorkoutView's `restoredSelectedGym`), and is any of it a real problem? The principal-slot switch
   (`InlineTitleOrTrainSwitcher`) on pushed pages, at AX sizes, with VoiceOver.
3. **TodayView**: start flow at the remembered gym (D1) and with no gym; Resume; Up next ordering; the cardio picker;
   today's rows (dates across midnight / time zones); the day rings' states, colours in light/dark, AX layout and
   VoiceOver labels; the shared identifiers (`startEmptyWorkout`, `startCardio`, `resumeWorkout`) — can both Today's and
   Train's exist at once anywhere a test or VoiceOver would see them?
4. **Profile**: `SettingsView(title:)` as a tab root — its own `navigationDestination`s, sheets, sign-in and account
   pages, the tour anchor moved onto its title.
5. **UI tests**: the mechanical rewrite (`TabNavigation.swift`, 31 files, the per-file `tab(_:)` helpers, the tour
   test's spots). Any call that now lands on the wrong tab/part, or a test whose meaning changed (e.g. one that
   asserted the launch screen).
6. Strings and docs (D68, ticket).

Run yourself on **WT-iPhone27** `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`, paths under `/tmp/codex-s2/`:
`xcodebuild … build-for-testing`, then `test-without-building` with
`-only-testing:WorkoutTrackerUITests/FloodlightTourUITests -only-testing:WorkoutTrackerUITests/FloodlightSettingsUITests
-only-testing:WorkoutTrackerUITests/HistoryTemplateUITests -collect-test-diagnostics never` (UI classes the tab change
touches most); report exit codes and xcresult counts, and read any failures. The full capture and core-flow run stays
deferred (the user). Do not modify files other than the report; do not commit or push.

Write `work-record/soft-redesign/codex-review-s2.md`: findings numbered P1/P2/P3 with file:line, failure scenario and
fix; end with exactly `Verdict: clear` or `Verdict: not clear`.
