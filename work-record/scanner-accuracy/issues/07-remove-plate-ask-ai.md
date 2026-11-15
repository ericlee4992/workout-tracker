# 07 — Remove the switched-off plate "Ask AI" (Claude) and correct D56's model

Status: done — merged into `main` 2026-11-14 (Claude implemented, Codex reviewed — T6)
Branch: `ericlee4992/remove-ask-ai-plate` (off `main` `56db78ab`), worktree `~/.paseo/worktrees/1qmeipq9/workout-chart-machines`

## Why

The user asked (2026-11-14) whether machine scans all use GPT. They do not: Scan Machine (D56) sends one photo to the
server's `scan-machine` flow on GPT-5.6 Terra; the machine form's "Read label on device" reads the plate with Vision and
the app's matcher, on the phone. Two leftovers surfaced, and the user said "make those changes":

1. The on-device sheet still carries ticket 05's "Ask AI about this plate" (D53): a Claude client, a plate prompt and
   schema, a crop to send, state and UI. It has been unreachable since D56/D60 — `AskAI.transcriber` returns nil
   outside the `-uiTestAskAI` fixture — and its footnote still says "to Claude, with your key". The direct
   Anthropic client used by ticket 06's exercise proposer is dead too: suggestions go through the server
   (`ServerExerciseProposer`).
2. D56's heading says the model was switched to GPT-6.1 Terra by D79, but D79 was amended on 2026-11-10: the training
   flows (Scan Machine among them) stay on GPT-5.6 Terra (`TRAINING_MODEL` in `server/src/ai.ts`). D79 names the
   constant `MODELS`, which does not exist.

## Acceptance

- The on-device label sheet has no Ask AI state, button, footnote, crop or fixture tally; its reading card always says
  "What the camera read". Nothing else about the sheet changes (capture, reading, matching, preselection, create-new).
- Gone: `PlateTranscriber`, `AnthropicPlateTranscriber`, `StubPlateTranscriber`, `AskAI.transcriber`,
  `AnthropicMessagesClient`, `AnthropicExerciseProposer`, `PlateTranscription`, `PlateTranscriptionAPI`,
  `ExerciseProposalAPI`'s Messages-API request (prompt, schema, `requestBody`), `MessagesReply`, `AskAIFixtureLedger`,
  the no-brand scan fixture that existed only to drive the ask.
- Kept, unchanged in behaviour: "Suggest exercises with AI" (server flow, the stub under `-uiTestAskAI`/`-uiTestTerra`,
  the parse rules: ids from the list only, repeats dropped, at most six); `LabelCrop` (Scan Food's label photos use
  it) with its unit tests; the error messages a suggestion can show.
- Errors that no longer have a sender are removed (a rejected key "in Settings" no longer exists).
- DECISIONS: D53 and D34's amendment say the plate ask was removed (2026-11-14) and what remains (the box-crop rule for
  Scan Food labels); D56's heading names GPT-5.6 Terra as the current model per D79 amended; D79 names
  `TRAINING_MODEL` / `FOOD_MODEL`.
- `xcodebuild build` succeeds; affected unit tests pass; the label sheet's UI tests pass.

## Progress

- 2026-11-14 — implemented (Claude). Removed `PlateTranscription.swift` and `PlateTranscriptionTests.swift`; the
  label sheet lost its ask state/UI/crop/fixture tally and `ReadingSource`; `AskAI.swift` keeps only the exercise
  proposer (protocol, availability, stub, server); `ExerciseProposalAPI.parse` now reads the server's result object
  directly (before: wrapped into a Messages-API shape only to be unwrapped again — same bytes reach the same checks);
  `AskAIError` (offline / timedOut / refused / malformed, same strings) replaces `PlateTranscriptionError`, dropping
  `unauthorized` ("Check it in Settings" — that field is gone) and `unavailable`, which nothing threw any more. The
  4 `LabelCrop` geometry tests moved to `LabelCropTests.swift`; `signedOutMeansNoAsk` became
  `ExerciseProposalTests.signedOutMeansNoSuggestion`. The no-brand scan fixture (`-uiTestScanFixtureNoBrand`) went
  with the ask it existed for; no UI test used it. DECISIONS D34, D53, D56, D79 amended.

## Evidence

Simulator WT-Floodlight `9E822EF6-DC67-4958-AEA2-D53D2D36D674` (prepared), derived data `build/dd-ci`:

- `build-for-testing`: exit 0 (`build/results/s07-build.log`).
- Unit plan, `ExerciseProposalTests` + `LabelCropTests` + `LabelCropRenderingTests` + `MachineLabelOCRTests`:
  26/26 passed (`build/results/s07-unit.xcresult`).
- Full Unit plan: 1361/1361 passed, none skipped (`build/results/s07-unit-full.xcresult`) — 1370 before, −14 plate
  tests deleted, +4 crop tests moved, +1 net in `ExerciseProposalTests`.
- UI: `ScanMachineLabelUITests` (2) + `AskAIUITests/testManualModelSuggestionsRequireConsentAndKeepConfirmation`:
  3/3 passed (`build/results/s07-ui.xcresult`).

Verified: build; the full Unit plan; the label sheet's UI tests and the suggestion UI test.
Not verified: the full UI suite (routine scope per DEVELOPMENT — a removal confined to these files);
a live signed-in suggestion against the server (the parse change is byte-for-byte the same input).
Known flaky: none seen.

## Review

Codex round 1 clear, 0 findings ([report](../codex-review-07.md)): independent build, the 26 affected unit tests and
the 3 UI tests all exit 0; parser equivalence traced for every result `AIServerClient.complete` can return; the
LabelCrop tests moved with all 13 assertions.
