# N8 — Barcode and online food search (Open Food Facts + USDA)

Type: feature
Status: **proposed** (2026-11-07) — awaiting the user's approval
Blocked by: N7
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/nutrition-08-barcode` off `main`.
Spec: [nutrition](../spec.md). Decisions: D72.

## Goal

Scan a packaged food's barcode, or search a food by name, and log it from a food database.

## Scope

- **On the phone:** the camera's Barcode mode reads EAN-13 / UPC-A / EAN-8 (VisionKit / AVFoundation, no
  third-party code).
- **Server:** `GET /food/barcode/:code` looks up **Open Food Facts** first, then **USDA FoodData Central** branded
  foods; normalises to one food shape (per-serving and per-100 g); caches results in D1 (hits and misses, with an
  expiry). Signed-in only; a modest per-account rate limit (no AI cost). Open Food Facts needs a descriptive
  User-Agent and **attribution** (ODbL: "Food data from Open Food Facts" where its data is shown). USDA needs an **API
  key** that the user creates at api.data.gov and sets as a Worker secret (`USDA_API_KEY`) — never in chat or the repo.
- **Not found →** "Not in the database" with **Scan the label** (N7) and Manual Add.
- **Online search by name** *(approved by the user, 2026-11-11: "Yes, add online search")*: the Log Food search shows the user's own foods first,
  then USDA generic foods (e.g. "banana", "chicken breast") from `GET /food/search?q=`, cached; anything else →
  Describe (food-describe).
- A logged database food becomes a SavedFood (recent), so it works offline next time.

## Acceptance

1. Server tests: both sources, the fallback, normalisation, cache hit/miss/expiry, rate limit, missing key.
2. App UI tests with a stubbed server: found, not found → label scan, offline.
3. Real lookups of a few products (one US, one Korean) recorded here; attribution visible; Codex clear.

## Code map

- New `server/src/food.ts`, a D1 migration for the cache; `server/src/index.ts` routes; app `Features/Food/`.

## Progress

Not started.

## Comments
