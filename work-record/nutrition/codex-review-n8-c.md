# N8 independent review — round 3

Reviewed by Codex on 2026-11-11. Clean checkout on `ericlee4992/nutrition-08-barcode`, HEAD
`e7a7b28ac28e66dddf97eb79f2d4f7f49a284860`; reviewed `9b754ab..e7a7b28`. Read AGENTS, STATE, the round-3 brief,
ticket's round-2 note and previous report, applying the established spec and review guidance. Separate standards and
spec passes completed. Only this report changes the checkout; no commit, push, deployment, physical-phone install,
live food-API call or credential access.

## Spec

### R3-S1 — P2: Serving-unit inference still disagrees with the nutrition basis

`server/src/food.ts:203–204,218–229`.

The exact round-2 liquid examples now work, but resolving the nutrition basis and serving unit separately still
allows dimensional mistakes. The new `per100Unit === "ml"` branch can override explicit grams in the serving text;
in the opposite direction, serving-text evidence recognized later never updates the earlier default gram basis.

**Introduced regression — a gram serving of a product sold by volume.** With:

- `quantity: "500 ml"`, `serving_size: "1 spoon (10 g)"`, `serving_quantity: "10"`, no explicit unit field;
- only per-100-ml nutrition: 810 calories and 90 g fat;

the new code chooses millilitres for the **10 g** serving, scales by `10 / 100`, and emits **81 calories / 9 g fat**.
That calculation is for 10 ml; no density was supplied to convert the stated 10 g. The server retains the gram text
but sets `grams: null`. The actual app serving parser then drops the parenthetical weight and displays **“1 spoon”**
with those derived numbers. In the previous round's code, this same input left the serving absent, avoiding the
cross-unit derivation and retaining the known 100-ml basis.

