# 03 — Server foundation and Sign in with Apple

Type: task
Status: in progress — **server half implemented 2026-10-02** (the user's go-ahead); the app half waits on the paid
team (ticket 01, B)
Blocked by: 01 (the paid team is required for the Sign in with Apple capability)
Implementer: Claude (the user's go-ahead to start the server half, 2026-10-02); Reviewer: Codex.
Branch: `ericlee4992/beta-03-server-apple` off `main`.
Spec: [spec.md](../spec.md) → *Accounts*, *Server*. Decision: D60.

## Goal

A deployed Cloudflare Worker with D1 that signs people in with Apple, keeps a session, stores a display name,
signs out, and deletes accounts completely — and the app's Account row in Settings that uses it.

## Scope

**Server (`server/`, TypeScript, Cloudflare Workers + D1):**
- Project skeleton, `wrangler` config, D1 migrations (accounts, identities, sessions), `server/README.md` with
  setup, local dev and deploy steps for the user.
- `POST /v1/auth/apple`: verify the identity token (Apple's JWKS, issuer, audience = bundle ID, expiry, the
  nonce's SHA-256), exchange the authorization code for Apple's refresh token (client secret JWT signed with the
  Sign in with Apple key) and keep it for revocation; create or find the account; store the first-sign-in name
  and email; return an opaque session token (random, stored hashed; 90-day expiry renewed by use).
- `POST /v1/auth/signout`; `GET`/`PUT /v1/profile` (display name only here); `DELETE /v1/account` (every row for
  the account; Apple token revocation; idempotent).
- Stub `GET /privacy` and `GET /support` pages (filled in ticket 08).
- **Secrets only in Cloudflare** (`wrangler secret`); `.dev.vars` and any key file git-ignored; a pre-commit or
  CI check that rejects key-shaped strings. **The repository is public.**
- Tests with the Workers test runner: token verification against fixture keys (good, expired, wrong audience,
  wrong nonce, bad signature), session expiry, sign-out, deletion cascade, malformed input.

**App:**
- Sign in with Apple capability (`com.apple.developer.applesignin`) on the paid team.
- An account client over `URLSession`; the server URL is one build setting. Session token in its own Keychain item
  (this device only). Errors fail closed with a one-line message; signed-out use is unchanged.
- Settings: an **Account** row at the top (Sign in / name and email) opening a minimal account sheet with Sign in
  with Apple, Sign out, and **Delete account** (confirmation states that workouts on this phone stay). Ticket 05
  builds the full profile page on top of it.
- Onboarding page 5 (ticket 02) gains Sign in with Apple / Not now.

## User steps (cannot be done by an agent)

Create the Cloudflare account; create the Sign in with Apple key in the developer portal and hand it to
`wrangler secret put` locally (never in chat or the repo); approve the first production deploy.

## Progress

### Server half — 2026-10-02 (Claude)

Branch `ericlee4992/beta-03-server-apple` from `main` `f6895a5`. `server/` (TypeScript, Cloudflare Workers + D1):
`wrangler.jsonc` (D1 binding `DB`, vars `APPLE_CLIENT_ID` = the bundle ID and `APPLE_TEAM_ID` = empty until the paid
team; compatibility date 2026-08-22, the newest the local runtime supports), `migrations/0001_accounts.sql` (accounts,
identities, sessions; cascades), `src/` — `crypto.ts` (base64url, SHA-256, tokens, UUIDs, AES-256-GCM, PKCS#8 import),
`jwt.ts` (decode, RS256 verify, ES256 sign), `apple.ts` (identity-token verification: Apple JWKS by `kid` with one
refetch, issuer, audience, expiry with 60 s leeway, `iat` not in the future, nonce = SHA-256 of the raw nonce, subject;
client-secret JWT; code exchange; revocation), `store.ts`, `index.ts` (router; `createHandler(deps)` takes the clock,
fetch and randomness so tests replace them), `pages.ts` (stub privacy/support). Fail-closed choices: no encryption key
→ sign-in 503; Apple refuses the code → 502 and **no account**; deletion revokes first, then deletes every row whatever
Apple answers and reports `appleRevoked`. Session tokens stored only as SHA-256; 90 days, renewed at most daily by use.
Errors are `{error: code}`; no bodies or tokens logged.

Secrets: `server/.gitignore` (`.dev.vars`, `*.p8`, `*.pem`), `.dev.vars.example`; `scripts/check-secrets.sh`
(`--staged` / `--all`: PEM private keys, OpenAI/Anthropic/AWS/GitHub/Google key shapes, filled `.dev.vars` names;
boundary-anchored after a false positive on CSS `mask-image-…` in a prototype bundle); opt-in hook
`scripts/git-hooks/pre-commit`; CI `.github/workflows/server.yml` (secret scan over every tracked file + `npm ci`,
`tsc`, `vitest` on Ubuntu). `server/README.md`: endpoints, dev/test, the developer's one-time deploy steps.

Tooling notes: npm 10.9 crashes resolving vitest 4's peer graph (`edgesOut`) → `server/.npmrc` `legacy-peer-deps=true`
with every needed package listed; the Workers pool (0.22) keeps one D1 per test file → the harness empties the tables
before each test.

**Evidence:** `tsc --noEmit` exit 0; `vitest run` **26/26** — token checks (good; expired; wrong audience; wrong issuer;
forged signature; unknown `kid`; `alg` none; no subject; `iat` in the future; wrong nonce; garbage tokens; malformed,
array and oversize bodies), the code exchange with a client secret verified against the fake key's public half and
the refresh token stored encrypted, no account when Apple refuses the code or the server lacks its key, the first-sign-in
name kept and cleaned, the newest refresh token kept, users kept apart, profile read/rename/validation, missing and
unknown tokens, expiry after 90 days unused and renewal by use, sign-out of one session only, deletion (revocation
with the decrypted token, every row of that account only, the dead session refused, rows deleted even when Apple refuses
and reported), re-sign-in after deletion is a new account, pages and 404s, no secrets in errors. **Mutations:**
removing the nonce check fails exactly the nonce test; removing the audience check fails exactly the audience test.
**Local smoke** (`wrangler dev`, local D1 migrated): `/v1/health` 200, `/privacy` 200 HTML, sign-in 503
`server_not_configured` without keys, profile 401 without a session. Secret scan: `--all` clean over the repository;
`--staged` catches a planted OpenAI-style key and a PEM key and passes the CSS line.

**Not done (needs the user / the paid team):** the Cloudflare account, D1 creation, secrets, deploy; the app half
(capability, account client, Settings Account row, onboarding sign-in).

## Acceptance

- [ ] Server tests green; `wrangler dev` smoke from the Simulator: sign in, rename, sign out, delete.
- [ ] Deployed Worker; sign-in and deletion work from a development build on the phone; Apple's "Apps using Apple
      ID" list no longer shows the app after deletion.
- [ ] Signed-out app behaviour unchanged (targeted UI tests); Account row captures, Default and AccessibilityL.
- [ ] No secret in the diff or history (check run and recorded).

## Verification scope

Server unit tests; app targeted unit/UI tests for the account client and Settings; captures. No full UI suite.

## Comments
