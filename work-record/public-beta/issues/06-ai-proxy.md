# 06 — AI through the server

Type: task
Status: server half — Codex review 06 round 1 not clear (6 findings) → fixed; round 2 next. The app switch waits on
03's app half (the paid team).
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
- [ ] **Before external testers (codex-review-06 #6, CPU risk):** against the deployed server, (a) a maximum-size scan
      (≈ 2 MB JPEG) with its CPU time read from Workers Logs, within the plan's limit (Workers Free: 10 ms; else lower
      the cap or move to Workers Paid — the user's call); (b) adversarial inputs in each allowed field (goals, plate
      lines, exercise names, text in a photo) asking for off-task output, confirming replies stay on-task and inside
      the server's bounds. Record both here.
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
  duplicates) with unknown fields dropped, so no field can change the instructions, model or parameters (typed text
  still reaches the model as data — see the round-1 response, #6).
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

## Codex review 06 — response (round 1)

Report [codex-review-06.md](../codex-review-06.md) (HEAD `ef76d30`): **not clear**, 6 findings; all accepted. Codex
ran 129/129 and probed the actual functions (invalid JPEG acceptance, empty muscle group, pause during upload, body
timeout misclassification) and measured 15.9–24.4 ms of Node CPU for a 3 MB scan's parse/prepare/serialize.

1. **P2 JPEG accepted from its first bytes** — `jpeg()` now requires canonical base64 (length a multiple of 4,
   padding only at the end), ≤ 2 MB decoded, SOI and a well-formed marker walk to a frame header with 1–4096 px sides
   (bounded to the first 64 KB), and EOI at the end. Real 16 × 12 JPEG fixture (PIL). Tests: header-only, bad length,
   header-prefixed garbage, truncated, mid-string padding, 5000 px, 0 px, PNG, 2 MB + 1 refused with no slot or call;
   a real JPEG and an exactly-2 MB one accepted and forwarded intact. (The exactly-2 MB test caught a bug of mine: the
   header slice was not a whole number of base64 groups, which would have refused every JPEG over 64 KB.)
2. **P2 body-read timeout → ai_invalid** — one deadline (`AbortSignal.timeout`) and one transport classifier now cover
   fetch and `response.text()`; JSON parsing happens after. The fake OpenAI honours the abort signal for headers and
   for a streaming body. Tests: headers that never come (real 50 ms deadline via a `Deps.openAITimeoutMs` test seam),
   a body that stalls, a connection dropped mid-body → `ai_timeout`/`ai_unavailable`, slot released, status logged.
3. **P3 README limits** — per-route caps listed (scan 3 MB body / 2 MB JPEG; routine 256 KB; model-exercises 128 KB).
4. **P2 `muscleGroup: ""` refused** — accepted (the app sends it for an exercise without a group); test added.
5. **P2 pause bypass by a slow upload** — the reservation (the admission point) now also requires not paused, globally
   or for the account; a refused reservation reports `ai_paused` first. Tests: both pause scopes set mid-upload, on
   the first request of the day and with an earlier request present → no slot, no call.
6. **P2 the injection claim** — narrowed and hardened rather than claimed solved: names, muscle groups and plate
   brand/model/lines must be single-line (no CR/LF/U+2028/9: no fabricated rows or sections; the routine input is
   JSON, so its multi-line goals stay inside a JSON string); the server refuses replies outside the app's bounds (IDs
   not offered, ≤ 6 proposals with reasons ≤ 300 characters, scan field lengths and ≤ 6 IDs, exactly the requested
   sessions with valid targets) as `ai_invalid` without counting a success. README and the design notes now state the
   guarantee precisely (fixed model/parameters/instructions/schema, bounded replies, quotas; typed text can still
   steer within bounds) and acceptance gains a pre-external-testers adversarial check on the deployed server.
- **CPU (observation):** the JPEG cap is lowered to 2 MB (the app's scans are ≤ 1568 px at q 0.85, well under 1 MB),
  the upstream body splices the checked base64 in instead of re-stringifying it, and acceptance gains a Workers Logs
  CPU measurement of a maximum-size scan before external testers.

Verification: server **157/157**, `tsc` clean. Mutations, each failing its tests: no pause check at admission (insert
path); no single-line rule; no reply bounds; no EOI check; the body read outside the deadline. (Dropping the pause
check from the upsert's UPDATE branch alone is equivalent: the INSERT … SELECT's WHERE gates the update path too.)

## Comments
