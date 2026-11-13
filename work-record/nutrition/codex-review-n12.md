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

## Round 2

Reviewed fix commit `6ed3cdf0ca77f0c9e6b0a3e89f980527a6c70434` against `aa29dc51` on
`ericlee4992/nutrition-12-korean-db`. Starting checkout was clean. Reread current STATE, the ticket's round-1 fix
record, this report and the changed source/callers. STATE still describes round 1 as running; Git and the ticket
establish that the fixes are committed but not merged/deployed. Separate standards/spec passes completed. Only this
report is modified. Evidence: `/tmp/codex-n12-r2/`; the fresh build updates `/tmp/codex-n12-r1/dd`.

### Spec

#### R6 — P2: Food QR still omits the completeness metadata the new app requires

`WorkoutTracker/Domain/FoodDatabase.swift:158–164`, fed by `server/src/korean.ts:343–364`.

The R2 fix makes the app rely exclusively on `notListed`, but only `fromKoreanRow` emits that field. Food QR's
normalizer also accepts missing macros and turns them into zeros, yet never includes `notListed` in its result.
A Food QR label that lists calories and protein but omits carbs/fat therefore opens without the D86 missing-macros
note. The removed heuristic previously warned for this example; the new exact-metadata path loses the disclosure.

**Reproduced offline with current source:** a consistent, correctly identified Food QR label containing only
187 kcal and 5 g protein per 100 g is accepted as `foodQR`, with carbs/fat **0** and **no `notListed` property**.
`probe.cjs`/`probe.jsonl` and `qr-food.json`, exit **0**. The app parser's absent-field default is `[]`, and `save`
clears the side-store entry for that list, so `SelectedFoodView` has no note. The server reproduction is executed;
the parser/save/display consequence is source-traced. This is not an observed live provider record.

**Fix:** derive Food QR's missing macro list from the raw null fields before zero conversion, using the same
contract as MFDS. Cover an incomplete QR label through normalization, app parsing and kept-food note lookup; keep
valid zero values distinct from absent values.

#### R7 — P2: Non-object barcode rows still become cached misses

`server/src/korean.ts:299–302,392–395`.

R3 now rejects objects with missing/wrong/mismatching barcode fields, but filters away non-object values **before**
checking whether a nonempty response contained any verified match. A successful envelope with `items: [null]`
(Food QR) or `row: [null]` (C005) becomes `rows: []`, bypasses the malformed-response guard and returns an ordinary
empty result. This violates the brief/N8 contract that malformed provider replies must not be cached as misses.

**Reproduced through current `lookupBarcode`, offline:** with OFF/USDA legitimate misses and the other Korean
service legitimately empty, each malformed provider array independently returns `{found: false}` and writes a
**one-day negative cache entry**. `probe.cjs`/`probe.jsonl`, exit **0**, fake fetch/D1 dependencies only. This is a
malformed-provider boundary, not a live outage observation.

**Fix:** validate the raw collection before discarding elements, or base the unmatched/nonempty guard on the
original collection. Non-object entries must not turn an invalid answer into an authoritative empty answer. Add
both provider cases through the route, checking 200 soft failure with no cache write, and retain valid empty/matching
controls.

### Standards

#### R8 — P2: The metadata side store can disagree with restored nutrition

`WorkoutTracker/Domain/FoodDatabase.swift:343–359,462–463`; backup/restore integration in
`WorkoutTracker/Domain/SafetyCopy.swift:83–85,103–123,188–202`.

The dictionary stores only the latest completeness list per database ID, independently of the stored food version.
Safety copies restore only the store/WAL/SHM files. If a copy contains missing fat, then a later complete refresh
clears its dictionary entry, restoring the copy brings back the original zero fat but leaves the newer empty
metadata: the required note disappears. Reversing the sequence attaches a missing-fat note to complete restored
nutrition. The nutrition spec's backup/export data rule and D86 disclosure require the metadata to describe the
food actually restored. Source completeness is not merely an appearance preference.

