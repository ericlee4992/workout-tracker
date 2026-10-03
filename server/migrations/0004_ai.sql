-- Public beta ticket 06: AI through the server. Every row names its account and is deleted with it (claimDeletion
-- deletes them in the deletion transaction; the foreign keys cascade as well). Nothing here holds a prompt, a photo,
-- an input or a reply.

-- Today's use per account and flow (New York day). `successes` count against the limit (60 / 10 / 60); `attempts`
-- are capped at twice it; `in_flight` holds a slot while a request is with OpenAI, so concurrent requests cannot pass
-- the limit together. A request that dies mid-way leaves its slot until the day ends.
CREATE TABLE ai_usage (
  account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  day TEXT NOT NULL,                  -- YYYY-MM-DD, America/New_York
  flow TEXT NOT NULL CHECK (flow IN ('scan-machine', 'routine-week', 'model-exercises')),
  successes INTEGER NOT NULL DEFAULT 0,
  attempts INTEGER NOT NULL DEFAULT 0,
  in_flight INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (account_id, day, flow)
);

-- One row per proxied request, counts only (spec: account, flow, time, status, latency, OpenAI's token counts).
-- Kept 90 days (hourly cron).
CREATE TABLE ai_requests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  flow TEXT NOT NULL,
  created_at INTEGER NOT NULL,        -- ms since 1970
  status TEXT NOT NULL,               -- ok | refused | invalid | upstream_<http status> | timeout | network
  latency_ms INTEGER NOT NULL,
  input_tokens INTEGER,
  output_tokens INTEGER,
  reasoning_tokens INTEGER
);
CREATE INDEX ai_requests_account ON ai_requests(account_id);
CREATE INDEX ai_requests_created ON ai_requests(created_at);

-- The off switch (spec): a global row ('paused' = '1') and per-account rows, read on every request, so a change made
-- with `node scripts/ai.mjs pause …` applies to the next request without an app build or a deploy.
CREATE TABLE ai_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
CREATE TABLE ai_account_pauses (
  account_id TEXT PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
  created_at INTEGER NOT NULL
);
