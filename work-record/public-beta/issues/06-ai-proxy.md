# 06 — AI through the server

Type: task
Status: ready-for-agent (after 03)
Blocked by: 03
Implementer: Codex (default); Reviewer: Claude — or the reverse.
Branch: `ericlee4992/beta-06-ai-proxy` off `main`.
Spec: [spec.md](../spec.md) → *AI through the server*. Decisions: D60 (reopens D53, D56, D58 key rules).

## Goal

All three AI flows run on the developer's OpenAI key through the server, with per-person daily limits and an off
switch; no OpenAI key exists on any phone.

## Scope

- **Server:** `POST /v1/ai/scan-machine`, `/v1/ai/routine-week`, `/v1/ai/model-exercises`. The server owns each
  flow's instructions, JSON schema, model `gpt-5.6-terra`, `store=false`, reasoning effort and output-token cap
  (moved from the app's request builders; the prompts are unchanged in meaning). The app sends only the input
  text and, for scans, the one JPEG. Size limits on input and image; requests need a valid session.
- **Limits** per account per America/New_York day: 60 / 10 / 60; successes count, attempts capped at twice the
  limit. `GET /v1/ai/usage` for the profile page.
- **Off switch:** global and per-account, effective immediately, no app build.
- **Logging:** account, flow, time, status, latency, token counts — never bodies, photos or replies.
- **App:** `TerraAccess.client` becomes the server-backed client; every caller keeps its validation and
  confirmation (the server is not trusted). Error copy for signed out ("Sign in to use AI"), over the limit (with
  the reset time), paused, offline and timeout; manual paths remain. The three consent flags stay; the
  disclosure names the developer's server and OpenAI.
- **Remove** the Settings OpenAI-key field and the production use of `AskAIKeyStore` for everyone, including
  the developer. Confirm the legacy Anthropic client stays test-fixture-only and remove any key path found.
- Update DEVELOPMENT/AGENTS notes that mention the device key and the Mac credential file; the live smoke test
  uses the server's secret.

## Acceptance

- [ ] Server tests: per-flow request shape, limits and the attempt cap, day rollover in New York time, off
      switches, no body logging, oversize and malformed input, expired session.
- [ ] Each flow works end to end on the phone through the deployed server (live smoke, one request each).
- [ ] Over-limit and paused messages shown (forced by a test account's limit).
- [ ] No OpenAI key in the app, Keychain path, settings or repo; existing AI UI tests adapted to a stub server.

## Verification scope

Server unit tests; the AI scanner, Settings and Ask AI for Templates UI tests and their domain tests (targeted,
per DEVELOPMENT); live smoke. Escalate to the full UI suite only if the transport change cannot be bounded.

## Comments