**Reproduced with the current file-copy/restore and metadata helpers:** `restore-probe.swift` extracts the actual
`SafetyCopies` implementation and current defaults/note helpers; it uses isolated defaults and sentinel store bytes,
not a live database. In both directions the original store bytes restore successfully while the note remains from
the newer version (`restore-probe.log`, exit **0**): original incomplete → `note=none`; original complete →
`Fat isn't listed for this food; it counts as 0.` The probe's temporary files/defaults suite are removed. This
executes the file-swap/metadata mismatch, not a full SwiftData migration or phone restore.

`ExportCollector.swift:182–193` and `ExportSnapshot.SavedFoodRow` also omit this metadata, so the JSON backup loses
the distinction between source-missing and genuine zero. That omission is source-traced, not an import test.

**Fix:** bind completeness to the corresponding stored food version and preserve it through backup/export/restore.
If using a side store to honor D86's no-schema-change constraint, it must participate consistently in that lifecycle;
otherwise explicitly reopen the stored-format decision. Add both restore directions and backup fidelity coverage.

### Round-1 disposition and other checks

- **R1 fixed:** spaced and unspaced provider queries run concurrently, merged and ranked. The spaced cache key stays
  distinct; an unspaced query still makes one call. Either form failing marks the answer incomplete and prevents
  caching; usable results from the other form remain available. Both failing with no local results returns 502.
  These paths are source-checked and covered by the passing server suite; no additional live requests this round.
- **R2 original beer/potato cases fixed:** `notListed` is parsed explicitly; complete beer no longer generates the
  heuristic warning, and missing fat can be named. Current unit coverage passes. R6 and R8 cover the remaining
  producer/lifecycle gaps, not a recurrence of the original energy calculation.
- **R3 original reproduction fixed:** missing, numeric, empty and different barcode fields are rejected. Zero-padded
  identity is retained; all-invalid object rows take the soft-failure path and are not negative-cached. R7 covers
  the still-unhandled non-object array boundary.
- **R4 fixed:** C005 diagnostics accept only bounded `INFO/ERROR-` plus three digits, otherwise `malformed`.
  Reran a sentinel error-field probe: `sentinelLeaked: false`, logged `food upstream c005 malformed`. New tests also
  check fake URL/key/barcode/query sentinels. No real key was read or printed this round.
- **R5 fixed:** test-plan registration and generated TodayTrain plan agree; `scripts/test-plans.py --check` exits 0.
  The privacy routing wording and trailing blank line are corrected; full-branch whitespace check exits 0.
- **Test isolation:** no concrete concurrent defaults race found. The suite is `@MainActor`, serialized, and the
  override test executes synchronously with deferred restoration of the prior defaults instance. Its assertions
  read the same isolated defaults; they do not exercise a real store restore, which is why R8 remains uncovered.

### Round-2 verification

Xcode 27.2; WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`, iOS 27.0. Prepared the simulator, rebuilt after the
source/test changes, ran the affected unit suite, then the two requested UI classes with two workers. Reran the two
failed cases serially on the unchanged binary. No source edits, deployment, physical install, secret access or full
UI suite. The requested executions and capture review are complete; one UI case remains failing as detailed below.

| Check | Command / scope | Result |
|---|---|---|
| Server typecheck | `cd server && npm run typecheck` | exit **0**, `typecheck.log` |
| Server tests | `cd server && npx vitest run` | **337/337**, 10 files, exit **0**, `server.log` |
| Simulator | `scripts/prepare-test-simulator.sh 47D21838-69A6-4BCB-AE90-B0D9C0AAA70B` | exit **0**, `prepare.log` |
| Build | `xcodebuild build-for-testing -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=47D21838-69A6-4BCB-AE90-B0D9C0AAA70B' -derivedDataPath /tmp/codex-n12-r1/dd` | exit **0**, `build.log` |
| Unit | `test-without-building` with that project/scheme/destination/derived data; `-only-testing:WorkoutTrackerTests/FoodDatabaseTests -parallel-testing-enabled NO -resultBundlePath /tmp/codex-n12-r2/unit.xcresult` | **15/15**, no failures/skips, exit **0**, `unit.log`, `unit-summary.json` |
| UI | Same test base; `-only-testing:WorkoutTrackerUITests/KoreanFoodUITests -only-testing:WorkoutTrackerUITests/BarcodeSearchUITests -parallel-testing-enabled YES -maximum-concurrent-test-simulator-destinations 2 -parallel-testing-worker-count 2 -resultBundlePath /tmp/codex-n12-r2/ui.xcresult` | **12/14**, 2 failures, no skips, exit **65**; PID **43910**, `ui.log`, `ui-summary.json` |
| UI failure rerun | Prepared simulator again; same test base with `-only-testing:WorkoutTrackerUITests/BarcodeSearchUITests/testABarcodeNotFoundOffersTheLabelScanAndManualAdd -only-testing:WorkoutTrackerUITests/KoreanFoodUITests/testAKoreanBarcodeOffersIsThisItAndTheLoggedFoodOpensNextTime -parallel-testing-enabled NO -resultBundlePath /tmp/codex-n12-r2/ui-serial.xcresult` | **1/2**, 1 failure, no skips, exit **65**; `ui-serial.log`, `ui-serial-summary.json` |
| Plans | `python3 scripts/test-plans.py --check` | exit **0**, `test-plans.log` |
| Whitespace | `git diff --check f56bf476...HEAD` | exit **0**, `diff-check.log` |
| Diagnostic probes | `node /tmp/codex-n12-r2/probe.cjs`; `swift /tmp/codex-n12-r2/restore-probe.swift` | both exit **0**; incorrect behaviors recorded above |

