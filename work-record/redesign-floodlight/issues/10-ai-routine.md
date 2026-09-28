# 10 — Floodlight: Ask AI for Templates (AI routine flow)

Type: feature (part of [01](01-implement-redesign.md), area order item 9)
Status: in progress
Implementer: Claude. Reviewer: Codex.
Branch: `ericlee4992/redesign-floodlight-ai-routine` (scratch checkout `/tmp/wt-floodlight/ai-routine`),
stacked on the ticket-09 settings tip `c286b59` (Codex clear). Nothing merged to `main`; nothing installed.

## User decisions (2026-09-28, asked in session)

1. **Generating shows the prototype as-is:** the percentage ring and the timed stage lines ("Building your
   week…" → "Checking equipment at <gym>…" → "Balancing muscle families…" → "Fitting sessions to your
   time…", 8 → 35 → 65 → 90 % at 0 / 0.8 / 1.7 / 2.5 s), holding at 90 % until OpenAI replies. The
   percentage is a timed illustration, not measured progress (the API reports none). The week appears
   as soon as the reply arrives (no added wait).
2. **A Saved step after "Save templates":** the week's family ring, "N templates saved", the new
   templates as tiles (tap one: the flow closes and that template opens on the Workout tab) and Done.
   Today the sheet closed at once.
3. **Leaving an unsaved week asks first — edited or not:** Cancel, Back and Change preferences on
   "Your week" ask "Discard this week?" (Discard Week / Keep Editing). Today Cancel discarded silently.
   Cancel while generating still stops and closes without asking (there is no week yet).
4. **The optional profile follows the unit setting:** ft + in and lb with U.S. customary, cm and kg with
   Metric (whole numbers). The request still carries cm / kg; nothing is stored.

Record decisions 1–4 with the D54 entry before merge.

## Scope

Ticket 01 area 9 in the approved Floodlight design: the full-screen Ask AI flow (today one form in a
full-screen cover, `AIRoutineSheet`) becomes the prototype's stepped flow. Reference: prototype captures
2026-09-28 into `../reference/prototype-ai/{dark,light}/` (`LOOKS=final APPEARANCE=dark|light AXL=1 SETTLE=5
scripts/capture.sh all … A01 A01:p2 A01:empty A02 A02:p2 A02:consentOff A02:noKey A02:hotel A03
A03:balancing A03:failure A04 A04:p2 A04:saved A04:discard A05 A05:p2 A05:picker A05:removed`, dark then
light, one at a time).

Chrome on every step: a top bar (Back · ✦ Ask AI · Cancel) with the step indicator Goals → Equipment →
Your week (the current step's name is the page heading), and a pinned bottom bar holding the step's
one filled command.

1. **A01 Goals.** The goal field ("What would you like to work toward?") with four phrase chips that
   add or remove their phrase in the text ("Build strength", "Build muscle", "Improve endurance",
   "Lose fat"); **Experience** as three tiles with rising bars (Beginner / Intermediate / Experienced);
   **the schedule panel (bold element):** "N days per week" over seven cells lit 1…N, then "N minutes
   per session" over a draggable 15–120 min bar with − / + (5 min steps); **Optional profile**: height
   and weight fields in the user's units (decision 4). **Next** (filled, off until there is a goal; a
   tap on the off Next puts the cursor in the goal). The real limits stay: goal ≤ 1,000 characters,
   height 50–250 cm, weight 20–400 kg (checked at Next, the message above it).
2. **A02 Equipment.** The gym as a menu card (the gyms, "No gym", Add Gym…); "N saved machines" and a
   strip of machine chips led by a dashed **Scan Machine** chip (the ticket-07 scan adds the machine);
   without a gym, "Choose or add a gym to save scanned machines."; **Available equipment** as eight
   tiles with line glyphs; **Available cardio** as nine tiles; the consent switch "Allow sending routine
   details to OpenAI" with one consequence line and "OpenAI data policies" while it is off, and the
   Ask AI row (key hint or "No key") opening the ticket-09 Ask AI sheet. Bottom bar: a live readout of
   what the AI may use (the five family maps lit for the families the eligible exercises train · N
   exercises · N cardio) over **Generate week** (filled; off until consent, a goal and something to use;
   a tap on the off button scrolls to what is missing and outlines the switch). With no key: "Add your
   OpenAI API key to create routines." and **Ask AI Settings** instead of Generate.
3. **A03 Generating** (decision 1): the ring with the percentage, the stage line, "Iron Temple · 3 days
   · 45 min", and a board where the session cells fill and the families light at "Balancing…"; **Back
   to preferences** stops the request. Reduce Motion: no sweep, shimmer or stagger. **Error** (new step):
   the broken ring with the error glyph, the message split into what happened / what to do, the request
   line, **Generate week** (retry) and **Back to preferences**.
4. **A04 Your week.** **The week scoreboard (bold element):** the gym, Sessions · Sets · Time, and the
   week's working sets per family; each session as a card (its families sized by their share of the
   sets with the counts, the name, N exercises · N sets · N min, the exercises with sets × reps, cardio
   blocks) → A05; **Change preferences** (secondary). **Save templates** (filled) saves every session at
   once (atomic, as today), then the Saved step (decision 2). Save errors show above the button.
