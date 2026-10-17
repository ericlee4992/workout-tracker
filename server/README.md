# Stacked server

The app's backend (public beta, D60): a Cloudflare Worker with a D1 database and an R2 bucket, live at
https://stacked-server.stacked-server.workers.dev. It holds accounts — Sign in with Apple (ticket 03) and Google
(ticket 04), sessions, the profile name, sign-out and account deletion — the training profile (ticket 05), the AI proxy
with daily limits (ticket 06), in-app feedback (ticket 07), and the privacy policy and support pages (ticket 08).

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
| `POST /v1/auth/google` | `{ idToken, nonce }` (ticket 04: the app's own PKCE code exchange for the iOS client; the raw nonce) → `{ session, expiresAt, profile }`. Checks Google's signature, issuer, audience/`azp` = `GOOGLE_CLIENT_ID`, expiry, nonce; keeps a verified email only; no Google token is stored. `503 server_not_configured` until `GOOGLE_CLIENT_ID` is set in `wrangler.jsonc` `vars` |
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
  row insert removes it, so an upload whose row never landed is deleted an hour later. The hourly cron first expires
  feedback older than a year (ticket 08: ≤ 1,000 rows a run, their screenshots queued due at once), then works through
  due keys 1,000 per run (at most 14 D1 statements — the expiry's two, one read, ≤ 10 deletes by id, the counter
  clean-up — and one R2 call; with the revocation retry, now 20 a run, the AI prune's two and the expired-session
  prune's one, at most 38 of Workers Free's 50 per invocation).
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

## Backups and restore (ticket 08)

The database has two safety nets; neither covers the feedback screenshots in R2 (`stacked-feedback`).

- **D1 Time Travel** (automatic, nothing to run): any minute of the last 7 days on Workers Free, 30 on Paid.
  `npx wrangler d1 time-travel info stacked [--timestamp=<ISO time>]` shows the bookmark for a moment;
  `npx wrangler d1 time-travel restore stacked --timestamp=<ISO time>` **replaces the live database** with it — every
  account, sign-in and feedback row written since is lost. The user approves a restore; it is the first choice after a
  bad migration or a bad write.
- **A manual export** before a migration or anything risky, and kept outside the repository:
  ```sh
  cd server
  D=~/WorkoutTracker-Backups/server/$(date +%F)-<reason>; mkdir -p "$D"; chmod 700 "$D"
  (umask 077; npx wrangler d1 export stacked --remote --output "$D/stacked.sql" -y)
  scripts/check-export.sh "$D/stacked.sql"     # restores it into a throwaway file; row counts vs production
  ```
  The export briefly blocks the database while it runs (a moment at beta size). Wrangler also prints a one-hour
  download link to the same file: treat it like the file — it is every account's email, profile and feedback. An
  export keeps deleted accounts' data for as long as the file is kept, so **delete every export 30 days after it was
  made** (`rm -r ~/WorkoutTracker-Backups/server/<date>-<reason>`; the privacy policy promises it — the user,
  ticket 08). To restore from one: create a new database, `npx wrangler d1 execute <new> --remote --file
  "$D/stacked.sql"`, point `database_id` in `wrangler.jsonc` at it and deploy (the user approves each step).
- **Before any restore** (the privacy policy says deleted data may reappear after one, that the developer deletes
  again what can be identified and tells testers): restoring brings back rows deleted after the backup — accounts,
  feedback, sessions, profile edits — and a Time Travel restore **overwrites the live database in place**. So, in
  order, with the user approving each step:
  1. Pause AI for everyone (the off switch) so fewer writes land meanwhile. Sign-out, account deletion and profile
     edits stay possible, so the evidence is taken twice (steps 2 and 5).
  2. Export the current database (the procedure above), even if it is damaged: evidence A of what was deleted or
     changed since the backup. Note the Time Travel bookmark of "now" (`time-travel info`).
  3. Restore into a **new** database where possible (export → new database), not over the live one.
  4. In the restored copy: delete **every** `sessions` row (everyone signs in again — no signed-out session can come
     back); delete every `accounts` row absent from the evidence (with its identities, training profile, feedback,
     screenshots and AI rows, as `claimDeletion` does) and every `feedback` row absent from it (and its R2
     screenshot); where a training profile differs or is missing, take the evidence's version; re-run the retention
     clean-ups (feedback older than a year, AI records, counters).
  5. Immediately before switching, export the live database again (evidence B) and repeat step 4's account,
     feedback and profile comparison against B; then check counts (`scripts/check-export.sh`-style), point
     `database_id` at it, deploy, and lift the pause.
  6. Changes in the minutes between B and the switch, or any period with no usable evidence, cannot be identified:
     email the affected testers (or all, if unknown) what may have come back so they can delete it again. Record the
     restore in the ticket.

Rehearsed 2026-10-15: an export of production (13 tables, 7.9 KB) restored with integrity `ok` and every row count
equal to production; an export with one table's rows removed is reported as a mismatch (exit 1).

## Checking for Workers Free failures (ticket 08)

The user kept Workers Free (D61) and asked to be told if it causes a failure. Invocation logs are off, so use the
analytics API (wrangler's own login can read it); any `status` other than `success` — notably `exceededCpu` — is a
failure to report:

```sh
T=$(grep -E '^oauth_token' ~/Library/Preferences/.wrangler/config/default.toml | cut -d'"' -f2)
curl -s -A curl/8 https://api.cloudflare.com/client/v4/graphql -H "Authorization: Bearer $T" -H 'content-type: application/json' \
  -d '{"query":"query{viewer{accounts(filter:{accountTag:\"d4c369014a3ec67425d0914615bc02ff\"}){workersInvocationsAdaptive(limit:100,filter:{scriptName:\"stacked-server\",datetime_geq:\"<ISO start>\"}){sum{requests errors}quantiles{cpuTimeP50 cpuTimeP99}dimensions{status scriptVersion}}}}}"}'
```

`cpuTime*` is in microseconds (Free's limit is 10 ms = 10,000).

## Reading feedback

```sh
cd server
node scripts/feedback.mjs list [--limit 20]          # newest first: ID, time (New York), category, status, 📎 = screenshot, sender
node scripts/feedback.mjs list --open                # only the ones not yet handled (status new)
node scripts/feedback.mjs show <id>                  # the whole message, its details and its status
node scripts/feedback.mjs done <id> [note]           # handled, e.g. done <id> fixed in build 7
node scripts/feedback.mjs wontfix <id> [note]        # read, deliberately not acted on
node scripts/feedback.mjs reopen <id>                # back to new (clears the note)
node scripts/feedback.mjs screenshot <id>            # saves it to server/.feedback/ (git-ignored), nowhere else
node scripts/feedback.mjs delete <id>                # a tester asked: the row, its R2 screenshot and any download
```

Every run first deletes downloaded screenshots 15 days old or more (whether or not the database can be reached) and,
in production, those whose feedback no longer exists; `--local` downloads go to `server/.feedback-local`. **While any
download exists, run `node scripts/feedback.mjs prune` at least every 15 days** — so no copy outlives the 30 days the
privacy policy promises (ticket 08); a session that downloads a screenshot records the next prune date in STATE. The server deletes feedback and its screenshot about a year after it was sent
(the hourly job; a failed screenshot delete is retried).

**Tracking (ticket 15):** every feedback starts as `new`; check them off with `done`/`wontfix`. The status and the
optional one-line note (≤ 200 characters, your own words, never personal details) live on the feedback row, so they are
deleted with it — account deletion, the one-year sweep, `delete`. Work that comes out of feedback becomes a numbered
ticket in `work-record/`, describing the problem in your own words and citing the feedback ID, never the tester.

Add `--local` to read `wrangler dev`'s local copies. The Cloudflare dashboard (D1 → stacked → `feedback`; R2 →
stacked-feedback) shows the same. Feedback is tester data: keep it out of the repository, issues and chats.
