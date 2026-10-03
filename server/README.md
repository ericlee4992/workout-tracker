# Stacked server

The app's backend (public beta, D60): a Cloudflare Worker with a D1 database and an R2 bucket. Ticket 03 adds accounts —
Sign in with Apple, sessions, the profile name, sign-out and account deletion — and placeholder `/privacy` and `/support`
pages; ticket 07 adds in-app feedback; ticket 06 the AI proxy (server half). Later tickets add Google sign-in (04) and the
training profile (05).

**This repository is public.** Secrets live only in Cloudflare (`wrangler secret put`) and, for local runs, in the
git-ignored `.dev.vars`. `scripts/check-secrets.sh` (repository root) rejects key-shaped text — PEM keys (also escaped
in strings), `sk-…`, AWS, GitHub and Google key shapes, and this project's secret names assigned a value — reporting
only file, line and detector, never the text. `scripts/test-check-secrets.sh` is its regression test. CI runs both on
every push to `main` (after publication, in this no-PR workflow), so turn on the pre-commit hook:
`git config core.hooksPath scripts/git-hooks`. It cannot catch every possible secret format; review what you commit.

## Endpoints

| | |
|---|---|
| `POST /v1/auth/apple` | `{ identityToken, authorizationCode, nonce, givenName?, familyName? }` → `{ session, expiresAt, profile }` |
| `POST /v1/auth/signout` | ends this session |
| `GET /v1/profile`, `PUT /v1/profile` | `{ displayName, email, provider, memberSince, training }`; PUT `{ displayName?, training? }` — a name of 1–50 characters; `training` `{ goals, experience, days, minutes, height?: { value, unit: "cm"\|"in" }, weight?: { value, unit: "kg"\|"lb" } }` (Ask AI's bounds; units stored as entered) or `null` to remove it (ticket 05) |
| `DELETE /v1/account` | deletes every row now (feedback and its screenshots too); revokes Apple's tokens → `{ deleted, appleRevocation: "done" \| "pending" \| "manual" }` |
| `POST /v1/ai/scan-machine` | `{ exercises: [{ id, name, loadType }], jpeg: <base64 of a JPEG ≤ 2 MB, ≤ 4096 px a side> }` → `{ result }` (the model's JSON) |
| `POST /v1/ai/routine-week` | the app's routine request `{ goals, experience, days, minutes, heightCm?, weightKg?, exercises, cardioActivities }` → `{ result }` |
| `POST /v1/ai/model-exercises` | `{ plate: { brand, model, lines }, candidates: [{ id, name, muscleGroup? }] }` → `{ result }` |
| `GET /v1/ai/usage` | `{ day, resetsAt, paused, flows: { <flow>: { used, limit } } }` |
| `POST /v1/feedback` | multipart: `category` (bug/idea/other), `message` (1–4,000 characters), `appVersion`, `build`, `systemVersion`, `model`, optional `screenshot` (JPEG/PNG ≤ 5 MB) → `201 { id }`; signed in or out |
| `GET /privacy`, `GET /support`, `GET /v1/health` | pages / liveness |

Signed-in calls send `Authorization: Bearer <session>`. Sessions last 90 days and renew with use; only their SHA-256
is stored. Apple's refresh token (kept to revoke on deletion, as Apple requires) is stored AES-GCM encrypted.

- **Sign-in fails closed:** the identity token Apple returns from the code exchange must name the same user as the
  sign-in's identity token, or nothing is created (`code_identity_mismatch`); if the server cannot exchange the code
  or keep the token, no account is created.
- **Deletion:** one transaction claims it — every current Apple token moves to `pending_revocations` (encrypted, linked
  to no account) and every account row is deleted, so a concurrent sign-in or second deletion cannot slip past it — then
  each token is revoked and leaves the queue. One that cannot be revoked now (Apple down, a timeout, the key unavailable)
  stays; the hourly cron retries it with backoff and drops it after 30 days (bounded retention; Apple tokens stay valid
  until revoked, so a dropped one may still be live). Answers: `"done"`; `"pending"` — **the app then tells the user,
  at once, how to stop it themselves**: iOS Settings → Apple Account → Sign in with Apple → Stacked (Apple TN3194);
  `"manual"` — no token was ever kept, only that route. A deletion that lost the race to another gets `409
  deletion_in_progress` (never a made-up outcome). A sign-in that finds the identity already deleted makes a new
  account; one whose token was stored and then claimed by a deletion ends `409 reauthorize` (ask Apple again).
- **Feedback** (ticket 07): text and details in D1, the screenshot in R2 (`stacked-feedback`, typed by its own bytes,
  never the declared type). Per New York day: 10 signed-out attempts per address, 30 per account, 500 in all
  (`429 rate_limited`; the global one `429 feedback_full`). An attempt counts once it passes validation, even if the
  global limit or storage then fails it (a malformed request counts for nothing). The address is never stored: the counter key is an HMAC of the day and the address under a key
  derived from `TOKEN_ENC_KEY` (so signed-out feedback needs that secret). A session that is sent must be valid (`401`).
  Screenshots to delete go through a queue (`screenshot_deletions`): account deletion queues its keys in the deletion
  transaction and deletes them right after, in R2's batches of 1,000; an upload queues its key before the put and its
  row insert removes it, so an upload whose row never landed is deleted an hour later. The hourly cron works through
  due keys 1,000 per run (at most 12 D1 statements — one read, ≤ 10 deletes by id, the counter clean-up — and one R2
  call; with the revocation retry, now 20 a run, at most 33 of Workers Free's 50 per invocation).
- **AI** (ticket 06; signed in only): the server owns each flow's instructions, JSON schema, model (`gpt-5.6-terra`),
  `store: false`, reasoning effort and output cap; the app sends only checked, bounded structured input (unknown fields
  are dropped; names and plate lines are single-line, so they cannot fabricate rows; the JPEG's structure is checked)
  and still validates every reply itself. The server also checks replies as the app does: a scan or routine the app
  would refuse is `502 ai_invalid` (lengths counted as the app counts characters; IDs compared case-insensitively;
  the routine's day count, targets and session-length tolerance), and exercise proposals are cleaned as the app cleans
  them (unknown or repeated IDs dropped, six at most) with each reason cut to 300 characters — the one deliberate
  server restriction. **What this does and does not guarantee:** a tester cannot
  change the model, its parameters, instructions or output schema, and gets at most a bounded, schema-shaped reply a
  limited number of times a day. Text a tester types into an allowed field (goals, a plate, an exercise name) still
  reaches the model as data and could steer an answer within those bounds; that is accepted for the beta, with the
  adversarial check in ticket 06's acceptance run against the deployed server before external testers. Limits per account per New York day: 60 scans, 10 routine weeks, 60
  exercise suggestions — successes count; attempts stop at twice that; requests in flight hold a slot. Errors:
  `429 ai_limit | ai_attempts | ai_busy`, `503 ai_paused | ai_unavailable | ai_timeout | server_not_configured`,
  `502 ai_refused | ai_invalid`. Kept per request: account, flow, time, status, latency and token counts (90 days) —
  never the input, photo or reply, and nothing of them is logged. Account deletion deletes all of it.
- **Off switch:** `node scripts/ai.mjs pause` (everyone) or `pause --account <id>`; `resume`; `status`. It is a D1 row,
  read on every request: effective at once, no app build or deploy.
- **Limits:** request bodies are counted in bytes from the stream and cut off past 64 KB (feedback: 5 MB + 64 KB;
  `/v1/ai/scan-machine` 3 MB — a 2 MB JPEG is about 2.7 MB as base64; `routine-week` 256 KB; `model-exercises` 128 KB); Apple's key set is cached for
  an hour, an unknown key ID refetches it at most once per five minutes, and every call to Apple times out after 5 s.
- Errors are `{ "error": "<code>" }` and never contain tokens or keys; request bodies are not logged.

## Develop and test

```sh
cd server
npm ci                 # Node 22; .npmrc sets legacy-peer-deps (vitest's peer graph crashes npm's resolver)
npm test               # Workers runtime + local D1 + a fake Apple; nothing reaches the network
npm run typecheck
npm run migrate:local && npm run dev    # http://localhost:8787 — sign-in needs .dev.vars (see .dev.vars.example)
```

## First deploy (the developer, once — an agent cannot do these steps)

1. Create a free Cloudflare account; `npx wrangler login`.
2. `npx wrangler d1 create stacked` and put the printed `database_id` in `wrangler.jsonc`; then `npm run migrate:remote`.
   `npx wrangler r2 bucket create stacked-feedback` (feedback screenshots; R2 must be enabled on the account once).
3. In the Apple Developer portal (paid team): enable **Sign in with Apple** for `com.ericlee4992.workouttracker`,
   create a **Sign in with Apple key**, download its `.p8` once. Set `APPLE_TEAM_ID` in `wrangler.jsonc`.
4. Secrets, typed or piped locally — never in chat, never in the repository:
   ```sh
   npx wrangler secret put APPLE_KEY_ID
   npx wrangler secret put APPLE_PRIVATE_KEY < AuthKey_XXXXXXXXXX.p8
   openssl rand -base64 32 | npx wrangler secret put TOKEN_ENC_KEY
   npx wrangler secret put OPENAI_API_KEY      # the developer's OpenAI key (ticket 06); typed at the prompt
   ```
   Keep the `.p8` somewhere safe outside this folder; `TOKEN_ENC_KEY` must not change once accounts exist (it decrypts
   the stored refresh tokens).
5. `npm run deploy` — the user approves the first production deploy. The URL (`https://stacked-server.<you>.workers.dev`)
   becomes the app's server build setting.

## Reading feedback

```sh
cd server
node scripts/feedback.mjs list [--limit 20]          # newest first: ID, time (New York), category, 📎 = screenshot, sender
node scripts/feedback.mjs show <id>                  # the whole message and its details
node scripts/feedback.mjs screenshot <id>            # saves it to server/.feedback/ (git-ignored); --out <dir> elsewhere
```

Add `--local` to read `wrangler dev`'s local copies. The Cloudflare dashboard (D1 → stacked → `feedback`; R2 →
stacked-feedback) shows the same. Feedback is tester data: keep it out of the repository, issues and chats.