5. **A05 Edit session** (pushed): the name as an editable title; the families and figures live; exercise
   cards (drag to reorder, VoiceOver Move up / Move down, swipe to remove, tap to open sets / reps / rest
   steppers and Remove exercise — one open at a time); every removal shows "<name> removed · Undo" for
   5 s; **Add exercise** (dashed; "10/10" at the limit) opens a searchable sheet of what the AI may use,
   by muscle group, each with its machine or equipment; cardio blocks (activity menu, minutes stepper,
   remove) and **Add cardio** (menu of the sent activities; "3/3" at the limit). Edits apply live.

Not in this ticket: the prototype's capture variants and paging helpers; the study looks' branches.

## Prototype features the real app lacked (approved with the prototype; each can be vetoed)

- The stepped flow itself (was one long form), the step indicator, pinned commands, Back.
- Goal phrase chips; experience tiles; day cells; the minutes bar; unit-following profile (decision 4).
- Equipment/cardio tiles with glyphs; the machine chip strip; the live "what the AI may use" readout;
  pointing at what is missing; the Ask AI key row in the flow; the flow usable before a key is saved
  (only Generate needs it).
- The generating ring, stages and build board (decision 1); the error step with retry.
- The week scoreboard, family shares per session, estimated minutes; the Saved step (decision 2); the
  discard confirmation (decision 3).
- The day editor's cards, undo bar, grouped searchable exercise picker, limit counts.
- Consent line: the real three-sentence footnote becomes one line. Implementer's wording (the
  prototype's "Sends your goals and exercise list, not Health data or history." left out the schedule
  and profile, which are also sent): "Sends your goals, schedule, optional profile and exercise list —
  not Health data or history."

## Domain (pure, unit-tested)

`Domain/AIRoutineFlowMath.swift`: `AIGoalPhrase` (toggle a phrase in the goal text), `AIProfileUnits`
(ft/in ↔ cm, lb ↔ kg, whole numbers), `AIRoutineStages` (the stage table; progress at elapsed time),
`AIRoutineReadouts` (a session's minutes by the SAME estimate the validator uses — 45 s per set, rest
between sets, 60 s per exercise, plus cardio; sets; families per session and their shares; the week's
per-family sets; the families the eligible options train), `AIRoutineErrorText.split`.
`AIRoutinePersistence.save` returns the new templates' ids (for the Saved step).
Rules kept: D58 (1–7 sessions, atomic isolated-context save, duplicate-submit protection, validated
IDs/bounds/duration, authored edits may exceed the duration), D56–D58 consent (the routine flag, the
same `@AppStorage` key as Settings), device-only key, `RoutineAvailability` (conservative eligibility),
no load estimates, planned cardio in the user's distance unit, explicit Start later.

