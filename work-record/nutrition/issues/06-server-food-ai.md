# N6 — Server: food-photo, food-label, food-describe flows, limits, privacy text

Type: feature
Status: **proposed** (2026-11-07) — awaiting the user's approval
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
- Model `gpt-5.6-terra`, `store: false`, image inline and not kept, the same size limits (`MAX_JPEG_BYTES`); the
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

Not started.

## Comments
