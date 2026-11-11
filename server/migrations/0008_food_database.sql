-- Nutrition N8: barcode lookups (Open Food Facts, then USDA FoodData Central branded foods) and online search by name
-- (USDA generic foods), through the server.

-- The lookup cache, shared by everyone: public product data, linked to no account. `key` is 'barcode:<GTIN>' (the
-- normalised code) or 'search:<SHA-256 of the normalised query>' — a typed search is kept only as that one-way hash.
-- `body` is the normalised answer as JSON: a food (barcode), `null` for a miss, or a list of foods (search). Hits and
-- misses both expire (`expires_at`); the hourly cron deletes expired rows.
CREATE TABLE food_cache (
  key TEXT PRIMARY KEY,
  body TEXT NOT NULL,
  created_at INTEGER NOT NULL,        -- ms since 1970
  expires_at INTEGER NOT NULL
);
CREATE INDEX food_cache_expires ON food_cache(expires_at);

-- Lookups per account and kind per New York day (a modest limit; no AI cost). Every request counts, cache hits too.
-- Deleted with the account (claimDeletion; the foreign key cascades as well); earlier days are removed by the cron.
CREATE TABLE food_limits (
  account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  day TEXT NOT NULL,                  -- YYYY-MM-DD, America/New_York
  kind TEXT NOT NULL CHECK (kind IN ('barcode', 'search')),
  count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (account_id, day, kind)
);
