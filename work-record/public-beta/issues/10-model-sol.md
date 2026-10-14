# 10 — Switch the AI model from GPT-5.6 Terra to GPT-6.1 Sol

Type: task
Status: **closed without change — the user kept GPT-5.6 Terra (2026-10-14)** after the measurements below: Sol is
cheaper per token but not per request for this app, and 2–3× slower.
Blocked by: — (the server is deployed; the OpenAI key is a Cloudflare secret, ticket 03)
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch: `ericlee4992/beta-10-model-sol` off `main`.
Spec: [spec.md](../spec.md) → *AI* (the server owns each flow's model). Decision: D60. Related: [06](06-ai-proxy.md).

## Request (the user, 2026-10-13)

"make it a ticket to switch to 6.1 sol. Apparently it's cheaper than 5.6 terra." The existing OpenAI API key is
kept; a key is not tied to a model (unless the user restricted it to models when creating it).

## Where the model is set

- `server/src/ai.ts:12` — `MODEL = "gpt-5.6-terra"`: every flow through the server (scan-machine, routine-week,
  model-exercises). Changing it needs a redeploy, not an app update.
- `WorkoutTracker/Domain/TerraAPI.swift:8` — `static let model = "gpt-5.6-terra"`: the app's direct path with the
  on-device key. Changing it needs a new build.
- Docs naming the model: `work-record/public-beta/spec.md` (*AI*), and any SPEC/DECISIONS lines that name it.

## Before changing anything (verify; do not assume)

1. The **exact model ID** from OpenAI's model documentation (a guess such as `gpt-6.1-sol` is not enough).
2. **Price** per input/output token (and image input, which scan-machine uses) against 5.6 Terra. The user's
   statement that Sol is cheaper is the reason for the ticket; record the published figures. If Sol is in fact
   dearer, stop and ask the user. Check the daily limits (60/10/60, ticket 06) still fit the cost assumption.
3. **API compatibility** on the Responses API as the server calls it: `reasoning.effort` ("medium"), structured
   output with a strict JSON schema, image input (base64 JPEG), `store: false`, `max_output_tokens` 8000.
   Any parameter Sol rejects or renames is a change to `ai.ts`'s request body, not just the constant.

## Change

- Both constants above, plus the docs that name the model. Comments that say "Terra" where they mean the model (not
  the app's `Terra*` type names, which stay) are updated.
- Server tests that assert the request body's model follow the constant.

## Verification scope

- Server: `tsc --noEmit`, `vitest run` (all files). App: build; the unit tests covering `TerraAPI` / `TerraClient`
  request construction.
- **Live check after deploy:** one real request per flow through the deployed server (scan-machine with a test
  photo, routine-week, model-exercises) returns a valid structured reply; record latency and OpenAI's reported
  token usage. Counts-only logs — no prompt or reply content kept.
- The direct-key app path gets one real request on the Simulator with the Mac's key file (never in chat).
- No full UI suite.

## Acceptance

- [ ] Model ID, prices and parameter support recorded with their sources.
- [ ] Server and app use the same model; tests green; deployed; three live flows answer.
- [ ] Codex clear.
- [ ] The app half reaches the phone with the next TestFlight build (the server half applies at deploy).

## Result (2026-10-14, Claude)

Branch `ericlee4992/beta-10-model-sol` off `main` `507c1dd` (ticket 06 merged). The app no longer has a model constant
(ticket 06 removed `TerraClient`); the only one is `server/src/ai.ts` `MODEL`.

**1. Model ID and prices (OpenAI's own pages, checked 2026-10-14).**
[Pricing](https://developers.openai.com/api/docs/pricing), standard tier per 1M tokens (≤ 272K input):
`gpt-6.1-sol` $2.00 input / $0.10 cached / $10.00 output; `gpt-5.6-terra` $2.00 / $0.20 / $12.00. No separate image
price for either (images count as input tokens). Secondary sites disagreed on Terra ($2/$12 vs $2.50/$15); OpenAI's page
was used. [Model page](https://developers.openai.com/api/docs/models/gpt-6.1-sol): ID `gpt-6.1-sol` (the only snapshot).

**2. Compatibility.** The model page lists the Responses API, `reasoning.effort` low | **medium (default)** | high |
xhigh | max, structured outputs, image input, 128,000 max output. Confirmed in practice: with `MODEL = "gpt-6.1-sol"`
the server's tests passed (tsc clean, 196/196) and a local `wrangler dev` (local D1, the Mac's development key file,
never printed) answered all three flows with valid structured replies — the server's request body unchanged
(`store: false`, effort medium, strict JSON schema, base64 JPEG, `max_output_tokens` 8000).

**3. Cost and speed per request** (Sol: 8 local requests; Terra: ticket 06's deployed checks the same day; output
tokens include reasoning):

| Flow | Terra tokens in / out | Sol tokens in / out | Cost Terra → Sol | Latency Terra → Sol |
|---|---|---|---|---|
| scan-machine (app-sized photo) | 4961 / 72–74 | 4961 / 72–74 | $0.0108 → $0.0107 | 1.4–1.7 s → 3.3–4.5 s |
| model-exercises | 4410 / 58–60 | 4393–4400 / 53–97 | $0.0095 → $0.0095 | 1.2–1.4 s → 2.6–3.4 s |
| routine-week (2 days, 45 min) | ~1790 / 534–579 (reasoning 94–139) | ~1770 / 819–1093 (reasoning 167–383) | $0.0103 → $0.0127 | 5–6 s → 13–18 s |

Scans and suggestions are dominated by input (the photo, the exercise list), priced the same; Sol writes ~60 % more
output for a week (more reasoning), which outweighs its lower output price. Samples are small (indicative).

**Decision (the user, 2026-10-14): keep Terra; close 10.** The one-line change and its doc edits were reverted; nothing
was deployed. A later option, not tried: Sol at reasoning effort `low`.

## Comments
