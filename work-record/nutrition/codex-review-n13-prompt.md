# Codex review — N13 goal setup (round 1)

You are the independent reviewer; Claude implemented. Checkout: `/Users/ericlee06/.paseo/worktrees/1qmeipq9/nutrition-13-goal-setup`,
branch `ericlee4992/nutrition-13-goal-setup` (off `main` `e6255e85`). Review `git diff e6255e85..HEAD`.

Read first: `work-record/nutrition/issues/13-goal-setup.md` (Goal, Scope, Acceptance; Progress: the prototype, the safe
rates table, the user's answers, "built" — code, data, own decisions, design/wireframe/tells); decisions **D84** (this
ticket), D70 (goals calculated, dated, every number editable), D52 (entered units kept), D80 (Personal details), D25;
`docs/DEVELOPMENT.md` → *When a backup is required* and *Persistence and export lessons*; `.claude/skills/ios-design/REVIEW.md`;
swiftui-pro / swiftdata-pro apply (project rules override).

Check in particular:
1. **Math and safety** (`Domain/GoalPlan.swift`, `NutritionGoals.calories`): the pace shares and caps, rounding in the
   user's unit (0.05 kg / 0.1 lb) and the floor hold (`paces`: is the fastest offered pace always ≥ the floor in
   calories, including after rounding and in lb?), `nil` when nothing fits, the BMI 18.5 lower line, arrival rounding,
   `dailyAdjustment`; that goals stored before N13 (no pace) keep N3's −500 / +250 exactly.
2. **Store and commit** (`Domain/GoalSetupStore.swift`, `NutritionGoalStore`): what the commit writes; "unchanged"
   detection for height (entered unit/precision kept, D52) and weight (no duplicate weigh-in; an Apple Health weight as
   the latest); same-day vs next-day goals (D70); `matches()` with the new fields; maintain clears desired and pace;
   overrides kept; Personal details edits / Body weight's Recalculate keep the pace. Apple Health: does the new weigh-in
   reach Health the same way Personal details' weight does?
3. **Stored-format change:** `NutritionGoal`'s four optionals; `StoreFormatGuardTests` (`approvedFingerprint` d339bba6…,
   `release020Fingerprint` ad42bc46…); `Fixtures/Release020.store` really in 0.2.0's format and representative;
   `GoalSetupMigrationTests`; no first-launch rewrite of existing rows (a refresh of a migrated goal must not change it);
   export v13 (keys omitted when nil, a v12 file decodes; the version pins moved).
4. **First launch** (`OnboardingCoordinator`, `FirstLaunchView`, `WelcomeView`, `WorkoutTrackerApp`): cannot be left
   unfinished (no Skip/Close/swipe; `startTour` refused while the welcome is up; quitting part-way brings it back); Show
   Me Around saves then tours; a save failure keeps the cover and the answers; What's New / tour interplay; existing
   0.2.0 users who already answered the welcome are not forced in; `beginSetup` units.
5. **Existing users** (`NutritionGoalsView` Goal weight row, `ActivityMenu`): prefill (`GoalSetupDraft(prefill:)`:
   units, clamping, a finer activity kept), Close discards, Save Goals; the removed Goal menu and N3 onboarding sheet
   leave nothing dangling (callers, identifiers, docs).
6. **The flow UI** (`Features/GoalSetup/`): Dynamic Type / AccessibilityL, VoiceOver labels and selected traits, the
   keyboard over the weight field, Reduce Motion, the blocked-goal lines, Continue/Start enabled states; ios-design
   rules (one dominant treatment, cards group, controls). New strings are listed in the ticket (the user's decision).

Per AGENTS' reviewer rule (round 1): build; **Unit plan**; UI classes `AAAWarmUpUITests`, `GoalSetupUITests` (incl. its
4 capture tests — look at the PNGs), `NutritionGoalsUITests`, `FloodlightTourUITests`, `FloodlightAccountUITests`,
`FloodlightGoogleUITests` (ProfileAI plan, `-only-testing`, 2 workers; rerun failures serially). Claude's evidence:
`/tmp/n13-unit2.xcresult` (Unit), `/tmp/n13-ui1.xcresult`, `/tmp/n13-ui2.xcresult`. Use a simulator other than
WT-Floodlight if it is busy, `scripts/prepare-test-simulator.sh <udid>` first; derived data and results under
`/tmp/codex-n13/`. Claude runs nothing while you run. Do not modify files other than the report; do not commit or push.
Never open or send `~/Downloads/IMG_59*` (the user's local reference screenshots).

Write `work-record/nutrition/codex-review-n13.md`: findings P1/P2/P3 with file:line, failure scenario and fix; a
Verified / Not verified / Known flaky block; end with exactly `Verdict: clear` or `Verdict: not clear`.
