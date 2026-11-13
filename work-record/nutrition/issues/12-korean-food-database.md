# N12 — Korean food database (식품영양성분DB) for barcodes and search

Type: feature
Status: **approved — release 0.2.2** (the user, 2026-11-11: after 0.2.1 = workout lag + goal setup)
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

- **Key:** the user's data.go.kr service key for 식품영양성분DB (received 2026-11-11) is kept on the Mac in
  `~/.config/workouttracker/mfds.env` (`MFDS_API_KEY=`, mode 600, outside the repo). For the coverage and live checks
  copy it into the git-ignored `server/.dev.vars` and delete that after; never print it. At release the user sets the
  Worker secret `MFDS_API_KEY` (`npx wrangler secret put`, in a Terminal window) — never in chat or the repo.
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

**2026-11-12 — Step 1 coverage check done (branch `ericlee4992/nutrition-12-korean-db` off `main` `f56bf476`); waiting
on the user's scope decisions (below) before any code.** The key was read at run time from `~/.config/workouttracker/mfds.env`
by a throwaway script in `/tmp` (never printed; `server/.dev.vars` was not needed and does not exist). Raw outputs:
`/tmp/n12data/` (local, not kept).

### The API (식품영양성분DB정보, data.go.kr 15127578), confirmed with the key

- `GET https://apis.data.go.kr/1471000/FoodNtrCpntDbInfo03/getFoodNtrCpntDbInq03?serviceKey=…&type=json&pageNo&numOfRows`
  + filters `FOOD_NM_KR` (substring match), `MAKER_NM`, `ITEM_REPORT_NO` (prefix match — filter exactly ourselves;
  the field can hold several numbers joined by `/`), `DB_CLASS_NM` (`품목대표` / `상용제품`), `FOOD_CAT1_NM`,
  `RESEARCH_YMD`, `UPDATE_DATE`. The key goes in the URL (no header option) — never log URLs.
- Reply `{header: {resultCode: "00"}, body: {totalCount, items: [...]}}`; every value a string, numbers with
  thousands commas (`"2,117.000"`), missing values `""`. ~3.5 KB per row (157 nutrient fields).
- Fields we need: `FOOD_NM_KR`, `MAKER_NM`, `DB_GRP_CM/NM` (`D` 음식, `P` 가공식품, `R1` 원재료성), `SERVING_SIZE`
  = the basis (`100g` / `100mL`), `AMT_NUM1` kcal, `AMT_NUM3` protein, `AMT_NUM4` fat, `AMT_NUM6` carbs, `AMT_NUM7`
  sugars, `AMT_NUM8` fibre, `AMT_NUM13` sodium mg, `AMT_NUM24` saturated fat, `NUTRI_AMOUNT_SERVING` (1회 섭취참고량,
  often a category text like "유탕면(봉지)120g"), `Z10500` (식품중량: package / dish weight, e.g. "400.000g"),
  `ITEM_REPORT_NO`, `SUB_REF_NAME` (출처: 식품의약품안전처, 국립식량과학원, …), `FOOD_CD`.
- Size: 347,334 rows — 9,235 `품목대표` (dishes, raw foods, generic processed foods) and 338,099 `상용제품`
  (brand products and restaurant-chain items).
- Speed: 1.4–12 s per call (most 2–6 s) — sometimes over N8's 8 s upstream timeout.
- Order: fixed internal order (dishes, then products, then raw foods), not relevance: "바나나" has 1,871 matches and
  "바나나, 생것" is on the last page. With `DB_CLASS_NM=품목대표` it is among 14 results.
- Licence: 이용허락범위 **제한 없음** (no restriction), free. Credit still planned ("식품의약품안전처 식품영양성분DB").
- Limits: development account 10,000 calls/day (auto-approved); the **operating account needs 심의승인** (a review,
  requested by registering the app as a 활용사례) — the user's step before release if more traffic is needed.
- Data quirks: duplicates (the same dish from several survey years); restaurant-chain rows often give kcal, protein
  and sodium but blank fat/carbs; some dishes per 100 mL; the raw egg is "달걀", not "계란".

### Searches (Korean)

Dishes (김치찌개 401, 비빔밥 817, 떡볶이 2,907, 김밥 3,099), products (불닭볶음면 50, 새우깡 19, 허니버터칩 9,
바나나맛우유 11, 초코파이 202, 비비고 430) and raw foods (with 품목대표: 바나나, 사과, 삼겹살, 우유) are all well
covered, with sensible numbers. Weak spots: generic words match many dishes first (닭가슴살 → sandwiches); raw
ingredients need the 품목대표 filter or our own ranking.

