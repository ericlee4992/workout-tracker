# Ticket 03 — independent server review, round 4

Reviewed by Codex (T6), 2026-10-02. Branch: `ericlee4992/beta-03-server-apple`.
Diff: `0be6a42..HEAD`; implementation commit `522e7c3b082b034177328bae9224abe8ae9b24c6`;
HEAD `403c7b46e6abda664a7eb87d895cd178673cc163` adds the review prompt afterward.
Scope: server half only, following `codex-review-03d-prompt.md` and the ticket's round-three response.

## Round-3 finding

1. **Resolved — P2: sign-in retry reused a token already claimed for revocation.**
   `server/src/index.ts:85–96` now stores the credential and attempts session creation once. If deletion
   removed the account in between, the response is `409 {"error":"reauthorize"}`. The request no longer
   creates another account from the same exchange result.

   Repeated the independent interleaving probe with unchanged router/store/crypto source loaded in memory,
   SQLite foreign keys and atomic batches, fake provider operations, and a database barrier immediately
   before session insertion. The probe did not use the newly added `Deps.pause` seam.

   | Revocation result | Deletion response | Interrupted sign-in | Remaining state |
   |---|---|---|---|
   | Success | `deleted:true`, `appleRevocation:"done"` | 409 `reauthorize` | Zero accounts, identities and sessions; queue empty; revoked token is exactly T2 |
   | Failure | `deleted:true`, `appleRevocation:"pending"` | 409 `reauthorize` | Zero accounts, identities and sessions; exactly T2 retained encrypted in the queue |

   The two new Workers/D1 tests independently cover the same outcomes through the actual handler.
   README correctly requires fresh Apple authorization for this response.

## Regression and standards review

- Initial-sign-in conflict recovery remains intact. `createOrFindAccount` still joins the winning account
  after the identity uniqueness conflict; successful credential storage leads to the single session check.
  Both concurrent first-sign-in and deterministic conflict tests pass.
- `claimDeletion` is unchanged: current credentials are queued and account rows deleted in one transaction;
  its winner result prevents a second deletion from reporting a fabricated success. The strengthened
  concurrent-deletion and deterministic loser tests pass.
- `Deps.pause` is optional, absent from `liveDeps`, and supplied only by injected test dependencies.
  Request input cannot activate it. The new tests use it to place deletion after credential storage,
  and assert the exact token disposition and absence of recreated rows.
- No new authentication/spec or standards findings were established in this diff. The prior rounds'
  resolved findings remain closed; the remaining round-three finding is now resolved.

## Verification

- `cd server && npx tsc --noEmit`: exit 0.
- `cd server && npx vitest run`: **48/48 passed**, exit 0, in the local Workers runtime with fake Apple.
- Independent successful/failed-revocation interleaving probes: both passed, process exit 0.
- `scripts/check-secrets.sh --all`: clean, exit 0.
- `git diff --check 0be6a42..HEAD`: exit 0.

No Apple/Cloudflare network calls, deployment, account/phone/backup access or desktop control. Only this
report was added to the checkout. This clears the reviewed server implementation locally; it does not
establish deployment, real Apple exchange/revocation, or the deferred app-half acceptance criteria.

Verdict: clear
