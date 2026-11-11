# N12 — Korean food database (식품영양성분DB) for barcodes and search

Type: feature
Status: **approved — after release R** (the user, 2026-11-11: "add that as a new update after release")
Blocked by: R
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/nutrition-12-korean-db` off `main`.
Spec: [nutrition](../spec.md). Decisions: D72 (barcodes: Open Food Facts first, USDA fallback) — extended here.
Builds on: [N8](08-barcode-and-search.md) (`server/src/food.ts`, `Domain/FoodDatabase.swift`, the lookup screens).

## Goal

People in Korea get proper results: Korean name searches find Korean foods and dishes, and Korean barcodes that Open
Food Facts names but has no numbers for still open with official nutrition.

## Why

N8's live check found popular Korean products in Open Food Facts (Shin Ramyun, Buldak), but its coverage of less
common products is thin, and a search typed in Korean goes to USDA, which mostly finds nothing. The Ministry of Food
and Drug Safety's 식품영양성분DB has nutrition for ~16,000+ processed foods (plus dishes), keyed by food code and the
product report number (품목제조보고번호).

## What the sources give (2026-11-11, from their listings — confirm with the real key)

- **식품의약품안전처_식품영양성분DB정보** ([data.go.kr 15127578](https://www.data.go.kr/data/15127578/openapi.do)): food name,
  category, food code, nutrient basis amount, energy, carbohydrate, protein, fat, sugars, sodium, …, report number,
  maker, imported, origin. **No barcode field is listed** — it cannot be looked up by a barcode on its own.
- **바코드연계제품정보 C005** ([식품안전나라](https://www.foodsafetykorea.go.kr/api/openApiInfo.do?menu_grp=MENU_GRP31&menu_no=661&show_cnt=10&start_idx=1&svc_no=C005)):
  barcode → product name, maker, report number; no nutrition. Third-party notes say it stopped being updated around
  2018 and answers over http only. A separate key from a separate site.

## Scope (the user's choice, 2026-11-11: 식품영양성분DB first; C005 only if the coverage check shows it is needed)

- **Key:** the user applies for a data.go.kr service key for 식품영양성분DB and sets it as a Worker secret (e.g.
  `MFDS_API_KEY`) — never in chat or the repo; a temporary git-ignored `server/.dev.vars` for the live check only.
- **Korean search:** a query containing Hangul goes to 식품영양성분DB (processed foods and dishes) instead of USDA;
  normalised to N8's food shape (per 100 g/ml by the DB's basis amount; its serving when given), cached and limited
  as N8's search, credited (the source's required attribution — check its licence, e.g. 공공누리 type).
- **Korean barcodes** (GS1 Korea prefix `880`): Open Food Facts first as now. When it has the product's **name** but
  no usable nutrition (or none at all after USDA), search 식품영양성분DB by that name and maker and show the best
  candidates as **"Is this it?"** — the user confirms one before it is logged (a name match can be the wrong product
  or size; never logged silently). The confirmed food is kept on the phone with the barcode (N8's `SavedFood`), so the
  next scan opens it at once. Sharing confirmed matches between users: out of scope.
- **Not found** stays N8's: Scan the label (reads Korean labels) or Manual Add.

## Step 1 — coverage check (before building)

With the key: ~20 real Korean barcodes (a mix of popular and less common products, recent and older). For each:
Open Food Facts found with nutrition / name only / not at all; 식품영양성분DB found by name (and was the top
candidate right?). Recorded here. Decide from it:
- whether C005 (barcode → exact report number) is worth a second key — only if many barcodes are unknown to Open Food
  Facts and C005 actually knows them;
- the candidate matching rule (name + maker, size).

## Acceptance

1. Server tests: Hangul routing, normalisation (basis amount, units, missing vs invalid values as N8's bounds),
   candidate search, cache, limit, missing key (search falls back to USDA / says unavailable; barcodes unaffected).
2. App: "Is this it?" confirm flow (UI tests with the fixture: a match, no match, offline), credit shown, a confirmed
   food reopens offline.
3. Coverage check and a live check recorded here; Codex clear.

## Progress

Not started (after R).

## Comments