**UI results inspected directly:** the parallel run passed BarcodeSearch 7/8 and KoreanFood 5/6. Failures:

- `BarcodeSearchUITests.testABarcodeNotFoundOffersTheLabelScanAndManualAdd`, helper `scanBarcode`, line **37**:
  `scanFoodMode.barcode` did not appear. This failed again at the same line in the serial rerun. The same case passed
  serially in round 1, but this round does **not** have passing reviewer evidence for it.
- `KoreanFoodUITests.testAKoreanBarcodeOffersIsThisItAndTheLoggedFoodOpensNextTime`, helper `scanBarcode`, line
  **38**, also waiting for `scanFoodMode.barcode`. It **passed** in the unchanged serial rerun.

The first test of each class failed in parallel; the serial run's first case failed while its second passed. This
pattern is consistent with the earlier camera-entry instability, but its cause is not established and no new source
defect is inferred from timing alone. All six N12 cases have passing evidence across the bundles; the full requested
scope remains **13/14 distinct cases passing** this round. Failure details are retained in `ui-failure-barcode.json`,
`ui-failure-korean.json` and `ui-serial-failure.json`. AVAudioSession main-thread warnings remain in the summaries.

**Captures:** attachment export exited **0** (`attachments/manifest.json`). Inspected the changed note in light
Default (`AEC07178-F3B3-4F47-B364-3B9A7A91F7B5.png`) and dark AccessibilityL, scrolled
(`FFFC4331-6B1F-4E5D-8F51-56E6B570BD82.png`): the named-macro wording wraps fully. Inspected the new
`search-korean-2` pair (`481EE299-4DC2-476D-9935-136A695F1FE9.png` and
`2DE1300C-03E7-45B8-805C-E9AFA031324E.png`): the full Korean-source credit is visible at AccessibilityL after
scrolling, closing round 1's capture gap. No additional layout finding in those changed states.

Spec: **2 P2 findings** (R6, R7). Standards: **1 P2** (R8). No additional P1/P3 findings.

Verified: server typecheck, 337/337 server tests, fresh app build, FoodDatabaseTests 15/15 (`unit.xcresult`), plans and
whitespace checks, all exit 0; current-source offline probes; R1/R4/R5 corrections and original R2/R3 cases checked;
UI 12/14, exit 65 (`ui.xcresult`), then 1/2, exit 65 (`ui-serial.xcresult`), results inspected; changed Default/
AccessibilityL captures inspected. Evidence `/tmp/codex-n12-r2/`.

Not verified: a passing barcode-not-found UI case this round (failed both runs); real provider calls, deployed routes,
production logs/cache, physical camera/phone, full SwiftData restore/export round trip, full UI suite, human VoiceOver,
dark Default/light AccessibilityL captures.