### Barcodes (20 real Korean codes; Open Food Facts, C005 via its public sample key, then this DB)

- Open Food Facts holds only **6,457** products with an `880` code (C005 lists ~260,000 barcode rows). Its most-scanned
  ones: 92 of 100 with nutrition; its least-scanned / newest: ~65 with nutrition, ~20–25 name only, ~11 nothing.
- Its names for Korean products are almost all **English or French** ("Original Onion Ring", "Ottogi Korea Pancake
  Mix"), and this DB matches Korean names only: **searching this DB by the Open Food Facts name found 0 of 11** products
  that lacked nutrition there.
- 6 popular (Shin Ramyun, Buldak, Pepero, Jin Ramen, …): Open Food Facts had nutrition for all 6.
- 7 with weak entries: 3 had nutrition by now; 4 name only — C005 knew 3 of the 4, and this DB had the exact product
  by C005's report number for 1 (양파링 오리지널).
- 7 not in Open Food Facts (taken from C005's own sample list, so older, mostly discontinued products): this DB had 1
  (매일맛있는진간장골드).
- Net: of 11 barcodes with no nutrition in Open Food Facts, this DB rescued **2 (only through C005)**, 0 by name.
- C005: barcode → Korean name, maker, report number; last modified **2020-08-13**; 5 of 13 modern products tested
  were missing from it; separate key from 식품안전나라 (sample key: 5 rows a call).

### The user's Chrome tabs (2026-11-12; read through Chrome's tab list — agent-desktop lacks Accessibility permission)

| Tab | Useful? |
|---|---|
| 식품의약품안전처_식품영양성분DB정보 (15127578) | Yes — the API above, the main source |
| 전국통합식품영양성분정보(음식) 표준데이터 (15100070) | Yes, as a whole-file download (CSV/JSON) of the dishes, or its own API (up to 1,000 rows a page; separate 활용신청, auto-approved). Licence to confirm |
| 전국통합식품영양성분정보(가공식품) 표준데이터 (15100066) | Same, for processed foods (updated 2026-11-05) |
| K-FIND 식품영양성분 데이터베이스 OpenAPI page | A hub linking the same datasets (plus 원재료성식품 and 국가표준식품성분표); its "영양성분 DB 내려받기" is the official full download |
| 바코드연계제품정보 C005 | Only for barcode → report number; frozen since 2020; small gain (above) |
| 식품안전나라 main page | No (portal home) |
| 가공식품 품목별 영양성분 DB_20221231 (15112364) | No — 720 rows, one-off 2022, 공공누리 제4유형 (no commercial use, no changes) |

### Other Korean sources (searched 2026-11-12, after the user asked for more)

| Source | What it gives | Verdict |
|---|---|---|
| **HACCP 제품이미지 및 포장지표기정보** (data.go.kr 15033307, 한국식품안전관리인증원; `apis.data.go.kr/B553748/CertImgListServiceV3/getCertImgListServiceV3`) | Per HACCP-certified product: **barcode**, Korean name, report number, maker, capacity, the label's nutrition (`nutrient`, one text field), allergens, ingredients, package images; since 2017, "real time"; licence 제한 없음; dev and operating accounts both auto-approved | **Most promising for barcodes.** No barcode filter (name, report number, maker, type only), so barcodes would need a copy kept on our server, refreshed regularly. Not yet tested: the user's key is not registered for it (`SERVICE_KEY_IS_NOT_REGISTERED_ERROR`) — needs a one-click 활용신청 on data.go.kr. To check then: row count, how many 880 products, the `nutrient` text format |
| **푸드QR 정보 서비스** (15143798, `apis.data.go.kr/1471000/FoodQrInfoService02`, 11 operations) | **Barcode filter** (`brcd_no`) everywhere; structured label nutrition (nutrient name, amount, unit, per-serving and total amounts) | Good shape, tiny reach: under 0.1% of foods carried Food QR (2025 National Assembly audit). Key not registered either. A cheap extra fallback at most |
| 유통바코드 I2570 (식품안전나라) | barcode → name, report number | No: 53,245 rows loaded 2015, lacks Shin Ramyun |
| 식품 회수·판매중지 정보 (15074318) | Recalls with **barcode**, reason, grade, photo | Optional idea: warn when a scanned product is recalled. Out of N12's scope |
| 조리식품의 레시피 DB (15060073) | ~Korean home recipes with weight per serving, kcal, carbs, protein, fat, sodium; 제한 없음 | Optional: home dishes per serving; the main DB's dishes already cover most |
| 원재료성식품 표준데이터 (15100065) | Raw foods as a file download | Goes with the 15100066/15100070 files if we build the representative items in |
| 농진청 메뉴젠 음식별 영양성분 (15143461) | Dishes by ingredient | No: 공공누리 제4유형 (no commercial use, no changes) |
| 전국건강기능식품영양성분 표준데이터 (15155983) | Health-supplement nutrition | Low priority (most protein powders are ordinary foods here) |

### HACCP and Food QR, tested with the key (2026-11-12, after the user's 활용신청)

The same data.go.kr key works for both once applied for (one key, three services). Both lists downloaded in full
(HACCP 147 pages of 100, ~1.5 s each; Food QR 27 pages).
- **HACCP** (`CertImgListServiceV3`): 14,653 products (11,427 식품, 3,226 축산물). The `barcode` field is often
  "알수없음"; **5,194 valid unique barcodes** (5,157 with `880`), **3,445 of them with label numbers** in `nutrient`.
  `nutrient` is free text in varying forms ("열량 187kcal,나트륨 23.41mg,…"; "1회 제공량 기준(…) : 열량(kcal) 515kcal,
  …"; "100g당/총 내용량 300g 열량 80kcal, 나트륨 0% 0mg, …") — its basis (per serving, per 100 g, per package) must
  be parsed and a row skipped when unclear. Keys absent when empty. No barcode filter (a `barcode=` parameter is
  ignored), so barcodes need a server-side copy (refresh: 147 calls).
- **Food QR** (`FoodQrInfoService02`): 2,653 products, **2,324 valid barcodes**; `getFoodQrProdNsd02?brcd_no=` (the
  barcode as 14 digits with a leading 0) gives clean rows per nutrient (`NIRWMT_NM` 열량/나트륨/탄수화물/…, `CTA`,
  `IGRD_UCD`, basis `NTRTN_INDCT_TCT` + unit) — usable live, 2–4 s.
- Together **7,491 distinct barcodes** (27 in both). Overlap with ~240 Open Food Facts Korean codes sampled: 16
  (HACCP), 1 (Food QR) — mostly products Open Food Facts lacks; it has 6,457 Korean codes.
- The 20-code test: HACCP knew 4 (신라면, 까르보불닭볶음면, 양파링, 부침가루), all with numbers; Food QR 0. Of the 11
  without nutrition in Open Food Facts, HACCP filled **2** (양파링, 부침가루) directly by barcode.
- Licences: both 제한 없음. Operating approval: HACCP automatic; Food QR and 식품영양성분DB by review (심의승인).

### Bridge: barcode → report number → 식품영양성분DB (2026-11-12, the user's question)

식품영양성분DB has no barcode; its product key is `ITEM_REPORT_NO`. HACCP rows carry `prdlstReportNo` beside the
barcode (5,663 barcode rows with one), Food QR has `IMRPT_NO` (`getFoodQrProdMnfInfo02`), C005 `PRDLST_REPORT_NO`.
Sample of 80 HACCP barcodes, looked up by report number with an exact match on our side (the API's filter is a
prefix match; the field can list several numbers joined by `/`):
- of 50 **without** label numbers in HACCP: **8 found** (16%; e.g. 치킨브레스트햄, 오뚜기 바삭김말이, 동원훈제연어슬라이스)
  → roughly 300 more barcodes with numbers;
- of 30 **with** label numbers: **16 found** (53%) — for those, the DB's clean per-100 numbers can replace parsing
  HACCP's text.
C005 is the largest bridge (~260,000 barcode rows, frozen 2020, direct barcode lookup, its own key from 식품안전나라);
earlier it rescued 2 of 11. Worth re-testing with a real key now that the bridge is the plan.

### Decisions to ask the user

1. Search architecture: live API only (slow, poor order) / **the 9,235 representative items built into the server
   from the download (instant, well ranked) + the live API for brand products** (recommended) / a full copy (heavy).
2. Barcodes: C005 is not worth a second key now (2 of 11 rescued). Instead, a Korean barcode Open Food Facts can't
   fill opens the Korean search with the name prefilled (editable, "Is this it?" confirm, saved with the barcode).
3. Restaurant rows with blank fat/carbs: hide them, or show them with the blanks as "not given" (N8 reads blank macros
   as 0).

## Comments
