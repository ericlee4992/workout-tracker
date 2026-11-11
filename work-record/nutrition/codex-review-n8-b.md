# N8 independent review — round 2

Reviewed by Codex on 2026-11-11. Clean checkout on `ericlee4992/nutrition-08-barcode`, HEAD
`9b754ab14a097a4546bb81f63187fdef25ca3ba3`; reviewed `c9fd8a0..9b754ab`. Read AGENTS, STATE, the round-2 brief,
ticket's round-1 fixes and previous report, applying the established spec/decisions and review/SwiftUI/SwiftData/design
guidance. Separate standards and spec passes completed. Only this report changes the checkout. No commit, push,
deployment, device installation, real food-API call or USDA-key access. Public provider documentation was consulted.

## Spec

### R2-S1 — P2: A volume serving still gets invented grams when its unit field is absent

`server/src/food.ts:218–226`.

The no-serving liquid case from S2 is fixed, but the package-serving path still defaults a missing
`serving_quantity_unit` to `"g"`. For a liquid package whose quantity is `"330 ml"`, with serving text
`"1 can (330 ml)"`, `serving_quantity: "330"`, and valid per-serving nutrition, the new code correctly infers
`per100Unit: "ml"` yet emits **`serving.grams: 330`**. The app preserves that supplied weight, contrary to the ticket's
promise that millilitre servings claim no grams without a density.

