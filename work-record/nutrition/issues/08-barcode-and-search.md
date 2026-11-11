# N8 — Barcode and online food search (Open Food Facts + USDA)

Type: feature
Status: **built, in review** (2026-11-11) — approved 2026-11-11 (online search included); branch
`ericlee4992/nutrition-08-barcode`
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

**2026-11-11 (Claude).** Built on `ericlee4992/nutrition-08-barcode` off `main` (`59e354b`).

- **Server** (`server/src/food.ts`, migration `0008_food_database.sql`, routes in `index.ts`):
  `GET /v1/food/barcode/:code` (GTIN check digit; UPC-A and 14-digit forms → EAN-13 key) → Open Food Facts v2, then
  USDA branded (`foods/search`, the code in all its 12/13/14-digit forms — USDA matches `gtinUpc` only exactly, live
  check); `GET /v1/food/search?q=` → USDA Foundation / SR Legacy / FNDDS, re-ranked (the food itself before dishes with
  it, raw first, plainer names first). One normalised shape (per 100 g, a serving with its nutrients, other measures).
  D1 cache `food_cache` (shared, no account; search keyed by SHA-256 of the query): hit 30 d, miss 1 d, search 7 d / 1 d
  empty; a miss is not cached without the USDA key or when a source failed (`502 food_unavailable`). Per-account daily
  limit `food_limits` (200 barcodes, 500 searches, hits count; `429 food_limit`), deleted with the account, pruned by
  the cron. No key: barcodes use Open Food Facts only, search `503 server_not_configured`. USDA key in `X-Api-Key`,
  never in a URL; logs only source + status. Privacy page draft gains "Barcodes and food search" and the two
  processors (still behind the predeploy placeholder — the user approves the text at R). README updated.
