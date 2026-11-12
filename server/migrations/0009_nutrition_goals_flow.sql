-- Nutrition N14 (D85): the goal setup's AI plan (nutrition-goals) joins ai_usage's allowed flows. SQLite cannot alter
-- a CHECK constraint, so the table is rebuilt with every row kept (same columns, same key, same cascade), as in 0007.
CREATE TABLE ai_usage_new (
  account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  day TEXT NOT NULL,                  -- YYYY-MM-DD, America/New_York
  flow TEXT NOT NULL CHECK (flow IN ('scan-machine', 'routine-week', 'model-exercises',
                                     'food-photo', 'food-label', 'food-describe', 'nutrition-goals')),
  successes INTEGER NOT NULL DEFAULT 0,
  attempts INTEGER NOT NULL DEFAULT 0,
  in_flight INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (account_id, day, flow)
);
INSERT INTO ai_usage_new (account_id, day, flow, successes, attempts, in_flight)
  SELECT account_id, day, flow, successes, attempts, in_flight FROM ai_usage;
DROP TABLE ai_usage;
ALTER TABLE ai_usage_new RENAME TO ai_usage;
