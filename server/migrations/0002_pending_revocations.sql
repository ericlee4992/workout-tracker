-- Public beta ticket 03 (codex-review-03 #5): account deletion removes every account row at once; an Apple refresh
-- token whose revocation failed (Apple down, a timeout, the key unavailable) is kept here — encrypted, linked to no
-- account, holding no personal data — and retried by the hourly scheduled handler until Apple accepts it or 30 days
-- pass (then the user's documented fallback is Apple's own "Stop using Sign in with Apple", TN3194).
CREATE TABLE pending_revocations (
  token_hash TEXT PRIMARY KEY,        -- SHA-256 of the ciphertext: makes a repeated deletion idempotent
  token_enc TEXT NOT NULL,            -- the refresh token, AES-GCM encrypted as it was stored
  created_at INTEGER NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  next_attempt_at INTEGER NOT NULL
);
CREATE INDEX pending_revocations_due ON pending_revocations(next_attempt_at);
