# Codex review — nutrition N7, round 3 (fixes for codex-review-n7b)

Same reviewer session as round 2. Branch `ericlee4992/nutrition-07-scan-food`. Round 2's report:
`work-record/nutrition/codex-review-n7b.md` (2 × P2). Review `git diff 18458af..HEAD` and anything it touches.

- **R2-S1:** the queue keeps an earlier-day result's entry ID (`Pending.loggedEarlierID`), not the object. Today
  resolves it against its live `foodEntries` query each render: while the entry is deleted the card is hidden (kept in
  the queue), after Undo it shows again and Open edits the restored object. Test
  `testAnEarlierDayCardFollowsItsEntryThroughDeleteAndUndo` (yesterday → Open → Delete → card hidden → Undo → card back →
  Open → remove an item → Save → reopen shows the edit on the restored entry).
- **R2-S2:** Cancel and the camera's disappearance call `closeDown()`, which clears `captureID` and the capture snapshot
  synchronously (and cancels a picked-photo import), so a photo arriving afterwards fails `photo(_:)`'s identity check.
  Test `testCancelDropsAPhotoStillOnItsWay` uses `-uiTestFoodScanSlowShutter`: the fixture shutter now goes through the
  same pending-capture path and delivers the photo 2 s after the tap via `photo(_:)`.
- The flaky `testADescriptionIsLoggedAtOnce` taps the pill once more if Log food has not opened after 5 s.

Claude's evidence (scratchpad as before): `v3.xcresult` — ScanFood 12/12 + TodayFood 7/7, 2 workers, exit 0.

Reviewer rule (round 3): build; run the Unit plan; the fixes change UI behaviour/tests, so rerun `AAAWarmUpUITests`,
`ScanFoodUITests`, `TodayFoodUITests` (2 workers; failures serially before judging). WT-iPhone27, paths under
`/tmp/codex-n7c/`, progress in the existing tab `term_ac1339dc-202d-4c10-bab3-b528de726cbd`. Report only; no commit or
push; never print or copy the OpenAI key.

Write `work-record/nutrition/codex-review-n7c.md`: R2-S1 / R2-S2 fixed or not; new findings P1/P2/P3 with file:line,
failure scenario and fix; Verified / Not verified / Known flaky; end with exactly `Verdict: clear` or
`Verdict: not clear`.
