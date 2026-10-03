# 03 — Server foundation and Sign in with Apple

Type: task
Status: in progress — **server half implemented and Codex clear (4 rounds) 2026-10-02**, not merged (awaiting the
user's go-ahead); not deployed; the app half waits on the paid team (ticket 01, B)
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

## Codex review 03 — response (round 1)

Review: [codex-review-03.md](../codex-review-03.md) — not clear (P1 ×2, P2 ×5, P3). All accepted.

1. **P1 code ↔ identity binding** — `exchangeAppleCode(code, expectedSubject, …)` verifies the `id_token` Apple returns
   (same checks as the sign-in token, minus the nonce) and requires its `sub` to equal the sign-in token's, else
   `401 code_identity_mismatch` before any database write; a missing/empty/oversize refresh token or a bad/unsigned/
   wrong-audience `id_token` → 502. The fake Apple now binds each code to its user, makes codes single-use and returns a
   signed `id_token`. Tests: A's token + B's code → 401, nothing stored; a reused code → 502; four malformed answers → 502;
   tokens without numeric `iat`/`exp` → 401. Mutation: removing the subject check fails exactly the A/B test.
2. **P2 body limit** — the body is read from the stream counting bytes and cancelled past 64 KB. Tests: 80 KB of `é`
   (40 k characters) → 413; a stream without Content-Length is cut off (≤ 64 KB + 3 chunks pulled of 1 MB); exactly
   64 KB is read and judged (401).
3. **P2 JWKS refetches** — one cached key set per hour; concurrent fetches share one request; an unknown `kid` forces a
   refetch at most once per 5 minutes; every Apple call has a 5 s timeout. Tests: after warming, 5 sequential + 3
   concurrent bogus `kid`s → exactly 1 extra fetch; a rotated key is accepted after the cooldown. Mutation: removing the
   cooldown fails exactly that test.
4. **P2 first-sign-in race** — `createOrFindAccount`: on the identity primary-key conflict it joins the winner's
   account and keeps its own newer refresh token; if the winner was deleted meanwhile it creates afresh. Tests: two
   simultaneous first sign-ins → one account, two sessions; the deterministic loser path joins the winner.
5. **P2 deletion with Apple down** — every account row is deleted at once in one batch, and in the same batch an
   unrevoked token is queued in `pending_revocations` (migration 0002: ciphertext, SHA-256 key for idempotence, no
   account link); the hourly cron (`triggers.crons`) retries with backoff (1 h doubling to 24 h) and drops it after 30
   days. The answer is `appleRevocation: "done" | "pending" | "manual"` (manual = no token kept → iOS Settings, TN3194),
   documented in README and the spec. Tests: outage → pending → still down → revoked when back; key unavailable at
   deletion → revoked once restored; tampered ciphertext → retried, dropped after 30 days; no token → manual; two
   simultaneous deletions → nothing left, queued once.
6. **P1 scanner false negatives** — detectors now catch PEM headers followed by escaped `\n` + base64 or inline base64,
   and the project's secret names with optional quote, spaces and `:`/`=` (value ≥ 16 key characters).
7. **P2 staged diff parsing** — `--staged` runs `git grep --cached` over the staged files: the index version, whole
   files, no diff parsing; `--all` runs `git grep` over the tree (2,749 files in ~1 s).
8. **P3 printed secrets** — reports `FILE:LINE [detector]` only.
   `scripts/test-check-secrets.sh` (in CI): 12 cases — an `sk-` key, a `+`-prefixed line, PEM alone and escaped,
   named secrets in JSON / spaced / `.dev.vars`, four look-alikes that must pass (CSS `mask-image`, code `btoa(…)`,
   an empty example, the PEM regex in source), and `--all` finding a committed key without printing it. Its synthetic
   secrets are assembled at run time. Two of my own bugs found on the way: the first rewrite lost its "found" flag in
   a pipeline subshell, and put the pattern after `--`; both caught by this test.

**Evidence after the fixes:** `tsc --noEmit` exit 0; `vitest run` **42/42** (26 + 16 in `test/hardening.test.ts`);
mutations as above; `scripts/test-check-secrets.sh` exit 0 (12/12); `scripts/check-secrets.sh --all` clean.

## Codex review 03b — response (round 2)

Review: [codex-review-03b.md](../codex-review-03b.md) — round-1 #1, #2, #4, #7, #8 resolved; #3, #5, #6 partly; six
findings. All accepted.

1. **P2 rotation waiters** — `appleKeys`: a forced refresh joins the one in flight before the cooldown applies. Test:
   the key-set response held open while three valid rotated-key sign-ins arrive → all 200 on exactly one fetch.
   Mutation: removing the join fails exactly that test.
2. **P2 concurrent deletion reporting "done"** and 3. **P2 sign-in during deletion** — deletion is now *claimed* in one
   D1 transaction (`claimDeletion`): read the current Apple tokens, `INSERT … SELECT` them into the queue, delete sessions,
   identities, the account; `won` = the account row was deleted by this request. Revocation happens after, removing each
   success from the queue. A losing deletion returns `409 deletion_in_progress`. Sign-in: `updateRefreshToken` and
   `createSession` report whether the identity / account still exist (`INSERT … WHERE EXISTS`); if not, the sign-in
   makes a new account (twice at most, then `409 try_again`). Migration 0002 reshaped (not deployed anywhere):
   `token_enc` is the key. Tests: simultaneous deletions → exactly one 200 "pending", the other 401/409 without "done";
   the deterministic loser → null; a newer token written before the claim is the one queued; after the claim the token
   update and session insert refuse and a new sign-in gets a new account.
4. **P2 the 30-day drop** — the contract now makes manual recovery part of `"pending"`: the app shows the iOS Settings
   route (TN3194) at once (README, spec, the handler's doc comment); the wrong "tokens long gone" comment is corrected
   (Apple tokens stay valid until revoked). The terminal drop remains bounded retention, now stated as such.
5. **P2 escaped CRLF PEM** — the PEM detector accepts `\r\n` as well as `\n` after the header (and whitespace before
   inline base64). Test case added (a JSON `APPLE_PRIVATE_KEY` with an escaped-CRLF key).
6. **P3 pathspec magic** — `git --literal-pathspecs grep`, and a `git grep` failure (exit > 1) now refuses (exit 2)
   instead of reporting clean. Test: a staged file named `:(glob)abc.txt` holding a key is caught; the previous scanner
   (`f1e20de`) exits 0 on the same case.

**Evidence:** `tsc` exit 0; `vitest` **46/46**; `scripts/test-check-secrets.sh` **14/14**; `--all` clean.

## Codex review 03c — response (round 3)

Review: [codex-review-03c.md](../codex-review-03c.md) — round-2 #1, #2, #4, #5, #6 resolved, #3 partly; one P2.

1. **P2 a claimed token reused by the sign-in retry** — the retry loop is gone. A sign-in stores its token (on the
   existing identity, or via create-or-find); only when the identity was already gone *before* storing may a new
   account hold the token. Once stored, a vanished account at the session insert means a deletion claimed this token
   too: the request ends `409 reauthorize` (the app starts a fresh Apple authorization). `Deps.pause` is a test-only
   seam (absent in production) awaited just before the session insert. Tests (both revoke outcomes): pause → deletion
   runs → sign-in answers 409 `reauthorize`; no account, identity or session is recreated; with Apple accepting, the
   revoked token is exactly T2; with Apple failing, T2 stays queued and no active identity holds it.

**Evidence:** `tsc` exit 0; `vitest` **48/48**; scanner tests 14/14 unchanged.

**Round 4 (codex-review-03d): clear** — the round-3 finding resolved (Codex's own interleaving probes, independent of the
test seam, and the two new tests); no new findings. The clearance covers the server implementation locally — not a
deployment, a real Apple exchange/revocation, or the app half.

## Acceptance

- [ ] Server tests green; `wrangler dev` smoke from the Simulator: sign in, rename, sign out, delete.
- [ ] Deployed Worker; sign-in and deletion work from a development build on the phone; Apple's "Apps using Apple
      ID" list no longer shows the app after deletion.
- [ ] Signed-out app behaviour unchanged (targeted UI tests); Account row captures, Default and AccessibilityL.
- [ ] No secret in the diff or history (check run and recorded).

## Verification scope

Server unit tests; app targeted unit/UI tests for the account client and Settings; captures. No full UI suite.

## Comments
