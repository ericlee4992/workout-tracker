# Current project state

Updated **2026-11-14 (late): IN PROGRESS — CI fix + T6 default on branch `ericlee4992/ci-and-t6` (first green GitHub Tests run 43588010018); Codex round 1 not clear (3 findings, fixed in `b228c97c`), round 2 running; then merge. 0.2.0 (14) uploaded 2026-11-13 (live-workout 03 + N15; no Gate S) — the user's TestFlight steps.** Earlier: 0.2.0 (13) N12 and (12) N13/N14. The previous STATE (Floodlight delivery, the Oct 10–11 free re-sign, the Oct 3 public-beta handoff) is
archived byte-for-byte: [STATE before TestFlight](archive/STATE-2026-10-13-before-testflight.md). Verify Git on resume.

## RESUME HERE (2026-11-14)

- **IN PROGRESS (resume here) — CI fix + T6, branch `ericlee4992/ci-and-t6`** (worktree
  `~/.paseo/worktrees/1qmeipq9/workout-chart-machines`, Paseo workspace "Workout chart + save foods"; tip `0b04776d`,
  pushed; off `main` `d5abfdbf`). The user asked: make "Claude implements, Codex reviews" T6's official default (done:
  DECISIONS T6, AGENTS.md) and fix GitHub CI's Tests workflow, which never passed in 216 runs. Done on the branch:
  `.github/workflows/tests.yml` → `runs-on: xcode-27` (GitHub preview image) selecting Xcode 27.2 (macos-26's Xcode 26.6
  could not compile `LiveSetRow.swift`); `workflow_dispatch`; plain-iPhone simulator picker (it had picked "iPhone
  Duo"); `-testPlan Unit`; per-test allowance 600 s (120 s timed out 139 healthy tests queued for the main actor);
  25-min step cap; `.swift` errors printed on failure; artifact upload `continue-on-error`; a heartbeat that `sample`s the
  test host at 12 min into the `xcodebuild-log` artifact. Root cause of the old "hangs": `VNRecognizeTextRequest` never
  returns on the virtual Mac — the 8 `MachineLabelOCRTests` that call `MachineLabelOCR.perform/read` and
  `ScannerCorpusHarness.measureTheCorpus` are `.disabled(if: TestEnvironment.isCI, …)` (`WorkoutTrackerTests/
  TestEnvironment.swift`; `STACKED_CI` via `TEST_RUNNER_STACKED_CI=1` in the workflow); they run locally. AGENTS.md
  and DEVELOPMENT's CI note describe this. **Verified:** run 43588010018 (branch, workflow_dispatch) success — 1370
  tests, TEST SUCCEEDED, artifact shows exactly the 9 skips; locally Unit plan 1370/1370 none skipped
  (`build/results/ci-flag-off.xcresult`) and 1370 with the 9 skipped under the flag (`ci-flag-on.xcresult`). **Codex
  round 1** (agent `562c6d70-3c94-4da0-9760-a287cdd9a84b`, report `work-record/dev-speed/codex-review-ci.md`): not
  clear — P2 the corpus harness was skipped on CI even in its Vision-free `SCANNER_LLM=1` mode (now skipped only in
  Vision mode), P3 README's Building section, P3 STATE's merge command; all fixed in `b228c97c`. Round-1 fixes
  verified locally: OCR + corpus suites flag off 11/11, flag on 2 passed / 9 skipped, flag on + SCANNER_LLM 3 passed / 8
  skipped (`build/results/r2-*.xcresult`); branch CI run 43590959069 dispatched on `b228c97c`. **Codex round 2
  running** (brief `work-record/dev-speed/codex-review-ci-b-prompt.md`, report `…/codex-review-ci-b.md` — read its
  `Verdict:` line).
  **Next, in order:** (1) read the round-2 report and run 43590959069's result; fix findings, re-review to "clear"; (2) fast-forward `main` from the home checkout
  (`H="…/orca/projects/Health App"; git -C "$H" pull --ff-only && git -C "$H" merge --ff-only
  origin/ericlee4992/ci-and-t6 && git -C "$H" push`), refresh
  `release-build` (`git -C "…/workspaces/Health App/release-build" checkout --detach origin/main`); (3) confirm the push
  to `main` triggers a green Tests run (`gh run list --workflow tests.yml --branch main`); (4) rewrite this bullet and
  the "Follow-ups" CI line as done; tell the user. Gotchas: macOS has no `timeout`; `gh run view --log` is empty while a
  run is in progress — use `gh api repos/ericlee4992/workout-tracker/actions/jobs/<id>/logs`; Swift Testing results only
  print at the end of the run on CI.
- **Shipped:** **0.2.0 (14) uploaded 2026-11-13 16:14 EST** (`main` `20634c0f`): [live-workout 03](../work-record/live-workout-fixes/issues/03-chart-from-workout.md)
  (the chart from a live exercise, by machine) + [N15](../work-record/nutrition/issues/15-save-any-food.md) (save any
  food you open); no What's New (the user), no Gate S; record `work-record/release/0.2.0-build-14.md`. **The user's
  next steps:** Developer → install → try the live chart and the food bookmark → Friends with the What to Test note →
  Submit. Builds 12 and 13 were uploaded before it (their records hold their own steps: build 12 needed **Gate S**
  on the phone before installing — N13/N14 changed the stored format; build 13 did not).
- **Done 2026-11-14 (from the user's `/insights` review; merged, `main` `d5abfdbf`):** `scripts/testflight.sh` (archive / check / upload — the
  export options are written fresh each run; exit 2 = Xcode signed out), DEVELOPMENT's TestFlight checklist steps 3–5,
  an AGENTS.md accuracy pass (implementer per ticket, a pre-review self-check list, the STATE-top rule, CI's real
  status, delete rules, the design rule) and this STATE top. Codex clear (round 3); merged into `main`. T6's default is
  now "Claude implements, Codex reviews" (the user, 2026-11-14).
- **Next product work (the user to pick):** [research on what other apps lack](../work-record/research/2026-11-13-competitor-gaps.md)
  (2026-11-13). Proposed first: machine setup memory (seat/pins, with a note), logging a set from the Lock Screen,
  an "oil or sauce?" question after a meal-photo estimate; then the "It's taken" swap and a beginner machine card.
- **Still unverified on a phone (the user's TestFlight installs):** P1 workout lag, acceptance 1–2
  ([ticket](../work-record/performance/issues/01-workout-lag.md)); the first signed-in Generate Goals request
  (N14, [build 12 record](../work-record/release/0.2.0-build-12.md) — **Gate S before installing build 12 or later**
  if the phone is on build 11 or older: builds 11 (N13) and 12 (N14) each changed the stored format; 13 and 14 did not); the first signed-in Korean search (김치찌개) and Korean barcode (N12,
  [build 13 record](../work-record/release/0.2.0-build-13.md)); live-workout 03 and N15 (build 14).
- **Open for the user (not blocking):** live-workout 03's VoiceOver strings ("Last time", "Same model at another gym",
  "Not on this machine", "Other equipment", "All machines", "Progress"); N13's and N14's strings and own decisions
  (their tickets); App Store Connect → App Privacy: sex / age / weight declared for App Functionality (N14).
- **Follow-ups to propose:** a dev-speed ticket for the flaky live "New best" band test waits
  (`testMakingAFreshBestAWarmupTakesTheBandAway`); [dev-speed 02](../work-record/dev-speed/issues/02-ui-test-launch-unfinished-workout.md);
  GitHub CI's Tests workflow — fixed on `ericlee4992/ci-and-t6` (first green run 2026-11-14, `xcode-27` image; the 9
  text-recognition tests skipped there); merging after Codex review.
