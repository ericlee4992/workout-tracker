# Codex review — nutrition N7, round 2 (fixes for codex-review-n7)

You are the independent reviewer; Claude implemented. You are a fresh Codex session (the round-1 session ran out of
context): read AGENTS.md first, then this prompt. Checkout `/Users/ericlee06/orca/workspaces/Health App/UI_design`,
branch `ericlee4992/nutrition-07-scan-food`. Round 1's prompt is `work-record/nutrition/codex-review-n7-prompt.md`; its
report is `work-record/nutrition/codex-review-n7.md` (Verdict: not clear, 8 × P2 + 1 × P3 + the test-plan check).
Review the fixes: `git diff a6de2e5..HEAD` (round 1 reviewed `a6de2e5`), and re-check anything the fixes touch in the
whole N7 diff (`git diff 76600c2..HEAD`). Read N7's ticket and D82/D83 as in round 1.

What changed, per finding (verify each is fixed and nothing new broke):
- **T1 safety copy:** the photo is now a `FoodPhoto` row (`data: Data?`, inline — no `.externalStorage`) owned by
  `FoodEntry.photo` (`.cascade`); `photoData` accessor; thumbnail cache keyed by the entry (no photo row load once
  cached). New approved fingerprint (same user-approved N7 change, corrected). Tests: `SafetyCopyTests.
  aMealPhotoComesBackWholeFromACopy` (2,000,000 bytes through the real `make` / `scheduleRestore` /
  `performPendingRestore` into an emptied store folder) and `noAttributeIsStoredOutsideTheDatabaseFile` (the app
  model has no external-storage attribute). Is a relationship the right call vs. inline on `FoodEntry` (Today's
  `@Query` of all entries)? CloudKit: inline Data ≤ ~600 KB per photo.
- **S1:** Log food's Estimate asks to sign in when `TerraAccess.ready` is false (nothing sent, words kept); the queue
  keeps `.signedOut` (card: "Sign in, then try again." + Sign In → `AccountSignInSheet`, then the same scan is retried
  on dismiss if signed in). Tests `testASignedOutDescriptionAsksToSignInFirst`, `testAnExpiredSessionsCardOffersSignIn`.
- **S2:** a scan logged to an earlier day keeps its card ("Logged to Mon, Nov 9 · Lunch", Open → the items screen, ×).
  Test `testAPhotoFromAnEarlierDayStaysReachable` (`-uiTestFoodScanYesterday`).
- **S3:** the item editor keeps untouched numbers exactly (`EditableNumber`; `ScanItemNumbers.optional/required`);
  unit tests in `FoodScanTests`.
- **S4:** the shutter snapshots mode, box and view size (`capture`); the photo is handled as that; mode tiles and the
  library button are disabled while a capture is pending; `send` takes the mode explicitly; Barcode never sends.
- **S5:** the picked-photo import and the label read are owned tasks (`importTask`, `readTask`), cancelled on
  Cancel / Retake / close / disappear; a label reply is accepted only for its `attempt` UUID (not by bytes).
- **S6:** `BackgroundAssertion` (main actor) ends exactly once — work done, Remove (task cancel → defer), or iOS's
  expiration handler, which cancels the request and leaves a "Try again" card.
- **T2:** the queue no longer animates; Today animates on `scans.revision` with `reduceMotion ? nil : .snappy`; the
  card's transition is opacity-only under Reduce Motion; Remove has no forced animation.
- **T3:** README's Food logging gains Scan food; the privacy draft (`server/src/pages.ts`) says food scanning has no
  separate prompt (sent only on the user's shot/choice/Estimate; manual logging always available) — still a DRAFT for
  the user at R. The Log food README screenshot (`docs/readme/log-food.png`) is retaken from `LogFoodUITests/testCaptureReadme`
  (603 px wide like the others; shows the camera in the bar).
- **Test plans:** `ScanFoodUITests` added to TodayTrain; `python3 scripts/test-plans.py --check` exit 0.
- D83's "(the server's day is UTC)" corrected to New York midnight.

Claude's evidence (scratchpad
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/987d2e07-f1f0-4854-a4f2-1db12bf762c0/scratchpad/`):
`u3.xcresult` (guard/safety-copy/scan units before the fingerprint update), `u4.xcresult` (Unit plan: 1,232 definitions / 1,252
executions, 0 failed), `v2.xcresult` (ScanFood 10 + TodayFood + LogFood + LogFoodFlow, 2 workers: 27/27);
`rd.xcresult` (README capture); server `npm test` 254/254 and `tsc` clean.

Reviewer rule (round 2): build; run the Unit plan; the fixes change UI behaviour and UI tests, so rerun
`AAAWarmUpUITests`, `ScanFoodUITests`, `TodayFoodUITests`, `LogFoodUITests`, `LogFoodFlowUITests` (2 workers; rerun
failures serially before judging); server `npm test` + `npx tsc --noEmit`; `python3 scripts/test-plans.py --check`.
Run on **WT-iPhone27** `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B` (`scripts/prepare-test-simulator.sh <id>` first), paths
under `/tmp/codex-n7b/`. Show progress in the existing Orca tab "Test progress (Claude r2)"
`term_ac1339dc-202d-4c10-bab3-b528de726cbd` once it is back at its prompt — do not open a new terminal. Do not modify
files other than the report; do not commit or push; never print or copy the OpenAI key.

Write `work-record/nutrition/codex-review-n7b.md`: per round-1 finding fixed / not fixed; new findings P1/P2/P3 with
file:line, failure scenario and fix; a Verified / Not verified / Known flaky block; end with exactly `Verdict: clear` or
`Verdict: not clear`.
