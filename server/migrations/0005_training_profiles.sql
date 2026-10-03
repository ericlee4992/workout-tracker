-- Public beta ticket 05: the saved training profile (spec → Profile page; amends D58) — the inputs Ask AI for Templates
-- asks for. Height and weight keep the value and unit entered (D52): never converted here. One row per account,
-- deleted with it (claimDeletion's transaction; the foreign key cascades too).
CREATE TABLE training_profiles (
  account_id TEXT PRIMARY KEY REFERENCES accounts(id) ON DELETE CASCADE,
  goals TEXT NOT NULL,                -- 1–1,000 characters, as typed (trimmed)
  experience TEXT NOT NULL CHECK (experience IN ('Beginner', 'Intermediate', 'Experienced')),
  days INTEGER NOT NULL CHECK (days BETWEEN 1 AND 7),
  minutes INTEGER NOT NULL CHECK (minutes BETWEEN 15 AND 120),
  height_value REAL,                  -- as entered; NULL when not given
  height_unit TEXT CHECK (height_unit IN ('cm', 'in')),   -- feet + inches are stored as total inches
  weight_value REAL,
  weight_unit TEXT CHECK (weight_unit IN ('kg', 'lb')),
  updated_at INTEGER NOT NULL,        -- ms since 1970
  CHECK ((height_value IS NULL) = (height_unit IS NULL)),
  CHECK ((weight_value IS NULL) = (weight_unit IS NULL))
);
