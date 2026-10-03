# 06 — AI through the server

Type: task
Status: server half implemented 2026-10-03 (branch `ericlee4992/beta-06-ai-proxy`); Codex review 06 next. The app
switch waits on 03's app half (the paid team).
Blocked by: 03
Implementer: Claude (server half, the user's order 2026-10-03); Reviewer: Codex.
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

## Server half — 2026-10-03 (Claude)

Branch `ericlee4992/beta-06-ai-proxy` off `main` `60ebd25` (ticket 07 merged). `server/src/ai.ts`, `server/src/time.ts`
(New York day and next midnight, shared with feedback), `migrations/0004_ai.sql`, routes in `index.ts`, deletion in
`store.ts`, the hourly prune in the cron, `scripts/ai.mjs`, README, `.dev.vars.example`.

**Design decisions (for review):**
- **Structured input, not free text.** The app sends each flow's input as bounded JSON — scan: `{exercises:[{id,name,
  loadType}], jpeg}`; routine: the existing `AIRoutineRequest`; model-exercises: `{plate:{brand,model,lines},
  candidates:[{id,name,muscleGroup?}]}` — and the server builds the model's input text exactly as the app's request
  builders did. Reasons: the model-exercises schema must enumerate the candidates' IDs, which the server can only do
  from structure; and every field is checked (UUIDs, enums, lengths ≤ 1,000, ≤ 300 exercises, control characters,
  duplicates) with unknown fields dropped, so nothing the app sends becomes instructions or reaches OpenAI unchecked.
- Instructions, schemas, model `gpt-5.6-terra`, `store:false`, effort `medium`, `max_output_tokens` 8000 moved
  verbatim from `EquipmentIdentification`, `AIRoutine`, `ExerciseProposalAPI`/`TerraExerciseProposer`. The reply is
  read as `TerraClient.output` did (completed, one `output_text`, refusal → error) and returned as `{result}`; the app
  keeps all its validation.
- **Limits:** `ai_usage(account, NY day, flow, successes, attempts, in_flight)`; one conditional upsert reserves a slot
  only while the account exists, `successes + in_flight < limit` and `attempts < 2×limit`; settled after the call
  (success → successes+1). Refusals: `429 ai_limit` (used up), `ai_attempts` (2× cap), `ai_busy` (slots held by
  requests in flight — new; a crash leaves its slot until the day ends). Input errors spend nothing.
- **Off switch:** `ai_settings('paused')` and `ai_account_pauses`, read per request → `503 ai_paused`; `node
  scripts/ai.mjs pause|resume [--account id]|status`.
- **Kept:** `ai_requests` — account, flow, time, status (`ok|refused|invalid|upstream_<n>|timeout|network`), latency,
  input/output/reasoning tokens; 90 days; console logs carry the same counts only. Usage rows older than two days are
  pruned. Deletion removes usage, logs and pause rows in claimDeletion's transaction (FKs cascade too); a request
  outliving its account writes nothing (conditional writes) and still answers.
- OpenAI timeout 60 s → `503 ai_timeout`; upstream non-2xx/network → `503 ai_unavailable`; malformed → `502 ai_invalid`;
  refusal → `502 ai_refused`; no `OPENAI_API_KEY` → `503 server_not_configured` before any slot is taken.
- **For the app half (not built):** copy for `ai_limit` uses `resetsAt` from `GET /v1/ai/usage` ("You've used today's 60
  machine scans. They reset at midnight."); `ai_attempts`/`ai_busy`/`ai_paused`/offline/timeout lines need the user's
  wording then.

**Verification:** server **129/129** (`npx vitest run`; 41 new in `test/ai.test.ts`: per-flow request shape incl.
dropped injected fields and the candidate-ID enum; 15 input refusals with no slot or call; malformed/oversize; expired,
unknown and missing sessions; no key; limits, the attempt cap, concurrency via in-flight slots, NY-midnight rollover; 7
upstream outcomes with their status codes and logs; global and per-account pause; no input/photo/reply/key in logs or
rows; deletion and the deletion race; prune; usage endpoint and DST midnight). `tsc --noEmit` clean. Mutation checks,
each failing its test: limit without `in_flight`; no pause check; no attempt cap; logging the input text; an
unconditional log insert (after strengthening that test to require a normal answer). `scripts/ai.mjs` pause/resume/
status and its ID check smoke-tested against the local D1. No live OpenAI call (needs the deployed server and the
user's key).

## Comments
