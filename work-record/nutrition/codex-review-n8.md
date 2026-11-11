# N8 independent review — round 1

Reviewed by Codex on 2026-11-11. Clean checkout on `ericlee4992/nutrition-08-barcode`, HEAD
`c9fd8a03b96bed09fe31aa2707bcb0c9323f5732`; reviewed `59e354b..c9fd8a0` (server and app). Read AGENTS, current STATE,
the N8 brief/ticket, nutrition data rules, relevant decisions, server Food databases documentation and applicable
review/SwiftUI/SwiftData/design guidance. Separate standards and spec passes completed. Only this report changes the
checkout. No commit, push, deployment, device installation, live food-API call or USDA-key access.

## Spec

### S1 — P2: USDA fallback rejects the padded EAN-8 forms it searches for

`server/src/food.ts:290–303`.

D72 and the ticket require USDA fallback for supported product codes, including EAN-8. `gtinForms("96385074")` asks
USDA for the original eight digits and padded 13/14-digit equivalents. `sameGTIN`, however, compares their normalized
13-digit value against the original eight digits. A matching product returned under either padded form is discarded,
and a false miss is cached for a day.

**Reproduced offline:** the actual lookup function with an OFF miss and identical fake USDA food data returns found
for `96385074`, but not found for `0000096385074` or `00000096385074`; both failures issue a cache write of `null`.
See `spec-probe/output.jsonl`, cases `EAN8`, under the evidence root below.

**Fix:** validate both GTINs, then compare them in a common zero-padded representation. Cover both padded EAN-8
responses through fallback and caching, not only the list of search forms.

### S2 — P2: A volume-only food is stored as a weight serving

`server/src/food.ts:166–176`; `WorkoutTracker/Domain/FoodDatabase.swift:307–308`.

The contract's `per100g` field also carries per-100-ml drink nutrition (`food.ts:58`). When a drink has no usable
`serving_size`/serving record, the server returns those numbers without their basis; the app's fallback unconditionally
creates **100 g, grams = 100**. This contradicts the ticket's millilitre handling and the README's promise that a drink
claims no grams. Logging 100 g then applies numbers supplied for 100 ml, without a known density.

**Reproduced offline:** a volume-only OFF fixture produces `serving: null` and its 50-calorie per-100-ml data in
`per100g`. Passing that output through the actual Swift parser and `storedServing` returns
`serving: 100.0 g, grams: Optional(100.0), calories: 50.0` (`app-contract-probe.log`).

**Fix:** preserve the gram/millilitre basis through normalization and the app, or synthesize a correctly labelled
100-ml serving with no gram weight when that basis is known. Do not silently fall back to grams. Add a server-to-app
contract regression for a drink with per-100-ml nutrition but no package serving.

### S3 — P2: An error on the new barcode route logs the barcode

`server/src/index.ts:190–193,203–206`.

The new route embeds user input in `route`. A D1/cache exception reaches the shared catch, which logs that complete
route. This violates the new README promise that logs contain “never the code” and the privacy draft's statement that
logs do not hold what the user sent (`pages.ts:137–140`). Normal upstream logging is redacted, but this outer error path
is not.

**Reproduced offline:** the actual handler with fake authentication and a failing D1/cache operation returns 500 and
logs `["unhandled", "GET /v1/food/barcode/96385074", "Error"]`; no upstream fetch occurs (`spec-probe/output.jsonl`,
`barcode-log`). No production logging was accessed.

**Fix:** use a fixed route identifier such as `GET /v1/food/barcode/:code` in diagnostics, or redact dynamic input before
logging. Add a handler-level database-failure regression asserting the scanned value is absent from console output.

### S4 — P2: Structurally malformed provider replies become cached “not found” results

`server/src/food.ts:275,280–286`.

`fetchJSON` rejects invalid JSON syntax, but the provider wrappers do not validate the response envelope. A successful
HTTP response containing valid JSON such as `{ "error": "temporary upstream failure" }`, or an object missing the
expected fields, becomes an empty USDA list or OFF miss. It can then be cached for 24 hours instead of returning the
retryable failure required by the ticket's “miss is not cached … when a source failed” rule.

**Reproduced offline:** a fake USDA 200 error envelope produces search `{foods: []}` and, after an explicit OFF miss,
barcode `{found: false}`; the actual code issues cache writes for `[]` and `null` with a one-day expiry
(`malformed-search` / `malformed-barcode`). This is malformed-response handling evidence, not a claim that a real
provider was observed returning that envelope.

**Fix:** validate each provider's top-level envelope and distinguish an explicit valid empty/not-found result from
missing/wrongly typed fields or error envelopes. Classify malformed replies as upstream failures; do not negative-cache
them. Test both providers and both routes.

### S5 — P2: Impossible nutrient quantities survive both validation layers

`server/src/food.ts:156–164,187–199`; `WorkoutTracker/Domain/FoodDatabase.swift:154–165`.

