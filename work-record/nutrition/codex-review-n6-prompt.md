# Codex review — nutrition N6 (server: food AI flows, GPT-6.1 Terra)

You are the independent reviewer; Claude implemented. **This ticket lives in a different checkout:**
`/Users/ericlee06/orca/workspaces/Health App/nutrition-06-server`, branch `ericlee4992/nutrition-06-server` (on `main`
`46c9e92`). Review `git -C "<that path>" diff 46c9e92..HEAD`. Work and write only there.

Read first: that checkout's `work-record/nutrition/issues/06-server-food-ai.md` (scope; Progress: model id + source,
flows, checks, migration, privacy draft, tests, what is left for the user), decisions D60 (server AI), D72–D75 (food
AI, limits), D78 (no "estimated" flag), D79 (the model), `server/README.md`, and the public-beta ticket 06 and 10
records for the proxy's established rules (`work-record/public-beta/issues/06-*.md`, `10-model-sol.md`).

Check in particular:
1. **Flows** (`server/src/ai.ts`): input validation (JPEG reuse, the note and description bounds and line rules, JSON
   data not instructions), instructions (label: numbers only as printed; estimates for photo/describe), strict JSON
   schemas (nullable number type for strict mode — valid for OpenAI's structured outputs?), reply checks and their
   bounds, effort and output caps, body limits, `isFlow`/`FLOWS`, usage listing.
2. **Migration `0007_food_flows.sql`:** the table rebuild keeps every row, key, default and the cascade; safe on D1
   (foreign keys, concurrent requests during apply); old code against the new table and new code against the old one
   during a deploy window.
3. **Model switch:** `gpt-6.1-terra` for the existing flows too (D79) — anything in the request body the new model
   may reject (reasoning effort values, `max_output_tokens`, image `detail`)? Note: no live key is available tonight,
   so no real request was made; say what must be checked live before deploy.
4. **Privacy draft** (`server/src/pages.ts`): accurate to what is built (food on the phone, food AI, camera); the
   Apple Health sentence describes N9 (not built yet) — acceptable as a draft for the release, or should it wait?;
   the "[effective date]" placeholder keeps `npm run deploy` refusing.
5. **Tests** `server/test/food-ai.test.ts` and the usage change.

Run (the server only; no Xcode work in this ticket): `cd server && npm ci` if needed, `npx tsc --noEmit`,
`npx vitest run`, `npm run test:scripts`, `bash ../scripts/check-secrets.sh`. Claude runs nothing while you run. Do
not modify files other than the report; do not commit or push; do not deploy.

Write `work-record/nutrition/codex-review-n6.md` in that checkout: findings P1/P2/P3 with file:line, failure scenario
and fix; a Verified / Not verified block; end with exactly `Verdict: clear` or `Verdict: not clear`.
