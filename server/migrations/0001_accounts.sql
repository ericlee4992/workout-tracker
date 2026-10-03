-- Public beta ticket 03: accounts, sign-in identities and sessions. Deleting an account deletes its rows everywhere
-- (foreign keys with ON DELETE CASCADE; D1 enforces foreign keys).
CREATE TABLE accounts (
  id TEXT PRIMARY KEY,                -- random UUID
  display_name TEXT,                  -- first-sign-in name from Apple/Google, editable
  email TEXT,                         -- as given by the provider (may be an Apple relay address)
  created_at INTEGER NOT NULL         -- ms since 1970
);

CREATE TABLE identities (
  provider TEXT NOT NULL,             -- 'apple' (ticket 04 adds 'google')
  subject TEXT NOT NULL,              -- the provider's stable user ID (the token's `sub`)
  account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  refresh_token_enc TEXT,             -- Apple's refresh token, AES-GCM encrypted; kept only to revoke on deletion
  created_at INTEGER NOT NULL,
  PRIMARY KEY (provider, subject)
);
CREATE INDEX identities_account ON identities(account_id);

CREATE TABLE sessions (
  token_hash TEXT PRIMARY KEY,        -- SHA-256 of the bearer token; the token itself is never stored
  account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,        -- 90 days, renewed by use
  last_used_at INTEGER NOT NULL
);
CREATE INDEX sessions_account ON sessions(account_id);
