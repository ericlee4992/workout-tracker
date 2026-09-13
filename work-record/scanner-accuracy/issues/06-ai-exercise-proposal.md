# 06 — Create-new: let Claude propose which exercises a new machine serves

Status: DRAFT — the user's second idea (2026-09-05); not started
Blocked by: 05 (shares the client, the key handling and the opt-in)

## Why

When a plate matches no catalog row the user creates the machine and then has to tell the app
which exercises it serves. The catalog already lists exercises per row for known machines; a
Hammer Strength "Ground Base Combo Incline" or a Cybex "Plate Loaded Squat Press" is obvious to
a model that has read the plate, and the answer is a pick from the app's OWN exercise list, not
free text.

## What to build

- On the create-new path, after the reading (on-device or ticket 05's), one call: "given this
  brand, model and these plate lines, which of THESE exercises (the app's exercise names, sent
  in the request) does this machine serve? Return ids from the list only, most likely first,
  with a one-line reason." Constrained output: an array of exercise ids from the supplied list.
- The proposals appear as pre-ticked chips the user can untick; nothing is saved until Create.
  No proposal → the chips are simply empty, as today.
- Same opt-in, key handling, timeout and fail-closed rules as 05. Text only — no image needed
  once the reading exists — so D34 is untouched by this ticket.

## Design (2026-09-06, before building)

- **Button, not automatic** — the same rule the user chose for 05: a "Suggest exercises with AI"
  button in the New Model sheet's Exercises section, shown only when a plate reading exists and
  Ask AI is available. One tap, one call.
- **Text only.** `ExerciseProposalAPI` (Domain, pure) builds a Messages request from the brand,
  model and plate lines plus the app's OWN exercise list — `(id, name, muscle group)` for every
  exercise — and asks for ids from that list, most likely first, with a one-line reason each.
  Structured output; the `exercise_id` field is constrained to the sent ids by a JSON-schema
  `enum`, and the parser drops anything not in the list anyway (belt and braces).
- **Shared transport.** `AnthropicMessagesClient` (one URLSession call, the 05 error mapping)
  serves both `AnthropicPlateTranscriber` and `AnthropicExerciseProposer`; `AskAI` vends both, the
  stub answers both under `-uiTestAskAI`.
- **The reading travels to the sheet**: `ScanDraft` / `AddModelSheet` gain `plateLines`, set by
  the scan sheet's create-new (the raw camera or AI reading). Empty for a hand-entered model, and
  then no button.
- Proposals arrive as pre-ticked rows the user can untick; the reason shows under the row; nothing
  is saved until Add. A failure shows one line under the button and leaves the sheet as it was.

## Acceptance criteria

- Output validated against the sent id list; an id not in the list is dropped, not shown.
- The create-new sheet works identically with the feature off, offline, or on a refusal.
- Unit test on the validation; UI test with a stubbed client; Codex clear.

## Resolution (2026-09-06)

- **`Domain/ExerciseProposal.swift`** — `ExerciseCandidate` (id, name, muscle group),
  `PlateDescription`, `ExerciseProposal`; `ExerciseProposalAPI`: the text-only request (prompt +
  plate + the app's exercise list as `id | name | muscle group` lines; structured output whose
  `exercise_id` is an `enum` of exactly the ids sent) and the parser (ids validated against the
  list, repeats keep their first place, capped at six, order is the model's). `MessagesReply.text`
  (in `PlateTranscription.swift`) is the shared reply reducer for both features.
- **`AskAI.swift`** — `AnthropicMessagesClient` (one POST; credential + endpoint) now serves
  `AnthropicPlateTranscriber` and `AnthropicExerciseProposer`; `AskAI.proposer`;
  `StubExerciseProposer` picks "Machine Shoulder Press" FROM THE LIST IT WAS SENT (never an
  invented id).
- **The reading travels**: `ScanMachineLabelSheet.onCreateNew` carries the plate lines; `ScanDraft`
  and `AddModelSheet` take `plateLines`. Hand-entered models have none and see no button.
- **`AddModelSheet`** — "Suggest exercises with AI" section above the exercise list (only with
  lines + Ask AI available); one tap ticks the proposals and shows each reason under its row;
  unticking a row clears its reason; a failure or an empty answer is one line under the button and
  nothing else changes; nothing is saved until Add.
- **Tests** — `ExerciseProposalTests` (7): request carries plate + list and constrains ids;
  parse order/reasons; unknown ids dropped and repeats collapsed; empty is empty; the cap; refusal
  and malformed; the stub answers only from its list and no key → no proposer. UI:
  `testSuggestExercisesTicksWhatThePlateSaysAndTheUserKeepsTheFinalSay` — scan → create-new →
  Suggest → the reason under Machine Shoulder Press → Add enabled → untick → Add disabled.
