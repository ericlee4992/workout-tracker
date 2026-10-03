# Ticket 03 — independent server review, round 2

Reviewed by Codex (T6), 2026-10-02. Diff: `2e97c31..f1e20de`.
Implementation tip: `f1e20de238c29c24069940e8e939e2aca6c806d5`.
Checkout: `ericlee4992/beta-03-server-apple`, HEAD `79ee5528ce91af0c5186afc3dbf3f6f73505f8ab`;
the later commit adds only this round's prompt. Server half only; app and deployment remain deferred.

## Verification

- `npx tsc --noEmit`: exit 0.
- `npx vitest run`: **42/42 passed**, exit 0. The initial sandbox attempt could not open the
  local listener/write the Wrangler log; the approved rerun passed.
- `scripts/test-check-secrets.sh`: **12/12 passed**, exit 0.
- `scripts/check-secrets.sh --all`: clean, exit 0.
- `git diff --check 2e97c31..f1e20de`: exit 0.
- Independent probes loaded unchanged source into memory with generated fixture keys and fake Apple
  responses. Store/router race probes used in-memory SQLite with foreign keys enabled and explicit barriers;
  they supplement the Workers tests, rather than establish production D1 behavior. Scanner probes used
  disposable Git repositories and generated/synthetic credentials. No live Apple/Cloudflare service calls,
  deployment, phone, backups or desktop access. Only this report was added to the checkout.

## Round-1 finding status

| # | Original finding | Status | Evidence |
|---|---|---|---|
| 1 | Code/identity mismatch | **Resolved** | The exchanged ID token is verified and its subject must match before writes. The independent A-token/B-code probe now returns 401. The fake binds single-use codes to subjects; mismatch, reuse and malformed response tests pass. The submitted ID token's nonce remains checked. |
| 2 | Unbounded body buffering/character count | **Resolved** | Bytes are counted while reading. Independent multibyte body probe returns 413; streamed probe cancels at 81,920 bytes pulled for a 65,536-byte limit with 16,384-byte chunks. Exact-limit test passes. |
| 3 | Unbounded unknown-key refreshes | **Partly resolved** | Five bogus key IDs now cause one extra fetch, but concurrent legitimate requests during rotation do not all await that fetch. See finding 1 below. |
| 4 | Concurrent initial account creation | **Resolved** | Both concurrent sign-ins succeed. The deterministic loser test exercises a real D1 uniqueness error and joins the winning account. The error regex is broader than necessary, but works with the current schema and cannot select another subject's account. Deletion interleavings remain separate findings. |
| 5 | Revocation failure loses recovery credential | **Partly resolved** | Atomic queue insertion/deletion, missing-key recovery, retry/backoff, cron wiring and ciphertext deduplication are implemented. Short-outage tests pass. Concurrent deletion and abandonment still have gaps; see findings 2–4. |
| 6 | Secret formats evade scanning | **Partly resolved** | Original escaped-LF PEM, JSON and spaced assignments are detected. Valid escaped-CRLF PEM still passes both modes; see finding 5. |
| 7 | Plus-prefixed additions evade staged scan | **Resolved** | Whole staged blobs replace diff-line parsing; the original plus-prefix probe is rejected. A separate filename/pathspec edge remains in finding 6. |
| 8 | Scanner prints secret values | **Resolved** | Output contains location and detector only; regression tests verify the synthetic token is absent from output. |

## Authentication and spec findings

1. **P2 — Await an active forced JWKS refresh before applying its cooldown.**
   **Location:** `server/src/apple.ts:53–57`.

   With a fresh cached key set, the first request for a newly rotated key starts a refresh and sets
   `lastForcedRefresh`. A second request for that same valid key hits the cooldown and immediately receives
   the old keys, rather than awaiting `inflight`; it is rejected as `invalid_token` while the first succeeds.
   **Independent probe:** paused the refresh response, verified two identically signed valid tokens using the
   new key, then released it: first **accepted**, second **invalid_token**, two total fetches including warm-up.

   **Fix:** when an unknown key requires refresh, join an existing refresh before taking the cooldown path.
   Add a test with a deferred JWKS response and concurrent valid rotated-key tokens, asserting that all succeed
   with one fetch. `hardening.test.ts:90–98` launches its concurrent requests after sequential bogus requests
   have already completed the refresh; it does not prove this behavior.

2. **P2 — Concurrent deletion can report revocation complete while it is still pending.**
   **Location:** `server/src/index.ts:109–118`.

   Two DELETE requests can authenticate before either removes the account. The first fails revocation,
   queues its credential and deletes the identity. The second then reads no identities and treats the empty
   list as successful revocation. **Independent barrier probe:** responses were
   `{deleted:true, appleRevocation:"pending"}` and `{deleted:true, appleRevocation:"done"}`, with **one pending
   row still present** and no successful revoke. A client receiving the second response suppresses the
   pending/manual recovery information.

   **Fix:** atomically claim deletion or preserve an appropriate minimal outcome so a competing request
   cannot infer successful revocation from absent identity rows. Returning an authentication/deletion-race
   response is preferable to inventing success. Assert both response bodies in the simultaneous deletion
   test; its current row-count and “some 200” assertions miss this.

