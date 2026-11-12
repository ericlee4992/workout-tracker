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

Started 2026-11-12.
