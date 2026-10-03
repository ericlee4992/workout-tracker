You are the independent reviewer (AGENTS.md T6) for public-beta ticket 03, SERVER HALF ONLY (the app half waits on the
paid Apple team). Claude implemented it. Repository: /Users/ericlee06/orca/workspaces/Health App/public-beta, branch
ericlee4992/beta-03-server-apple. Diff under review: `git diff main..HEAD` (main = f6895a5).

Read first: AGENTS.md; work-record/public-beta/issues/03-server-and-apple-sign-in.md (scope and the Progress section);
work-record/public-beta/spec.md → Accounts, Server, Engineering constraints; D60 in docs/DECISIONS.md; server/README.md.

Review as a security reviewer of an authentication service whose source is PUBLIC:
1. Sign in with Apple verification (server/src/apple.ts, jwt.ts): signature, kid/JWKS handling and caching, alg
   confusion, issuer, audience, expiry/iat, nonce binding (the app sends SHA-256(rawNonce) to Apple and rawNonce here),
   subject; anything accepted that should not be. Client-secret JWT (ES256, claims, lifetime) and the code
   exchange/revocation per Apple's documented REST API; fail-closed behaviour.
2. Sessions (store.ts): token entropy, hashing, expiry/renewal, timing, sign-out; account deletion completeness and
   ordering, revocation semantics, idempotence; refresh-token encryption (AES-GCM, IV, key handling).
3. Input handling and the router (index.ts): body limits, JSON parsing, error responses, logging (no secrets/bodies),
   name cleaning, HTTP methods/paths, CORS/headers if relevant, D1 queries (injection, batches, foreign keys —
   note D1's foreign-key behaviour), concurrency (double sign-in, simultaneous deletion).
4. Secrets: wrangler.jsonc, .gitignore, .dev.vars.example, scripts/check-secrets.sh (false negatives/positives, the
   --staged diff parsing), the opt-in hook, .github/workflows/server.yml.
5. Tests (server/test/*): do they prove the claims? Missing cases? The harness's table reset, fake Apple, clock.
   You may run `cd server && npx vitest run` and `npx tsc --noEmit` (no network needed; node_modules is installed).
6. README accuracy and the deploy steps.

Rules: modify nothing except the report; no network calls to Apple or Cloudflare, no `wrangler login/deploy/secret`,
no phone, Apple account or ~/WorkoutTracker-Backups access, no desktop control (`orca computer`). Write the report to
work-record/public-beta/codex-review-03.md: numbered findings with severity (P0 … P3), file:line, the failure scenario
and a suggested fix; then a last line that is exactly "Verdict: clear" or "Verdict: not clear".
