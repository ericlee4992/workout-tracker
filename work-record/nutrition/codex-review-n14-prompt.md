# Codex review — N14 AI goals, Generate Goals, no Ask AI section (round 1)

Checkout `/Users/ericlee06/.paseo/worktrees/1qmeipq9/nutrition-13-goal-setup`, branch `ericlee4992/nutrition-14-ai-goals`
(off `main` `99bafefd`). Review `git diff 99bafefd..HEAD`.

Read first: `work-record/nutrition/issues/14-ai-goals.md` (the user's goal and answers — AI decides freely, fallback to
the calculation, keep first-use prompts, prefill only app-entered weights; Progress: built, deployed, verification);
D84 (N13) which this reopens; D52, D70, D80, D83(7)(8); the N9b Health promise ("Stacked does not upload Health data");
`server/README.md`; `docs/DEVELOPMENT.md` persistence/backup sections; swiftui-pro / swiftdata-pro.

**The server is already deployed** from `5a14da06` (the user's go): a server finding means a fix and a redeploy.

Check in particular:
1. **Server** (`server/src/ai.ts` nutrition-goals, migration 0009, tests): input validation and re-serialization (no
   injection; unknown keys dropped), the reply check, limits/accounting, body cap, the migration keeps rows.
2. **Privacy/support wording** (`server/src/pages.ts`) vs what the app actually sends (`GoalPlanAI.body`) and does —
   accurate and complete? Anything still promising Profile → Ask AI anywhere (app strings, docs, README)?
3. **Health promise:** can any Health-sourced weight reach the request (prefill uses `latestEnteredWeight`; the draft's
   inputs; a weight typed vs prefilled)?
4. **Draft generation** (`GoalSetupDraft`): ask-once per request, cancellation when leaving the page or changing answers
   mid-request (stale results applied to new answers?), Start/Save disabled while asking, the failure fallback, typed
   overrides on top, `answers.generated`.
5. **Store** (`NutritionGoalStore`, `NutritionGoal.generated`): generated numbers survive refreshes (Personal details,
   Body weight's Recalculate offer, a new day's age), typed overrides, Recalculate back to the calculation, `matches()`,
   same-day vs next-day goals; migration from `Fixtures/Build11.store`; fingerprint pins; export v14.
6. **UI:** Nutrition goals (numbers + Generate Goals + Recalculate), the plan page's loading/fallback states, Profile
   without Ask AI, the AI week step without its row; nothing dangling (identifiers, tests, tour, What's New text that
   mentions "Goal weight"); ios-design rules; new strings listed in the ticket.

Per AGENTS' reviewer rule (round 1): build; **Unit plan**; server `npm test` + `npm run typecheck`; UI classes
`AAAWarmUpUITests`, `GoalSetupUITests`, `NutritionGoalsUITests`, `FloodlightSettingsUITests`, `FloodlightAIAccessUITests`,
`AskAIUITests/testSignedOutRoutineOffersSignIn` + `testSignedOutRoutineAccessibility` (Full plan, `-only-testing`, 2
workers). Do not deploy, do not call the live server with real accounts. Claude's evidence: `/tmp/n14-unit2.xcresult`,
`/tmp/n14-ui1.xcresult`. Claude runs nothing while you run. Do not modify files other than the report; do not commit or
push. Never open or send `~/Downloads/IMG_59*`.

Write `work-record/nutrition/codex-review-n14.md`: findings P1/P2/P3 with file:line, failure scenario and fix; a
Verified / Not verified / Known flaky block; end with exactly `Verdict: clear` or `Verdict: not clear`.