- **App:** Barcode mode reads EAN-13 / UPC-A / EAN-8 / UPC-E with the camera's own `AVCaptureMetadataOutput` (same
  session as the photo; torch still works), only inside the band (`LabelCameraView.barcodeBand`). A code already on
  the phone (one of My foods first, then the most recently logged) opens at once with no network; else the lookup
  screen → found: Selected food (`source: .barcode`), credited ("Food data from Open Food Facts" / "… USDA FoodData
  Central") → Log; not found: "Not in the database" + **Scan the label** (camera switches to Food label) + Manual Add;
  failure: the reason + Try again + Manual Add. Log food's search on All: your foods, then **More foods** from USDA
  (signed in; 450 ms debounce; + logs one serving with Undo; tap opens it), credited; Estimate stays. A database food
  opened or logged becomes a `SavedFood` (`databaseID`, not My foods); only opened = a cached lookup, hidden from search
  and Create meal until logged or bookmarked (`SavedFood.isCachedLookup`). Selected food offers a database food's other
  servings by weight (`FoodLog.servingChoices`, `FoodLog.log(…, option:)`). No schema change (N2 had `barcode`,
  `databaseID`, `servingOptionsData`, `FoodSource.barcode/.search`).
- **Fixture** (`FoodDatabaseAccess.swift`): `-uiTestTerra` answers barcodes and searches locally; flags
  `-uiTestBarcodeNotFound`, `-uiTestTerraOffline`, `-uiTestFoodDatabaseOfflineAfterOne`, `-uiTestFoodSearchOff`,
  `-uiTestBarcodeNoRead` (added to N7's capture launch so its Barcode-mode capture is not interrupted).

### Live check (acceptance 3), 2026-11-11

The server's lookup functions against the real Open Food Facts and USDA (the user's key, read from a temporary
git-ignored `server/.dev.vars`, deleted right after; never printed). Through the functions, not the deployed route
(deploy is R):

| Lookup | Result |
|---|---|
| `3017620422003` (EAN-13, FR) | Open Food Facts: Nutella, Ferrero — 539 kcal / 100 g |
| `049000028911` (UPC-A, US) | Open Food Facts: Diet Coke, "1 can (354.9 mL)" — no grams claimed (fixed after this check) |
| `0016000275287` (US) | Open Food Facts: Cheerios, 39 g = 140 kcal; **USDA only** (OFF disabled): Cheerios Cereal, usda:2517161 |
| `8801043014809` (KR) | Open Food Facts: Shin Ramyun, Nongshim — 120 g = 505 kcal |
| `8801073110502` (KR) | Open Food Facts: Buldak Ramen, Samyang — 1 bag (140 g) = 560 kcal |
| `0000000000017` | not found |
| search banana / chicken breast / apple / egg | Banana, raw · Bananas, raw…; Chicken, breast, boneless, skinless, raw…; Apple, raw…; Egg, whole, raw… (after re-ranking; USDA's own order led with "Bananas, dehydrated…") |

Fixes from the check: USDA GTIN forms (the 12-digit query alone found nothing), millilitre servings, ranking.

### Codex round 1 (`codex-review-n8.md`): not clear — 5 P2, 2 P3; all fixed (round 2)

- S1 EAN-8 at USDA under zero-padded forms: `sameGTIN` compares two valid GTINs as 14 digits.
- S2 a drink's per-100 ml numbers: `per100Unit` ("g" | "ml") from the server to the app; a drink with no serving is
  kept as 100 ml with no grams and no "100 g" option; servings scale from 100 only within one unit.
- S3 the outer error log printed the barcode: the route is logged as `GET /v1/food/barcode/:code`.
- S4 a malformed reply (OFF without `status` 0/1 + product, USDA without `foods`) is `502`, never a cached miss.
- S5 impossible numbers: missing vs invalid kept apart (invalid → the set is unusable, not 0); bounds per basis (each
  nutrient and protein + carbs + fat ≤ the amount, sodium likewise, ≤ 9 kcal a gram); the app re-checks the same.
- S6 Log food's lists credit the databases of the foods (and meal items) they show (`logFoodCredits`).
- T1 an online row shows its check after + (and after the toast), cleared by Undo; local and online + buttons say
  "Logged" to VoiceOver.

Round 2 checks: server 282/282 + tsc; Unit plan 1284/1284 exit 0 (`r2-unit.xcresult`); `BarcodeSearchUITests` (8, incl.
captures) + `LogFoodUITests` + `LogFoodFlowUITests` 18/18 with 2 workers, exit 0 (`r2-ui.xcresult`).

### Codex round 2 (`codex-review-n8-b.md`): not clear — 2 P2 (remainders of S2/S4); fixed (round 3)

- R2-S1 an Open Food Facts serving without its unit field defaulted to grams for a drink ("1 can (330 ml)" → 330 g):
  the unit is millilitres when the serving says so or the product is per 100 ml; grams only otherwise.
- R2-S2 a 200 reply with JSON `null` read as the 404 miss: the HTTP miss is its own sentinel; every 200 body is
  validated.
- Advisory: the app's per-100 calorie bound is now the server's 900.
- Its 3 parallel UI failures (warm-up launch, `LogFoodFlowUITests` Add food, `LogFoodUITests` dark capture — Today
  instead of Log food) passed serially; parallel-load launch/navigation flakes, as before.

Round 3 checks: server 282/282 + tsc; Unit plan 1284/1284 exit 0 (`r3-unit.xcresult`). No UI code changed.

### Codex round 3 (`codex-review-n8-c.md`): not clear — 1 P2; fixed (round 4)

- R3-S1 the basis and the serving unit were resolved separately (a 10 g spoon of a product sold by the 500 ml was
  scaled as 10 ml; a "1 shot (30 ml)" with no package read as per 100 g). Now `offUnits` resolves both from all the
  evidence first: basis = the package's quantity, else the serving's unit (field, else its text), else grams (the
  database's default); serving unit = its field, else its text, else the basis (none when the field names another
  unit). Scaling only within one unit. An 11-case matrix test covers package weight/volume/absent, field/text/absent,
  per-100-only vs serving numbers, fl oz.

Round 4 checks: server 283/283 + tsc. App unchanged this round (Unit plan 1284/1284 from round 3 stands).

### Codex round 4 (`codex-review-n8-d.md`): not clear — 1 P2; fixed (round 5)

- R4-T1 an unsupported unit field ("oz") was bypassed by recognisable serving text ("2 oz (56 g)" → 2 g): the field
  now decides first — no serving unit at all, so the quantity is never scaled or shown as grams; the serving's own
  numbers stand with no weight. Matrix + 3 cases. Server 283/283 + tsc; app unchanged.

### The user's to review (not blocking)

Own decisions: (1) routes under `/v1/food/…` like every other route; (2) limits 200 barcodes / 500 searches a day,
cache hits counted; (3) cache times above; (4) a code already on the phone always opens from the phone (fresher
database numbers are not fetched for it); (5) Open Food Facts' User-Agent names the support page, no email;
(6) search re-ranking; (7) a database food only opened is kept but hidden until logged or bookmarked; (8) Estimate
stays above the results (N7's place), More foods after your foods; (9) other servings by weight on Selected food;
(10) signed out, search shows "Sign in to search more foods."; (11) not found: Scan the label (primary) + Manual Add;
failure: Try again + Manual Add. New strings: "Barcode", "Looking up the barcode…", "Not in the database", "Scan the
label to read its numbers, or add it by hand.", "Scan the label", "Couldn't look it up", "Try again", "Search foods"
(was "Search your foods"), "More foods", "Searching…", "No more foods found.", "Sign in to search more foods.",
"Food data from Open Food Facts", "Food data from USDA FoodData Central", the errors in `FoodDatabaseError` ("Too many
lookups today. Try again tomorrow.", "The food database didn't answer. Try again.", "Online search isn't available
yet."), and the privacy draft's "Barcodes and food search" paragraph.

### Verification (Claude, 2026-11-11; scope: Unit plan + the TodayTrain food classes, per DEVELOPMENT tiers)

Simulator WT-Floodlight `9E822EF6…`, `scripts/prepare-test-simulator.sh` first; xcresults in `/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/8bffdecc-0105-4db5-8c71-05a754a21832/scratchpad/`.

- Server: `npx tsc --noEmit` clean; `npm test` (vitest) 278/278 (21→24 new in `food.test.ts`), node script tests 4/4.
- Build: `build-for-testing` exit 0.
- Unit plan: 1282/1282, exit 0 (`unit-plan.xcresult`); `FoodDatabaseTests` × 10 iterations, exit 0 (`unit-iter.xcresult`).
- UI, serial: `BarcodeSearchUITests` 5 behaviour tests 5/5, exit 0 (`ui1.xcresult`).
- UI, 2 workers: `BarcodeSearchUITests` captures + `ScanFoodUITests` + `LogFoodUITests` + `LogFoodFlowUITests`: 24/25,
  exit 65 (`ui2.xcresult`) — `LogFoodFlowUITests.testManualAddLogsCaloriesAloneAndAMealIsCreatedLoggedAndDeleted`
  ("a second + is a second serving", Create meal); the class alone, serially: 5/5, exit 0 (`ui3.xcresult`).
- Light capture re-run after showing search with the keyboard away: 1/1, exit 0 (`ui4.xcresult`).
- Captures checked (light Default, dark AccessibilityL): looking up, found (credited), not found, offline, search
  (your foods → More foods → credit), a USDA food with its serving menu — `/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/8bffdecc-0105-4db5-8c71-05a754a21832/scratchpad/n8att/`.

```
Verified: server vitest 278/278 + tsc; Unit plan 1282/1282 exit 0; BarcodeSearchUITests 5/5 serial exit 0; ScanFood + LogFood + LogFoodFlow + BarcodeSearch captures 24/25 parallel (the 1 passes serially 5/5)
Not verified: the real camera reading a printed barcode (device-only; Simulator uses the fixture); the app against the deployed server (deploy at R); the live check went through the server's functions, not its HTTP route
Known flaky: LogFoodFlowUITests.testManualAddLogsCaloriesAloneAndAMealIsCreatedLoggedAndDeleted — "2 servings" not seen under 2 parallel workers, passes serially (the test already waits; Create meal's list now filters cached lookups, but the sample foods are not database foods)
```

## Comments