This is a valid missing-field boundary: Open Food Facts describes the serving unit as g/ml but does not require that
property. Its nutrition schema also documents that the `_100g` suffix can represent 100 ml for liquids.
[Product schema](https://openfoodfacts.github.io/documentation/docs/Product-Opener/schemas/schemas/product/),
[nutrition schema](https://openfoodfacts.github.io/documentation/docs/Product-Opener/schemas/schemas/product_nutrition/).

**Reproduced with current source, offline:** `spec-probe/serving-volume.json` records the exact 330-ml input and output.
The Swift contract probe then accepts it and formats **`1 can (330 ml) (330 g)`**, keeping `grams: 330` and 138.6 calories.
A separate 200-ml glass case has the same failure. Evidence is under `/tmp/codex-n8-r2/`; both probe runs exit **0**.
These are parser/normalizer observations, not a live-product or physical-device reproduction.

**Fix:** resolve serving units from reliable evidence consistently with the volume handling; if the serving's weight
is unknown, retain its text/nutrition with `grams: null`. Do not default missing unit metadata to grams. Add this
missing-unit liquid case through normalization and app storage, alongside the existing no-serving regression.

### R2-S2 — P2: An HTTP 200 JSON `null` reply is still cached as an OFF miss

`server/src/food.ts:320–334`.

The new envelope checks fix the original error-object cases, but `fetchJSON` returns `null` both for an explicit
HTTP 404 and for a successful response whose JSON body is `null`. `openFoodFacts` returns not found for either before
validating the envelope. When USDA subsequently returns an explicit empty list, the lookup caches a false miss for
24 hours. This remains contrary to the S4 fix's “malformed reply … 502, never a cached miss” contract.

**Reproduced with current source, offline:** `spec-probe/output.jsonl`, case `OFF-200-null`, shows `{found: false}` and
a `food_cache` write of `null` with expiry exactly one day later. The fake OFF response is HTTP 200 with JSON `null`;
USDA returns a valid empty result. The original malformed USDA error-envelope probes now correctly return 502 and
write no cache row.

**Fix:** represent an HTTP not-found outcome separately from every possible decoded JSON value, then validate all
successful response bodies. Add a 200/null regression asserting 502 and no negative-cache write; preserve explicit
404/status-0 misses and legitimate fallback hits.

## Standards

No additional confirmed P1/P2/P3 standards findings in this fix diff.

- **S6 fixed on the reported surfaces:** local Recent/search/Saved lists credit the databases of their displayed
  foods. My meals also derives section credits from linked ingredients. Existing attribution strings and text tokens
  are reused; Selected food attribution remains intact.
- **T1 fixed:** online rows use the kept food's persistent ID to read `logged`, draw the check and expose “Logged” to
  accessibility. Undo removes that ID, while toast expiry does not. Repeated logging remains available. The new test
  targets the original “banana raw” query and checks Undo and toast expiry.
- Schema, relationship rules, frozen snapshots and upsert exclusion of My foods are unchanged. No additional
  baseline-smell finding is warranted.

## Round-1 disposition and other assessment

- **S1:** fixed. The original eight-digit and both padded EAN-8 forms now return found and issue positive cache writes
  in the rerun; the new server regression exercises the route and cache.
- **S2:** partially fixed. `per100Unit` reaches the app; a volume-only fallback now formats `100 ml`, with no grams or
  weight-based options. R2-S1 covers the remaining package-serving case.
- **S3:** fixed for the reported route. The rerun database-failure probe logs
  `GET /v1/food/barcode/:code`, with no scanned value, and returns 500. The new handler-level test asserts that result.
- **S4:** partially fixed. The original malformed USDA search/barcode envelopes return 502 and are not cached;
  malformed OFF objects are rejected. R2-S2 covers the remaining null/sentinel collision.
- **S5:** fixed for the reported cases. The server rejects the former 10,000-g/negative-macro input. Independently
  feeding the old normalized 10,000-g response into the new Swift parser is also rejected. The new tests cover
  per-basis limits, excessive combined macros, sodium, known-weight serving energy and volume-only storage.
- **Advisory consistency note, not another finding:** the app's absolute per-100 calorie cap remains 1,000 while the
  server's is 900 (`FoodDatabase.swift:105`, `food.ts:182`). Combined with mass tolerance, the app can admit some values
  the server rejects (for example 940 kcal/100 g). No current producer was found that emits those values, and the
  original impossible-nutrient failures are fixed. Aligning the constants and adding a shared boundary case would
  make the “same bounds” comment precise.

## Probe evidence

Round-1 artifacts in `/tmp/codex-n8/` were preserved. New artifacts are under **`/tmp/codex-n8-r2/`**.
`spec-probe/food.mjs` and `index.mjs` bundle the current source; `probe.mjs` uses fake fetch/D1 dependencies, catches the
now-expected upstream failures so every case completes, and writes `output.jsonl`, `stderr.log` and `status`
(**exit 0**). The additional exact-volume case is in `serving-volume.mjs`, `.json` and `.status` (**exit 0**).
Outputs were inspected directly; no provider lookup or secret was used.

`app-contract-probe.swift` copies the current pure parser, serving conversion and supporting value types from the
reviewed source. `app-contract-input.json` includes current normalized outputs plus the old impossible response to
exercise the independent app check. `app-contract-probe.log/.status` (**exit 0**) confirm the corrected 100-ml fallback,
rejection of the old oversized nutrients, and the remaining false gram weights. Exit 0 means the diagnostics completed;
it does not mean every observed product behavior was correct. No SwiftData/UI behavior is claimed from this probe.

## Verification

Xcode **27.2**, WT-iPhone27 **`47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`**, iOS **27.0**. Prepared the simulator before
the first run, built fresh into `/tmp/codex-n8-r2/dd`, then ran Unit serially and the requested UI classes with **two
workers**, including launch-only warm-up. Reran the three failures serially without changing app/test sources or
binaries. Commands, process identities and exact exits are retained under the evidence root in `run.py`,
`runner.pid/.log`, `server-run.py`, `server-runner.pid/.log`, `serial.py`, `serial-runner.pid/.log`,
`tested-head.txt` and `*.command.json`.

| Check | Result | Evidence under `/tmp/codex-n8-r2/` |
|---|---|---|
| Server `npx tsc --noEmit` | exit **0** | `typecheck.log/.status` |
| Server `npm test` | Vitest **282/282**, script tests **4/4**, exit **0** | `server-tests.log/.status` |
| Build-for-testing | exit **0** | `build.log/.status` |
| Unit plan | **1,284/1,284**, no failures/skips, exit **0** | `unit.xcresult`, `unit-summary.json`, `unit.log/.status` |
| UI, two workers | **16/19 passed**, **3 failed**, no skips, exit **65** | `ui.xcresult`, `ui-summary.json`, `ui-tests.json`, `ui.log/.status` |
| UI failure rerun, serial | **3/3 passed**, no failures/skips, exit **0** | `ui-serial.xcresult`, `ui-serial-summary.json`, `ui-serial.log/.status` |
| Test-plan consistency / diff whitespace | both exit **0** | `test-plans.log/.status`, `diff-check.log/.status` |

The initial UI run passed **all 8 BarcodeSearch tests**, including the new online-row check/Undo/toast-expiry regression
and the new cached-food attribution assertion. `LogFoodUITests` passed **4/5**, `LogFoodFlowUITests` **4/5**, and warm-up
**0/1**. The three failures all passed on the unchanged serial rerun:

- `AAAWarmUpUITests.testLaunchReachesTheTabBar`, at `:15`: the tab bar was not found after launch.
- `LogFoodFlowUITests.testAddFoodMakesOneOfMyFoodsAndTheBookmarkSavesIt`, helper `open(foods:)` at `:21`: the lunch
  control was not found after tapping Log food.
- `LogFoodUITests.testCaptureDarkAccessibility`, capture helper at `:138`: after leaving Create meal, the test could
  not find the Usual breakfast row; the failure tree showed Today instead of Log food.

Failure details are saved as `ui-failure-1.json` (Add food), `ui-failure-2.json` (dark capture), and `ui-failure-3.json`
(warm-up). Their precise causes are not established; no additional product finding is inferred from those intermittent
results. All **18 requested feature UI cases**, plus warm-up, have passing evidence across the two bundles.

Fresh BarcodeSearch captures were exported to `attachments/`, with `manifest.json` and `attachments-export.log`.
Inspected the light Default search (`8D55FDE3-1326-408D-8DFB-29D5144D9B8C.png`) and scrolled dark AccessibilityL online
results/credit (`0F266ED1-6DFD-4614-9336-B9DD71D53EB9.png`). No new layout defect was established in those views.
The new local-credit and logged-check scenarios are verified by behavior assertions; this round does not supply a
dedicated default/AccessibilityL screenshot pair of those two new states.

Directly inspected the author's supplied `r2-unit.xcresult` (**1,284 passed**) and `r2-ui.xcresult` (**18 passed**), both
with no failures/skips. Saved summaries as `author-r2-unit-summary.json` and `author-r2-ui-summary.json`. The reviewer
checks above have independently captured exit codes; the report does not rely on the author's summary or shell exits.

Spec: **two P2 findings** (R2-S1, R2-S2). Standards: **no additional findings**. No P1/P3 findings; the calorie-cap
alignment note is advisory.

Verified: server type-check exit **0**; server **282/282** plus script **4/4**, exit **0**; fresh build exit **0**;
Unit **1,284/1,284**, exit **0**, `/tmp/codex-n8-r2/unit.xcresult`; all requested UI cases have passing evidence across
`ui.xcresult` (**16/19**, exit **65**) and `ui-serial.xcresult` (**3/3**, exit **0**); test-plan/diff checks exit **0**;
current-source offline probes and new original-case regressions checked; refreshed search captures inspected.

Not verified: real printed-barcode/camera behavior; live provider responses or deployed routes; production D1/logs;
the remaining false-weight scenario through a full UI/SwiftData save (reproduced through the actual pure parser and
serving conversion); dedicated default/AccessibilityL screenshots of the newly added local credit and logged-check
states; human VoiceOver; runtime Reduce Motion; the full UI suite. No live food lookup, real key access or installation
on a physical phone occurred.

Known flaky: the warm-up launch, Add food entry navigation and dark Log food capture failures above occurred in parallel
and passed serially unchanged. Both bundles are preserved in this round's evidence; causes remain undiagnosed. The two
reproduced server findings are independent of those UI failures.

Verdict: not clear
