# Stacked server

The app's backend (public beta, D60): a Cloudflare Worker with a D1 database. Ticket 03 adds accounts — Sign in with
Apple, sessions, the profile name, sign-out and account deletion — and placeholder `/privacy` and `/support` pages.
Later tickets add Google sign-in (04), the training profile (05), the AI proxy (06) and feedback (07).

**This repository is public.** Secrets live only in Cloudflare (`wrangler secret put`) and, for local runs, in the
git-ignored `.dev.vars`. `scripts/check-secrets.sh` (repository root) rejects key-shaped text; CI runs it on every push
to `main`, and `git config core.hooksPath scripts/git-hooks` turns it on before every commit.

## Endpoints

| | |
|---|---|
| `POST /v1/auth/apple` | `{ identityToken, authorizationCode, nonce, givenName?, familyName? }` → `{ session, expiresAt, profile }` |
| `POST /v1/auth/signout` | ends this session |
| `GET /v1/profile`, `PUT /v1/profile` | `{ displayName, email, provider, memberSince }`; PUT `{ displayName }` (1–50 characters) |
| `DELETE /v1/account` | revokes Apple's tokens, deletes every row → `{ deleted, appleRevoked }` |
| `GET /privacy`, `GET /support`, `GET /v1/health` | pages / liveness |

Signed-in calls send `Authorization: Bearer <session>`. Sessions last 90 days and renew with use; only their SHA-256
is stored. Apple's refresh token (kept to revoke on deletion, as Apple requires) is stored AES-GCM encrypted. Sign-in
fails closed: if the server cannot exchange the code or store the token, no account is created. Errors are
`{ "error": "<code>" }` and never contain tokens or keys; request bodies are not logged.

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
3. In the Apple Developer portal (paid team): enable **Sign in with Apple** for `com.ericlee4992.workouttracker`,
   create a **Sign in with Apple key**, download its `.p8` once. Set `APPLE_TEAM_ID` in `wrangler.jsonc`.
4. Secrets, typed or piped locally — never in chat, never in the repository:
   ```sh
   npx wrangler secret put APPLE_KEY_ID
   npx wrangler secret put APPLE_PRIVATE_KEY < AuthKey_XXXXXXXXXX.p8
   openssl rand -base64 32 | npx wrangler secret put TOKEN_ENC_KEY
   ```
   Keep the `.p8` somewhere safe outside this folder; `TOKEN_ENC_KEY` must not change once accounts exist (it decrypts
   the stored refresh tokens).
5. `npm run deploy` — the user approves the first production deploy. The URL (`https://stacked-server.<you>.workers.dev`)
   becomes the app's server build setting.