3. **P2 — A sign-in during deletion can replace the credential after deletion takes its snapshot.**
   **Location:** `server/src/index.ts:109–117`; `server/src/store.ts:130–139`.

   Deletion reads encrypted token T1, then awaits Apple. Meanwhile a sign-in can store T2 and issue a session.
   When the T1 revoke fails, deletion queues only its old snapshot and removes the identity containing T2.
   **Independent probe:** overlapping sign-in returned **200**, the identity held `synthetic-refresh-new`,
   and deletion returned `pending` with only `synthetic-refresh-old` queued. The latest credential was lost.
   An older token is not a substitute the service can guarantee is still usable; no live Apple claim about
   revoking an entire grant from T1 was assumed in this probe.

   **Fix:** coordinate sign-in with deletion and atomically capture the current revocation credentials before
   deleting their identity rows. For example, claim deletion and prevent further credential/session writes,
   or atomically move current credentials to the queue before external calls. Add a deterministic
   read-T1 → write-T2 → fail-revoke-T1 regression test, including preservation of the credential needed for recovery.

4. **P2 — The 30-day drop has no actionable manual-revocation outcome.**
   **Location:** `server/src/index.ts:118,131–134`; `server/README.md:30–33`;
   `work-record/public-beta/spec.md:76–77`.

   Corrupt ciphertext, or an encryption key unavailable for the whole retry window, yields `pending` and
   later loses its last credential at 30 days. The only terminal signal is an aggregate log. The account,
   sessions and linkage are already gone; there is no status endpoint or notification path to tell that
   person to revoke manually. README/spec reserve manual instructions for the initial “no token was kept”
   case. The tampered-ciphertext test confirms abandonment without checking an actionable recovery outcome.

   Bounded retention is reasonable, but the comment that Apple refresh tokens are “long gone” after 30 days
   is incorrect: Apple documents their continued use until invalidation, not a 30-day expiration.
   See [Verifying a user](https://developer.apple.com/documentation/signinwithapple/verifying-a-user).

   **Fix:** make manual recovery part of the initial `pending` contract and instruct the future app to show
   it then, or supply a privacy-conscious way to surface terminal failure before disposal. Correct the
   expiration comment and test missing-key/corruption through abandonment with the promised client-facing
   fallback. This finding concerns the server contract; it does not require implementing the deferred app now.

## Standards findings — public repository secret protection

5. **P2 — Valid private keys serialized with escaped CRLF still bypass both scans.**
   **Location:** `scripts/check-secrets.sh:10`.

   The PEM detector recognizes escaped `\n` immediately after the header, but not escaped `\r\n`.
   The named-secret detector does not compensate because the PEM header contains spaces.
   **Independent probe:** generated a disposable P-256 PKCS#8 key, converted the PEM to CRLF, confirmed that
   `createPrivateKey` accepts it, then JSON-serialized it under `APPLE_PRIVATE_KEY`. Both `--staged` and
   `--all` returned **0, clean**. This is an ordinary representation of the very credential the guard is
   supposed to protect, rather than an arbitrarily obfuscated secret.

   **Fix:** recognize escaped CRLF and the accepted PEM whitespace forms. Add generated-key fixtures for
   both line-ending forms and both scan modes while preserving the intentional code/regex false-positive tests.

6. **P3 — Treat staged filenames as literal paths.**
   **Location:** `scripts/check-secrets.sh:35–36`.

   The filenames from `git diff --name-only` are passed back as Git pathspecs. `--` stops option parsing
   but does not disable pathspec magic. **Independent probe:** a staged file literally named
   `:(glob)abc.txt`, containing a synthetic OpenAI-shaped key, passed `--staged` (**0**) while `--all`
   rejected it (**1**). The pre-commit guard silently skips that staged blob.

   **Fix:** use `git --literal-pathspecs grep` or explicitly literal pathspecs. Add an unusual-filename
   regression and make unexpected Git scan failures fail closed rather than report clean.

## Other checks and limits

Migration 0002, the reset order and D1 batch ordering are compatible with foreign-key enforcement. The queue
keeps encrypted credentials and scheduling metadata without an account link; those credentials remain sensitive
retained data despite the migration comment saying “no personal data.” Hashing the stored ciphertext deduplicates
the same captured token across simultaneous deletions. No missing production cron call was found:
`wrangler.jsonc` schedules the exported handler, which puts `runPendingRevocations` into `waitUntil`.
The tests invoke the retry function directly; they do not invoke the production scheduled entry point.

Apple calls now receive a five-second abort signal. The fake throws immediately for simulated outages and
does not exercise an actual delayed abort, so the suite establishes failure recovery rather than elapsed-time
behavior. The README and spec describe the queue and bounded retention, but need the fallback clarification
above. No deployment or real provider interaction was attempted.

Summary: five round-1 findings resolved, three partly resolved. Authentication/spec: four P2 findings;
public-repository standards: one P2 and one P3.

Verdict: not clear
