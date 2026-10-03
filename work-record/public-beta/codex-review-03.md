# Ticket 03 — independent server security review

Reviewed 2026-10-02 by Codex (T6; Claude implemented). Scope: **server half only**,
`git diff main..HEAD`, `f6895a5948977cdfbf987b6b4885bc728f2081b7` →
`2e97c319cbe0a2ce30535ec6561d0bd0fcddcd61`, branch `ericlee4992/beta-03-server-apple`.
Read AGENTS, STATE, ticket 03 including Progress, the public-beta spec, D60 and server README.
The deferred app, paid team, deployment and phone acceptance are outside this clearance.

## Verification

- `cd server && npx tsc --noEmit`: exit 0.
- `cd server && npx vitest run`: **26/26 passed**, exit 0. Initial sandbox run could not write the
  Wrangler log or listen on loopback; the approved rerun succeeded.
- `scripts/check-secrets.sh --all`: exit 0. `git diff --check main..HEAD`: exit 0.
- Additional probes loaded the unchanged TypeScript in memory, used generated fixture keys, fake Apple
  responses and in-memory SQLite with foreign keys enabled. These establish the specific application
  defects below; they do not substitute for Workers/D1 regression tests. Scanner probes used synthetic
  strings in isolated temporary Git repositories. No live Apple/Cloudflare service requests, deployment,
  account operations, phone, backups or desktop access. Public documentation was checked through indexed
  search results. Only this report was added to the checkout.

## Authentication, availability and spec findings

1. **P1 — Bind the authorization code's identity to the account being signed in.**
   **Location:** `server/src/apple.ts:96–98`; `server/src/index.ts:55–64`.

   The exchange discards Apple's returned `id_token` and accepts any string `refresh_token`. The router
   associates that credential with the independently submitted identity token's subject. A valid ID token
   and raw nonce for A plus a valid code for B therefore creates a session for A while storing B's refresh
   token. Deleting A then revokes B's credential. Someone who captures A's ID token and nonce can use their
   own fresh codes to replay A's identity during its validity window, even after A's original code is consumed.
   This requires possession of A's token/nonce; it is not a signature forgery.

   **Evidence:** the local probe supplied a signed A token and returned a signed B token from the exchange:
   HTTP **200**, stored subject `user-A`, decrypted refresh credential `synthetic-refresh-B`, session issued.
   The existing fake always returns `id_token: "x"` and accepts arbitrary reused codes
   (`server/test/helpers.ts:54–58`), so the green tests conceal the missing binding.

   **Fix:** verify the exchanged ID token and bind its subject, audience and nonce to the expected identity
   before any database mutation; alternatively make the verified exchanged identity authoritative and reject
   any mismatch. Require a nonempty refresh credential. Add cross-user, cross-nonce, malformed response and
   consumed-code cases with a fake that associates each single-use code with its actual identity.
   Apple's [token validation API](https://developer.apple.com/documentation/signinwithapplerestapi/generate-and-validate-tokens)
   returns the identity token with the refresh token and defines codes as single-use.

2. **P2 — Enforce the body limit while reading bytes.**
   **Location:** `server/src/index.ts:23–26`.

   Without Content-Length, `request.text()` buffers the entire body before checking the limit. An unauthenticated
   chunked request can exhaust Worker memory before a 413 is returned. The subsequent check also measures
   UTF-16 string length rather than bytes. **Evidence:** a 655,360-byte stream was fully consumed before 413;
   a valid JSON sign-in padded with multibyte text, **90,735 bytes**, returned **200** despite the 65,536-byte limit.

   **Fix:** count bytes from the request stream and cancel as soon as the limit is exceeded, then decode and
   parse. Treat Content-Length as an early rejection optimization. Add streamed, multibyte and exact-boundary
   tests; the current ASCII oversize test only proves rejection after buffering.

3. **P2 — Bound forced JWKS refreshes triggered by unverified key IDs.**
   **Location:** `server/src/apple.ts:29–35,51–55`.

   Every unknown `kid` bypasses the hour cache and triggers another Apple request before signature validation.
   A public caller needs only a syntactically valid JWT with a bogus key ID and signature to generate outbound
   fetches and hold sign-in requests open. Concurrent misses also have no shared in-flight fetch. The comment
   claiming one fetch per isolate per hour does not describe this path.

   **Evidence:** after warming the cache, five unknown-key requests caused **five additional JWKS fetches** at
   the same clock time. **Fix:** coalesce concurrent fetches and impose a bounded global refresh cooldown for
   unknown IDs while retaining a rotation recovery path. Bound fetch duration and test rotation, repeated and
   distinct unknown IDs, concurrent misses, expiry and upstream failure. The existing unknown-ID test checks
   rejection only, not fetch count.

4. **P2 — Recover the account-creation race after exchanging a single-use code.**
   **Location:** `server/src/index.ts:57–66`; `server/src/store.ts:28–32`.

   Two first sign-ins for the same subject can exchange distinct valid codes and both find no account.
   One account/identity batch wins; the other hits the identity primary key and returns 500. Its code has
   already been consumed, so retrying the request fails again. The transaction correctly prevents an orphan
   account, but it does not implement the ticket's “create or find” behavior under concurrency.

   **Evidence:** a barrier around the two absent lookups produced **200 / 500**, with one account, identity
   and session; retrying the losing code returned **502**. This probe used real store/router code with a
   fake identity verifier, single-use code exchange and serialized SQLite batches.

   **Fix:** on the specific identity uniqueness conflict, resolve the winning account, safely retain the
   newly obtained revocation credential and issue its session. Coordinate with deletion so that recovery
   cannot revive an account being deleted. Add a deterministic concurrent first-sign-in regression test.

