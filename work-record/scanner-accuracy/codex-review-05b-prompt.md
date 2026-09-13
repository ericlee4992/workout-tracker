Round 2 (T6) of scanner-accuracy ticket 05 "Ask AI", now reviewed TOGETHER with ticket 06
"Suggest exercises with AI" (they share the client). Round-1 review:
work-record/scanner-accuracy/codex-review-05.md. The response is in
issues/05-ask-ai-escalation.md under "Codex review 05 — response"; ticket 06's build is in
issues/06-ai-exercise-proposal.md under "Resolution". Boundary of the fixes + ticket 06:
ba130b6..HEAD on branch ask-ai. The LLM report was re-measured with the production prompt
(reports/llm-sonnet-2026-09-06b.md, identical totals).

Scope, part A — are the round-1 findings closed exactly:
1. The library photo / degenerate geometry: `LabelCrop.pixelRect` now returns nil for no box, a
   degenerate box, or a box that is the frame; `LabelCrop.jpeg` returns nil then; the sheet computes
   a crop only when the read had a region (`read(_:regionOfInterest:)`). Is there ANY path left on
   which the whole photo is encoded or sent? Is the fixture's `plateRegion` a box, not the frame?
2. Ask lifecycle: `askTask` / `askRequest` in `ScanMachineLabelSheet` — trace a rescan mid-ask, a
   second photo mid-ask, dismissal mid-ask, a reply arriving after `abandonAsk()`, and whether
   `asking` can be released by anyone but the owning request. Does `URLSession.data(for:)` honour
   the cancellation, and does the stub (`AskAI.stubDelay`) behave the same?
3. Credential: `AnthropicMessagesClient.Credential` (.apiKey vs .bearer) and `request(for:)`.
4. `ScanFixture.isEnabled` gated by `WorkoutTrackerStore.fixtureIsEnabled`.
5. The new tests: `LabelCropRenderingTests` (does the `.right`-tagged image really prove
   orientation, or would an unrotated crop also pass?), `theWireRequestCarriesTheCredential…`,
   `testARescanDropsTheAskInFlight`, `testARefusedAskIsSaidPlainly`.

Scope, part B — ticket 06, by what could hurt the user:
6. `ExerciseProposalAPI`: can the model's answer link an exercise that was NOT in the list sent
   (parse validation + the schema enum)? Can it write free text anywhere that is saved? Is the
   request text-only (no image), so D34 is untouched?
7. `AddModelSheet.suggestExercises`: one tap one call; a failure or empty answer leaves the sheet
   as it was; can a proposal arrive after the sheet was dismissed or after Add? Are the ticks the
   user's (untick clears the reason; Add stores only `linkedExerciseIDs`)?
8. `onCreateNew` now carries the plate lines through `ScanDraft` — any site that lost them or
   passes stale ones? The hand-entered path shows no button?
9. `StubExerciseProposer` only answers from its list; the UI test proves Add flips on the tick and
   off on the untick.

If everything is closed and 06 is sound, say "clear" in one paragraph. Otherwise report by
severity with file:line. Do not modify source files.
Write to work-record/scanner-accuracy/codex-review-05b.md
