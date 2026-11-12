# N14 — Nutrition goals: one "Generate Goals" button; AI-generated goals; no Ask AI section

Type: feature
Status: **in progress** (the user, 2026-11-12)
Implementer: Claude; Reviewer: Codex (Paseo agent `edd217f6-…`), to "clear".
Branch: `ericlee4992/nutrition-14-ai-goals` off `main` `99bafefd` (worktree `~/.paseo/worktrees/1qmeipq9/nutrition-13-goal-setup`).
Decisions: reopens **D84** ("calculated on the phone only") and D80's Nutrition goals rows; extends D83(7)/(8) (no
consent screen, no "AI" wording). New decision **D85**.

## Goal (the user, 2026-11-12)

1. **Nutrition goals:** remove Personal details and Activity; one button, **Generate Goals**, opens the goal setup
   steps (sex … pace → the plan).
2. **AI generates the goals** — no statement or consent about sending it to AI ("users are already aware that function
   is utilizing AI").
3. **Remove the Ask AI section** in Profile (settings) — "users are already aware this app utilizes AI".

## The user's answers (2026-11-12)

- **No AI available** (signed out — e.g. first launch before sign-in — offline, over the limit, paused, an invalid
  reply): **fall back to the on-phone calculation**; the setup always finishes.
- **Limits:** **AI decides freely** — its calories, protein, carbs and fat are shown as given (every number still
  editable). The setup's pages keep their bounds (pace slow…fast, BMI 18.5 for the desired weight); only plausibility
  checks on the reply (as the editors allow: 500–10,000 cal, 0–1,000 g), else the fallback.
- **Permissions:** **keep the first-use prompts** of Scan Machine, Suggest exercises and Ask AI week; with Profile → Ask
  AI gone, an answer cannot be changed later (except by reinstalling). Goal generation asks nothing.
- **Apple Health:** **prefill only weights entered in Stacked** — never a weight read from Health — so what is sent is
  what the user typed or confirmed; "Stacked does not upload Health data" stays true.
- Raised to the user, accepted: App Review guideline 5.1.2(i) (disclosure and permission before sharing personal data
  with third-party AI) — risk of review questions.

## Scope

- **Server:** flow `nutrition-goals` (FOOD_MODEL), structured input (sex, age, height cm, weight kg, activity, goal,
  desired kg, pace kg a week), schema `{calories, protein, carbs, fat}`, checks, daily limit, migration 0009 (ai_usage
  CHECK), tests; deploy with the user's go. **Privacy page** (user approval + date): goal-setup answers sent; "turn the
  permissions off in Profile → Ask AI" lines removed/reworded. App Privacy in App Store Connect: check the types.
- **App:** plan page asks the server when signed in (a loading state), else / on failure the calculation; the
  generated numbers stay until regenerated or typed over (a stored marker on `NutritionGoal` → stored-format change:
  migration test from build 11's format, safety copy, `StoreFormatGuardTests`, export, **Gate S** before the next
  build reaches the phone). Nutrition goals: numbers + Generate Goals (+ Recalculate when typed over, as today);
  Personal details, Activity and Goal weight rows removed. Profile: Ask AI row and `AskAISettingsSheet` removed; the
  AI week's equipment step "Ask AI" row and the tour caption follow. Setup prefill: latest app-entered weight.
- **Copy:** new strings listed below for the user.

## Acceptance

1. Nutrition goals shows the numbers and Generate Goals only (captures light/dark × Default/AXL).
2. Signed in: the plan comes from the server; signed out / failing: from the calculation; tests for both.
3. Generated numbers survive Personal details / weight changes until regenerated; migration from build 11's store.
4. Profile has no Ask AI row; nothing dangling (callers, tour, AI week).
5. Server: tests + tsc; deployed with the user's go; privacy page approved.
6. Codex clear.

## Progress

### 2026-11-12 — built (Claude)

**Server.** `nutrition-goals` flow in `server/src/ai.ts` (FOOD_MODEL `gpt-6.1-terra`, low effort, 2,000 output tokens;
input re-serialized from checked fields — sex, ageYears 13–110, heightCm 100–260, weightKg 20–400, activity, goal,
desired 20–400 kg and pace 0.01–2 kg a week unless maintain; reply `{calories, protein, carbs, fat}` whole numbers,
500–10,000 / 0–1,000, else `ai_invalid`; 20 a day; 4 KB body); migration `0009_nutrition_goals_flow.sql` (ai_usage
CHECK rebuilt, rows kept); `test/nutrition-goals-ai.test.ts`; README. `npm test` **305/305**, `tsc` clean.
**Not deployed** (needs the user's go + the privacy wording below).

**App.** `Domain/GoalPlanAI.swift` (request body; reply check), `Features/GoalSetup/GoalPlanService.swift` (signed-in
generator; the Terra fixture under `-uiTestTerra`), `AIFlow.nutritionGoals`. `GoalSetupDraft`: asks once per request
(answers incl. pace + desired) on the plan page; while asking, "Making your plan" + a spinner, Start/Save disabled;
failure → the calculation with a line; typed numbers sit on top of the server's plan; `answers.generated`.
`NutritionGoal.generated` (Bool, default false) — the stored numbers stay through Personal details / weight changes
until the setup runs again or Recalculate (which goes back to the calculation); typed numbers keep their flags;
`NutritionGoalStore.Choices.generated`, `resolve(generated:overrides:)`. Setup prefill: the latest weight **entered in
Stacked** (`latestEnteredWeight`). Nutrition goals: numbers + **Generate Goals** (+ Recalculate when typed over or
generated); Personal details, Activity and Goal weight rows removed (`ActivityMenu` deleted). Profile: Ask AI row and
`AskAISettingsSheet` deleted; the AI week's equipment step loses its "Ask AI — On/Sign In" row (its Sign In command
stays); the tour's Profile caption drops "Ask AI". First-use permission prompts unchanged.

**Data (stored-format change).** `StoreFormatGuardTests.approvedFingerprint` `9d83c203…`, `build11Fingerprint`
`d339bba6…` (0.2.0 (11)). Fixture `Fixtures/Build11.store` (build-11 format, written by `main` `99bafefd` with the
design sample, Personal details, food sample + diary, nutrition charts; its goal given 170 lb / 0.4 kg a week with
sqlite3) + `GeneratedGoalsMigrationTests`. Export **v14** (`nutritionGoals[].generated`, true only). **Gate S before the
phone installs the build that carries this.**

**Own decisions:** 20 plans a day; low reasoning effort; the reply is checked only for plausibility (the editors'
bounds), as the user chose "AI decides freely"; one ask per set of answers (a failure is not retried until an answer
changes; Generate Goals again retries); Recalculate on a generated goal goes back to the calculation; "Generated" label.

**New strings (the user's decision):** "Generate Goals" · "Making your plan" · "Working out your calories and
macros…" · "Generated" · "Couldn't reach the server, so this plan was calculated on your phone." · tour: "Your
profile: units, appearance and backups — and this tour again."

**Privacy page — draft for approval** (`server/src/pages.ts`; date tentative "November 12, 2026" → the deploy day):
- AI features list adds "making your daily nutrition goals"; "you can turn each of those permissions off in Profile →
  Ask AI" → "remember your answer (reinstalling the app asks again)"; new: "Making nutrition goals has no separate
  prompt either: your goal-setup answers are sent when you reach the plan in the goal setup while signed in; signed
  out, or if my server cannot answer, your goals are calculated on your iPhone instead."
- What is sent adds: "for nutrition goals, your goal-setup answers — sex, age, height, your current weight as you
  entered it in Stacked, how often you work out, your goal, and the weight and weekly pace you chose."
- Support page: "To stop sending data to OpenAI, decline the AI features' permission prompts (or reinstall the app to
  be asked again), log food by hand rather than scanning or describing it, and set your nutrition goals while signed
  out (they are then calculated on your iPhone)."
- App Store Connect → App Privacy: check that Health & Fitness / sensitive data (sex, age, weight) are declared as
  collected for App Functionality (the user's step).