## Screen jobs, bold element (ios-design steps 1–2)

- **A01:** exists to say what you want and how often; the eye lands on the day cells (the schedule
  panel), the thumb on Next. Runner-up (the goal field) is plain.
- **A02:** exists to say what is available; the eye lands on the equipment tiles, the thumb on Generate;
  the readout above Generate answers "what will it use".
- **A03:** exists to wait; the eye lands on the ring.
- **A04:** exists to accept the week; the eye lands on the scoreboard, the thumb on Save templates.
- **A05:** exists to adjust one session; the eye lands on the exercise cards.
- **Saved:** exists to confirm; the eye lands on "N templates saved"; Done.

## Tells (ios-design step 4)

- Same container on everything: absent — tiles only for choices (experience, equipment, cardio), one
  panel for the schedule, cards per session (each a group), lists for the picker.
- Chips: deliberate — goal phrases are choices that write text; machine chips are information (no fill).
- All-caps labels: absent. Middle dots: deliberate for the request line and figures.
- Accent everywhere: absent — violet only on the step's one command; selection is the flood fill.
- Equal full-width blocks: deliberate for equal choices (tiles); each step leads with its bold element.
- Only survives default size: answered by AXL captures (tiles one column, the bar's label alone at AX,
  profile rows stack, day cards' rows stack).

## Strings changed

"N saved machines" → "1 saved machine" / "N saved machines" (singular fixed); the consent footnote (see
above); "Ask AI" stays the flow's title; "Your week" title → the step indicator; "Edit session" stays;
"Remove exercise" / "Remove cardio" stay; "Add exercise" / "Add cardio" stay; "Change preferences" and
"Back to preferences" stay; "Open AI Settings" → "Ask AI Settings"; "Building your week…" stays as the
first stage. New: the phrase chips, "Experience", "Optional profile", "day(s) per week", "minutes per
session", "Available equipment", "Available cardio", "saved machine(s)", "Choose or add a gym to save
scanned machines." (kept), "Add your OpenAI API key to create routines." (was "…with Terra."), the stage
lines, "Sessions", "Sets", "Time", "N exercises / sets / min", "Discard this week?", "Discard Week", "Keep
Editing", "N templates saved", "Done", "<name> removed", "Undo", "No matches", "10/10", "3/3".

## Rules and identifiers

Kept: `askAIRoutine`, `routineGoals`, `dismissRoutineKeyboard`, `routineGym` (the menu), `routineAddGym`
(in the menu), `routineMachineCount`, `routineScanMachine` (the chip), `routineEquipment.<raw>` and
`routineCardio.<raw>` (now tiles: buttons with the selected trait, were switches), `allowAIRoutine`,
`routineAIError`, `generateAIRoutine`, `saveAIRoutine`, `routineDay.<n>`, `routineAISettings`.
New: `routineNext`, `routineBack`, `routineCancel`, `routineGoalPhrase.<n>`, `routineExperience.<raw>`,
`routineDays`, `routineMinutes`, `routineHeight*`, `routineWeight`, `routineStopGenerating`,
`routineRetry`, `routineChangePreferences`, `routineSavedDone`, `routineSavedTemplate.<name>`,
`routineSessionName`, `routineItem.<n>`, `routineRemoveItem`, `routineAddExercise`, `routinePick.<name>`,
`routineAddCardio`, `routineUndo`.

## Tests (planned)

- Unit `AIRoutineFlowMathTests`: phrase toggling, unit conversions, stage progress, minutes estimate =
  the validator's, family shares, week counts, error split; persistence returns ids.
- UI: `AskAIUITests` routine cases moved to the steps (all three templates ×3, scan during setup ×2, gym
  picker, consent/failure, weekly routine ×3, key settings ×2); new `FloodlightAIRoutineUITests` —
  captures A01–A05, error, saved, discard, picker, undo light/dark × Default/AXL; flows: back keeps
  inputs, discard confirmation, error → retry, saved tile opens the template, undo restores.

## Verification

Runner `/tmp/wt-floodlight/ai-run.sh <name> build|test …` (NEW derived data `/tmp/wt-floodlight/dd-ai`);
logs, `.exit` files and result bundles `/tmp/wt-floodlight/results/ai-*`.

- Prototype captures: dark and light both exit 0 (38 each); two dark shots came out blank (A04:p2,
  A04:discard AXL — the known capture glitch) and were retaken (content checked); all 76 have content.
- `ai-build-1`: exit 0 (build-for-testing, fresh derived data, no warnings in the new files).
- `ai-unit-1`: **exit 0 — 33/33** (`AIRoutineFlowMathTests` 11 new, `AIGymTests` 22).
- `ai-ui-1` (exit 65): the light Default capture pass reached A01–A05 (an open card, the undo bar, the
  picker) and failed paging the editor to "Add cardio": no cardio had been chosen, so the editor ended
  on a bare "Cardio" header. Product fix: the Cardio section is hidden when the session has no cardio
  and none was sent. The capture now chooses a cardio tile, and shoots Generating at 2.6 s (the shot at
  2.9 s caught the week sliding in: the 4 s fixture was replying).
- `ai-ui-2` (exit 65): the test target did not compile (a duplicate `save` in the moved AskAI test).
- `ai-ui-3` (exit 65; started with a shell `&` by mistake instead of the tool's background mode — it ran
  to completion and wrote its exit file): `FloodlightAIRoutineUITests` **6/8** — light and dark Default
  capture passes and all four flows (Back keeps inputs + every way out of a week asks first; the error step
  → Back to preferences; a saved tile opens its template; undo restores). Both AXL passes failed reaching
  the first day card: at AX sizes a session card is taller than the space between the pinned bars (the
  helper now accepts a tall card once its top is in view, and taps near its top — its centre can sit under
  Save templates). `AskAIUITests` routine cases **7/12**: every Default case passed except scan-during-setup,
  which expected the old "1 saved machines" (the count now says "1 saved machine" — a string fix listed
  below); the four AX cases failed dismissing the keyboard: the recording showed iOS 27's floating keyboard
  Done, with a stale copy in the hierarchy while the keyboard rises — the test tapped that one. The helper
  waits for the keyboard to settle, taps the Done on it, retries once. The run's AX shots (A01–A04) were
  looked at: tiles in one column, the schedule figures wrap, the scoreboard as rows, cards stack — no
  layout faults. Product change after this run: the exercise card's accessibility label is its exercise
  (a container's label was empty, so the undo/reorder tests' label checks could pass vacuously; they now
  assert a non-empty label).
- `ai-ui-4`: **exit 0 — 13/13**: the whole `FloodlightAIRoutineUITests` class (four capture passes — both
  AXL now through the week, the editor, the picker, the undo bar, the discard confirmation, Saved and the
  error step — and the four flows) and the five `AskAIUITests` cases that had failed (populated-list AX,
  missing key AX, scan during setup ×2, weekly routine AX).
- Captures `../captures/10/` (84 PNGs, from `ai-ui-4`): A01 (empty, filled, profile), A02 (top, consent off,
  pages), A03 at 90 %, the error step, A04 (top, pages, discard), Saved, A05 (top, open card, undo, picker,
  pages) — light/dark × Default/AXL. Contact sheets beside the prototype:
  `/tmp/wt-floodlight/results/ai-sheets/compare-*.png`.

## Progress

- 2026-09-28: started in the ticket-09 session at the user's request; branch created from `c286b59`
  and pushed. Read ticket 01, the prototype AI area (flow, five steps, components, support, store
  logic) and the real `AIRoutineSheet` / `AIRoutine`. User decisions 1–4 recorded. Ticket written.
- 2026-09-28: implemented (`c469a0a` and after): `Domain/AIRoutineFlowMath.swift` + tests;
  `AIRoutineDay` gets a local id (not encoded); `AIRoutinePersistence.save` returns the ids;
  `Features/Templates/AIRoutine/` — `AIRoutineFlowModel`, components, the five steps and the Saved step;
  `AIRoutineSheet` is the stepped flow's root (same name, so the Workout tab's cover presents it; its tile
  callback opens the template). `FloodlightAIRoutineUITests` (four capture passes, four flows);
  `AskAIUITests` routine cases moved to the steps (helpers `typeGoals`, `toEquipment`, `choose`,
  `chooseGym`, `addGymFromRoutine`, `discardWeekAndClose`; `reach` knows the flow's pinned bars).

## Codex review 10 — response (round 1)

Report: [codex-review-10.md](../codex-review-10.md) — not clear; five medium, four low. All accepted.

1. **M1 — the off Next / Generate could not be activated with VoiceOver.** The off face stays a working
   button (a tap points at what is missing); VoiceOver hears the value "Unavailable" and a hint naming the
   requirement ("Add a goal first." / "Allow sending routine details to OpenAI first." / "Choose equipment
   or cardio first."). Generation is still gated by the model. Tests read the value, not `isEnabled`.
2. **M2 — schedule and count animations ignored Reduce Motion.** The day/minute figures, the minutes bar,
   the saved-machine count, the readout counts and `AIInlineFigure` now drop their numeric transitions and
   animations under Reduce Motion.
3. **M3 — cardio minutes lost one-minute precision.** The editor's minutes stepper is 1…180 in one-minute
   steps again (as the old editor); every value is reachable by the buttons and VoiceOver alike.
4. **M4 — the equipment line could name a machine the template will not use.** It follows
   `WorkoutTemplateService.resolvedMachine`'s rule: the gym's remembered machine, else the only compatible
   one; several compatible and none remembered read "N machines".
5. **M5 — revoking consent silently discarded the week.** Revocation now only stops a running request;
   a generated week stays (saving sends nothing) and is dropped only through Back / Cancel / Change
   preferences, which ask. (Decision 3 holds on every path.)
6. **L1 — the consent line omitted fields.** "Sends your goals, experience, schedule, optional profile,
   exercise list and chosen cardio — not Health data or history." (every `AIRoutineRequest` field).
7. **L2 — the undo message truncated at AX.** At accessibility sizes Undo sits under the message, which
   wraps whole.
8. **L3 — day cells under 44 pt on 375–393 pt phones.** The cells reach into the panel's padding and the
   gap narrows (6 → 4 → 2 → 0) until every cell is at least 44 pt wide.
9. **L4 — retry and undo not proved.** The error test now taps Retry and sees a new request's wait before
   the (still offline) error returns; `testUndoRestoresTheExactDay` edits a prescription (4 sets), removes
   another exercise, undoes, and compares every card, the session's figures ("19 sets") and the edited
   stepper.

Also found in this round (Claude): the reorder check in `testEditingGeneratedWeekKeepsRowsAndSavesOnlyOnce`
had passed in `ai-ui-3` only because both cards' labels were empty. With the cards named (see above), the
quick drag did not reorder (`ai-ui-5`, 6/7 — the other six routine cases passed on the final helpers); a
long press and slow drag does (`ai-ui-6`: the reorder check passed; the test then failed at the saved
template editor's last row, below the old helper's tab-bar margin inside a sheet — the test now only
requires it on screen). `ai-ui-6` also passed `testUndoRestoresTheExactDay`; the retry check needed the
slow fixture (the offline failure arrives in 0.2 s).

