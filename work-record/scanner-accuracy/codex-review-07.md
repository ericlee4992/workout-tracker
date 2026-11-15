# Scanner 07 — Codex review

Reviewed 2026-11-14 on `ericlee4992/remove-ask-ai-plate`, HEAD
`e62eb31de27f926690fd4aece5912c5115221b9d`, diff `56db78ab..HEAD`. Starting checkout was clean. Reviewed the ticket,
D34/D53/D56/D79/D60, changed source/tests and affected callers. Only this report was modified. This verdict was
written after all independent runs finished; no pushes or workflow dispatches were performed.

## Standards

No findings. The removed production code was already unreachable; current-screen styling and reachable layout
remain unchanged. The on-device reading card still says “What the camera read”. The four LabelCrop geometry tests
were moved verbatim with **all 13 assertions preserved**. The rendering tests and crop implementation change only
comments. Domain/UI boundaries and stored models are unaffected.

No executable app, unit/UI test, test-plan or script reference remains to the removed transcriber/client/types,
fixture ledger, `-uiTestScanFixtureNoBrand`, or `scanAskAI*` identifiers. Remaining references in archived records
and D53 are explicitly historical, not executable dependencies or current instructions to use the removed path.

D34/D53 record the removal and retain the camera-label crop rule. D56/D79 agree with the current server constants:
`TRAINING_MODEL = gpt-5.6-terra`, `FOOD_MODEL = gpt-6.1-terra`; Scan Machine and model-exercise suggestions use the
training model. D60's server ownership remains intact. No server code or deployment was changed.

## Spec

No findings. Capture, on-device Vision reading, catalog matching/repair, preselection, confirmation, rescan,
create-new guesses and plate lines remain in the label sheet. Removed state and callbacks belonged to the
switched-off ask path. Suggest exercises retains its protocol, availability check, server proposer, fixture
responses, cancellation-aware delay and user-controlled confirmation.

### Parser equivalence

The direct parser preserves behavior for **every result `AIServerClient.complete` can return**:

1. `complete` requires a dictionary-valued `result` and serializes that dictionary to valid JSON/UTF-8 bytes.
2. The old server proposer decoded those bytes as UTF-8, put the string into one fixed Messages text block, then
   `MessagesReply.text` extracted that same string. Its outer error/refusal branches were unreachable for this
   constructed wrapper. Converting the extracted string back to UTF-8 recovered the original result input.
3. The new parser reads that result directly. The dictionary/proposals-array checks, candidate-ID lookup,
   first-occurrence deduplication, order, reason trimming and six-item limit are unchanged.

Malformed result shapes therefore still fail closed, empty proposals remain an empty answer, and invalid/unknown
IDs are still dropped. Server transport/auth/refusal failures continue to arrive as `AIServerError`; the removed
`unauthorized` and `unavailable` cases had senders only in the deleted direct-Anthropic paths. The retained four
suggestion-fixture error descriptions are unchanged under the renamed `AskAIError`.

### Scan Food crop

`FoodScanFlow.send` still calls `LabelCrop.jpeg` for a camera label region and stops when cropping fails. Library
label photos follow the pre-existing user-selected-photo path. The geometry and rendering implementations are
unchanged; removing the machine-plate request crop does not remove the food-label crop.

## Verification

Only WT-Redesign-2 `EB4328A1-87BD-4850-A3B2-A6E604701F1C`, prepared before build/tests; derived data
`/tmp/wt-ci-codex`; logs, exit files and result bundles `/tmp/wt-s07-codex-review/`.

| Scope | Result |
|---|---|
| Independent `build-for-testing`, WorkoutTracker scheme | **exit 0**, `build.log` / `build.exit` |
| Unit plan: ExerciseProposalTests, LabelCropTests, LabelCropRenderingTests, MachineLabelOCRTests; CI flag unset | **26/26 passed**, no failures/skips, **exit 0**, `unit.xcresult` |
| Full plan narrowed to ScanMachineLabelUITests and AskAIUITests/testManualModelSuggestionsRequireConsentAndKeepConfirmation; serial | **3/3 passed**, no failures/skips, **exit 0**, `ui.xcresult` |
| Diff whitespace; test-plan consistency | passed |

Inspected actual process exits and xcresult summaries. The UI run covers label capture/read/matching, rescan,
preselection, save/override, create-new prefill, and the retained suggestion consent/confirmation flow. It is a
three-test scope, not a full UI-suite run. No new production visual layout was introduced by removing the
fixture-only ask controls, so no new design capture matrix was required.

Also directly inspected the author's full Unit result (`s07-unit-full.xcresult`): **1361/1361 passed**, no failures
or skips; and `s07-ui.xcresult`: **3/3 passed**. The test-count decrease is removal of obsolete plate-client tests,
with crop coverage moved and suggestion availability/error coverage retained.

Verified: independent build, 26 affected unit tests and 3 affected UI tests, all exit 0; parser/data-flow equivalence;
          removed-symbol/fixture references; crop assertions and callers; decisions/model wording.
Not verified: a live signed-in suggestion against the server; physical-camera framing; phone behavior; full local
              Unit/UI reruns by this reviewer. Author full Unit evidence was inspected instead.
Known flaky: none seen in these runs.

Standards: 0 findings. Spec: 0 findings.

Verdict: clear
