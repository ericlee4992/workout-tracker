-- Public beta ticket 07: in-app feedback. The text and the details the form showed are rows here; a screenshot is an
-- R2 object (binding FEEDBACK) named by `screenshot_key`. A signed-in submission keeps its account and is deleted with
-- it (claimDeletion deletes these rows in the deletion transaction, then the R2 objects; the hourly cron sweeps any
-- object left without a row). Signed-out rows have no account and no IP: the rate limit's counters live apart.
CREATE TABLE feedback (
  id TEXT PRIMARY KEY,                -- random UUID
  account_id TEXT REFERENCES accounts(id) ON DELETE CASCADE,   -- NULL when sent signed out
  category TEXT NOT NULL CHECK (category IN ('bug', 'idea', 'other')),
  message TEXT NOT NULL,              -- 1–4,000 characters, as typed (trimmed)
  app_version TEXT NOT NULL,          -- CFBundleShortVersionString
  build TEXT NOT NULL,                -- CFBundleVersion
  system_version TEXT NOT NULL,       -- iOS version
  model TEXT NOT NULL,                -- hardware identifier, e.g. iPhone16,2
  screenshot_key TEXT,                -- R2 key, NULL without a screenshot
  screenshot_type TEXT,               -- image/jpeg or image/png (from the file's own bytes)
  screenshot_bytes INTEGER,
  created_at INTEGER NOT NULL         -- ms since 1970
);
CREATE INDEX feedback_account ON feedback(account_id);
CREATE INDEX feedback_created ON feedback(created_at);
CREATE INDEX feedback_screenshot ON feedback(screenshot_key);

-- Submissions per New York day: 'ip:<keyed hash of the address and the day>' (signed out; the hash changes daily and
-- cannot be reversed without the server's key) or 'account:<id>' (signed in; deleted with the account). Rows from
-- earlier days are removed by the hourly cron.
CREATE TABLE feedback_limits (
  key TEXT PRIMARY KEY,
  day TEXT NOT NULL,                  -- YYYY-MM-DD in America/New_York
  count INTEGER NOT NULL
);