Known flaky / unresolved verification: camera entry in the two named cases above; Korean candidate case passed on
rerun, BarcodeSearch not-found still failed. Follow-up belongs to N12 acceptance-2 verification; preserve both bundles
and diagnose the entry/launch behavior before claiming a green focused scope. R6–R8 are independent of these failures.

Verdict: not clear

## Round 3

Reviewed on **2026-11-13**, `af19f582..09eb57ac`, exact implementation HEAD
`09eb57acde535425dfea6c5c937fb21c07d011a7`, branch `ericlee4992/nutrition-12-korean-db`; clean starting tree.
Read current STATE, ticket fixes, amended D86 and the changed source/callers. STATE's old round-1 wording is stale;
Git/ticket establish the current review. Separate standards/spec passes completed. Only this report changes.
Evidence: `/tmp/codex-n12-r3/` (fresh build updates `/tmp/codex-n12-r1/dd`).

### Spec

#### R9 — P2: The MFDS reader still turns malformed rows into cacheable misses

`server/src/korean.ts:214–217`, consumed by `server/src/food.ts:550–555` and the report-number barcode bridge.

R7 is fixed for the two reported readers, Food QR and C005. The adjacent MFDS reader still returns
`items.filter(isObject)`: an otherwise successful envelope with `totalCount: 1, items: [null]` becomes a valid
empty answer. For a search with no bundled match, it is cached as an empty search for a day; in a report-number
lookup it can cause a barcode miss to be cached for a day. This is another instance of the brief/N8 rule that
malformed provider replies must not become cached misses.

**This predates the round-3 diff; it is an additional discovered reader gap, not a regression introduced by the
fixes.** The requested QR/C005 corrections are acknowledged below.

**Reproduced offline with the current route functions:** `mfds-probe.cjs`/`mfds-probe.jsonl`, exit **0**. Fake
MFDS `[null]` gives search `{foods: []}` and barcode `{found: false}`, each with **one cache write, TTL 1 day**.
OFF/USDA legitimately miss; the barcode case supplies a matching C005 report number so MFDS is reached. Valid-empty
MFDS controls produce the same output/cache behavior. No provider call, real key or production cache was involved.

**Fix:** validate MFDS's raw items before discarding elements, as the QR/C005 fixes now do. Non-object items should
be an upstream failure: search with no usable local result returns 502/no cache; a Korean bridge failure with no
food remains a soft barcode miss/no cache. Cover both paths and retain the valid-empty controls.

### Standards

No new documented-standard or substantive smell finding in the fix diff. The transient metadata is explicitly
authorized by amended D86; there is no remaining storage/export requirement for this note. No schema or
relationship change was introduced.

### R6–R8 disposition and regression assessment

- **R6 fixed.** Food QR derives `notListed` from the raw macro fields before nulls become zero. The replay of
  `probe.cjs` now returns `notListed: ["carbs", "fat"]` for 187 kcal/5 g protein with those macros absent. The new
  route test also checks that explicitly supplied zeros generate no missing-macro list.
- **R7 reported cases fixed.** Replayed `[null]` responses for QR and C005 now each return a soft miss with **zero
  cache writes**. New tests include a valid-empty control that is still cached. R9 is the remaining MFDS boundary.
- **R8 resolved by the user's changed decision, not by adding persistence.** D86 now explicitly limits the note to
  where a food is found. The UserDefaults dictionary, override and writes are removed; its former backup/restore
  finding no longer applies. No new source references to `foodDatabaseNotListed`, `notListedDefaults` or
  `setNotListed` remain.
- **All selected-food callers traced.** An online result sets `selectedNotListed` and opens with
  `selectedFromSearch = true`; a local food row sets it false and passes `[]`. Fresh barcode answers and picked
  candidates copy their own `notListed`, replacing any prior selection's list. A local barcode hit creates a fresh
  `BarcodeState` with the default empty list. Later offline/local reopening therefore intentionally has no note.
- **Tests match the changed contract.** The unit suite checks source metadata/copy and that saving creates no
  `foodDatabase` defaults key. The UI test asserts the online note, logs the food, then reopens the local row and
  asserts no note. Removed persistence assertions implement the explicit D86 change rather than hide an unfixed
  requirement.
