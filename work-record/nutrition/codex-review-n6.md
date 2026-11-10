# N6 independent server review — round 1

Reviewed by Codex on 2026-11-10 in `/Users/ericlee06/orca/workspaces/Health App/nutrition-06-server`, branch `ericlee4992/nutrition-06-server`, HEAD `6044c7ed72c1d4687651350213320ab9b9da95f1`; diff `46c9e92..6044c7e`. Read this checkout's guide, state, N6 brief/ticket, decisions and prior proxy/model records. Separate standards and spec source reviews completed. No Xcode work, credential search, live OpenAI request, remote migration, deployment, commit or push.

**This clears the reviewed server implementation and local verification only. N6's live acceptance, cost measurements and privacy approval remain incomplete; this is not deployment clearance or a claim that N6 is finished.**

## Spec

No confirmed P1/P2/P3 code findings.

- The three new flows enter the existing authenticated route and shared proxy. Daily success limits are 30/30/60, attempts twice those limits, with in-flight reservations, pause checks, timeouts and settlement unchanged. `FLOWS`, `isFlow`, body limits and usage include all six flows. The existing usage client accepts string-keyed flow entries, so adding usage keys does not itself break its decoder; displaying food flows in the app remains client work.
- Photo/label requests reuse the bounded JPEG validator; the optional photo note is single-line and bounded to 300, while the required description permits line breaks within its 500 limit. User text remains JSON data and cannot replace server-owned instructions, model, schema or parameters. This bounds request shape; it does not guarantee model immunity to text inside permitted input.
- Photo/description prompts request estimates; the label prompt requires printed facts and nulls for unavailable measurements. Food reply checks bound item count, names/portions, confidence and finite numeric values. All schema fields are required and object extras prohibited. No input, image or reply persistence/logging path was added; the existing count-only accounting remains shared.
- Signed-out, attempt-cap and oversized-image checks are not individually repeated for every new food flow in `food-ai.test.ts`. The unchanged shared paths have existing tests, and the new routes use those paths. This is a coverage limitation, not a demonstrated defect.

## Standards and migration

No confirmed P1/P2/P3 source findings.

`server/migrations/0007_food_flows.sql:3–16` preserves every usage column, the zero defaults, composite primary key and account-delete cascade. It adds allowed flow values without rewriting counters. No secondary index, trigger or inbound foreign key on this table is lost. The reviewer additionally seeded four legacy rows across two accounts, applied the exact migration in SQLite with foreign keys enabled, and verified row/counter preservation, metadata/defaults, old/new flow writes, in-flight settlement, invalid-flow/missing-account/duplicate-key rejection and cascade deletion while retaining the unrelated account. This was an in-memory SQLite probe, not a remote D1 rehearsal.

