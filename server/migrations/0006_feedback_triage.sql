-- Public beta ticket 15: whether the developer has handled each feedback, set only by scripts/feedback.mjs. Kept on the
-- feedback row itself, not in a second copy, so every path that deletes feedback (account deletion, the one-year sweep,
-- `feedback.mjs delete`) deletes its status and note too — the privacy policy's deletion promises depend on that.
-- Additive: existing rows read 'new'; the Worker never reads or writes these columns.
ALTER TABLE feedback ADD COLUMN triage TEXT NOT NULL DEFAULT 'new' CHECK (triage IN ('new', 'done', 'wontfix'));
ALTER TABLE feedback ADD COLUMN triage_note TEXT;      -- the developer's own one-line note (≤ 200), never personal details
ALTER TABLE feedback ADD COLUMN triaged_at INTEGER;    -- ms since 1970; NULL while 'new'
CREATE INDEX feedback_triage ON feedback(triage, created_at);