- **Scan-helper retry is bounded.** Both helpers retain the camera-mode assertion and all later behavioral
  assertions. They retry the scan-button tap once only if the camera has not appeared and the original button is
  still hittable. Passing with that helper would establish flow coverage, not diagnose the original missed tap.
- The earlier C005 log-sentinel probe still reports `sentinelLeaked: false`. Test-plan and full-branch whitespace
  checks pass. Search variants/cache rules and barcode-link-on-log behavior were not changed by this fix.

### Round-3 verification

Xcode 27.2; prepared WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`, iOS 27.0, then rebuilt after all source/test
changes. The requested unit and UI scopes are used. No source edits, live calls, credential access, deployment or
physical-device install. Executions and capture inspection are complete; the remaining UI failure is retained.

| Check | Command / scope | Result |
|---|---|---|
| Server typecheck | `cd server && npm run typecheck` | exit **0**, `typecheck.log` |
| Server suite | `cd server && npx vitest run` | **339/339**, 10 files, exit **0**, `server.log` |
| Simulator | `scripts/prepare-test-simulator.sh 47D21838-69A6-4BCB-AE90-B0D9C0AAA70B` | exit **0**, `prepare.log` |
| Build | `xcodebuild build-for-testing -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=47D21838-69A6-4BCB-AE90-B0D9C0AAA70B' -derivedDataPath /tmp/codex-n12-r1/dd` | exit **0**, `build.log` |
| Unit | `test-without-building`, same project/scheme/destination/derived data, `-only-testing:WorkoutTrackerTests/FoodDatabaseTests -parallel-testing-enabled NO -resultBundlePath /tmp/codex-n12-r3/unit.xcresult` | **15/15**, no failures/skips, exit **0**, `unit-summary.json` |
| UI | Same test base; `-only-testing:WorkoutTrackerUITests/KoreanFoodUITests -only-testing:WorkoutTrackerUITests/BarcodeSearchUITests -parallel-testing-enabled YES -maximum-concurrent-test-simulator-destinations 2 -parallel-testing-worker-count 2 -resultBundlePath /tmp/codex-n12-r3/ui.xcresult` | **13/14**, 1 failure, no skips, exit **65**, `ui.log`, `ui-summary.json` |
| Failed case, serial | Prepared simulator again; same test base with `-only-testing:WorkoutTrackerUITests/KoreanFoodUITests/testAKoreanBarcodeOffersIsThisItAndTheLoggedFoodOpensNextTime -parallel-testing-enabled NO -resultBundlePath /tmp/codex-n12-r3/ui-serial.xcresult` | **0/1**, 1 failure, no skips, exit **65**, `ui-serial.log`, `ui-serial-summary.json`; unchanged source/binary |
| Plans / whitespace | `python3 scripts/test-plans.py --check`; `git diff --check f56bf476...HEAD` | both exit **0** |
| Current-source probes | `node /tmp/codex-n12-r3/probe.cjs`; `node /tmp/codex-n12-r3/mfds-probe.cjs` | both exit **0**; outputs inspected |

**UI assessment:** BarcodeSearch passed **8/8**, including the not-found case that failed in round 2. KoreanFood
passed **5/6**, including the amended online-note → log → local-reopen-without-note assertion and both capture tests.
`testAKoreanBarcodeOffersIsThisItAndTheLoggedFoodOpensNextTime` failed in both parallel and serial runs at
`KoreanFoodUITests.swift:43`, the final wait for `scanFoodMode.barcode` on the initial `scanBarcode()` call
(`:68`). The added retry has therefore not eliminated the entry instability in this reviewer environment.

The serial failure is **not simply an unchanged Today screen**: its exported hierarchy includes Today and an
`Outdoor Run +1` navigation surface, and the final frame extracted from its test recording shows **Choose Cardio**.
See `ui-failure.json`, `ui-serial-failure.json`, `serial-attachments/manifest.json` and `serial-failure.png`.
This establishes unexpected navigation before barcode mode, not its root cause; investigate fixture launch/layout
settling and the tap target before treating the helper retry as sufficient. No source regression is inferred solely
from the failed automation. AVAudioSession main-thread warnings remain in the result summaries. Both bundles are
preserved, and this round has **13/14** distinct requested UI cases passing, not a green focused scope.