- **The user's rules from 2026-11-13:** match the app's current screens, not the outdated ios-design skill (AGENTS.md);
  no violet, icon-only bookmark; no link field for photo meals/items (content match, no Gate S).
- **Dated chores:** delete server D1 backups `~/WorkoutTracker-Backups/server/2026-11-11-release-r` by **2026-12-11** and
  `2026-11-12-n14-ai-goals` by **2026-12-12** (the privacy policy promises it).
- **Own models (separate, private repo `github.com/ericlee4992/stacked-ml`, local `~/orca/projects/stacked-ml`):** the
  user's RTX 5080 Windows laptop sets up the environment and runs/trains models there, starting with meal photos
  (compare local vision models with GPT first, distil only if needed). Its docs/STATE.md "For the app repo" lists
  anything that needs an app/server change (routing to a self-hosted model + privacy wording) — done from the Mac.
- **Cleanup (the user's go):** Paseo workspaces "N12 Korean food DB" (Codex agent `006b23e1-…`), "N13 goal setup"
  (`edd217f6-…`) and, once this branch merges, "Workout chart + save foods" can be archived. Branches are kept.

## History below (older NOW entries; superseded by RESUME HERE)

- **2026-11-13: RESUME HERE as it stood before the 2026-11-14 rewrite (superseded; kept verbatim):**
  - **0.2.0 (14) uploaded 2026-11-13 16:14 EST** (`main` `20634c0f`; live-workout 03 + N15; no What's New, no Gate S;
    release review clear; record `work-record/release/0.2.0-build-14.md`). **The user's next steps:** Developer → install →
    try the live chart and the food bookmark → Friends with the What to Test note → Submit. The Paseo workspace
    "Workout chart + save foods" and its Codex agent `562c6d70-…` can be archived (branches kept).
  - **Next tickets (the user, 2026-11-13), in order, in Paseo workspace "Workout chart + save foods"
    (`~/.paseo/worktrees/1qmeipq9/workout-chart-machines`):** 1) [live-workout 03 — the chart from a live workout, by
    machine](../work-record/live-workout-fixes/issues/03-chart-from-workout.md) (branch `ericlee4992/workout-chart-machines`);
    2) [N15 — save any food you open](../work-record/nutrition/issues/15-save-any-food.md). D87. Each UI-first, Codex clear,
    merged before the next. Release afterwards: the user's call.
    **Ticket 1 — DONE: Codex clear (round 3), merged into `main` 2026-11-13** (branch kept; Codex agent
    `562c6d70-3c94-4da0-9760-a287cdd9a84b` in this workspace — reuse it for N15). Open for the user: its new strings
    (ticket). Follow-up to propose: a dev-speed ticket for the flaky live "New best" band test waits. **N15 — DONE: Codex clear (round 3), TodayTrain 72/72, merged
    into `main` 2026-11-13** (branch kept). Both tickets of this workspace are merged; the workspace can be archived.
    The user's rules from this session: no link field for photo meals/items (content match, no Gate S); no violet,
    icon only; match the app's current screens, not the ios-design skill (AGENTS.md). Open for the user: live-workout
    03's new VoiceOver strings; a release (TestFlight) is the user's call. Follow-up to propose: a dev-speed ticket for
    the flaky live "New best" band test waits.
  - **N12 Korean food data — DONE: merged into `main` and server deployed 2026-11-13** (Codex clear, round 4; branch
    `ericlee4992/nutrition-12-korean-db` kept; [ticket](../work-record/nutrition/issues/12-korean-food-database.md), D86,
    review `work-record/nutrition/codex-review-n12.md`). Worker **`16f93322`** with secrets `MFDS_API_KEY` +
    `FOODSAFETY_API_KEY`; privacy "Effective November 13, 2026"; no migration. The user approved screens, strings and
    privacy wording. **0.2.0 (13) uploaded 2026-11-13 01:55 EST** (`main` `f6faa31f`, release review clear; record
    `work-record/release/0.2.0-build-13.md`; What's New "New: Korean foods"). **The user's next steps:** Developer →
    install (**no Gate S**) → signed in, a Korean search (김치찌개) and a Korean barcode (the first live N12 check) →
    Friends with the What to Test note → Submit. Follow-up:
    [dev-speed 02](../work-record/dev-speed/issues/02-ui-test-launch-unfinished-workout.md). Workspace "N12 Korean food
    DB" and its Codex agent `006b23e1-…` can be archived.
  - **Git:** `main` = N12 + the deploy date commit; home checkout updated.
  - **Shipped to TestFlight:** **0.2.0 (12)** uploaded 2026-11-12 17:55 EST = P1 workout lag + N13 goal setup + N14 AI
    goals (build 11 was uploaded earlier the same day; the user kept the version at 0.2.0 so external review is likely
    skipped). Records: `work-record/release/0.2.0-build-11.md`, `0.2.0-build-12.md`.
  - **Server:** deployed 2026-11-12 (Worker `4c9d03db`, migration 0009, privacy "Effective November 12, 2026").
  - **The user's next steps (not the agent's):** App Store Connect → build 12 to Developer → **Gate S on the phone before
    installing** (stored-format change since build 10: N13 + N14) → install and check Generate Goals signed in (the first
    live `nutrition-goals` request), What's New, a workout (P1's phone check: P1 acceptance 1–2) → Friends with the edited
    What to Test note → Submit.
  - **Next ticket (agent):** **0.2.2 = [N12 Korean food DB](../work-record/nutrition/issues/12-korean-food-database.md)**
    (needs the user's data.go.kr key) — in its own Paseo worktree off `main`; a new Codex reviewer agent there (the one in
    the N13 workspace, `edd217f6-…`, goes when that workspace is archived).
  - **Open for the user (not blocking):** N13's and N14's new strings and own decisions (their tickets); App Store Connect
    → App Privacy: sex / age / weight declared for App Functionality (N14).
  - **Dated chores:** delete server D1 backups `~/WorkoutTracker-Backups/server/2026-11-11-release-r` by **2026-12-11** and
    `2026-11-12-n14-ai-goals` by **2026-12-12** (the privacy policy promises it).
  - **Own models (separate, private repo `github.com/ericlee4992/stacked-ml`, local `~/orca/projects/stacked-ml`):** the
    user's RTX 5080 Windows laptop sets up the environment and runs/trains models there, starting with meal photos
    (compare local vision models with GPT first, distil only if needed). Its docs/STATE.md "For the app repo" lists
    anything that needs an app/server change (routing to a self-hosted model + privacy wording) — done from the Mac.
  - **Cleanup:** archive Paseo workspace "N13 goal setup" (`~/.paseo/worktrees/1qmeipq9/nutrition-13-goal-setup`); the
    P1 workspace was archived earlier. Branches are kept.

