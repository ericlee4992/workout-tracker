-- Public beta ticket 03 (codex-review-03 #5, 03b #2–#4): account deletion first moves every current Apple refresh
-- token here and deletes every account row in ONE transaction (so a concurrent sign-in or a second deletion cannot slip
-- a token past it), then revokes them; one that cannot be revoked now (Apple down, a timeout, the key unavailable)
-- stays and the hourly scheduled handler retries it with backoff for up to 30 days. A row is a sensitive retained
-- credential (encrypted, linked to no account), kept only for revocation.
CREATE TABLE pending_revocations (
  token_enc TEXT PRIMARY KEY,         -- the refresh token, AES-GCM encrypted as it was stored; unique per token
  created_at INTEGER NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  next_attempt_at INTEGER NOT NULL
);
CREATE INDEX pending_revocations_due ON pending_revocations(next_attempt_at);