**Captures:** exported `ui.xcresult` attachments (exit **0**). Inspected light Default and dark AccessibilityL
selected-food shots (`77566E27-2B90-4457-AD5A-55CD9F82346C.png`,
`06D129A3-6F2E-4ED2-B41B-41AE2B947418.png`) and the scrolled Korean-search pair
(`6DFF3FD5-2392-475E-BCD5-1AE6E524D299.png`, `477E3C29-23F4-42F3-9D22-E6398DEDF319.png`). The transient note and
source credit remain fully readable; no new layout finding. The absence of the note on local reopening is checked
by the passing behavioral UI test, not a separate capture. Names/IDs are mapped in `attachments/manifest.json`.

Spec: **1 P2 finding** (R9, pre-existing in the N12 implementation). Standards: **0 new findings**. R6–R8 resolved.

Verified: server typecheck and 339/339 tests, fresh build, FoodDatabaseTests 15/15 (`unit.xcresult`), plans and
whitespace checks, all exit 0; QR/C005 and log regression probes; MFDS malformed-array issue reproduced offline;
UI 13/14, exit 65 (`ui.xcresult`), and failed-case rerun 0/1, exit 65 (`ui-serial.xcresult`), both summaries inspected;
changed-state Default/AccessibilityL captures inspected. Evidence root `/tmp/codex-n12-r3/`.

Not verified: a passing Korean found/picked-and-linked barcode UI case this round (both runs failed before barcode
mode); live MFDS/QR/C005 or deployed routes, physical camera/phone, production logs/cache, human VoiceOver, full UI
suite, dark Default/light AccessibilityL captures. No persistence of the note is required or claimed under amended D86.

Known flaky / unresolved verification: the Korean barcode case's initial navigation failed twice despite the helper
retry. Prior passing evidence and intermittent entry failures remain in rounds 1–2. Follow-up belongs to N12's
acceptance-2 verification, using the serial failure recording above; do not claim this run resolved the instability.

Verdict: not clear

## Round 4

Reviewed **2026-11-13**, `281ee5dd..bc04955d`, implementation HEAD
`bc04955dbb659e89f8a17e88727bc9651a49a119`, branch `ericlee4992/nutrition-12-korean-db`; clean starting tree.
Reread STATE, the round-3 fix/diagnosis record, source diff and earlier findings. STATE's round-1 status remains
stale; this section records the actual round. Separate standards/spec passes completed. Only this report changes.
Evidence root: `/tmp/codex-n12-r4/`.

### Spec

**R9 is fixed. No new product-spec finding in this diff.** `mfds()` rejects non-object entries before normalization.
The executed current-source replay (`mfds-probe.cjs`/`mfds-probe.jsonl`, exit **0**) confirms:

- Malformed `[null]`, search without bundled matches: **502 `food_unavailable`, zero cache writes**.
- Malformed `[null]`, search with bundled matches: **9 local foods, zero cache writes**.
- Malformed `[null]`, report-number barcode lookup: **soft miss, zero cache writes**.
- Valid-empty controls: empty search/barcode miss cached for **1 day**; local search results cached for **7 days**.

The additional regression replay (`probe.cjs`/`probe.jsonl`, exit **0**) keeps QR/C005 malformed rows uncached,
retains QR `notListed: ["carbs", "fat"]`, and keeps the C005 diagnostic sentinel out of logs. These probes use fake
fetch/D1 dependencies and no real keys. Added route tests cover the R9 failure and valid-empty paths.

### Standards

No new documented-standard or substantive smell finding. The scan helper adds a bounded, best-effort stability/
hittability wait without removing the camera-mode assertion or later flow assertions. Reaching its five-second
deadline is not itself success: the existing tap and barcode-mode assertion still execute. No production Swift
source, schema, relationship or D86 behavior changed in this fix.

### Camera-entry diagnosis: observed facts and limits

Inspected the author's `/tmp/n12data/ui-r4-004412.xcresult` (**13/14**) and
`/tmp/n12data/ui-r4s-005159.xcresult` (**2/2**), plus its serial log's `TEST EXECUTE SUCCEEDED`. Saved summaries as
`author-ui-summary.json` and `author-ui-serial-summary.json`. The author reports serial exit 0; the result/log
confirm success, but that process's numeric exit was not independently captured by this reviewer.