- **2026-11-12: N14 AI goals DONE — Codex clear (round 3), merged into `main`; server deployed.** [Ticket](../work-record/nutrition/issues/14-ai-goals.md),
  D85, review `work-record/nutrition/codex-review-n14.md`. Nutrition goals = numbers + Generate Goals; the plan from the
  server signed in (fallback: the calculation); `NutritionGoal.generated` (fingerprint `9d83c203…`, fixture
  `Build11.store`); Profile → Ask AI removed. Server: migration 0009, Worker `4c9d03db` (privacy "Effective November 12,
  2026" with the goal-setup exception); D1 backup `~/WorkoutTracker-Backups/server/2026-11-12-n14-ai-goals` (delete by
  2026-12-12). **0.2.0 (12) uploaded 2026-11-12 17:55 EST** (`main` `5058a16e`; record `work-record/release/0.2.0-build-12.md`) — next the user: Developer, **Gate S on the phone before installing**, Generate Goals signed in, then Friends. Not yet: a
  signed-in goal request from a device. For the user: N14's new strings (ticket). Branch kept; the worktree
  (`~/.paseo/worktrees/1qmeipq9/nutrition-13-goal-setup`, workspace "N13 goal setup") can be archived.
- **2026-11-12: N13 goal setup DONE — Codex clear (round 3), merged into `main`.** Branch
  `ericlee4992/nutrition-13-goal-setup` (kept); workspace "N13 goal setup" can be archived. D84 = the user's prototype
  answers. Stored-format change (NutritionGoal + desired weight + pace; fingerprint `d339bba6…`; fixture
  `Release020.store`). Evidence: Unit 1326/1326, UI 32/32 then 7/7 after fixes ([ticket](../work-record/nutrition/issues/13-goal-setup.md#progress),
  review `work-record/nutrition/codex-review-n13.md`). Codex agent `edd217f6-2a56-463d-abf4-8bbcf958a5af` (this
  workspace). **Next: 0.2.0 (11)** (P1 + N13; record `work-record/release/0.2.0-build-11.md`, branch
  `ericlee4992/release-0.2.0-11`) — **uploaded 2026-11-12 04:32 EST** (`main` `4be8a758`; release review clear) — next the user: Developer group, then Friends
  with the What to Test note;
  **Gate S on the user's phone before installing build 11** (stored-format change); then P1's phone check. For the user
  (not blocking): N13's new strings and own decisions (ticket).
- **2026-11-11 (late): tooling moved from Orca to Paseo** (the user; Orca may come back — its setup is kept in
  [tools-orca](agents/tools-orca.md), the active one is [tools-paseo](agents/tools-paseo.md)). Codex reviewer = a Paseo
  Codex agent, `gpt-6-astra` high, **full access** (the user). The Orca terminal IDs below are retired. **0.2.1 started:**
  P1 workout lag in Paseo workspace "P1 workout lag" (`wks_82b6a9c32a163410`,
  `~/.paseo/worktrees/1qmeipq9/perf-01-workout-lag`, branch `ericlee4992/perf-01-workout-lag` off `main` `97e63f9`);
  diagnose with measurements first, then N13. **P1 fixed on the branch (2026-11-11, `f379ba7`, pushed, not merged)**: the lag's
  causes and a typed-values-prefilled-over bug fixed; idle with heart rate 19.0 s of 20 s frozen → 2.3 s; Unit plan
  green (1,289). See the [ticket](../work-record/performance/issues/01-workout-lag.md#progress). Workout plan 73/74
  (the known flake passes alone). **Codex clear (rounds 1–2, `4c01a810`)** — Paseo Codex agent `2208216c-5a8a-48fa-ab89-876ff0ffdd22`
  (reuse it). **Merged to `main` 2026-11-12.** Phone check: the user tests it in the TestFlight build 0.2.0 (11) (planned as 0.2.1)
  (their choice) — P1 acceptance 1–2 stay open until then. Next: N13 goal setup on its own branch. Still the user's: release 0.2.0 (10) to Friends with the What to Test
  note, then the phone check.
- **Resume here (2026-11-11): R in progress** (branch `ericlee4992/release-r`; ticket
  `work-record/nutrition/issues/11-combined-release.md` → Progress has the checklist state, drafts and what waits for
  the user). Done: limits kept, full UI suite (381/386 + fixes), What's New (build 10) and What to Test approved,
  README, privacy/support copy (Codex clear), **server deployed 2026-11-11** (migrations 0007+0008, `USDA_API_KEY`,
  Worker `901eda5d`; backup in `~/WorkoutTracker-Backups/server/2026-11-11-release-r`, delete by 2026-12-11). Next:
  App Privacy done (Search History added). **Stacked 0.2.0 (10) uploaded 2026-11-11 20:07 EST** from `main` `e48ca60`.
  In Developer; **the user installed it and is testing** (2026-11-11) — Gate S was not taken first (the N1 safety copy
  covers the update; offer a container copy). Friends: the user, soon, with the What to Test note.
  **Next updates (the user, 2026-11-11):** **0.2.1** = [P1 workout lag](../work-record/performance/issues/01-workout-lag.md)
  ("the whole app lags during a workout": typing, scrolling, Add Exercise) then [N13 goal setup](../work-record/nutrition/issues/13-goal-setup.md)
  (required on first launch, no skip; asks sex and age too; reference screenshots local only in ~/Downloads);
  **0.2.2** = [N12 Korean food DB](../work-record/nutrition/issues/12-korean-food-database.md) (the user's data.go.kr key).
  **N8 DONE — Codex clear (round 5), merged into `main`.** N8 = barcode (Open Food
  Facts → USDA branded) + online search (USDA generic) through the server (`server/src/food.ts`, migration 0008, D1
  cache, per-account limit) and the app (Barcode mode, lookup screens, Log food "More foods", serving picker,
  credits). Live check done with the user's USDA key (temporary `server/.dev.vars`, deleted). **At R:** apply
  migration 0008 and set the Worker secret `USDA_API_KEY` (the user's; `npx wrangler secret put USDA_API_KEY`), deploy.
  5 Codex rounds (12 findings, all fixed: GTIN forms, ml vs g, logs, malformed replies, nutrient bounds, credits, the
  online row's check). Evidence, own decisions and new strings in the N8 ticket. Known flaky (parallel only, pass
  serially): `LogFoodFlowUITests` "2 servings", warm-up launch, a LogFood capture landing on Today.
  Codex terminal `term_df72a91c-b1a6-47a2-aedb-5b652fc9e0d0` (~context left: check before reuse).
  **For the user (not blocking):** N8's own decisions and new strings, the privacy draft's "Barcodes and food search"
  paragraph (N8 ticket); earlier tickets' items below.
  **C1 + N9b DONE: Codex clear (round 3), merged into `main`** (branch
  `ericlee4992/c1-n9b`). C1: no "AI" wording outside feature names (lines in `work-record/copy/issues/01-no-ai-wording.md`).
  N9b: Apple Health — Profile → Apple Health (read weight, read Burned, save weight, save food), reconcile sync by sync
  ids (`Domain/HealthNutritionSync.swift`, `Domain/HealthKitNutritionStore.swift`); 3 Codex rounds (T1 privacy: Ask AI
  prefills only an entered weight; S1–S7, R2-S1 fixed). Evidence and Verified / Not verified in the N9 ticket.
  **N10 DONE (2026-11-11): Codex clear (round 3), merged** — Progress body/food charts (Add Chart → Nutrition), History's
  food line → a day's food page (ticket `work-record/nutrition/issues/10-progress-history-nutrition.md`).
  **Next (the user, 2026-11-11):** N8 (barcode + online search by name, approved), then R. Codex terminal now
  `term_df72a91c-b1a6-47a2-aedb-5b652fc9e0d0` ("Review N10 round 2 (Codex)", ~78 % context left).
  **For the user (not blocking):** C1's camera/photo-library permission wording (left; proposal in C1's ticket); N9b's
  own decisions 1–5 and new strings (N9 ticket); N10's own decisions and new strings, incl. "N g under goal" for a past
  day's protein (N10 ticket). Known flaky:
  `FloodlightAIRoutineUITests.testBackKeepsInputsAndLeavingTheWeekAsksFirst` (Train tab, parallel run; serial passes).
  The user (2026-11-11) kept the review/test workflow as is (asked why rounds take long; no rule change).
  **N7 DONE (2026-11-10 night): Scan Food — Codex clear (round 4), merged.** D83 = the user's N7 answers (one entry
  named for the meal, name from the server, describe logged at once, both entry points, notification asked on the first
  scan, no consent screen, no "AI" wording, a library photo's own time). Data: `FoodPhoto` + `FoodEntryItem` (approved
  fingerprint `ad42bc46…`). Server `mealName` deploys at R. Evidence and Verified/Not verified in N7's ticket.
  **Open for the user (not blocking):** N7's new strings, own decisions and the privacy draft's food line (N7 ticket);
  older strings and own decisions in the N5 and N9 tickets.
  **Merged before N7** (each Codex-clear; the user's standing permission "merge whenever Codex clear"): N4 Log food
  (D81), N5 Today's food, N6 code (server food flows; D79 amended — training flows GPT-5.6 Terra, food flows GPT-6.1
  Terra; live check done; **deploy everything at R**), N9a Body weight.
  **Tools (Orca, retired 2026-11-11):** Codex reviews in terminal `term_20f2d1c6-628e-4ca8-9110-48b74ef8ec31` ("Review N7 round 2 (Codex)", this
  worktree, ~70 % context left; the older `term_3f1b832a…` is at 10 % — retired). Send the brief with `orca terminal
  send --terminal <id> --text … --enter --wait-submit 20`; watch the report file and approval prompts (not tui-idle).
  Test progress tab `term_ac1339dc-202d-4c10-bab3-b528de726cbd` (`bash scripts/test-progress.sh <log> <count> "<title>"`).
  2 parallel UI workers max; nothing runs while Codex runs. `server/node_modules` here is a symlink to the N6 worktree's
  (excluded via `.git/info/exclude`); N6's worktree `…/Health App/nutrition-06-server` is kept for the R deploy.
  Live AI checks: the dev key file and steps are in N6's ticket ("Live check") — copy into git-ignored `server/.dev.vars`,
  delete after, never print. Auto-handoff off (the user).
  **Goal:** the user's approved Soft redesign (Phase 1 — done) then nutrition (Phase 2), shipped to testers together as
  one release R (D76; no TestFlight build before R). Specs: [soft-redesign](../work-record/soft-redesign/spec.md),
  [nutrition](../work-record/nutrition/spec.md); decisions D67–D77. Workspace for both phases:
  `/Users/ericlee06/orca/workspaces/Health App/UI_design`. Prototype record: tag `design/soft-approved-2026-11-07`.
  **Git:** `main` = `origin/main` (see `git log`; N7 is the latest). Each ticket: a new branch off `main` in this worktree (Claude's
  own branches). The home checkout `…/orca/projects/Health App` is on clean `main`; fast-forward `main` there
  (`git -C "<home>" merge --ff-only <branch>` + push) — `main` cannot be checked out in this worktree.
  **Commands:** build `xcodebuild build-for-testing -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk
  iphonesimulator -destination 'platform=iOS Simulator,id=9E822EF6-DC67-4958-AEA2-D53D2D36D674' -derivedDataPath
  <scratch>/dd`; then `test-without-building … -testPlan Unit` (or `-only-testing:WorkoutTrackerTests/<Suite>`;
  `-test-iterations 10` for new suites); read results with `xcrun xcresulttool get test-results summary --path …`.
  **Done 2026-11-07/08:** S4 (History day journal; Progress Training charts + visible "…" menu; shared
  `refreshingNow`); the combined Phase 1 run (238/250 parallel → 3 S1–S4 test assumptions fixed; all ~777 captures
  checked); README refreshed; **S5 — Today's up next** (D77: learned split, "Not today", optional My Split in Train,
  rest days, no-templates last workout + Repeat, Start Lifting/Cardio on Train only; Codex clear round 3; merged). The
  user reviewed the app on the Simulator (WT-Floodlight, sample data) and found Profile ≠ prototype → **S6**.
  **Next, in order (the user's plan, 2026-11-08):**
  1. ~~Testing-workflow ticket~~ — **done 2026-11-09**: Codex clear (round 3), merged into `main`
     ([ticket](../work-record/dev-speed/issues/01-testing-workflow.md): before/after table, evidence). New workflow:
     `scripts/prepare-test-simulator.sh` first; scopes are test plans (DEVELOPMENT → Tiers and test plans);
     `scripts/explore.sh` for quick screenshots; reviewer rerun rule and reporting block in AGENTS.
  2. ~~N1 (safety copy)~~ — **done 2026-11-09**, merged `b911247` ([ticket](../work-record/nutrition/issues/01-safety-copy.md):
     files-only copy before a format change (store metadata vs model), newest 2 kept, restore at the next launch as a
     journaled swap with rollback, blocked open when a swap cannot be undone or a request cannot be withdrawn,
     full-screen waiting screen; 3 Codex rounds). Open for the user: 4 strings added after approval (in the ticket).
  3. ~~N2~~ — **done 2026-11-09**, merged `5f8ff92` → ~~S6~~ — **done 2026-11-09**, merged `6e53446` (D80) ([Profile like the prototype](../work-record/soft-redesign/issues/06-profile-layout.md): account card,
     grouped rows to sub-pages, Help; Goals & tracking filled by N3/N9 — confirm groups with the user) → N3 … N10 → R.
     Testing plan: per-ticket unit + UI + changed-screen captures; a core-flow check after N5 (ask); full suite at R (ask).
  **Open follow-ups:** Training Profile's Weight field sits half under the number pad (pre-existing); known failure
  `AskAIUITests/testEditingGeneratedWeekKeepsRowsAndSavesOnlyOnce`; candidate: a pre-seeded UI-test store to cut each
  launch's ~4 s (testing ticket, not done). The cardio-start flake and the clone keyboard failures are fixed by the
  testing-workflow ticket (`testGoalsNumberPadsHaveAppDone` passed in 2 parallel runs + Codex's serial run).
  **User preferences (memory):** every status update ends with a done / in progress / left board; multi-minute test
  runs show in ONE reused Orca tab "Test progress (Claude r2)" `term_ac1339dc-202d-4c10-bab3-b528de726cbd` (send
  `bash scripts/test-progress.sh <log> <count> "<title>"` to it; never open a new one); ask before runs over ~20 min;
  explain plainly; screenshots by SendUserFile **and** Preview.
  **Codex:** see Tools above (current terminal `term_20f2d1c6…`). If a Codex session asks approval for a
  simulator/orca command: read the `$ ` line, then send `--text "y"` alone; read any new script it runs before
  approving. It writes "Verdict: not clear" as a checkpoint while its UI run is going — act on the final report. Brief
  it to use WT-iPhone27 `47D21838-…`; Claude uses WT-Floodlight `9E822EF6-…`.
  **Gotchas (2026-11-09):** rebuild (`build-for-testing`) after any app OR test edit — `test-without-building` runs the
  old bundle; SwiftData has no public close, so file-level tests write stores via Core Data (`coordinator.remove`); a
  `fullScreenCover(isPresented: .constant(...))` dismissed another alert on the same view — use a real binding on a
  different view; XCUITest still lists a full-screen cover's presenter elements (assert not hittable, not "exists");
  a Codex session can die with API "Bad Request" on every request — open a fresh one (`orca agent launch --agent
  codex --surface terminal --prompt …`), point it at the saved `/tmp/codex-*` results; Codex's launch prompt may arrive
  late and twice (harmless); several waiters reading one xcresult at once collide — read it once.
  **Gotchas (2026-11-07/08):** run `scripts/prepare-test-simulator.sh` before a session's first test run (keeps the
  simulator booted — xcodebuild shuts down a simulator it booted — and keeps the keyboard up on parallel clones); this worktree has no `Config/Local.xcconfig` → Debug installs as
  `com.example.workouttracker`; the Simulator app is **DeviceHub** (`/Applications/Xcode.app/Contents/Applications/
  DeviceHub.app`); a manual launch needs `xcrun simctl privacy <dev> grant motion <bundle>` or an alert covers the screen;
  sample data: `xcrun simctl launch <dev> <bundle> -uiTestReset -uiTestDesignSample -uiTestDesignHistory
  -uiTestDesignGyms` (throwaway store; reopening from the home screen drops it); in 3-worker runs xcodebuild writes
  "Test case … passed" lines in batches as classes finish (the progress tab sits at 0 for a while); clones hit
  `kAXErrorServerNotFound`, keyboards not rising, dropped typing → rerun failures serially before diagnosing; compare
  against `main` (git archive into the scratchpad, build there) before blaming a branch; `.accessibilityIdentifier` on a
  container hides its children's ids; `openTrain` taps Train twice when a pushed page hides the switcher (pops it) —
  use one tab tap to return to a pushed page; UI tests start workouts via `app.trainStartButton(_:)`; the session
  scratchpad (derived data, captures, logs) is temporary — rebuild rather than rely on it.
- **Resume here (2026-11-06, handoff from the build 9 bug-fix session):** nothing in progress. Goal now: continue
  **exercise media** in the `public-beta` worktree ("Exercise media" entry below; ticket 03 + the DIY animation report's
  four open decisions). Next steps, in order: (1) the user closes the finished `beta-19-bug-fixes` worktree in Orca
  (merged; branch kept); (2) the user opens a new Claude tab in `…/workspaces/Health App/public-beta` — "Read STATE
  and continue the exercise media work"; that branch is a few docs-only commits behind `main` (merge it first);
  (3) the user's phone check of build 9 (cancel a workout → the Lock Screen card goes and stays gone, ticket 21;
  Add Exercise Exercises | Machines; template Machines tab); (4) ask before deleting `ericlee4992/beta-22-wip`.
  Gotchas: Codex's weekly limit was under 5% on 2026-10-23 (ask the user if reviews fail); serial unit runs on a
  freshly booted simulator are slow (`EquipmentLifecycleTests` 179 s on `main`) — warm the simulator or allow minutes;
  start UI runs with the warm-up (now `AAAWarmUpUITests`, in every test plan; testing ticket 01); never run one UI run per simulator
  alongside another heavy run (focus/launch flakes); never `pkill` broad xcodebuild patterns (other sessions'
  runs share the machine); `/private/tmp` scratch worktrees vanish — push WIP to a branch.
- **Agent skills (2026-10-31):** `swiftui-pro` and `swiftdata-pro` (Paul Hudson, MIT) vendored on branch
  `ericlee4992/swift-pro-skills` (checkout `…/Health App/swift-pro-skills`, off `main` `57a5764`); project
  overrides in AGENTS, pins in DEVELOPMENT. **Codex clear; merged to `main` `ac7d6fc`** (2026-10-31); skills load in new sessions. Optional next: a read-only swiftdata-pro/swiftui-pro check of the existing app, findings into a ticket (not started).
  [Ticket](../work-record/agent-skills/issues/01-vendor-swift-skills.md).
- **Done (2026-10-29): build 9 bug fixes** — checkout `…/Health App/beta-19-bug-fixes`, branch
  `ericlee4992/beta-19-bug-fixes` (pushed; **merged into `main`**; the session is finished). Tickets, each Codex-reviewed:
  [19 Add Chart by body area](../work-record/public-beta/issues/19-add-chart-body-areas.md) **clear** ·
  [20 delete one cardio](../work-record/public-beta/issues/20-delete-cardio-in-history.md) **clear** ·
  [21 Live Activity after cancel](../work-record/public-beta/issues/21-live-activity-after-cancel.md) **clear** (phone
  check with build 9) · [22 one Add Exercise (Exercises | Machines)](../work-record/public-beta/issues/22-one-add-exercise-button.md)
  **clear** (D65) · [23 template Exercises | Machines + Add Machine/Scan](../work-record/public-beta/issues/23-template-machines-tab.md)
  **clear** (D66), 2026-10-24. All five clear; **merged** (`main` `daa3cc6`, the user's go-ahead
  2026-10-24) and **build 9 uploaded 2026-10-24 02:25 EDT** from `main` `5ab7a16` (note approved; no What's New; no Gate
  S). **Build 9 added to Developer and Friends by the user (2026-10-29)** (note in
  [ticket 23](../work-record/public-beta/issues/23-template-machines-tab.md#build-9-tickets-1923--record)). Open: the
  user's phone check of build 9 (incl. ticket 21's Lock Screen card after a cancel); delete `ericlee4992/beta-22-wip`
  and this session's scratch checkouts (ask first).
  - Codex: one Orca terminal "Codex review 19-22" (`term_941e7732-91a5-4b1b-8749-651c3cf01354`); its **weekly limit is
    under 5%** (2026-10-23) — if it runs out, ask the user. Kept the current model when it offered gpt-6-luna.
  - Scratch: `ericlee4992/beta-22-wip` (pushed) holds the pre-merge history of 22/23 — delete after the merge (ask);
    its checkout `…/scratchpad/wt-22` is temporary.
  - Ticket 18 is reserved for the exercise-media session (`…/public-beta`, `ericlee4992/beta-18-exercise-media`).
- **Resume here (2026-10-18):** **Build 8 is live** (`main` **`7c81e28`**: tickets 16 Progress tab + 14 What's New + 17
  cardio-only pause clock, D64) — **Developer** and **Friends** both show it **Testing**; the phone has **0.1.0 (8)**
  and What's New appeared (the user). Friends: the approved note, testers notified; 3 testers (2 anonymous public-link
  on build 6, 2 of 20 limit). Build 7 was never given to testers. Build 9 uploaded 2026-10-24 (tickets 19–23); next build number **10**. Open:
  the Live Activity's cardio-only clock not checked on a device; ExerciseProgressView's metric-pill VoiceOver label
  (ticket 16). `main` was fast-forwarded to the branch's notes (the user, 2026-10-18), so `main` and
  `ericlee4992/beta-17-cardio-pause` are the same; start the next ticket on a new branch off `main`. [Ticket 17](../work-record/public-beta/issues/17-cardio-pause-clock.md).
- **Session 2026-10-17/18 summary:** done — 08 closed (tester feedback waived as a gate), 13 done, 15 feedback triage
  live (migration 0006; export `~/WorkoutTracker-Backups/server/2026-10-17-pre-15-migration` delete by 2026-11-16),
  16 Progress tab + 14 What's New merged (Codex clear; full unit 1041 pass; Progress 7/7, What's New 5/5, Settings+Tour
  20/20 UI), build 7 uploaded but skipped. **Gotchas:** watch Codex approvals by the prompt's `Reason:` line (identical
  "Yes, proceed" prompts otherwise get missed); a backgrounded xcodebuild reports the wrapper's exit — read
  `TEST SUCCEEDED/FAILED` in the log; App Store Connect session expired in Chrome (the user signs in); the iOS 27
  simulators are WT-Floodlight `9E822EF6-…` and WT-iPhone27 `47D21838-…` (run them in parallel for regression);
  UI tests: the first tests a fresh runner executes can fail with `kAXErrorServerNotFound` after a 60 s automation set-up (not the app) — put a short warm-up test first (ticket 17); rm with a variable path is blocked by the safety check — overwrite instead; ExerciseProgressView's metric pills carry
  `.accessibilityLabel("Metric")` that hides each option's name from VoiceOver (pre-existing, noted in ticket 16, not
  fixed). Next build number: **9**.