5. **P2 — A failed revocation permanently loses the means to finish deletion's Apple step.**
   **Location:** `server/src/index.ts:108–111`; `server/src/store.ts:85–93`.

   An Apple outage or rejection produces `appleRevoked:false`, then deletes the only stored refresh
   credential and all sessions. Missing/wrong encryption keys similarly skip revocation and destroy the
   ciphertext. A retry returns 401, even after the transient failure is fixed. The Progress section explicitly
   describes this best-effort choice, but D60/spec and README promise deletion with Apple revocation.
   Reporting failure is useful; it does not provide a recovery mechanism.

   **Fix:** define a recoverable deletion flow: invalidate local sessions promptly, bound the revocation
   attempt, and retain the minimum encrypted revocation work until it succeeds before declaring that step
   complete. Specify how this interacts with the requirement to remove account data. When credentials are
   irrecoverable, honor data deletion and explicitly require the manual revocation recovery described by
   [Apple TN3194](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple).
   Document that fallback in the server/app contract rather than relying on a bare boolean. Add outage→retry,
   decryption failure and concurrent deletion tests. The current test establishes permanent loss as success.

## Standards findings — secrets in a public repository

6. **P1 — Common stored-secret formats bypass both scans.**
   **Location:** `scripts/check-secrets.sh:10,16`.

   The PEM detector requires the header to end the physical line, missing a key represented as a quoted
   string with escaped newlines. The named-secret detector requires an immediately adjacent `=`, missing
   JSON keys and spaced assignments. Synthetic fixtures for an escaped PEM string, a JSON `TOKEN_ENC_KEY`
   property, and `TOKEN_ENC_KEY = <value>` each returned **exit 0 in both modes**. This defeats the public-repo
   protection required by the spec; CI does not compensate because it uses the same detector.

   **Fix:** recognize multiline and escaped private-key material, quoted assignment names, optional
   whitespace and `:`/`=` separators. Add regression fixtures and narrowly handle deliberately generated
   test-key scaffolding without excluding test directories or allowing real credentials.

7. **P2 — The staged diff filter drops added lines beginning with a plus sign.**
   **Location:** `scripts/check-secrets.sh:21`.

   `grep -E '^\+[^+]'` treats every added source line starting with `+` as metadata. A string concatenation
   containing a key can therefore bypass the opt-in pre-commit check. A staged line consisting of a leading
   plus and a quoted synthetic OpenAI-shaped key passed `--staged` (**0**) while `--all` rejected it (**1**).
   In this no-PR workflow CI runs on main after publication, and feature-branch pushes are not scanned by
   this workflow, so the local guard matters.

   **Fix:** inspect staged blobs of changed files, or parse unified-diff headers and hunks correctly before
   extracting additions. Test plus-prefixed content and accurate original filename/line reporting.

8. **P3 — Secret detection prints the credential into logs.**
   **Location:** `scripts/check-secrets.sh:27–28`; `.github/workflows/server.yml:16`.

   Truncating matches to 160 characters still prints complete ordinary API keys. The synthetic 35-character
   key appeared intact in stderr in both scan modes. A CI failure therefore republishes the credential in
   public job logs, creating another copy to remove during incident recovery.

   **Fix:** report only filename, original line number and detector type; redact the matched value. Assert
   that scanner output never includes the synthetic secret, including on failure.

## Remaining review observations

The inspected RS256 verification pins its algorithm and trusted key source; no algorithm-confusion or signature
bypass was found. Issuer, audience, nonce hash and nonempty subject checks are present. Expiry has the documented
60-second leeway. `iat` is only checked when numeric; malformed/missing time claims and boundary behavior are not
covered. The ES256 client secret uses P-256/SHA-256, JOSE signature bytes, the expected claim values and a five-minute
lifetime; the suite verifies its signature but not its time claims. Code exchange and revocation use form-encoded
POST requests, with the correct native-client parameters and refresh-token hint.

Production sessions use 32 CSPRNG bytes, SHA-256 storage and expiry/renewal checks; sign-out deletes the selected
session. There is no character-by-character plaintext-token comparison to exploit. AES-GCM uses a random 96-bit IV,
a validated 256-bit key and an authentication tag. Add tampering/wrong-key tests when repairing deletion recovery.

D1 queries bind untrusted values. Account creation and deletion use atomic batches, and the schema has cascading
foreign keys. D1 [enforces foreign keys by default](https://developers.cloudflare.com/d1/sql-api/foreign-keys/);
the harness correctly resets children before parents. Repeated deletion leaves state unchanged, although a dead
session gets 401. The suite does not exercise simultaneous deletion or deletion racing with sign-in.

The router uses exact method/path matches, bounded name length and control-character filtering, JSON errors and
`no-store` on API replies. Its explicit error log omits bodies, tokens and exception messages. No cookie session
or browser client is introduced, so absence of permissive CORS is appropriate. Checked-in config/example values
are placeholders; ignore rules cover the stated `.dev.vars` and PEM/P8 files. No additional deploy-step defect was
established; the README's unconditional revocation and scanner claims need qualification after the fixes above.
No live deploy, real Apple exchange/revocation or history-wide secret audit was performed.

Summary: authentication/spec — 5 findings (highest P1); public-repository standards — 3 findings (highest P1).

Verdict: not clear
