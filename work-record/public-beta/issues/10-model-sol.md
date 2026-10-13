# 10 — Switch the AI model from GPT-5.6 Terra to GPT-6.1 Sol

Type: task
Status: ready-for-agent — the user's request, 2026-10-13
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

## Comments