D1 enforces foreign keys inside implicit transactions, and Wrangler documents rollback of a failed migration. The child-table rebuild does not require disabling foreign keys. [D1 foreign keys](https://developers.cloudflare.com/d1/sql-api/foreign-keys/), [migration application](https://developers.cloudflare.com/d1/wrangler-commands/#d1-migrations-apply).

D1 serializes database queries. Together with migration transaction behavior, this supports the inference that concurrent reservation/settlement writes cannot interleave with the copy/drop/rename transaction; requests may queue or encounter transient availability errors. Remote concurrency and timing were not exercised. [D1 concurrency](https://developers.cloudflare.com/d1/reference/faq/#how-much-work-can-a-d1-database-do).

**Deployment order:** back up under the existing procedure, apply 0007, then deploy the new Worker. Old code works against the expanded table; new food requests against the old CHECK constraint fail during reservation (`ai.ts:506–511`, surfacing as a server error). Existing flows still fit the old schema. If rolling back the Worker, retain the expanded table: the old code tolerates its extra flow rows. Apply the migration as one migration, not manually as separate live statements.

## OpenAI compatibility

Checked official documentation on the review date:

- The documented model ID is `gpt-6.1-terra`; it supports Responses, image input and Structured Outputs. Its documented reasoning values include this code's `low` and `medium`, and its maximum output is 128,000 tokens. Standard text pricing is $1 input / $5 output per million tokens; those rates do not establish per-request cost. [Model documentation](https://developers.openai.com/api/docs/models/gpt-6.1-terra).
- Nullable type unions are valid for otherwise required fields in strict Structured Outputs. The label's `type: ["number", "null"]`, required keys and `additionalProperties: false` follow that pattern. [Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs).
- `max_output_tokens` includes reasoning and visible output. The 4,000/8,000 caps are within the documented limit, but their adequacy must be checked with real samples for truncation and `ai_invalid`. The body does not add unsupported sampling controls such as temperature/top_p. [Responses reference](https://developers.openai.com/api/reference/python/resources/responses/methods/create).
- Inline JPEG input and `detail: "high"` use the documented request form. Detail behavior is model-dependent; the fetched general sizing table did not provide a Terra-specific preprocessing row, so do not treat documentation review as a live guarantee of image acceptance, sizing or cost. [Images and vision](https://developers.openai.com/api/docs/guides/images-vision).

No documented request incompatibility was identified. Before deploying the model switch, run real nonpersonal samples through **all six flows**, including the three existing beta flows. Confirm account access, low/medium effort, strict nullable schemas, image detail/size handling, completed replies within the output caps and 60-second deadline, and downstream validation. Record input/output/reasoning tokens, latency and actual cost per flow; use the ticket's approximately-one-cent decision threshold rather than assuming the limits are affordable from token prices alone.

## Privacy draft

`server/src/pages.ts` is acceptable as a held release draft. The N7 consent, photo re-encoding and permission-screen claims, and N9 Health behavior, must be checked against those implementations before publication; they are not all implemented by this server change. User wording approval, effective date and App Store privacy-answer alignment remain release work.

The exact `[effective date]` placeholder matches the existing npm predeploy guard. Running **only** `npm run predeploy` returned exit **1** with the expected refusal. No deployment was attempted. Direct Wrangler invocation bypasses that npm hook; do not use it to publish the unapproved draft.

## Verified

Node **22.23.2**, npm **10.9.8**. Existing dependencies were present and `npm ls --depth=0` succeeded; no `npm ci` was needed. Local evidence is in this checkout's ignored `server/.wrangler/codex-review-n6/` directory.

| Check | Result |
|---|---|
| `npx tsc --noEmit` | Exit **0** (`tsc.log`, `tsc.status`) |
| `npx vitest run` | **7 files, 250/250 tests passed**, exit **0** (`vitest.log`, `vitest.status`) |
| `npm run test:scripts` | **4/4 passed**, exit **0** (`scripts.log`, `scripts.status`) |
| `bash ../scripts/check-secrets.sh` | Exit **0**, clean; default staged scope (`secrets.log`, `secrets.status`) |
| Additional `bash scripts/check-secrets.sh --all` from checkout root | Clean across tracked files |
| Seeded migration probe | Exit **0**, preservation/constraint checks passed (`migration-probe.log`, `.status`) |
| `npm run predeploy` | Expected exit **1** for the unapproved date placeholder |
| `git diff --check` | Exit **0** |

Vitest uses the Workers runtime and local D1 with a fake OpenAI, and applies the migrations. The seeded preservation probe supplements its post-migration constraint test; it does not replace remote migration verification. Only this report changes tracked project content; test-generated files/logs remain ignored.

## Not verified

Real requests or account access for GPT-6.1 Terra; actual six-flow token costs, latency and quality; remote D1 migration/concurrency, production quotas or deployment; N7/N9 client behavior and App Store privacy disclosures; user approval of the draft. These remain explicit gates before deployment/release. No live key was requested or searched for, and no data was sent to OpenAI inference endpoints.

Review totals: **Standards 0 findings; Spec 0 code findings.** Server source review is clear within the stated scope; live acceptance is still open.

Verdict: clear
