# 03 — Server foundation and Sign in with Apple

Type: task
Status: ready-for-agent (after 01)
Blocked by: 01 (the paid team is required for the Sign in with Apple capability)
Implementer: Codex (default); Reviewer: Claude — or the reverse, recorded here at the start.
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

## Acceptance

- [ ] Server tests green; `wrangler dev` smoke from the Simulator: sign in, rename, sign out, delete.
- [ ] Deployed Worker; sign-in and deletion work from a development build on the phone; Apple's "Apps using Apple
      ID" list no longer shows the app after deletion.
- [ ] Signed-out app behaviour unchanged (targeted UI tests); Account row captures, Default and AccessibilityL.
- [ ] No secret in the diff or history (check run and recorded).

## Verification scope

Server unit tests; app targeted unit/UI tests for the account client and Settings; captures. No full UI suite.

## Comments
