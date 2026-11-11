# N8 independent review — round 5

Reviewed by Codex on 2026-11-11. Clean checkout on `ericlee4992/nutrition-08-barcode`, HEAD
`7aad680072657eff2e5fe5073257082499b0e6f4`; reviewed `ff2156f..7aad680`. Read AGENTS, STATE, the round-5 brief,
ticket's round-4 note and previous report. Separate standards and spec passes completed. Only this report changes the
checkout. No commit, push, deployment, app rebuild, Unit/UI run, live food-API call, credential access or phone install.

## Spec

No P1/P2/P3 findings. **Round-4 T1 is fixed.**

`server/src/food.ts:218–219` now resolves a nonempty unsupported unit before falling back to the serving text or basis.
Its caller at `:243–250` therefore leaves the quantity unset, prevents scaling from it and claims no gram weight.
Independently supplied serving nutrition still follows the existing validation path.

The current-source replay of the previous unit-edge-cases probe confirms:

- `"oz"` with either `"2 oz"` or `"2 oz (56 g)"` produces no derived serving. Quantity 2 is no longer interpreted as
  two grams, and the valid per-100-g nutrition remains available.
- With supplied serving nutrition, **224 calories** and the source's serving text are retained with **`grams: null`**.
- Supported gram/millilitre fields retain their precedence. The mixed-unit controls do not scale across dimensions.
- The earlier 10-g spoon/per-100-ml case still avoids a derived serving; the text-only 30-ml shot still derives
  **12.6 calories** with no grams. Ordinary gram servings remain unchanged.
- Padded EAN-8 matching, malformed-envelope/HTTP-200-null handling, barcode-log redaction and impossible-nutrient
  rejection remain corrected in the additional regression probe replay.

The three new matrix cases exercise both recognizable-text forms and preservation of supplied serving nutrition.

## Standards

No P1/P2/P3 findings or additional baseline-smell findings. The function now follows its documented unsupported-unit
policy, and the caller respects the nullable serving unit. No app, UI, schema, relationship or snapshot code changed.

## Verification

Fresh verification was **server only**, as directed. The tracked app, app-test, UI-test and Xcode project trees have
an empty diff from `ff2156f`; no rebuild or Unit/UI rerun was performed. Prior app verification remains historical
evidence in the earlier N8 reports.

Evidence root: **`/tmp/codex-n8-r5/`**. Commands and process identity: `server-run.py`, `server-runner.pid`,
`server-runner.log`, `tested-head.txt`, `*.command.json`.

| Check | Result | Evidence under the root |
|---|---|---|
| `npx tsc --noEmit` | exit **0** | `typecheck.log/.status` |
| `npm test` | Vitest **283/283**, script tests **4/4**, exit **0** | `server-tests.log/.status` |
| Diff whitespace | exit **0** | `diff-check.log/.status` |
| App/test/project unchanged check | empty diff, exit **0** | `app-unchanged.log/.status` |

Rebundled the actual current `food.ts` and `index.ts` into `spec-probe/food.mjs` and `index.mjs`, preserving all earlier
rounds' artifacts. Reran `unit-edge-cases.mjs`, including the reported failure and the supplied-nutrition case, plus
`unit-consistency.mjs`, `serving-matrix.mjs`, `serving-volume.mjs` and `probe.mjs`. All five `.status` files are **0**;
their `.jsonl` outputs were inspected directly. Fetch and D1 dependencies are fake. In particular, malformed USDA
responses and OFF HTTP-200/null still return **502 with no cache writes**. No real provider request or secret was used.

Spec: **0 findings**. Standards: **0 findings**. Round-4 T1 is resolved.

Verified: server type-check exit **0**; server **283/283** plus script **4/4**, exit **0**; current-source unit-edge-cases
and regression probes rerun, all exits **0**, outputs inspected; diff/app-unchanged checks exit **0**.
Evidence: `/tmp/codex-n8-r5/`.

Not verified: app build/Unit/UI this round (explicitly omitted because the app tree is unchanged); live provider data,
deployed routes, production D1/logs, physical camera/device behavior or the malformed-unit cases through a full
UI/SwiftData save. No real credentials accessed.

Known flaky: none observed in this round's server checks. Earlier UI launch/navigation failures and unchanged passing
serial reruns remain documented in `codex-review-n8-b.md`; UI was not rerun this round.

Verdict: clear