- **Ticket 13 (2026-10-17): merged and uploaded as TestFlight build 6** (`main` `f5151c2`). **Checked 05:30 EDT:**
  build 6 is in Developer and in Friends as **"Testing"** (submitted, through Beta App Review); the phone has
  **Stacked 0.1.0 (6)** (`devicectl`). The user: "the build 6 works well." **Ticket 13 done.**
  [Ticket 13](../work-record/public-beta/issues/13-goals-keyboard.md).
- **Friends (checked 2026-10-17 05:30 EDT):** public link **on** (`testflight.apple.com/join/SWyzYCtB`, limit 20);
  1 tester, **Anonymous via the public link** (iPhone 17 Pro Max, iOS 27.0.1; installed build 5 on Oct 17; no
  TestFlight feedback). D1: a new Apple account at 03:58 EDT (likely that tester), no feedback, no AI use. Workers
  Free: no `exceededCpu`; one `clientDisconnected` (10-15 20:20 EDT, 31 ms CPU); hourly job up to 9.4 ms. Details in
  [ticket 08](../work-record/public-beta/issues/08-external-testers.md).
- **08 final test pass done (2026-10-17):** build 6 "works well" (the user); `model-exercises` confirmed on the server
  (05:42 EDT, ok); Workers Free re-check clean (no `exceededCpu`); no full UI suite (the user: "not necessary").
  **Ticket 08 closed by the user 2026-10-17**: tester feedback is general, ongoing input, not a gate (item 3 waived).
  Follow-up candidate: a client disconnect can leave an AI slot held for the day and the request unlogged (ticket 08).

