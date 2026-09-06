Round 3 (T6) of scanner-accuracy tickets 05 "Ask AI" + 06 "Suggest exercises with AI".
Round-2 review: .scratch/scanner-accuracy/codex-review-05b.md. The response is in
issues/05-ask-ai-escalation.md under "Codex review 05b — response" (ticket 06's status line
points there too). Boundary of the fixes: 6242324..HEAD on branch ask-ai.

Scope: are the round-2 findings closed exactly —
1. `LabelCrop.pixelRect` now returns nil when the clamped crop touches all four edges. Is there a
   box that passes this and still is, for practical purposes, the frame? Is the new fixture
   (plate on a 2000×800 canvas, `ScanFixture.plateRegion`) a box that survives the margin, and do
   `ScanMachineLabelUITests` still read the plate (Vision's region of interest is that box)?
2. `AddModelSheet.proposalTask` — cancelled by Cancel, Add and `onDisappear`; the task's
   post-cancel guard. Anything that can still land on dead state?
3. SPEC lines 28 and 76–79 and D53 — do the documents now say exactly what leaves the phone, and
   when, for BOTH tickets?
4. The counting client: `AskAIFixtureLedger` + `scanAskAICalls`; the assertions in
   `testAPreselectedPlateNeverOffersAskAI` (0) and `testAskAIRanksWhatClaudeReadAndTheUserStillConfirms`
   (0 before, 1 after). And `-uiTestAskAITimeout` + `testATimedOutAskIsSaidPlainly`.
5. The gym-creation helper hardening in `AskAIUITests` (keyboard wait + value check) — harmless?
And whether the fixes introduced anything new.

Do NOT run xcodebuild or simctl: the full XCUITest suite is running on the WT-iPhone simulator
right now and a second test run would corrupt both. Review by inspection; the verification record
(697/697 unit, AskAIUITests 7/7, ScanMachineLabelUITests 2/2 at this head) is in the ticket.

If closed, say "clear" in one paragraph. Otherwise report by severity with file:line. Do not
modify source files. Write to .scratch/scanner-accuracy/codex-review-05c.md