The author's failed-case activity tree (`author-activities.json`) and video establish more than the final hierarchy:

- Recording begins at **00:45:09.803**. At offsets **5 s and 12 s**, the app visibly presents the active
  **Outdoor Run +1** workout, before the first scan-button tap.
- The scan tap starts at **00:45:26.589** (about **16.8 s** into the recording); XCTest reports
  **`Computed hit point {-1, -1} after scrolling to visible`** at **00:45:26.838**.
- At **17 s** the workout is still visible; at **19 s and 22 s**, **Choose Cardio** is visible. Thus the ticket's
  claim that **Choose Cardio was already open before this tap is not supported by the recording**. The active
  workout was already present; the sheet appears afterward.

Extracted evidence: `author-before-5.png`, `author-before-12.png`, `author-before-17.png`, `author-after-19.png`,
`author-after-22.png`; exported original video/hierarchies remain in `author-attachments/`. The hierarchy confirms
Today/Resume workout beneath the presented workout/cardio UI.

**Assessment:** I agree with tracking this launch/fixture/navigation issue as a separate follow-up from N12's food
lookup implementation: the recorded unexpected workout precedes entry to that feature, and N12 does not change
Today, workout/cardio implementation, app initialization or UI-test store-reset code. I do **not** regard the precise
cause as proven, or the issue as demonstrated to be parallel-only/pre-existing outside the store. The test-store
reset code removes its directory; how this workout is supplied/presented remains to be established. Prior reviewer
serial failures in rounds 2–3 also remain valid evidence despite the author's later serial pass. The test comments'
moving-target explanation and the ticket's restored-clone-state explanation are hypotheses, not interchangeable
proven diagnoses. Follow-up should inspect launch arguments, fixture creation and presentation/restoration state,
using the recording timeline rather than only the final accessibility hierarchy.

### Round-4 verification

