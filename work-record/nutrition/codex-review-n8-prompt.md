# Codex review — nutrition N8 (barcode scanning and online food search)

You are the independent reviewer; Claude implemented. Same checkout, branch `ericlee4992/nutrition-08-barcode` (on
`main` `59e354b`). Review `git diff 59e354b..HEAD` — server and app.

Read first: `work-record/nutrition/issues/08-barcode-and-search.md` (Scope, Acceptance; Progress: what was built, the
live check against the real databases, own decisions, new strings), decision D72 (and D52, D78, D81, D83),
`work-record/nutrition/spec.md` (data rules), `server/README.md` → Food databases, `.claude/skills/ios-design/REVIEW.md`;
swiftui-pro / swiftdata-pro apply. The USDA key is the user's Worker secret (`USDA_API_KEY`), never in the repo or a
report; tests use fakes — do not call the real APIs.

Check in particular:
1. **Server** `server/src/food.ts`, `migrations/0008_food_database.sql`, routes in `src/index.ts`, `claimDeletion`,
   cron: GTIN validation and normalisation; Open Food Facts and USDA parsing (energy kJ/kcal, sodium g→mg, ml vs g,
   bounds, names); fallback order; caching (keys, TTLs, what is and is not cached on failure / without the key);
   per-account limit (the upsert, the 401/429 split, deletion, pruning); timeouts; no key/code/query in logs or URLs;
   Workers Free statement budget; search ranking (`rankFoods`). Tests `server/test/food.test.ts`.
2. **Privacy draft** (`src/pages.ts`): the new paragraph and processors match what the code does.
3. **App domain** `Domain/FoodDatabase.swift`: `FoodBarcode` (UPC-E expansion, check digit, forms matching the
   server's), `DatabaseFood(json:)` (the app re-checks the server's answer), `FoodDatabaseClient` (requests, error
   mapping, 401 sign-out), `FoodDatabase.save` (upsert by `databaseID`, never touching My foods; entries keep their
   snapshot), `local(barcode:)`, `storedServing`; `FoodLog.all` hiding cached lookups (`SavedFood.isCachedLookup`) —
   check every caller of `FoodLog.all`; `FoodLog.servingChoices` / `log(…, option:)` (scaling by weight; Undo).
4. **Camera** `Features/Gyms/LabelCameraView.swift`: the metadata output on the shared session (Scan Machine and the
   label/meal modes must behave exactly as before; types switched only while a band is set; the ordering of
   `applyBarcodeTypes` vs session configuration; band filtering via `transformedMetadataObject`).
5. **Flow** `Features/Food/Scan/FoodScanFlow.swift`: `barcodeRead` (only from the camera itself, the resting code after
   going back, UPC-E), the lookup task's cancellation and attempt identity, not found → Scan the label (mode switch),
   failure → Try again / Manual Add, the found food in `SelectedFoodView` (`source: .barcode`, meal), deletion of a
   local My food from there. `FoodScanBarcodeLookup` design (REVIEW.md), AX.
6. **Log food** `Features/Food/LogFoodView.swift`: debounce and cancellation (`.task(id: onlineQuery)`), stale results,
   dedupe against the user's foods, the + (save + log + Undo, the check mark), signed-out line, failure lines,
   attribution; `SelectedFoodView` serving picker and attribution.
7. **Fixture and tests**: `FoodDatabaseAccess.swift` flags; `FoodDatabaseTests`; `BarcodeSearchUITests`;
   `ScanFoodUITests` capture launch now passes `-uiTestBarcodeNoRead`; `scripts/test-plans.py` mapping.

Per AGENTS' reviewer rule (round 1): `cd server && npx tsc --noEmit && npm test`; build; Unit plan; UI:
`AAAWarmUpUITests`, `BarcodeSearchUITests`, `ScanFoodUITests`, `LogFoodUITests`, `LogFoodFlowUITests` (2 workers;
rerun failures serially). Claude's evidence: see the ticket's Verification block (xcresults under Claude's scratchpad
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/8bffdecc-0105-4db5-8c71-05a754a21832/scratchpad/`:
`unit-plan.xcresult`, `ui1.xcresult`, `ui2.xcresult`; captures `n8att/`). WT-iPhone27 with
`scripts/prepare-test-simulator.sh <udid>` first; paths under `/tmp/codex-n8/`. Claude runs nothing while you run. Do
not modify files other than the report; do not commit or push.

Write `work-record/nutrition/codex-review-n8.md`: findings P1/P2/P3 with file:line, failure scenario and fix; a
Verified / Not verified / Known flaky block; end with exactly `Verdict: clear` or `Verdict: not clear`.
