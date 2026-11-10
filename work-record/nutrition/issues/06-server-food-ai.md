# N6 — Server: food-photo, food-label, food-describe flows, limits, privacy text

Type: feature
Status: **code done — Codex clear (round 1), merged; live check, cost and deploy wait for the user** (2026-11-10) — the user's go-ahead (2026-11-10: "for N6 I give you the go-ahead")
Blocked by: N2
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/nutrition-06-server-ai` off `main`.
Spec: [nutrition](../spec.md). Decisions: D73, D75; D60/D61 (server, privacy); ticket 06 (AI proxy).

## Goal

Three new AI flows on the existing Worker, with the same sign-in, limits, image handling and logging rules as today's
flows.

## Scope

- **Flows** (added to `Flow` and `DAILY_LIMITS` in `server/src/ai.ts`; attempt cap = twice the limit, as today):
  - `food-photo` (limit **30**/day): a meal photo → items, each with name, portion description, grams, calories,
    protein, carbs, fat and a confidence; strict JSON schema.
  - `food-label` (limit **30**/day): a photo cropped to a nutrition-facts label → serving size, servings per container,
    calories, macros and the other facts printed; strict JSON schema; numbers only as printed (no guessing).
  - `food-describe` (limit **60**/day): text ("two eggs and toast") → items as food-photo.
- Model **GPT-6.1 Terra for every flow, old and new (D79)** — verify the exact API model id first; re-run each existing
  flow (routine-week, scan-machine, model-exercises) against it; the deploy is confirmed with the user. Then: `store: false`, image inline and not kept, the same size limits (`MAX_JPEG_BYTES`); the
  usage endpoint lists the new flows so the app's AI limits screen shows them.
- **Cost check:** measure tokens and cost per request for each flow (as ticket 10 did) and record them here; if any
  flow costs much more than ~1 cent, stop and ask the user before keeping the limits.
- **Privacy:** draft changes to `/privacy` (food photos, label photos and descriptions sent for one estimate and not
  kept; diet data stays on the phone; Apple Health use) and the App Store privacy answers; **the user approves the
  wording** (as in ticket 08). Deployed in R, with the release (an earlier deploy only with the user's go-ahead).
- Server tests (`npm test`): schemas, limits, the attempt cap, oversized images, a signed-out request.

## Acceptance

1. Server tests pass; each flow answers a real sample in local `wrangler dev` (no personal photos).
2. Cost per flow recorded; limits as decided or changed by the user.
3. Privacy draft approved by the user; Codex clear.

## Code map

- `server/src/ai.ts` (`Flow` `:19`, `DAILY_LIMITS` `:21`), `server/src/pages.ts` (privacy page), `server/README.md`.
- App client: `Domain/AIServerClient.swift`, `Domain/TerraAPI.swift`.

## Progress

**Built (2026-11-10, night — Claude; worktree `…/Health App/nutrition-06-server`, branch `ericlee4992/nutrition-06-server`
off `main` `c03bd12`).**
- **Model id verified:** `gpt-6.1-terra` (OpenAI's model page, https://developers.openai.com/api/docs/models/gpt-6.1-terra;
  pricing https://developers.openai.com/api/docs/pricing: $1 / 1M input, $5 / 1M output, standard tier — checked
  2026-11-10). `MODEL` switched for every flow (D79).
- **Flows** (`server/src/ai.ts`): `food-photo` (30/day; `{ jpeg, note? }` → `food_items`, effort medium, 8,000 output
  tokens), `food-label` (30/day; `{ jpeg }` → `food_label`, nullable numbers "only as printed", effort low, 4,000),
  `food-describe` (60/day; `{ text ≤ 500 }` → `food_items`, effort low, 4,000). Inputs travel as JSON data; photos as
  scan-machine's (checked JPEG ≤ 2 MB, inline, not kept). Replies checked: ≤ 15 items, names 1–100, numbers finite
  and bounded (grams ≤ 5,000, calories ≤ 10,000, macros ≤ 1,000; label sodium ≤ 50,000 mg), else `ai_invalid` (no
  success). Body limits 3 MB / 3 MB / 16 KB. `/v1/ai/usage` lists all six flows.
- **Migration `0007_food_flows.sql`:** rebuilds `ai_usage` with the new flows in its CHECK, every row copied.
- **Privacy draft** (`server/src/pages.ts`, for the user's approval): what stays on the phone (food, goals, weight,
  personal details); Apple Health (weight read/saved, food totals saved, active energy read — N9); camera (meal and
  nutrition-label photos); AI features (food estimates and label reading; what is sent; one estimate each; the food
  log never included). `POLICY_EFFECTIVE_DATE` is a "[…" placeholder so `npm run deploy` refuses until the user
  approves and the date is set.
- **Tests** `server/test/food-ai.test.ts` (request shapes, input checks, reply bounds, limits, migration); the usage
  test lists six flows.
- **Evidence:** rebased on `main` `46c9e92` (N5); `tsc --noEmit` exit 0; `vitest run` **7 files, 250/250**; script
  tests pass; `scripts/check-secrets.sh` clean. Privacy placeholder uses the tests' "[effective date]" form.
- **Not done — needs the user (the morning):** the cost check and each flow against a real sample need a live OpenAI
  key — the only one is a Cloudflare secret, and no local `.dev.vars` key exists (Claude did not search the Mac for
  keys); the deploy (it switches the live beta's three flows to the new model) is held until a real request per flow
  has passed, which needs either a local key or a signed-in session on the deployed server; the privacy wording's
  approval. App side of the new flows: N7.

**Codex round 1 (`codex-review-n6.md`): clear** — no findings; it checked OpenAI's docs (model id, low/medium effort,
nullable unions in strict schemas, image input) and probed migration 0007 in SQLite with foreign keys (rows, defaults,
key, cascade kept). Merged into `main` (no deploy). **Before deploy (the morning, with the user):** (1) a real,
non-personal sample through **all six flows** on `gpt-6.1-terra` — completed replies within the output caps and 60 s,
strict nullable schema accepted, image handling — recording tokens, latency and cost per flow (stop if any is much
over ~1 cent); (2) approve the privacy wording and set `POLICY_EFFECTIVE_DATE` (the predeploy guard refuses until
then; do not bypass it with `wrangler deploy`); (3) deploy order: back up, `npm run migrate:remote` (0007) **before**
`npm run deploy`; a rollback of the Worker keeps the expanded table.

**Live check (2026-11-10 morning, Claude; the user: "can you look for it" — the development key file
`~/.config/workouttracker/openai.env`, copied into a git-ignored `server/.dev.vars` for the run and deleted after, never
printed).** Local `wrangler dev` (local D1 migrated through 0007, a local test account), `MODEL = gpt-6.1-terra`, one
non-personal sample per flow — Wikimedia Commons images re-encoded as the app does (≤ 1568 px, JPEG 0.85): a leg press
machine, a chicken/rice/sweet-potato plate, the FDA's 2016 Nutrition Facts example label. All six answered `ok` with
valid structured replies; the label read exactly (2/3 cup (55 g), 8 servings, 230 cal, protein 3, carbs 37, fat 8,
saturated 1, fiber 4, sugars 12, sodium 160 mg). Tokens from the server's own count-only log; cost at $1 / 1M input and
$5 / 1M output (output includes reasoning):

| Flow | Tokens in / out (reasoning) | Cost | Latency |
|---|---|---|---|
| scan-machine | 2,746 / 239 (180) | $0.0039 | 7.2 s |
| routine-week (3 days, 45 min) | 637 / 1,091 (516) | $0.0061 | 15.1 s |
| model-exercises | 475 / 273 (172) | $0.0018 | 5.2 s |
| food-photo | 2,433 / 331 (94) | $0.0041 | 5.4 s |
| food-label | 1,861 / 79 (0) | $0.0023 | 2.8 s |
| food-describe | 272 / 244 (70) | $0.0015 | 4.7 s |

Every flow is well under the ~1 cent threshold — cheaper than GPT-5.6 Terra's ~1 cent per request (public-beta ticket
10); one person at every daily limit at once costs about $0.68 a day. Single samples (indicative). **Left for the
deploy:** the user's approval of the privacy wording and its effective date; then `migrate:remote` (0007) before
`deploy`.

**The user (2026-11-10): deploy everything at R (option 2)** — the model switch, the food flows, migration 0007 and the
privacy page go live together with the release, not before; the live beta stays on GPT-5.6 Terra until then. **And (same day): keep GPT-5.6 Terra for the existing flows; GPT-6.1
Terra only for food** (D79 amended) — the live check's latency (above) was the reason. `MODELS` maps each flow;
`TRAINING_MODEL` / `FOOD_MODEL`.

## Comments