The README says impossible numbers make the food unusable, and the app promises to re-check the answer. Instead,
per-100-g macros share the 100,000-g cap used for large portions; supplied invalid values are also collapsed to
“missing” and then zero on the server. The app repeats the overly broad bound.

**Reproduced offline:** an OFF payload with 100 calories, **10,000 g protein per 100 g** and **−5 g carbs** becomes a
valid food with 10,000 g protein and 0 g carbs. The actual Swift parser and serving conversion accept that normalized
payload unchanged (`impossible-macro` and `app-contract-probe.log`). Thus the second check cannot recover the invalid
carb input already changed to zero, and does not reject the impossible protein amount.

**Fix:** apply bounds appropriate to the nutrient and its weight/volume/serving basis in both layers. Distinguish a
missing nutrient from an invalid supplied value; reject the invalid nutrient set and use a valid alternate basis or
provider fallback. Add negative, nonfinite and excessive-macro cases alongside the existing calorie tests.

### S6 — P3: Cached Open Food Facts rows lose attribution

`WorkoutTracker/Features/Food/LogFoodView.swift:300–310`.

After an OFF food is logged or bookmarked, its local Recent/search/Saved row shows its imported name, calories and
serving without the credit that Selected food supplies. The local list passes no provenance into `logRow`, so no
attribution is rendered there. The USDA credit in More foods does not cover that local section. This falls short of
the project's explicit “wherever it shows it” attribution requirement in `server/README.md:90` and the N8 scope.

**Fix:** retain visible OFF credit on the cached-result surface, for example per sourced row or an unambiguous section
credit. Keep user-created foods distinct. Extend the existing found → log → Recently logged test to assert the credit
on that screen. This is a source-traced gap against the project's stated requirement, not a legal assessment.

## Standards

### T1 — P3: Some online rows never show their logged checkmark

`WorkoutTracker/Features/Food/LogFoodView.swift:399–411`, with `:71–74` and `Domain/FoodLog.swift:311–317`.

Search **“banana raw”** and use the online `+` on **“Bananas, raw.”** The fixture supports that query, and the entry saves.
However, local matching requires the whole query substring, so this name does not appear in Your foods. Dedupe only
considers those visible local rows, leaving the online row present. Its button always draws `plus`, despite inserting
the saved food's ID into `logged`. After the toast disappears there is no logged indication on the visible row.

This breaks N4's established “+ logs with a check and a 5 s Undo” behavior (`issues/04-manual-logging.md:98`).
**Fix:** derive the online row's completion state from its saved database/persistent ID, render the same check state
as local rows, and clear it on Undo. Preserve the ability to log another serving. Add a UI regression with a query
whose words are reordered or separated in the result name. This scenario was source-traced, not run as an extra UI test.

No additional baseline-smell finding is asserted. The privacy and data-validation concerns above also affect standards
and are counted once.

## Other assessment

- The limit upsert is atomic, counts cache hits, distinguishes a deleted account (401) from an exhausted limit (429),
  and is removed during account deletion. Cron wiring includes food expiry/count pruning. Source worst case is
  **40 D1 statements**: revocations 21, feedback 14, AI 2, sessions 1, food 2, within the repo's documented 50-statement
  budget. This is source arithmetic, not a production load test.
- USDA credentials are supplied in a header; account data/client network address are not forwarded in provider
  requests. Normal upstream logs contain source/status only. The privacy draft's new processors and shared-cache/count
  description match the intended path, except for the error logging in S3. The deployment-date placeholder remains.
- Database upsert excludes My foods, preserves the existing bookmark/last-used state and leaves prior food-entry
  snapshots unchanged. Both `FoodLog.all` callers (Log food and Create meal) honor the cached-only filter. Alternate
  serving scaling updates macro/other nutrient values and receipt calories; Undo retains the established behavior.
- Barcode attempt identity/cancellation and the resting-code guard are present; local food deletion clears the route.
  Search debounce and cancellation reject obsolete results; 401 invalidates the refused session. Camera types are
  applied on the session queue after configuration and are gated by the current band; metadata coordinates are
  transformed through the preview. Real camera operation remains unverified on Simulator.

## Diagnostic evidence

Evidence root: **`/tmp/codex-n8/`**. The offline Node probes bundle the actual `food.ts` and `index.ts` code with fake
D1/fetch dependencies: `spec-probe/food.mjs`, `index.mjs`, `probe.mjs`, `output.jsonl`, `stderr.log`, `status` (**exit 0**).
The outputs were inspected directly. They reproduce S1–S5; exit 0 means the diagnostic completed, not that the product
behavior is correct. No external requests or real secrets were used.

