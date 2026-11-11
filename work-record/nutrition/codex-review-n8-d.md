# N8 independent review — round 4

Reviewed by Codex on 2026-11-11. Clean checkout on `ericlee4992/nutrition-08-barcode`, HEAD
`ff2156f80a3306718fcd547f748ac56684b38e3e`; reviewed `e7a7b28..ff2156f`. Read AGENTS, STATE, the round-4 brief,
ticket's round-3 note and previous report. Separate standards and spec passes completed. Only this report changes the
checkout. No commit, push, deployment, app rebuild, Unit/UI run, live food-API call, credential access or phone install.

## Spec

**The reported R3-S1 cases are fixed.** The rerun of the actual-source unit-consistency and serving-matrix probes confirms:

- A 10 g spoon from a 500 ml package, with only per-100-ml nutrition, now produces `serving: null`; it is no longer
  calculated as 10 ml. Its known volume basis remains available.
- A 30 ml shot identified only by serving text now retains `per100Unit: "ml"`, derives 12.6 calories, and claims no grams.
- Ordinary gram portions, explicit millilitre servings, package-only volume inference and supplied serving nutrition
  retain the expected behavior. The expanded matrix exercises these branches, including fluid ounces.
- The earlier EAN-8, malformed-envelope/HTTP-200-null, logging and nutrient-bound probes remain corrected.

No separate spec finding is counted beyond the guard defect below. It concerns the new explicit policy for an
unsupported serving-unit field, rather than either of the previously reported valid gram/millilitre cases.

## Standards

### T1 — P2: Recognizable text bypasses the guard for an unsupported unit field

`server/src/food.ts:214–216`, consumed at `:240–247`.

`offUnits` documents that when a nonempty field names an unsupported unit, its quantity is not used at all
(`:206–207`). The new matrix also tests that policy. However, `inServing = field ?? unitIn(servingText)` computes a
recognized dimension from the text first. The return expression reaches the unsupported-field guard only when
`inServing` is null.

**Reproduced with actual current source, offline:**

```text
quantity: "400 g"
serving_quantity_unit: "oz"
serving_quantity: 2
serving_size: "2 oz (56 g)"
per-100-g nutrition: 400 calories, 80 g carbs
```

The resolver returns `serving: "g"`, and normalization emits **`grams: 2`, 8 calories and 1.6 g carbs**. The number 2
is an ounce quantity; it has been interpreted as two grams without conversion. With the same unsupported field and
quantity but text `"1 portion"`, the guard correctly produces no derived serving. That is the control covered by the
new matrix; recognizable unit text is the missing branch.

Evidence: `/tmp/codex-n8-r4/spec-probe/unit-edge-cases.mjs`, `unit-edge-cases.jsonl`,
`unit-edge-cases.status` (**exit 0**). The output was inspected directly. This is a **malformed-provider-input handling
defect**: [OFF’s product schema](https://openfoodfacts.github.io/documentation/docs/Product-Opener/schemas/schemas/product/)
documents the normal field values as g/ml, and no live record with an oz field was observed. It is counted
because the new resolver explicitly promises to reject such quantities, its test intentionally covers that boundary,
and this branch instead produces a falsely scaled food. The finding does not claim the previously reported supported
input cases remain broken.

**Fix:** handle a nonempty unsupported unit before text fallback for the serving quantity. Keep inference of the
per-100 basis separate. Return no usable serving-quantity unit in that case, while retaining safe base nutrition or
independently supplied serving nutrition. Add unsupported `"oz"` paired with `"2 oz"` and `"2 oz (56 g)"`, asserting
that the raw quantity is not scaled or exposed as grams. Cover both absent and supplied serving-specific nutrients.

This violates the function's new documented contract and AGENTS' requirement to check internal functions/doc comments
against their callers. No additional baseline-smell finding is asserted.

## Verification

Fresh checks were limited to the server, exactly as the brief directs. `git diff e7a7b28..ff2156f` confirms that no
app, app-test, UI-test or Xcode project source changed. **No app build, Unit run or UI run was performed this round.**
The round-3 app verification remains historical evidence, not a new run.

Evidence root: **`/tmp/codex-n8-r4/`**. Commands/process identity: `server-run.py`, `server-runner.pid`,
`server-runner.log`, `tested-head.txt`, `*.command.json`.

| Check | Result | Evidence under the root |
|---|---|---|
| `npx tsc --noEmit` | exit **0** | `typecheck.log/.status` |
| `npm test` | Vitest **283/283**, script tests **4/4**, exit **0** | `server-tests.log/.status` |
| Diff whitespace | exit **0** | `diff-check.log/.status` |
| App/test/project unchanged check | empty diff, exit **0** | `app-unchanged.log/.status` |

Previous-round probe artifacts were preserved. The current `food.ts` and `index.ts` were bundled into
`spec-probe/food.mjs` and `index.mjs`. Replayed `probe.mjs`, `unit-consistency.mjs`, `serving-matrix.mjs` and
`serving-volume.mjs`; their results and corresponding `.status` files all show **exit 0**. Additional malformed-unit
and supported mixed-text controls are in `unit-edge-cases.mjs/.jsonl/.status`, also **exit 0**. All fetch/D1 dependencies
are fake. Probe success means the diagnostic completed; T1's observed incorrect output is preserved, not classified
as a passing product assertion.

Spec: the original R3-S1 manifestations are resolved. Standards: **one P2 finding** (T1). Total **one P2; no P1/P3**.

Verified: server type-check exit **0**; server **283/283** plus script **4/4**, exit **0**; current-source
unit-consistency/serving-matrix and earlier regression probes rerun, all diagnostic exits **0**, outputs inspected;
malformed-unit guard failure reproduced; diff/app-unchanged checks exit **0**. Evidence: `/tmp/codex-n8-r4/`.

Not verified: app build/Unit/UI this round (explicitly omitted because the app tree is unchanged); live provider
responses, including an unsupported serving-unit record; deployed routes or production D1/logs; physical camera/device
behavior; the malformed-unit case through a full UI/SwiftData save. No real credentials were accessed.

Known flaky: none observed in this round's server checks. Earlier UI launch/navigation flakes remain documented in
`codex-review-n8-b.md`; UI was not rerun. T1 is independent of those UI failures.

Verdict: not clear
