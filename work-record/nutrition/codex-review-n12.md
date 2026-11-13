# N12 independent review — round 1

Reviewed by Codex on 2026-11-12, branch `ericlee4992/nutrition-12-korean-db`, clean starting HEAD
`85d1252fd81c288778b542114f3f0546ad72a26d`. Scope: `git diff f56bf476...HEAD`, including all N12 code, generated data,
tests and documentation. Read the brief, AGENTS/STATE, N12 and N8 tickets, all five N8 reviews, D52/D72/D81/D86,
nutrition data rules and applicable review, SwiftUI, SwiftData and iOS design guidance. Separate standards and spec
passes were followed by independent source checks and reproductions. Only this report changes tracked files.

Evidence root: `/tmp/codex-n12-r1/`. Review and prescribed verification are complete. No source edits, deployment,
Worker-secret changes, physical-phone installation or push to `main` occurred.

## Spec

### R1 — P2: Removing spaces prevents valid Korean product names from matching

`server/src/korean.ts:231–233` (cache key at `server/src/food.ts:546`).

D86 calls for live brand-product search and a product-name-prefilled "Is this it?" search. The provider matches a
literal substring, but the implementation sends only `query.replace(/\s+/g, "")`. This destroys the match when the
stored product name contains a space. Local ranking cannot recover a brand product the live request never returned;
the resulting empty search is eligible for a one-day cache entry.

**Confirmed against the real MFDS API:** with the same `상용제품` filter, `양파링 오리지널` returns **3** records, all
named `양파링 오리지널`; `양파링오리지널` returns **0**. Conversely, `신라면 건면` returns **0** while `신라면건면`
returns **5**, so merely removing the existing compaction would lose the other valid case. Evidence:
`live-spacing.py` and `live-spacing.jsonl`, exit **0**. Four bounded provider requests, no deployment. Credentials
were read from the prescribed temporary git-ignored `server/.dev.vars`, never printed, and that file was deleted
and its absence verified.

**Fix:** retain the as-typed spaced form and support compact matching through bounded alternate queries/token
retrieval, merging and ranking results. Keep the request deadline and failure/cache rules intact. Add regression
cases with actual spaced and unspaced provider names; review the shared compact cache key so a failed form does not
mask a successful one.

### R2 — P2: The missing-macros note invents and loses source completeness

`WorkoutTracker/Domain/FoodDatabase.swift:333–338`, used by `WorkoutTracker/Features/Food/SelectedFoodView.swift:65–72`.

D86 requires foods missing fat/carbs to appear "with a note that the source does not list them." The server supplies
`notListed`, but the app does not parse it; instead it infers missing data when macros explain less than half the
calories. Actual bundled foods demonstrate both errors:

- `맥주` (`mfds:P115-104010400-0008`): 53 kcal, 0.24 g protein, 2.9 g carbs, 0.02 g fat per 100 ml, **all supplied**.
  The helper returns true and claims macros are not listed.
- `감자, 자색, 생것` (`mfds:R102-001180001-0000`): 82 kcal, 2.8 g protein, 18.5 g carbs, **fat missing**. The server
  emits `notListed: ["fat"]`, but the helper returns false; the source's missing fat appears as an unqualified zero.

**Reproduced offline:** the actual bundled normalizer in `probe.cjs`/`probe.jsonl`, followed by the current Swift
helper extracted unchanged into `macro-note.swift`/`macro-note.log`; both exit **0**. This checks the real data and
helper, not a physical-device rendering of these two foods. The existing tests cover only a low-protein restaurant
fixture that happens to satisfy the heuristic.

**Fix:** use explicit completeness from the source and retain it for cached/offline display. Preserve D86's
no-stored-format-change constraint using a compatible representation, or explicitly revisit that decision before
changing the schema; calorie arithmetic cannot establish whether a source supplied a value. Test complete alcohol
foods and incomplete foods whose remaining macros explain most calories, including reopen/offline behavior.

### R3 — P2: Food QR accepts rows without a verified matching barcode

`server/src/korean.ts:283–284`.

The brief explicitly requires not trusting Food QR's barcode filter. The local predicate nevertheless accepts every
row whose `BRCD_NO` is missing or is not a string. Thus a malformed response can supply another product's identity
or nutrition and have it attached to the scanned code, bypassing the intended exact-match protection.

**Reproduced through the actual `lookupBarcode` route function, offline:** Open Food Facts misses, and fake Food QR
maker/nutrient rows contain numeric `BRCD_NO: 12345678` and a different product name. Looking up `8801043036597`
returns `found: true`, source `foodQR`, that wrong product's nutrition, and the scanned code; it writes a **30-day
positive cache entry**. `qr-route.cjs`/`qr-route.jsonl`, exit **0**, use fake fetch/D1 dependencies and no credential.
This is malformed-provider-input evidence, not a claim that the live service was observed returning numeric codes.

