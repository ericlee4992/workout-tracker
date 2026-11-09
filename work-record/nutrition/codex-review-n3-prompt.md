# Codex review — nutrition N3 (goals, Personal details, onboarding step)

You are the independent reviewer; Claude implemented. Read AGENTS.md first. Checkout
`/Users/ericlee06/orca/workspaces/Health App/UI_design`, branch `ericlee4992/nutrition-03-goals` (off `main` `6e53446`).
Review `git diff 6e53446..HEAD`.

Read first: `work-record/nutrition/issues/03-goals.md` (the approved calculation; D80's Personal details; the user's
answers — tap-to-edit, mock and strings approved, the 1,350 floor, "Both" for first-time setup; Built; Evidence),
decisions D70, D80 (and D52 plain numbers, D45 heart-rate zones), `work-record/nutrition/spec.md`, DEVELOPMENT's
migration rules, `.claude/skills/ios-design/REVIEW.md` for the screens; swiftui-pro / swiftdata-pro apply (project
rules override).

Check in particular:
1. **Calculation** (`Domain/NutritionGoals.swift`, `NutritionGoalsTests`): matches the ticket's approved formula,
   factors, adjustments, floors (1,350 for "Prefer not to say"), protein/fat/carbs, rounding; `resolve` with typed
   numbers; age.
2. **Stored goal** (`Domain/NutritionGoalStore.swift`): the same-day vs new-dated-goal rule and frozen history with
   `NutritionMath.goal(on:)`; overrides surviving input changes; nothing written while details are incomplete;
   `matches`; the "latest goal" tie-break; time zones / day boundaries; the `.task` refresh on the goals page writing a
   new goal on a new day (intended? does it create noise rows?).
3. **Storage change:** `AppPreferences.heightValue/heightUnit/heightCm/sex`, `HeightUnit` pinned, the guard's new
   `approvedFingerprint` (user approval via D80) — additive to an existing entity: is a lightweight migration from the
   shipped format still sound (`NutritionMigrationTests` in the Unit plan)? Is a Simulator rehearsal needed again, or
   does the N2 one plus the fixture test cover it? Export v12 `preferences` fields (v12 unreleased, so not bumped —
   agree?). `setHeight` keeping value/unit/cm in step.
4. **Screens:** `Features/Nutrition/` (PersonalDetailsView + PersonalDetailsList, NutritionGoalsView,
   FoodGoalsSetupSheet + GoalChoiceMenus, DetailEditorSheets, MacroStyle), `ProfileTabView` rows and the optional
   `ProfileRow` action; choices held before the first goal (`pending`); editor validation ranges and number parsing;
   weight entries appended (history) vs edited; the date of birth shared with the heart-rate zones sheet.
5. **Onboarding:** `OnboardingCoordinator.offerFoodGoalsIfPending` — offered once after Skip or after a tour started
   from Welcome (not Profile → Show Tour), not when a goal exists, not over the tour; the `-uiTestFoodGoalsStep` gate.
6. **Ask AI:** `AIRoutineFlowModel.prefillMissingMeasurements` + `AIRoutineSheet` — the training profile wins; marked
   typed so a save stores it; never after the tester's first change.
7. **Tests:** `NutritionGoalStoreTests`, `NutritionGoalsUITests` (flow, onboarding, captures), the
   `-uiTestPersonalDetails` fixture.

Per AGENTS' reviewer rule (round 1): build; run the Unit plan; run as UI classes (3 workers): `AAAWarmUpUITests`,
`NutritionGoalsUITests`, `FloodlightSettingsUITests`, `FloodlightTourUITests`, `FloodlightProfileUITests`,
`AskAIUITests`, `HeartRateUITests/testZonesAreReachableFromSettings` (rerun failures serially before judging; the
warm-up's clone `kAXErrorServerNotFound` and the share-sheet close are known clone flakes). Look at the captures:
Claude's under
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/f473a23d-3eaa-41a2-9817-2ebe24bda24e/scratchpad/`
(`n3-caps2/`, `n3-caps3/`, `n3-caps4/`; results `n3-unit`, `n3-ui1`, `n3-ui2`, `n3-ui3`, `n3-onb` `.xcresult`).

Run on **WT-iPhone27** `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B` (`scripts/prepare-test-simulator.sh <id>` first), paths
under `/tmp/codex-n3/`. Show progress in the existing Orca tab "Test progress (Claude r2)"
`term_ac1339dc-202d-4c10-bab3-b528de726cbd` once it is back at its prompt — do not open a new terminal. Do not modify
files other than the report; do not commit or push.

Write `work-record/nutrition/codex-review-n3.md`: findings P1/P2/P3 with file:line, failure scenario and fix; a
Verified / Not verified / Known flaky block; end with exactly `Verdict: clear` or `Verdict: not clear`.