**Related remaining path — volume evidence only in the serving text.** An Orange juice record with
`serving_size: "1 shot (30 ml)"`, `serving_quantity: "30"`, no package quantity/unit field, and only 42-calorie
per-100-ml nutrition returns **`per100Unit: "g", serving: null`**. The app consequently formats **“100 g”** with 42
calories. Adding only the explicit `serving_quantity_unit: "ml"` yields the correct volume basis and a 12.6-calorie
serving. The provider's `_100g` field can represent 100 ml for liquids; package and serving-unit metadata are not
required properties. [OFF product schema](https://openfoodfacts.github.io/documentation/docs/Product-Opener/schemas/schemas/product/),
[OFF nutrition schema](https://openfoodfacts.github.io/documentation/docs/Product-Opener/schemas/schemas/product_nutrition/).

**Reproduced offline with actual code:** `/tmp/codex-n8-r3/spec-probe/unit-consistency.jsonl` compares round 2 and round 3
for both cases plus a gram-based control. `serving-matrix.jsonl` covers the missing-field variants.
`app-contract-probe.log` confirms the resulting “1 spoon” / 81 calories and “100 g” / 42 calories at the app's actual
parser/serving-conversion boundary. These are synthetic contract cases, not live-product or physical-device observations.

**Fix:** resolve the available unit evidence consistently before computing either nutrient basis, while keeping the
nutrition basis and serving unit distinct. Explicit serving-unit evidence must not be overridden by the package's
volume. Scale only when the two units are established and compatible; otherwise retain valid serving-specific data
or a known base portion, without inventing grams or converting through an assumed density. If the basis is genuinely
unknown, do not assert a gram basis. Add a small matrix covering weight/volume/absent package metadata, explicit or
text-only serving units, and per-100-only versus serving-specific nutrients. The new text-only test inherits serving
nutrition from `offProduct`, so it does not exercise the blocked-fallback path above.

This is one unit-resolution finding with two manifestations, not two separately counted defects.

## Standards

No additional confirmed standards findings in this small diff. The standards pass identified the explicit-gram-serving
candidate; its offline reproduction is included in R3-S1 rather than counted again. No new baseline-smell finding.
Persistent schemas, relationships, snapshot behavior, UI source and UI tests are unchanged.

## Round-2 disposition

- **R2-S1 exact reproductions:** fixed. Both the 330-ml can and 200-ml glass now return `grams: null` and keep their
  volume labels in the app. R3-S1 describes the remaining/inconsistent combinations and the introduced cross-unit case.
- **R2-S2:** fixed. `NOT_FOUND` is a distinct symbol, so no decoded JSON value can collide with it. The original OFF
  HTTP-200/null probe now returns **502 with no cache write**. Explicit HTTP 404/status-0 misses and legitimate fallback
  behavior remain covered by the server suite.
- **900-calorie advisory:** fixed. The app's limit now matches the server; both the new unit assertions and the current
  Swift probe accept **900** and reject **940** calories per 100 g.
- Earlier EAN-8 forms, malformed USDA envelopes, error-log redaction and impossible-nutrient probes remain corrected.

## Verification

Xcode **27.2**, WT-iPhone27 **`47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`**, iOS **27.0**. Prepared the simulator, built
fresh into `/tmp/codex-n8-r3/dd`, then ran the Unit plan serially. No UI execution this round, as directed: the diff
contains no UI source or UI-test changes, and the only app production change is the calorie-limit constant.

Evidence root: **`/tmp/codex-n8-r3/`**. Commands/processes: `run.py`, `runner.pid/.log`, `server-run.py`,
`server-runner.pid/.log`, `tested-head.txt`, `*.command.json`.

| Check | Result | Evidence under the root |
|---|---|---|
| Server `npx tsc --noEmit` | exit **0** | `typecheck.log/.status` |
| Server `npm test` | Vitest **282/282**, script tests **4/4**, exit **0** | `server-tests.log/.status` |
| Build-for-testing | exit **0** | `build.log/.status` |
| Unit plan | **1,284/1,284**, no failures/skips, exit **0** | `unit.xcresult`, `unit-summary.json`, `unit.log/.status` |
| Test-plan consistency / diff whitespace | both exit **0** | `test-plans.log/.status`, `diff-check.log/.status` |

Reran the earlier probes against bundled current `food.ts`/`index.ts`, preserving all prior-round artifacts.
`spec-probe/probe.mjs`, `output.jsonl`, `stderr.log`, `status` (**exit 0**) cover the original cases and corrected
200/null behavior. `serving-volume.mjs/.json/.status` and `serving-matrix.mjs/.jsonl/.status` also exited **0**.
The additional comparison is `unit-consistency.mjs/.jsonl/.status` (**exit 0**), importing the retained round-2 module
and the current module; its expected gram control is unchanged. All provider and D1 dependencies are fake.

`app-contract-probe.swift` copies the current pure parser, serving conversion and supporting value types; input is
`app-contract-input.json`, output/status are `app-contract-probe.log/.status` (**exit 0**). It confirms the corrected
original volume cases and calorie boundary, as well as R3-S1. No network or SwiftData persistence runs in that probe.
Diagnostic exit 0 means the probe completed, not that each observed product behavior was correct.

**UI evidence inspected instead of rerunning:** the author's supplied `r2-ui.xcresult` reports **18/18 passed**, no
failures/skips; its `r2-ui.log` contains `TEST EXECUTE SUCCEEDED`. Saved its summary as `author-r2-ui-summary.json`.
No separate numeric shell-exit artifact was supplied for that author run, so no fresh reviewer UI exit is claimed.
The previous reviewer round also retains passing evidence for every requested case across
`/tmp/codex-n8-r2/ui.xcresult` and the unchanged **3/3**, exit **0**, serial rerun. No new captures were required or made.
The author's `r3-unit.xcresult` was inspected directly too: **1,284 passed**, no failures/skips
(`author-r3-unit-summary.json`).

Spec: **one P2** (R3-S1). Standards: **no additional findings**. No P1/P3 findings.

Verified: fresh build exit **0**; server type-check exit **0**; server **282/282** plus script **4/4**, exit **0**;
Unit **1,284/1,284**, exit **0**, `/tmp/codex-n8-r3/unit.xcresult`; current-source offline probes exit **0** and outputs
inspected; test-plan/diff checks exit **0**; prior UI bundle **18/18 Passed** inspected as required, not rerun.

Not verified: fresh UI execution or captures this round; live provider data/deployed routes; physical camera behavior;
production D1/logs; the newly identified unit cases through a full UI/SwiftData save (reproduced at the actual pure
normalizer/parser boundary); human VoiceOver; runtime Reduce Motion; the full UI suite. No real credentials accessed.

Known flaky: none observed in this round's executed checks. The prior warm-up/Add food navigation/dark Log food capture
parallel failures and their unchanged passing serial reruns remain documented in `codex-review-n8-b.md`; they were not
rerun this round. R3-S1 is independent of those UI failures.

Verdict: not clear