**Fix:** require an explicit, valid barcode matching the requested GTIN before using a maker or nutrient row. If
numeric codes are deliberately supported, normalize and validate them before comparison; absent identity must not
be accepted. Handle a malformed response as a soft failure so it also cannot become a cached negative answer.
Cover missing, wrong-typed, mismatching and valid zero-padded identities through the route and cache.

## Standards

### R4 — P2: Provider-controlled C005 error text reaches logs

`server/src/korean.ts:367`, logged at `:377`.

The brief and privacy policy require diagnostics never to contain a key, URL, barcode or query. C005's arbitrary
`RESULT.CODE` is converted directly to `Upstream.status`, which is logged unchanged. A malformed error envelope
containing reflected request data therefore bypasses the otherwise sanitized source/status diagnostics.

**Reproduced offline:** `probe.cjs` supplies a fake C005 response whose `RESULT.CODE` is a sentinel string and captures
`console.error`. The sentinel reaches the log unchanged (`probe.jsonl`: `reflected: true`), exit **0**. No real key or
production log was used. Existing HTTP-error tests do not exercise this response-body field.

**Fix:** map recognized provider codes to fixed/allowlisted diagnostics and classify every other value as
`"malformed"`. Add a regression whose unexpected code contains fake key/URL/barcode/query sentinels and assert that
none reaches logs.

No additional substantive baseline-smell or SwiftData schema/relationship violation was established. The logging
finding also affects the spec's privacy requirement and is counted once.

## Verification integration

### R5 — P3: The new UI suite is omitted from the area test plans

`WorkoutTrackerUITests/KoreanFoodUITests.swift:8`, with `scripts/test-plans.py:23–27` and
`TestPlans/TodayTrain.xctestplan`.

DEVELOPMENT requires every UI class to belong to exactly one area plan. `python3 scripts/test-plans.py --check`
exits **1**: `KoreanFoodUITests is in no area plan (add it to AREAS)`. Explicit reviewer selections can run these tests,
but the normal TodayTrain scope omits all six new regression/capture cases.

**Fix:** register the class in the food flows' area, regenerate the plans, and require `--check` to pass.

## Other assessment

- Barcode linking is called after successful logging, not on candidate open. A later search save preserves the
  previously linked barcode. Attempt identity, task cancellation and submitted-query checks guard late responses.
- The older parser rejects unknown `mfds`/`foodQR` sources by returning nil; its barcode client treats that as not
  found. This is source inspection of baseline code, not a build-12 device test.
- Upstream stages are concurrent: OFF/USDA/QR/C005 first, then the report-number requests together. The report
  lookups do not add three sequential eight-second waits. No additional deadline defect was established.
- Gram/millilitre bases, exact report-number comparison, nutrient bounds, local/live search cache separation and
  normal soft-failure handling were inspected and are exercised by the passing server suite. The tests do not cover
  the malformed identity/error cases above.
- Privacy draft: source identities, server-side keys, shared cache, per-account counts and phone-only confirmed
  barcode choice match the implementation, subject to R4. The wording "also looked up" is imprecise for a Korean
  name search: it goes to MFDS **instead of** OFF/USDA, not to all providers. Clarify that routing in the draft before
  the user's approval/deployment. No approval of the wording or deployment is inferred from this review.
- Root/server README describe the new capability. `git diff --check f56bf476...HEAD` exits **2** for an extra blank
  line at `server/src/korean.ts:425`; this is a whitespace cleanup, not a separate product finding.

## Verification