`app-contract-probe.swift` copies the actual `FoodBarcode`, `DatabaseFood`, `storedServing` and their pure supporting
value types/serving parser from the reviewed source. Its input is the Node probe's normalized outputs
(`app-contract-input.json`); `app-contract-probe.log` and `.status` (**exit 0**) confirm S2/S5 at the app parsing/conversion
boundary, without claiming a live UI/SwiftData persistence test. No network code is executed by this probe.

## Verification

Xcode **27.2**, WT-iPhone27 **`47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`**, iOS **27.0**. Ran
`scripts/prepare-test-simulator.sh` first, built fresh into `/tmp/codex-n8/dd`, ran Unit serially, then the requested
UI classes with **two workers**. No source changes occurred between build and tests. Commands, exact exit codes,
process identities and tested commit are retained in `run.py`, `runner.pid/.log`, `tested-head.txt`,
`server-run.py`, `server-runner.pid/.log`, and `*.command.json` under the evidence root.

| Check | Result | Evidence under `/tmp/codex-n8/` |
|---|---|---|
| `npx tsc --noEmit` | exit **0** | `typecheck.log/.status` |
| `npm test` | Vitest **278/278**, script tests **4/4**, exit **0** | `server-tests.log/.status` |
| Build-for-testing | exit **0** | `build.log/.status` |
| Unit plan | **1,282/1,282**, no failures/skips, exit **0** | `unit.xcresult`, `unit-summary.json`, `unit.log/.status` |
| Requested UI | **31/31**, no failures/skips, exit **0** | `ui.xcresult`, `ui-summary.json`, `ui-tests.json`, `ui.log/.status` |
| Test-plan consistency / diff whitespace | both exit **0** | `test-plans.log/.status`, `diff-check.log/.status` |

UI breakdown: `AAAWarmUpUITests` **1/1**, `BarcodeSearchUITests` **7/7**, `ScanFoodUITests` **13/13**,
`LogFoodUITests` **5/5**, `LogFoodFlowUITests` **5/5**. No failures required a serial rerun. The fresh Unit run includes
`FoodDatabaseTests`; the UI fixtures cover found/offline reuse, not found → label/manual, retry/manual, search and
alternate servings, signed-out/unconfigured search, plus adjacent food flows. These passing cases do not cover the
malformed/boundary inputs reproduced by S1–S5 or the two P3 scenarios.

Fresh BarcodeSearch attachments were exported to `attachments/` with `manifest.json` and `attachments-export.log`.
Inspected light Default and dark AccessibilityL captures of looking up, not found, offline, the found food/credit,
search results and the selected USDA food/serving. No additional new layout defect was established. Representative
files are `F665E3AC-6935-40C7-AAD7-DC8FBBB27C53.png` / `74366A15-EB26-4885-98C5-969004D21256.png` (not found),
`FD098E76-C843-47C4-A2BB-9F878DE0B331.png` / `1DFB6443-7510-4387-BCEE-59AFC677E2BE.png` (OFF credit), and
`A51B6262-CB0D-4620-92C3-617D8B1E918B.png` / `D0C6DE64-5051-4756-9E03-6336B5B23872.png` (search).
Also inspected the author's supplied not-found pair and AccessibilityL selected-food capture.

Directly inspected the supplied author bundles: `unit-plan` **1,282 passed**, `ui1` **5 passed**, `ui2` **24 passed /
1 failed**, `ui3` **5 passed**, `ui4` **1 passed**; no skips. Saved their summaries as `author-*-summary.json`.
`ui2` failed at the Create meal assertion “a second + is a second serving”; the author's serial `ui3` passed, and that
same method passed in this reviewer's fresh two-worker run. Author shell exit codes were not used as reviewer evidence;
the fresh checks above have their own captured exits.

Spec: **five P2 and one P3** (S1–S6). Standards: **one P3** (T1). Total **five P2, two P3; no P1**.

Verified: server type-check exit **0**; server **278/278** plus script **4/4**, exit **0**;
fresh build exit **0**; Unit **1,282/1,282**, exit **0**, `/tmp/codex-n8/unit.xcresult`;
requested UI **31/31**, exit **0**, `/tmp/codex-n8/ui.xcresult`; test-plan/diff checks exit **0**;
S1–S5 diagnostic outputs inspected (both probes exit **0**); fresh default/AccessibilityL captures inspected.

Not verified: real printed-barcode reading, physical camera session/torch/band behavior or hardware resumption;
the app against deployed food routes; real provider lookups (explicitly not called); production D1/log behavior or load;
S6/T1 through additional UI probes (source-traced); human VoiceOver; runtime Reduce Motion; the full UI suite.
The ticket's author-recorded live database checks were read, not independently repeated. No USDA key was accessed.

Known flaky: none observed in this reviewer run. The author's recorded
`LogFoodFlowUITests.testManualAddLogsCaloriesAloneAndAMealIsCreatedLoggedAndDeleted` parallel “second serving” failure
remains in its original bundle and did not recur here. The reproduced data/logging findings are not test flakes.

Verdict: not clear