Xcode 27.2; WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`, iOS 27.0, prepared before the first run. Rebuilt the
changed UI test bundle into `/tmp/codex-n12-r1/dd`; also reran FoodDatabaseTests under the standing review rule.
The requested two UI classes run with two workers. No live provider calls, secrets, deployment or physical install.
All requested executions are complete. The UI results below remain non-green because of the separately assessed
camera-entry issue; they are not represented as passing reviewer runs.

| Check | Command / scope | Result |
|---|---|---|
| Typecheck | `cd server && npm run typecheck` | exit **0**, `typecheck.log` |
| Server | `cd server && npx vitest run` | **341/341**, 10 files, exit **0**, `server.log` |
| Simulator | `scripts/prepare-test-simulator.sh 47D21838-69A6-4BCB-AE90-B0D9C0AAA70B` | exit **0**, `prepare.log` |
| Build | `xcodebuild build-for-testing -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -sdk iphonesimulator -destination 'platform=iOS Simulator,id=47D21838-69A6-4BCB-AE90-B0D9C0AAA70B' -derivedDataPath /tmp/codex-n12-r1/dd` | exit **0**, `build.log` |
| Unit | `test-without-building`, same project/scheme/destination/derived data; `-only-testing:WorkoutTrackerTests/FoodDatabaseTests -parallel-testing-enabled NO -resultBundlePath /tmp/codex-n12-r4/unit.xcresult` | **15/15**, no failures/skips, exit **0**, `unit-summary.json` |
| UI | Same test base; `-only-testing:WorkoutTrackerUITests/KoreanFoodUITests -only-testing:WorkoutTrackerUITests/BarcodeSearchUITests -parallel-testing-enabled YES -maximum-concurrent-test-simulator-destinations 2 -parallel-testing-worker-count 2 -resultBundlePath /tmp/codex-n12-r4/ui.xcresult` | **12/14**, 2 failures, no skips, exit **65**, `ui.log`, `ui-summary.json` |
| Affected cases, serial | Prepared simulator again; same test base with `-only-testing:WorkoutTrackerUITests/BarcodeSearchUITests/testABarcodeNotFoundOffersTheLabelScanAndManualAdd -only-testing:WorkoutTrackerUITests/KoreanFoodUITests/testAKoreanBarcodeOffersIsThisItAndTheLoggedFoodOpensNextTime -parallel-testing-enabled NO -resultBundlePath /tmp/codex-n12-r4/ui-serial.xcresult` | **1/2**, 1 failure, no skips, exit **65**, `ui-serial.log`, `ui-serial-summary.json` |
| Warm-launch diagnostic | Same serial command selecting only `BarcodeSearchUITests/testABarcodeNotFoundOffersTheLabelScanAndManualAdd`, no additional simulator preparation/reset; `-resultBundlePath /tmp/codex-n12-r4/ui-warm.xcresult` | **0/1**, 1 failure, no skips, exit **65**, `ui-warm.log`, `ui-warm-summary.json` |
| Plans / whitespace | `python3 scripts/test-plans.py --check`; `git diff --check f56bf476...HEAD` | both exit **0** |
| Probes | `node /tmp/codex-n12-r4/mfds-probe.cjs`; `node /tmp/codex-n12-r4/probe.cjs` | both exit **0**, outputs inspected |

The parallel failures are the same two initial-camera-entry cases: BarcodeSearch at `BarcodeSearchUITests.swift:57`
and KoreanFood at `KoreanFoodUITests.swift:58`, waiting for `scanFoodMode.barcode`. The Korean case passed in the
unchanged serial rerun; BarcodeSearch failed again. A single additional focused run tested whether the now-running
simulator improved that case; it still failed, so this does not support a simple cold-launch explanation. No further
reruns were used to seek a green result. Failure details are in `ui-failure-barcode.json`, `ui-failure-korean.json`,
`ui-serial-failure.json` and `ui-warm-failure.json`. The 12 other cases passed, including transient-note behavior and
both classes' captures. This reviewer has **13/14 distinct cases passing** this round. The author's inspected serial
bundle provides passing evidence for both affected cases on this implementation, but does not erase these failures.

Exported fresh attachments (exit **0**) and inspected selected-food light Default
(`F7AA832F-475F-42BD-8B41-F4B507EC98CF.png`) and scrolled dark AccessibilityL
(`BC3374E2-D274-42A3-9F78-F41547FEA720.png`): note and credit remain readable, with no new layout finding. The actual
screen code is unchanged in this round. Attachment mapping is in `attachments/manifest.json`.

Spec: **0 outstanding findings**. Standards: **0 new findings**. R1–R9 dispositions are recorded above; the amended
D86 deliberately resolves the former note-persistence requirement. Camera-entry follow-up remains separate.

**Clearance scope:** the N12 code review is clear. The original findings are resolved and the requested checks have
been executed and inspected. I accept the documented camera-entry instability as a separate launch/test-fixture
follow-up based on the before-feature video evidence, unchanged relevant production code, and inspected passing
author coverage. This is **not** certification of a green reviewer UI run, a resolved launch defect, or the ticket's
specific clone-state explanation. Keep that follow-up and the contradictory serial results visible.

Verified: server typecheck and 341/341 tests, fresh build, FoodDatabaseTests 15/15 (`unit.xcresult`), plans and
whitespace checks, all exit 0; current-source regression probes; author's result bundles and failure timeline inspected;
reviewer UI 12/14, exit 65 (`ui.xcresult`), serial 1/2, exit 65 (`ui-serial.xcresult`), warm diagnostic 0/1, exit 65
(`ui-warm.xcresult`), all summaries inspected; fresh Default/AccessibilityL captures inspected.

Not verified: a green full focused UI run in this reviewer environment; live services/deployment, physical camera/
phone, production logs/cache, human VoiceOver, full UI suite; root cause of the unexpected workout at test launch.

Known flaky / follow-up: the two named WT-iPhone27 initial camera-entry cases. The Korean case passed serially this
round; BarcodeSearch remained failing even in the warm diagnostic, while the author's two-case serial bundle passes.
Track the launch/fixture/navigation investigation proposed in N12's round-3 fix section, with the timeline corrections
above; the stability wait does not establish that the problem is fixed.

Verdict: clear
