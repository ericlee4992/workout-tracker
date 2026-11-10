# N6 independent server review — round 2

Reviewed by Codex on 2026-11-10 in `/Users/ericlee06/orca/workspaces/Health App/nutrition-06-server`. Branch `ericlee4992/nutrition-06-server`, HEAD `20ceb0a9d91dbb75c7740e854c69acc6789add08`; diff `6044c7e..20ceb0a`. The user's amended D79 governs this review: the three training flows retain GPT-5.6 Terra, and the three food flows use GPT-6.1 Terra. Separate standards and spec source passes completed. No deployment, migration, live inference call, credential-file read, commit or push.

## Spec

**Clear — no P1/P2/P3 code findings.**

`server/src/ai.ts:15–16,32–35` maps exactly:

| Flows | Model |
|---|---|
| scan-machine, routine-week, model-exercises | `gpt-5.6-terra` |
| food-photo, food-label, food-describe | `gpt-6.1-terra` |

`prepare` assigns `MODELS[flow]` after preparing checked input (`ai.ts:297–298`), and `openAIRequestBody` uses that assigned model (`:474–480`). Client-supplied model fields are not copied into Prepared and cannot override the selection. The image serializer uses the same prepared request. Instructions, schemas, effort, output caps, `store: false`, authentication, quotas and reply checks are unchanged.

Tests pin the complete six-flow map, assert outgoing training/food models, and retain the injected-model checks. Training requests return to their established GPT-5.6 model without a parameter change; the food requests retain the prior reviewed GPT-6.1 configuration.

## Standards

**Clear — no blocking findings.** The typed `Record<Flow, string>` makes model assignment explicit for every flow. No new storage format, migration or logging behavior is introduced. README describes the amended split, and D79 records the user's reason and deployment at R.

Documentation note, nonblocking: the ticket's original Scope and some unstruck D79 rationale still describe the superseded all-6.1 plan. Mark those passages historical during handoff cleanup. The explicit dated amendment and the user's current instruction take precedence; they are not reasons to restore the old single-model implementation.

## Live-check record

The added record reports one successful local live sample per flow with **all six on GPT-6.1 Terra**, followed by the user's mixed-model decision. I reviewed that record and recomputed its arithmetic; I did not independently reproduce or audit raw upstream responses.

At the record's $1 input / $5 output per million tokens, all six listed per-request costs round correctly to the displayed figures. Multiplying the unrounded costs by the six daily limits gives **$0.68762**, approximately **$0.69/day**. The record's “about $0.68” is a rough summary of that experiment. It is **not** the daily cost of the final mixed-model configuration, which retains the old training-model prices and usage. Do not carry that figure forward as the mixed deployment's budget.

The latency comparison uses single samples from different runs/inputs. Treat it as indicative evidence supporting the user's choice, not a controlled or universal 3–4× benchmark. No further live requests were necessary for this narrow routing review. A presence-only check found `server/.dev.vars` absent; no credential contents were inspected.

## Verified

Existing dependencies were available; `npm ls --depth=0` succeeded. Actual command exits and results were inspected. Evidence is in this checkout's ignored `server/.wrangler/codex-review-n6b/` directory.

- `npx tsc --noEmit`: **exit 0** (`tsc.log`, `tsc.status`).
- `npx vitest run`: **7 files, 251/251 tests passed**, **exit 0** (`vitest.log`, `vitest.status`). Workers/local D1 and fake OpenAI, not live inference.
- `bash scripts/check-secrets.sh --all` from the checkout root: **clean, exit 0**, across tracked files (`secrets-root.log`, `secrets-root.status`).
- `git diff --check`: **exit 0**.

Only this report changes tracked project content; generated test logs remain ignored.

## Not verified

A new live run of the final mixed-model configuration, raw live-response artifacts, a representative mixed-model daily cost, production deployment, remote migration or release acceptance. The previous migration/privacy review remains applicable because those files are unchanged. Deployment stays deferred to **R** as requested; privacy approval/effective date and migration 0007 before Worker deployment remain release gates. No deployment was attempted.

Review totals: **Standards 0 blocking findings; Spec 0 code findings.** The implementation matches amended D79.

Verdict: clear