Xcode **27.2 (27B52)**; prepared WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`, iOS **27.0**, then built fresh
into `/tmp/codex-n12-r1/dd`. The brief's named scopes cover the changed domain logic and adjacent barcode/search
flows; no full UI run was required. The existing workspace Paseo terminal **Test progress** was reused for the runs.

Commands completed (logs and recorded numeric exits under the evidence root):

| Check | Command | Result |
|---|---|---|
| Server dependencies | `cd server && npm ci` | exit **0** |
| Server typecheck | `cd server && npm run typecheck` | exit **0** |
| Server suite | `cd server && npx vitest run` | **334/334**, 10 files, exit **0** |
| Simulator preparation | `scripts/prepare-test-simulator.sh 47D21838-69A6-4BCB-AE90-B0D9C0AAA70B` | exit **0** |
| Fresh build | `xcodebuild build-for-testing -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=47D21838-69A6-4BCB-AE90-B0D9C0AAA70B' -derivedDataPath /tmp/codex-n12-r1/dd` | exit **0** |
| Affected unit suite | `xcodebuild test-without-building` with the same project/scheme/destination/derived data, `-only-testing:WorkoutTrackerTests/FoodDatabaseTests -parallel-testing-enabled NO -resultBundlePath /tmp/codex-n12-r1/unit.xcresult` | **15/15**, no failures/skips, exit **0** |
| Focused UI | Same `test-without-building` base, `-only-testing:WorkoutTrackerUITests/KoreanFoodUITests -only-testing:WorkoutTrackerUITests/BarcodeSearchUITests -parallel-testing-enabled YES -maximum-concurrent-test-simulator-destinations 2 -parallel-testing-worker-count 2 -resultBundlePath /tmp/codex-n12-r1/ui.xcresult` | **13/14**, 1 failure, no skips, exit **65**; PID **30980**, `ui.log` |
| Failed UI case, serial | Prepared the simulator again, then the same test base with `-only-testing:WorkoutTrackerUITests/BarcodeSearchUITests/testABarcodeNotFoundOffersTheLabelScanAndManualAdd -parallel-testing-enabled NO -resultBundlePath /tmp/codex-n12-r1/ui-serial.xcresult` | **1/1**, no failures/skips, exit **0**; unchanged binary/source |
| Test-plan consistency | `python3 scripts/test-plans.py --check` | exit **1**, R5 |
| Diff whitespace | `git diff --check f56bf476...HEAD` | exit **2**, blank EOF line |

Diagnostic probes use bundled current source, except the Swift probe which extracts the current pure helper.
Their exit **0** means the diagnostic completed, not that the product behavior was correct. Author-provided test
counts were not substituted for reviewer executions.

The main UI bundle passed **KoreanFoodUITests 6/6** and **BarcodeSearchUITests 7/8**. The failed case stopped at
`BarcodeSearchUITests.swift:37`, waiting for `scanFoodMode.barcode`; its failure hierarchy remained on Today after
the scan-button tap. It passed in the serial rerun. The cause is not established, and the original failure is retained
in `ui.xcresult`, `ui-failure.json` and exported attachments. All **14** requested cases have passing evidence across
the two bundles, but the original parallel run was not green. The AVAudioSession main-thread warning is also retained
in the result summary; this review does not attribute it to N12.

**Capture assessment:** exported attachments with `xcrun xcresulttool export attachments --path
/tmp/codex-n12-r1/ui.xcresult --output-path /tmp/codex-n12-r1/attachments` (exit **0**). Inspected all **12** N12 PNGs:
candidate list and scrolled list, no match, Korean search, selected food and scrolled selected food, each in light
Default and dark AccessibilityL. Candidate names/metadata, fallback buttons, note and credit wrap legibly; the scrolled
candidate/selected-food shots expose their full credit and note. No additional layout defect established. The Korean
search AccessibilityL shot leaves its credit below/behind the tab bar and does not include a scrolled companion;
that particular scrolled state is not visually verified. Also inspected the existing N8 `search-3` Default and
AccessibilityL captures, which show the online rows and USDA credit after scrolling. No dark Default/light
AccessibilityL pair or human VoiceOver check is claimed. Attachment names map to exported PNG IDs in `manifest.json`.

Spec: **3 P2 findings** (R1–R3); standards: **1 P2** (R4); verification integration: **1 P3** (R5).

Verified: fresh build, exit 0; server typecheck and 334/334 tests, exit 0; FoodDatabaseTests 15/15, exit 0,
`unit.xcresult`; focused UI 13/14, exit 65, `ui.xcresult`, plus unchanged serial rerun 1/1, exit 0,
`ui-serial.xcresult`; exported Default/AccessibilityL captures inspected; source/offline reproductions; four live
search requests; temporary key file removed. Evidence root `/tmp/codex-n12-r1/`.

Not verified: deployed routes, production D1/logs, physical camera/phone behavior, build-12 runtime compatibility,
the Korean search's scrolled AccessibilityL credit, dark Default/light AccessibilityL, human VoiceOver or full UI
suite. Test-plan consistency remains failing (R5); the diff has the whitespace warning recorded above.

Known flaky: `BarcodeSearchUITests.testABarcodeNotFoundOffersTheLabelScanAndManualAdd` failed to reach the camera
in the parallel run, passed unchanged serially. Cause unresolved; follow-up belongs to N12's acceptance-2 test
evidence in `issues/12-korean-food-database.md`. The reproduced R1–R4 defects are independent of this intermittent test.

Verdict: not clear
