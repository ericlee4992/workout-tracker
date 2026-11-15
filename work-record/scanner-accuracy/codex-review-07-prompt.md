Review, same checkout, now on branch ericlee4992/remove-ask-ai-plate (off main 56db78ab). Review `git diff 56db78ab..HEAD`.
Ticket: work-record/scanner-accuracy/issues/07-remove-plate-ask-ai.md (acceptance, progress, evidence). Decisions: D34,
D53, D56, D79 (docs/DECISIONS.md) and D60.

The user asked whether machine scans all use GPT; they do not (Scan Machine → server `scan-machine` on GPT-5.6 Terra;
"Read label on device" → Vision + the app's matcher). The user then asked to remove the switched-off plate "Ask AI"
(Claude) leftovers and correct D56's model line. This removes the plate ask (state, UI, crop, fixture tally, no-brand
fixture), the direct Anthropic client and plate transcription types, and the Messages-API request for ticket 06's
exercise proposal; keeps "Suggest exercises with AI" (server flow + stub) and `LabelCrop` (Scan Food labels).

Check especially: nothing still reachable lost behaviour (the label sheet's capture/read/match/preselect/create-new; the
New Model sheet's suggestion, its errors and fixtures; Scan Food's label crop); `ExerciseProposalAPI.parse` reading the
server's result object directly is equivalent to the old wrap-then-unwrap for every input `AIServerClient.complete` can
return; the removed error cases (`unauthorized`, `unavailable`) had no remaining sender; no UI test, test plan, script or
doc still relies on a removed fixture/identifier (`-uiTestScanFixtureNoBrand`, `scanAskAI*`); comments and DECISIONS
wording are true; the test moves kept every LabelCrop assertion.

Author's evidence (WT-Floodlight 9E822EF6-DC67-4958-AEA2-D53D2D36D674, derived data build/dd-ci): build exit 0; full Unit
plan 1361/1361 (build/results/s07-unit-full.xcresult); ScanMachineLabelUITests + the suggestion UI test 3/3
(build/results/s07-ui.xcresult). Round 1: build and run the affected unit suites and those UI tests yourself on
WT-Redesign-2 (EB4328A1-87BD-4850-A3B2-A6E604701F1C), derived data /tmp/wt-ci-codex. Do not push or trigger workflows.
Modify nothing but work-record/scanner-accuracy/codex-review-07.md, ending with exactly "Verdict: clear" or
"Verdict: not clear" — written only after your runs finish.
