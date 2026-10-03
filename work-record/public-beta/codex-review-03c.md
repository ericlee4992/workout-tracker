# Ticket 03 — independent server review, round 3

Reviewed by Codex (T6), 2026-10-02. Branch: `ericlee4992/beta-03-server-apple`.
Diff: `79ee552..HEAD`; implementation commit `378b6a9`, HEAD
`0be6a421cab7f19128803a1ccada2f7a6c6809fa` (the later commit adds only the round-three prompt).
Scope remains the server half. Read the prompt, ticket's round-two response, changed source/tests,
README/spec and migration, and checked the changes against the previous report.

## Verification

- `cd server && npx tsc --noEmit`: exit 0.
- `cd server && npx vitest run`: **46/46 passed**, exit 0; local Workers runtime and fake Apple.
- `scripts/test-check-secrets.sh`: **14/14 passed**, exit 0.
- `scripts/check-secrets.sh --all`: clean, exit 0.
- `git diff --check 79ee552..HEAD`: exit 0.
- Repeated the deferred-JWKS, generated CRLF private-key and literal-pathspec probes. Added a
  deterministic probe for the new sign-in retry/deletion interleaving described below. Probes loaded
  unchanged source in memory; database probes used SQLite with foreign keys and transaction batches,
  with fake provider operations and explicit scheduling barriers. They supplement the actual Workers
  suite. Scanner fixtures used isolated temporary Git repositories.

No Apple/Cloudflare network requests, deployment, account/phone/backup access or desktop control.
Only this report was added to the checkout.

## Round-2 finding status

| # | Finding | Status | Evidence |
|---|---|---|---|
| 1 | Rotation waiters receive stale keys | **Resolved** | Forced refresh now joins `inflight` before applying the cooldown. Independent deferred-response probe: both valid rotated-key tokens accepted, second request waited, one refresh beyond warm-up. The new Workers test also passes. |
| 2 | Concurrent deletion falsely reports `done` | **Resolved** | `claimDeletion` reads/queues credentials and deletes rows in one batch. Its account-delete result identifies the winner; a loser returns null and the router returns 409, or authentication already returns 401. The strengthened concurrent test checks both response bodies; the deterministic loser test passes. |
| 3 | Deletion loses a newer credential written after its snapshot | **Partly resolved** | The atomic `INSERT … SELECT` captures the current credential and removes the old read/network/delete gap. However, the new sign-in retry can reinstall the captured credential into a fresh account after deletion; see finding 1 below. |
| 4 | Abandonment lacks manual recovery | **Resolved for the server half** | README, spec and handler contract now require the app to show the manual route immediately for `pending`, as well as `manual`. The 30-day drop is correctly described as bounded retention, with no claim that Apple tokens expire then. Implementing the app message remains deferred with the app half. |
| 5 | Escaped CRLF PEM bypasses the scanner | **Resolved** | A generated, parseable P-256 PKCS#8 key serialized as CRLF JSON is rejected with exit 1 in both modes. Regression coverage includes CRLF and retains the intentional false-positive cases. |
| 6 | Staged filenames interpreted as pathspecs | **Resolved** | The original `:(glob)abc.txt` fixture is rejected with exit 1 in both modes. `--literal-pathspecs` preserves the actual filename; staged scanning still reads index contents. Unexpected `git grep` failures now exit 2 rather than claim clean. |

## Authentication/spec finding

1. **P2 — Do not retry an interrupted sign-in with a refresh token already claimed for revocation.**
   **Location:** `server/src/index.ts:82–94`, especially the retry loop at lines 85–93.

   The code exchange happens once, outside the retry loop. A valid interleaving is:

   1. Sign-in obtains T2 and updates the existing identity to store it.
   2. Before `createSession` executes, deletion atomically queues T2 and deletes that account.
   3. Deletion revokes T2 successfully and returns `appleRevocation: "done"`.
   4. The interrupted session insert returns null. The sign-in loop creates a new account with the
      **same T2**, then returns 200 with a new local session.

   **Independent reproduction:** paused the actual router/store flow immediately before its first
   session insert, completed deletion with a successful fake revoke, then resumed it. Observed:

   - Deletion: `{deleted:true, appleRevocation:"done"}`.
   - Sign-in: **200**, a different account ID, and the stored refresh token was exactly the token
     already recorded as revoked.
   - `GET /v1/profile` with the new session: **200**; one account and one session remained.

   The outage variant also reproduces: the resumed sign-in returns 200 with T2 in its active identity
   while that same plaintext T2 remains in the pending queue. A later successful cron run revokes it
   without removing the active local account/session. This does not depend on whether revoking an
   older Apple token invalidates an entire grant: both operations use the exact same credential.

   The account is therefore recreated without a fresh authorization after its credential was claimed
   for deletion, contradicting the sign-in retry's claim that deletion remains complete. The test at
   `server/test/hardening.test.ts:239–250` starts a fresh sign-in/code after the claim and does not
   continue the already-exchanged request through this retry.

   **Suggested fix:** when deletion wins after this sign-in has stored its credential, stop that
   request with a retryable response requiring fresh Apple authorization; do not reuse the consumed
   exchange result to create another account. Alternatively, coordinate credential storage, session
   insertion and deletion so the same credential cannot become both active and claimed for revocation.
   Preserve recovery for two initial sign-ins racing to create the same account. Add deterministic tests
   pausing between the credential update and session insert, for both successful and pending revocation.

## Standards and remaining checks

No new substantive standards findings in the scanner changes. The queue now correctly identifies its
contents as sensitive retained credentials. Its ciphertext primary key, immediate-attempt cleanup,
cron cleanup and retry updates use the same column consistently. Reshaping migration 0002 is consistent
with the ticket's statement that this schema has not been deployed; an already-migrated database would
require an additional migration. The existing cron wiring is unchanged and remains connected to the
retry function. No further concrete regression was established in the reviewed changes.

Summary: five round-two findings resolved; one partly resolved. One remaining P2 authentication/spec
finding; no new standards findings. All requested checks pass, but they miss the interleaving above.

Verdict: not clear