- **TestFlight 0.1.0 (5) from `1ce3424` uploaded 2026-10-15 19:36 EDT** (archive
  `scratchpad/tf/Stacked-0.1.0-5-1ce3424.xcarchive` of session 34187b7c; checked: build 5 incl. the widget, production
  `WTServerURL`, `WTGoogleClientID`, the new camera/photo/Health strings, the font, team X68M8SR6NA). Only
  `project.pbxproj` changed since build 4 — no Gate S. In "Developer"; **installed on the phone 2026-10-15**.
- **Archive checkout:** `/tmp/wt-live02` lost its `.git` file to macOS's temp clean-up (prunable; left untouched).
  Builds now archive from `/Users/ericlee06/orca/workspaces/Health App/release-build` (detached; `git checkout --detach
  <main commit>`; `Config/Local.xcconfig` copied in, identical to wt-live02's).
- **Production server version `8e0434be`** (deployed 2026-10-15 19:08 EDT from `0191b3f`): `/privacy` and
  `/support` live (effective October 15, 2026), invocation logs/traces off, one-year feedback expiry, hourly
  expired-session prune. No migration.
- **Data clean-up promises (D61):** delete `~/WorkoutTracker-Backups/server/2026-10-15-rehearsal` and
  `…/2026-10-15-pre-08-deploy` **by 2026-11-14**, and `…/2026-10-17-pre-15-migration` **by 2026-11-16** (exports: 30 days). While any download is in `server/.feedback`, run
  `node scripts/feedback.mjs prune` at least every 15 days (none downloaded so far).
- **Phone check of build 4 (2026-10-15):** the user: "I tried the features. they seem to work." Production D1 shows a
  Google identity (account `5efc7cb3…`, separate from the Apple one, by design) with a saved training profile
  (05, 09:05 UTC), one Ask AI week (`routine-week`, ok, 9.6 s) and one Scan Machine (`scan-machine`, ok, 3.9 s), no
  stuck in-flight slots. New Model → Suggest exercises with AI (`model-exercises`) was not tried; the user moved it
  to 08's final test pass.
- **08 progress (2026-10-15):** D1 backup procedure rehearsed; the user skipped the live off-switch and AI-limit
  checks; the user answered every privacy question and approved the pages and Claude's proposed terms (D61);
  deployed. **Workers Free for now** — tell the user if Free causes a failure (check Workers metrics for exceeded-CPU
  errors after the final test pass: server/README → Checking for Workers Free failures). [Ticket](../work-record/public-beta/issues/08-external-testers.md).
- **Branch for 08:** `ericlee4992/beta-08-testers` is merged into `main`; continue 08's remaining notes on the current
  branch (above) or a new short branch off `main`.
- **Codex:** one session for every review (AGENTS.md): Orca terminal **"Codex review"**
  (`term_be05cca0-da6f-4532-b4bd-c8cf220eebe8`). 08 pages and enforcement: rounds 4–6, **round 6 clear**
  (`work-record/public-beta/codex-review-08f.md`, HEAD `c7d47dd`). Ticket 13: Codex implemented (`915b84e`), Claude
  fixed the tests, Codex review round 2 **clear** (`codex-review-13b.md`). The session was resumed once with
  `codex resume 01a13ef3-f80c-70b1-ab14-220e750d8afb` after an interrupt closed it; reuse that terminal. Codex's
  sandbox cannot reach github.com (its pushes need approval); approve only commands within the task.
- **Next (08):** App Store Connect done 2026-10-15; the user submitted build 5 in external group "Friends" — **Beta
  App Review passed** (seen 2026-10-16). Invites: the user chose a **public link** (2026-10-16); Claude opened App
  Store Connect's Public Link dialog (Open to Anyone; a tester limit recommended, e.g. 20) — **not yet confirmed by the
  user**; check Friends → Testers → Public Link. On 2026-10-17 Friends showed **1 tester** (build 5: 2 invites,
  1 install) — find out who/how → final test pass incl. New Model → Suggest exercises with AI (confirm
  `model-exercises` on the server) → Workers Free check → acceptance: one external tester installs, signs in, sends
  feedback. Google sign-in **published (In production)** 2026-10-15 — any Google account can sign in; branding
  unverified (Google may not show the name Stacked on its sign-in screen).
- **Server:** https://stacked-server.stacked-server.workers.dev (version `8e0434be`, above; previously `0f2b49c4`).
  Secrets set by the user: APPLE_KEY_ID, APPLE_PRIVATE_KEY, TOKEN_ENC_KEY, OPENAI_API_KEY; `APPLE_TEAM_ID`
  `X68M8SR6NA` in `server/wrangler.jsonc`. The Sign in with Apple `.p8` is at `~/WorkoutTracker-Backups/keys/Auth.p8`
  (0600, never committed). Feedback: `node scripts/feedback.mjs list|show|screenshot|delete|prune`. Cloudflare blocks Python's default
  user agent (error 1010) — send a curl-like `User-Agent` from scripts.

## Agreed order to external testers (the user, 2026-10-13)

1. **06 app half** — AI through the server: remove the OpenAI key screen, sign-in required for AI, daily limits;
   then the deployed max-size-scan CPU check and the adversarial check. *(Merged 2026-10-14; phone smoke with build 3.)* [ticket](../work-record/public-beta/issues/06-ai-proxy.md)
2. **10** — GPT-6.1 Sol. *Closed 2026-10-14 without change: not cheaper per request, slower; the user kept Terra.* [ticket](../work-record/public-beta/issues/10-model-sol.md)
3. **05 rest** — Ask AI prefill + "Save to my training profile". *Merged; build 3 uploaded 2026-10-14.* [ticket](../work-record/public-beta/issues/05-profile.md)
4. **04** — Google sign-in. *Merged 2026-10-14 (Codex clear round 2); Google Cloud project Stacked set up; server
   deployed; Simulator sign-in/out/delete passed. Phone check with build 4.* [ticket](../work-record/public-beta/issues/04-google-sign-in.md)
5. **11** — automatic safety copy before a store-changing update. *Deferred by the user 2026-10-14: built with the
   first format change; `StoreFormatGuardTests` guards against an accidental one.* [ticket](../work-record/public-beta/issues/11-safety-copy.md)
6. **08** — external testers: privacy policy at `/privacy` and `/support`, App Privacy answers, external group, beta
   description, feedback email, Beta App Review, invites. *In progress: answers in (D61), pages built, in review.*
   A release-candidate test pass.

**README refresh (2026-10-16):** README, screenshots, server README, SPEC note, AGENTS rule — Codex **clear** (round 2);
the user's go-ahead ("do both"): `main` fast-forwarded to `8a94620`; GitHub description "Stacked: an iPhone gym log that
knows every machine at every gym. In TestFlight beta.", website = the privacy page.

**Next feature:** [14 In-app "What's New"](../work-record/public-beta/issues/14-whats-new.md) (needs-triage; before the first big update; D62 — every build also gets a What to Test note, DEVELOPMENT → TestFlight build checklist).
**Later (after the beta):** [09 App Store launch](../work-record/public-beta/issues/09-app-store-launch.md);
[12 marketing website](../work-record/public-beta/issues/12-marketing-website.md) (the user, 2026-10-15) — with a
domain of the user's own, which also allows Google branding verification.

## The phone

- iPhone 15 Pro Max, iOS 27.0, UDID `00008130-001E10C01E62001C`, bundle `com.ericlee4992.workouttracker`.
- **Installed: TestFlight Stacked 0.1.0 (8) = `main` `7c81e28`** (confirmed by `devicectl` 2026-10-18).
- **Previously: TestFlight Stacked 0.1.0 (6) = `main` `f5151c2`** (installed 2026-10-17).
- **Previously: TestFlight Stacked 0.1.0 (5) = `main` `1ce3424`** (uploaded 2026-10-15 19:36 EDT, installed 2026-10-15;
  only usage strings and the build number changed since build 4, no Gate S).
- **Previously: TestFlight Stacked 0.1.0 (4) = `main` `5a4ca0c`** (uploaded 2026-10-14 23:04 EDT, installed over build 2
  by 2026-10-15; build 3 = `1be0768` never installed). Uses AI through the server; no on-device OpenAI key.
- **Previously: TestFlight Stacked 0.1.0 (2) = `main` `5836b68`** (uploaded 2026-10-13 23:17 EDT, in place over build 1;
  Automatic Updates **off**). No Gate S before it — no store change in `936b18f..5836b68` (the backup rule below).
  The user verified real Apple sign-in and signed-in feedback ("I confirm 03 works"); account deletion/Apple
  revocation was not separately itemised. Still uses the on-device OpenAI key for AI until 06's app half ships.
- **Builds:** bump the build number (next **9**; 10 occurrences in `project.pbxproj`), archive from a recorded `main`
  commit in `…/Health App/release-build` (holds the paid-team `Config/Local.xcconfig`; `git checkout --detach <commit>` there),
  upload, add to internal group "Developer" by hand, the user installs from TestFlight. Auto-updates stay off.
- **Backups (the user, 2026-10-13: "yes skip the backup"):** Gate S only when an update changes what the phone stores
  — [DEVELOPMENT → When a backup is required](DEVELOPMENT.md). Otherwise check the diff against the installed commit
  and record it in the ticket. A direct USB copy of the TestFlight container worked once (2026-10-13); re-check before
  relying on it.
- **Latest backup:** `~/WorkoutTracker-Backups/2026-10-13-testflight/` (31 workouts, 411 sets; round trip exit 0).
  Captures need USB; the app stays closed; a failed process query proves nothing. Erase WT-Backup-01 after every use.
- Known: a long workout title truncates beside Cancel. Open: the minimized Live Activity's heart rate gets no
  recurring update (01b R3-P1); the home-screen widget was not checked on the TestFlight build.

## Tickets

| Ticket | State (evidence in each ticket) |
|---|---|
| 01 paid team + TestFlight | **Done** (App Store Connect "Stacked: Gym Log", Apple ID `6822152192`; group "Developer"). |
| 01b background mode | **Done**, merged. |
| 02 onboarding | **Done**, merged; on the phone. |
| 03 server + Sign in with Apple | **Done 2026-10-13**: deployed; app half Codex clear (round 3); build 2 verified by the user. |
| 04 Google sign-in | **Merged** `ba6cc20` (Codex clear); client ID configured, server deployed, Simulator passed; phone with build 4. |
| 05 profile | **Done in code** (merged `1be0768`, Codex clear); phone check with build 3. |
| 06 AI proxy | **Merged**; deployed checks done; build 3 uploaded — phone smoke next. |
| 07 feedback | **Done**; live since build 2. |
| 08 external testers | **Done 2026-10-17** (pages live, Beta App Review passed, public link, final pass; item 3 waived by the user). |
| 09 App Store | Not started. |
| 10 model Sol | **Closed, no change** (the user kept Terra after measurements). |
| 11 safety copy | **Scheduled as nutrition N1** (2026-11-07, D76); guard in `main`. |
| 13 Goals keyboard | **Done** — build 6, the user: "works well". |
| 14 What's New | **Done** — build 8; seen on the phone. |
| 15 feedback triage | **Done 2026-10-17** (Codex clear round 2; merged `07af7a6`; migration 0006 live). |
| 16 Progress tab | **Done** — build 8 (build 7 skipped for testers). |
| 17 cardio pause clock | **Done** — build 8 (Developer + Friends, 2026-10-18). |
| 19–23 build 9 bug fixes | **Done** — build 9 in Developer and Friends (2026-10-29); phone check open. |

## Working conventions (in force)

One branch per ticket off `main`; Claude implements, Codex reviews to "clear" in a visible Orca terminal
(`orca terminal create --worktree current --title … --command 'codex "$(cat <prompt>)"'`; watch the report file for the
`Verdict:` line, not Orca's idle state). The user's go-ahead before every merge (`git merge --ff-only`, push, confirm
the remote). `scripts/check-secrets.sh --staged` before every commit (public repo). Secrets are typed or piped by the
user locally, never in chat or the repo; never ask for the OpenAI key. Decline desktop control (`orca computer …`); the
user accepts legal terms and Claude never enters credentials. Multi-class UI runs use
`-parallel-testing-enabled YES -parallel-testing-worker-count 2` (the user, 2026-11-09; was 3), and never while the
reviewer's build/test run is going (or vice versa); unit tests serial; every run gets unique
log/status/result paths; read the results before recording them. Show screenshots in Preview and by file. At each
ticket's end: update STATE and the ticket and give the user a resume prompt.

Simulators: **WT-Floodlight** `9E822EF6-DC67-4958-AEA2-D53D2D36D674` (iOS 27; targeted runs), **WT-Onboarding**
`2CEC4AD8-F702-421F-B3B2-D68C302A3453` (sample data only), **WT-Backup-01** `A3D88C6F-6426-427A-9A0E-CF11A93798B1`
(Gate S round trips; erase after every use).

## Still waiting on the user / not yet exercised

- Visual acceptance of the Floodlight redesign on the phone. Not exercised anywhere: VoiceOver by a person, Reduce
  Motion at runtime, real GPS and sensors on the redesigned cardio screens, Lock Screen commands on a device, a restore
  from a backup on a phone, a non-US simulator region.
- Scratch to remove when no longer needed (ask first): `/tmp/wt-resign` (detached `b83cf39`); `/tmp/wt-live02` is the
  archive checkout — keep it. The Codex terminal "Review 03 app half" can be closed.

## Found 2026-10-02 (pre-existing, not caused by the public-beta work)

- **iOS CI ("Tests" workflow) fails on every `main` run since the Floodlight merge `4765b76` (2026-09-29):** the build
  stops compiling `WorkoutTracker/Features/ActiveWorkout/LiveSetRow.swift` on the `macos-26` runner (Xcode 26); the same
  code builds and tests locally on Xcode 27. A runner-image/SDK mismatch to look at with the deferred hosted-CI work.
  The new "Server" workflow (secret scan + server tests, Linux) passed on `e455222`.
- **`AskAIUITests.testEditingGeneratedWeekKeepsRowsAndSavesOnlyOnce` fails on `main`** (found 2026-10-14 in ticket 06's
  runs; fails identically on `0998e40`, 2 of 2): the reorder drag does not move the exercise ("the dragged exercise
  leads the session"). Same follow-up ticket as below.
- **Three UI tests fail on `main` too** (ticket 02's regression run): `FloodlightHistoryUITests` light/dark captures at
  `:100` ("a multi-day series draws", likely date-dependent since the month changed) and
  `CoreLoopUITests.testModelPickerFiltersAndSearchesDownToOneModel` (:274, the known model-picker flake). A small
  follow-up ticket.

## Still open from before the redesign (unchanged; details in the archived STATE)

- [AI ticket 06 — private device acceptance](../work-record/ai-gym/issues/06-device-acceptance.md): after the
  September 22 update, the phone checks were never reported. These cover all generated templates visible without a
  restart, Scan Machine inside template setup, preserved preferences and equipment, and old history visible. Also
  gym recognition and routine feedback. Do not ask for the OpenAI key in chat; the Mac credential
  `~/.config/workouttracker/openai.env` (0600) is not bundled.
- [Cardio hardware checks](../work-record/cardio/issues/02-device-acceptance.md): pause/reconnect, phone-position
  accuracy, background GPS, mixed sessions. The Watch companion has never been built or installed.
- [Deferred work](../work-record/deferred-work.md): scanner/picker, history/calculation, supersets, precision,
  migration/restore, HR, Watch, catalog, public launch and CI follow-ups. Non-failing invalid-frame warnings, the
  hosted CI runner hang, and actual Orca workspace Sleep also remain deferred.

## Other sessions and scratch state (do not clean without asking)

- **Checkouts after the 2026-11-06 clean-up** (the user's choice; layout rule in AGENTS.md → Checkout layout): the
  home checkout `…/orca/projects/Health App` is on `main` (switched 2026-11-06; it was on
  `ericlee4992/redesign-visual-proposal`, kept on origin); Orca worktrees `public-beta`
  (exercise media), `release-build` (detached, TestFlight archives) and `beta-19-bug-fixes` (finished — the user closes
  it in Orca). **Removed 2026-11-06 with `orca worktree rm` (branches kept, every one checked at its tip):**
  ai-schema-baseline, redesign-floodlight, ai-template-followup-review, redesign-prototype, review-finish-summary-order,
  review-session-handoff, cardio-api-research, review-ai-gym-code, review-ai-gym-spec, review-cardio-design,
  review-cardio-ui-refinements, review-cardio-units, review-compact-start-outdoor, review-handoff-sep20,
  review-start-capsules, review-verification-policy. Their never-committed files (Claude review reports; the
  `RedesignPrototype/` Simulator prototype of the Floodlight look) were first committed to their own branches —
  **local-only branches, not on origin**; the secret scan was clean. Earlier clean-up (2026-10-01): the eleven
  `/tmp/wt-floodlight/*` scratch checkouts and sixteen older worktrees; `/tmp/wt-floodlight/` kept `results/`,
  `shots/`, runner scripts and `dd-device/`. Simulators: **WT-Floodlight** `9E822EF6-DC67-4958-AEA2-D53D2D36D674`
  (iOS 27); WT-iPhone27 / WT-iPhone kept for regression and compatibility.
- The Graft index is a git-ignored local cache per checkout: rebuilt in this worktree 2026-10-01 (graft 0.18.0); the
  main checkout's is older (`graft build` refreshes it).
- **Branches on origin with commits not in `main`, all deliberately unmerged records** (nothing else is unmerged):
  `ericlee4992/redesign-visual-proposal` (4, the superseded 09-24 visual proposal, the main checkout's branch),
  `ericlee4992/cardio-design-prototype` (3, 09-17 cardio prototypes), `ericlee4992/finish-summary-second-pass` (3,
  09-17 finish-summary exploration), `ericlee4992/review-cardio-implementation` (3, 09-18 review records),
  `ui-redesign-16-active-workout` (1, a ticket-16 docs note). Every `redesign-floodlight*` branch is in `main`.
