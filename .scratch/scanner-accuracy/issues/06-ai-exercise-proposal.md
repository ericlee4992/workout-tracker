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

## Acceptance criteria

- Output validated against the sent id list; an id not in the list is dropped, not shown.
- The create-new sheet works identically with the feature off, offline, or on a refusal.
- Unit test on the validation; UI test with a stubbed client; Codex clear.
