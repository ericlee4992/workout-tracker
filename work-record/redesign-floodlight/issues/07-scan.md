# 07 — Floodlight: Scan

Type: feature (part of [01](01-implement-redesign.md))
Status: in progress — implemented 2026-09-27; targeted verification running (see Verification)
Implementer: Claude. Reviewer: Codex.
Branch: `ericlee4992/redesign-floodlight-scan` (scratch checkout `/tmp/wt-floodlight/scan`),
stacked on the ticket-06 gyms tip `d45d5c5` (Codex clear). Nothing merged to `main`; nothing installed.

## User decisions (2026-09-27, asked in session)

1. **A scan from the gym page's Scan Machine or from AI routine setup adds the machine
   directly** (the prototype): the result's filled command is "Add to <gym>", then an **Added**
   step ("Added to <gym>", the new machine's card, the gym's machine count, **Done** and **Scan
   another machine**). Unit and preset are set later on the machine page (ticket 06's inline
   setup). The machine form's own **Scan equipment…** still fills the form (you started there),
   with the same restyled sheet; its commit reads "Use This Machine".
2. **Photo consent stays before the camera** (D56 as written). The consent step uses the
   prototype's layout (the data path to OpenAI and the four facts) with a camera glyph where the
   prototype shows the photo just taken.
3. **Ambiguous stays D56**: "N catalog models match" names the matching catalog rows as
   information; the machine is saved without a model (Correct Model can choose one later). No
   candidate picking and no confidence bars — Terra returns one identity and no score.
4. **The model picker gets no Scan Machine pill and no correction-scope alert.** The form keeps
   its scan buttons beside the model row; corrections go through the Correct Model sheet.

## Scope

The Scan half of ticket 01 area 6, in the approved Floodlight design. Reference: prototype
captures taken 2026-09-27 into `../reference/prototype-scan/{dark,light}/` (`LOOKS=final
APPEARANCE=dark|light AXL=1 SETTLE=4 scripts/capture.sh all … S01 S02 S03 S03:failure S04 S05 S06
S07`; both runs exit 0, 32 PNGs). Contact sheets: `/tmp/wt-floodlight/results/scan-sheets/proto-*`.

1. **IdentifyEquipmentSheet → the Scan Machine sheet (S01–S06).** One sheet, the navigation bar
   hidden, a glass **Cancel** capsule top-leading and the title "Scan Machine" centred (at AX
   sizes the title moves into the content as its first line). Steps:
   - **No key** — a key disc, "Add your OpenAI API key to identify equipment with Terra." as the
     title; **Open AI Settings** (filled) and **Choose a catalog model** (quiet).
   - **Consent (S02)** — the data path (camera glyph tile with the catalog badge → dashed
     connector → the OpenAI sparkles disc), "Send equipment photos to OpenAI?", one panel of four
     facts (sent: the full photo…, the exercise catalog; not kept/yours: photo not saved by the
     app, billed to your OpenAI API key) ending in the **OpenAI data policies** link; **Allow photos
     and continue** pinned (filled).
   - **Camera (S01)** — always dark: the live camera (or, under the fixture, a dark stand-in)
     edge to edge, the scrim outside the framing brackets, a gym chip "Iron Temple · 16" (gym,
     machine count), "Scan a machine or its label" in a glass capsule, then the control row:
     choose-photo circle · the violet **shutter** · flash circle. The camera does not frame for
     the AI (the whole photo is sent), so the brackets are a guide only. Camera unavailable:
     the stated reason over a glyph, **Choose a photo instead** filled and **Open Settings** when
     Settings can help.
   - **Identifying (S03)** — the photo just taken as the hero with the corner brackets and the
     violet sweep; a panel "Identifying equipment…" with the ten-cell chasing instrument;
     **Take another photo** pinned (quiet).
   - **Error (S03 failure)** — the photo greyed under a "!" stamp, the real error in a dashed
     card, **Take another photo** filled, **Choose a catalog model** quiet.
   - **Result (S04–S06)** — one panel: the photo, then the outcome stamp and its state name
     beside it, then the identity:
     - catalog match: a lit check, "Matches catalog", maker (secondary) over model (title 2), the
       equipment-type tag;
     - new model (a visible maker/model the catalog lacks): the dashed "+" disc, "New model",
       maker over model; "Added to your models" is implied by the tag "Custom";
     - ambiguous (decision 3): the count ring, "N matches", "Saved without a model", the matching
       catalog rows listed as information;
     - generic / uncertain: the hollow "?" disc, "Generic", the machine's name and "Saved as this
       gym's machine, with no model claimed."; uncertain adds "AI could not identify this
       equipment. Try a clearer angle or choose its exercises below.";
     - **Use generic identity** (catalog / new model) as a quiet chip that sets the answer aside,
       and **Use catalog match** / **Use new model** to bring it back (no second identification);
     - the words the AI read ("Read on the machine: …") as a caption under the identity;
     - **Already at <gym> as "<label>"** when a machine at this gym already has that model (new).
     Then **Name** (field; a catalog match prefills the D3 movement name, as the form did),
     **Maker and model** fields only for a specific identity (kept editable — D56's editable
     proposal), **Exercises** (information rows; **Change exercises** when no catalog model
     supplies them). Pinned: **Add to <gym>** (add mode) or **Use This Machine** (form mode),
     filled, disabled without a name or an exercise; **Take another photo** quiet.
   - **Added** (add mode) — the check stamp, "Added to <gym>", the new machine's card (name,
     model, exercises), the machine count ("17 machines"), **Done** filled and **Scan another
     machine** quiet.
   - **Change exercises** (pushed) — the prototype's picker: search, the picked ones as removable
     chips, the visible limit "2/6", **Suggested** (the AI's picks, then machine exercises of the
     same muscle groups), then every exercise by muscle group. The AI photo flow keeps D56's six;
     the form's own "Choose exercises" uses the same picker.
2. **ScanMachineLabelSheet → Read Label (on-device; no prototype screen).** Built from the same
   pieces: the dark viewfinder with the plate-shaped framing box (unchanged geometry — it is the
   OCR region), "Fit the name plate in the box", the shutter row (photo · shutter · flash);
   **Reading the label…**; results as one sheet: the "What the camera read" card (the text as
   read, monospaced), the candidates as radio rows with the **score as a ten-cell meter** and the
   percentage (D33 shows scores), the D33 footers, **Use This** filled, **None of these — create
   new** / **Add this as a new model** and **Scan again** quiet; failure: the message, Open
   Settings / Choose from photos / Try the camera again / Enter it by hand. The Ask AI (legacy)
   section stays for the fixture only (`AskAI.transcriber` is nil in production).
3. **LabelCameraView** — no visual of its own; unchanged except where the sheets draw over it.
4. **MachineModelCorrectionSheet → Correct Model (S07).** Header panel: machine glyph, label,
   gym; once a different model is picked, the old model struck through → the new one. The model
   list: the **Current** model (tag), up to five **suggestions** (models serving this machine's
   exercises: named for its label first, then most shared exercises, then A–Z), a model picked
   from the catalog that is not among them, **None**, and **Catalog Model** (pushes the existing
   `ModelPickerView` with its search/chips). The two **scope tiles** (the bold element) — Future
   Workouts Only / Apply to Past Workouts Too — each with its timeline (one dot per past workout on
   this machine, up to ten, a "Today" tick, three to come); the past tile states "8 workouts · 33
   sets". **Correct Model** pinned, a neutral disabled capsule until the model changes; with past
   workouts chosen and at least one to rewrite, a confirmation "Change the model in 8 past
   workouts?" (Apply to Past Workouts Too / Cancel).

Not in this ticket: the picker's Scan Machine pill and scope alert (decision 4); candidate
picking and confidence for the AI (decision 3); the prototype's tap-to-focus square (the real
camera focuses on the box at the shutter — scanner ticket 03); the prototype's demo menu.

## Prototype features the real app lacked (approved with the prototype; each can be vetoed)

- Direct add from Scan Machine with the **Added** step, the machine count and **Scan another
  machine** (decision 1).
- The consent data path and the four-fact panel (was one paragraph).
- Gym chip with the machine count over the viewfinder.
- The photo shown back while identifying, on the error and on the result (in memory only, never
  saved — D56).
- Outcome stamps and state names ("Matches catalog", "New model", "N matches", "Generic").
- **Already at <gym> as "<label>"** duplicate warning.
- Use generic identity is reversible (Use catalog match / Use new model).
- Change exercises: Suggested group, chips, the visible "2/6" limit (was a silent six).
- Correct Model: suggestions, before → after header, scope tiles with timelines and the rewrite
  count, and a confirmation before rewriting past workouts (was two bare buttons).

## Domain (derived on read, unit-tested)

`Domain/ScanMachine.swift`:
- `ScanMachine.label(for:resolution:modelExerciseNames:)` — the name the result prefills: the
  AI's label, or for an unedited catalog match D3's movement name (`MachineLabelDefaults`).
- `ScanMachine.add(_ proposal:, to gym:, context:)` — the form's save rules, once: resolve the
  identity (catalog → that model; new model → a user model with the confirmed exercises;
  ambiguous/generic → no model), the machine with its instance-local exercises only when no
  model supplies them. Used by the sheet's add mode AND the form (one implementation).
- `ScanMachine.existing(model:at:)` — a live machine at this gym already on that model.
- `ScanMachine.suggestedExercises(…)` — the AI's picks, then machine exercises of the same
  muscle groups (the picker's Suggested group).
- `ModelCorrection.impact(of:in:)` — distinct workouts and completed sets whose snapshot is this
  machine (what "Apply to Past Workouts Too" rewrites); `ModelCorrection.suggestions(for:among:)`.
- Rules kept: D10 (correction scope; history rewritten only on the explicit past choice), D23
  (history keyed on snapshots), D33 (on-device: proposes, preselects only by the three rules,
  always a tap), D34 (no photo written), D53 (fixture-only Ask AI), D56 (consent, one photo,
  editable proposal, ambiguous → model-less, movement-only names model-less), D3 (a picked model
  names the machine by its movement).

## Screen jobs, bold element, wireframes (ios-design steps 1–2)

- **Camera:** exists to take one photo; the eye lands on the framing brackets, the thumb on the
  shutter (the one filled element, bottom third).
- **Consent:** exists to agree to what is sent; the eye lands on the data path, the thumb on
  Allow (the one filled command).
- **Identifying:** exists to show the photo is being read; the eye lands on the photo with its
  sweep. No filled command (Take another photo is quiet).
- **Result:** exists to confirm what the machine is; the eye lands on the stamp and the identity
  under the photo; the thumb on Add to <gym>.
- **Added:** exists to show the scan changed something; the eye lands on the check and "Added to
  <gym>"; Done is the one filled command.
- **Read Label results:** exists to pick the catalog row in one tap; the eye lands on the first
  candidate (preselected when D33 allows); Use This is the one filled command.
- **Correct Model:** exists to pick the right model and how far back it reaches; the eye lands
  on the scope tiles once a model is picked; Correct Model is the one filled command.

```
Camera (always dark)        Result (catalog match)      Correct Model
┌──────────────────────┐   ┌──────────────────────┐    ┌──────────────────────┐
│(Cancel) (⌂ Gym · 16) │   │(Cancel) Scan Machine │    │(Cancel) Correct Model│
│ ┌┐              ┌┐   │   │┌────────────────────┐│    │┌────────────────────┐│
│                      │   ││   photo (236 pt)   ││    ││[▤] Lat Pulldown    ││
│      (viewfinder)    │   │├────────────────────┤│    ││    Iron Temple     ││
│                      │   ││(✓) Matches catalog ││    ││ Insignia (struck)  ││
│ └┘              └┘   │   ││ Life Fitness       ││    ││ ↳ G7-S33 Diverging ││
│ (Scan a machine or…) │   ││ Insignia Chest…  T2││    │└────────────────────┘│
│  (▣)    (◉)    (ϟ)   │   ││ [Selectorized]     ││    │ ◉ Insignia  [Current]│
└──────────────────────┘   ││ (◌ Use generic id.)││    │ ○ G7-S33 …           │
                           │└────────────────────┘│    │ ○ None · 🔍 Catalog › │
                           │ Name [Seated Chest…] │    │┌─────────┐┌─────────┐│
                           │ Exercises            │    ││Future   ││Past too ││
                           │[+ Add to Iron Temple]│    ││○○○|●●●  ││●●●|●●●  ││
                           │ (Take another photo) │    │└─────────┘└─────────┘│
                           └──────────────────────┘    │[✓ Correct Model]     │
                                                       └──────────────────────┘
```

Relative sizes: the step title is `navTitle` in the bar (`title2` inline at AX); the result's
identity is `title2`; the Added count is `bigNumber`; stamps 58 pt (52 at AX).

## Rules and identifiers kept

Scan sheet: `allowAIPhotos`, `scannerAISettings`, `scanShutter`, `scanChoosePhoto`, `scanRescan`
(Take another photo, on the identifying, error and result steps), `scanAIError`,
`identifiedMachineLabel`, `scanUseCandidate` (the result's filled command in both modes),
`dismissEquipmentKeyboard`, the string "Scan a machine or its label".
Read Label: `scanStatus`, `scanFramingBox`, `scanFixtureViewfinder`, `scanTorch`,
`scanReadingText`, `scanAskAI`, `scanAskAIStatus`, `scanAskAINote`, `scanAskAICalls`,
`scanCandidate.<model>`, `scanUseCandidate`, `scanCreateNew`, "Scan again", "Take photo".
Callers: `scanMachineLabel`, `scanLabelOffline` (form), `scanMachine` (gym page),
`routineScanMachine`, `routineMachineCount` (routine setup).
New identifiers: `identifiedManufacturer`, `identifiedModel` (round 1), `scanCancel`, `scanDone`, `scanAnother`, `scanManual`, `scanGenericToggle`,
`scanDuplicate`, `scanExerciseCount`, `scanChangeExercises`, `correctModel.option.<displayName>`,
`correctModel.none`, `correctModel.catalog`, `correctModel.scope.futureOnly`,
`correctModel.scope.applyToPast`, `correctModel.commit`.
Changed: the sheets' navigation bars are gone, so tests find Cancel by `scanCancel` (was
`navigationBars["Scan Equipment"]`); routine setup's scan ends on the Added step (`scanDone`)
instead of the form's `saveMachine`.

## New / changed visible strings

New: "Scan Machine" (sheet title; was "Scan Equipment" / "AI Proposal"), gym chip "<gym> · N",
"The full photo, including any people or screens in frame", "The exercise catalog", "Photo not
saved by the app", "Billed to your OpenAI API key", "Camera access is off", "Choose a catalog
model", "Matches catalog", "New model", "N matches", "Saved without a model", "Generic", "Use
catalog match", "Use new model", "Read on the machine: …", "Already at <gym> as “<label>”", "Add
to <gym>", "Use This Machine", "Added to <gym>", "N machines", "Done", "Scan another machine",
"Suggested", "N/6", "Search exercises", "Read Label" (was "Scan Label"), "Current", "Catalog
Model", "Future Workouts Only" / "Apply to Past Workouts Too" as tiles, "Today", "N workouts · N
sets", "Change the model in N past workouts?".
Changed: "Take photo" / "Flash" become icon buttons with those accessibility labels; "Use this
equipment" → "Add to <gym>" / "Use This Machine"; the footer "Matches catalog: …" / "Will add new
model: …" / "Multiple catalog identities match…" / "Saved as this gym's machine…" become the
result's stamp and lines; "Correct model" row → the model list; the correction footer "Choose
whether existing workout snapshots…" → the scope tiles.
Removed: "AI Proposal" title; the "Equipment" section header; "Change exercises" as a pushed
plain list (now the picker above).

## Tells (ios-design step 4)

- Same container on everything: absent — panels only for groups (the consent facts, the result's
  photo + outcome + identity, the candidate list, the correction header, the model list, the
  scope tiles); titles, the name field and the pinned commands sit on the ground.
- Chips: deliberate — the equipment-type tag and Custom are information; the generic toggle is
  one quiet chip; the picked exercises are removable chips.
- All-caps labels: absent.
- Middle-dot metadata: deliberate for the gym chip ("Iron Temple · 16") and the rewrite count.
- Accent everywhere: absent — violet fills only the shutter / the step's one filled command; the
  sweep and the instrument use the live colour as a state.
- Equal full-width blocks: absent — the photo leads every photo step; the scope tiles are a
  deliberate equal pair (equal options, equal size).
- Phone-sized website: absent. First viewport: result = photo, stamp, identity, name, pinned Add.
- Control dressed as primary: absent — Take another photo, Choose a catalog model, Scan again
  are quiet capsules; the disabled Correct Model is neutral.
- Only survives default size: answered by the AXL captures (titles move into the content, the
  secondary command leaves the pinned bar and ends the scroll, the scope tiles stack).

## Tests (planned)

- Unit `ScanMachineTests`: label prefill (edited label kept; catalog match → movement name;
  generic keeps the AI label); add resolves catalog / new model (user model with the exercises,
  not seeded) / ambiguous and generic model-less with instance exercises; duplicate lookup
  ignores archived machines and other gyms; suggested exercises; correction impact (distinct
  workouts, completed sets, other machines excluded) and suggestions order.
- UI: `AskAIUITests` updated (Cancel by `scanCancel`; routine setup ends on `scanDone`); a new
  `FloodlightScanUITests` capturing consent, no key, camera, identifying (slow fixture), error,
  result ×4 identities, Added, change exercises, Read Label viewfinder/results, Correct Model
  (picked, scope tiles) — light/dark × Default/AXL; flows: gym page Scan Machine adds directly
  and the count moves; Scan another machine returns to the camera; correction with past workouts
  asks first and rewrites; future-only leaves history.
- `ScanMachineLabelUITests` (both), `CoreLoopUITests`, `GymsFlowsUITests`, `MachineDeletionUITests`
  as neighbours.

## Verification

Runner `/tmp/wt-floodlight/scan-run.sh <name> build|test …` (fresh derived data
`/tmp/wt-floodlight/dd-scan-test`, `-collect-test-diagnostics never`); logs, `.exit` files and
result bundles `/tmp/wt-floodlight/results/scan-*`; screenshots exported with
`/tmp/wt-floodlight/scan-export.sh`.

- `scan-unit-1` (exit 65): the new test file did not compile (`[a, b].forEach { insert }` over
  mixed model types). Fixed.
- `scan-unit-2`: **exit 0 — 49/49** (`ScanMachineTests` 11, `AIGymTests`, `EquipmentLifecycleTests`,
  `MachineCreationTests`), built from fresh derived data (app + tests).
- `scan-build-1`, `scan-build-2`: exit 0 (build-for-testing after the sheets).
- `scan-ui-1`: **exit 0 — 7/7** FloodlightScan light-default captures (scan, outcomes, Read
  Label, correction) and the three flows (direct add, future-only, past asks then applies). The
  captures showed a layout bug no assertion caught: the aspect-filled photo laid out at the
  fixture photo's own width and pushed the identifying, error and result columns off the screen.
  Fixed in `ScanPhotoTile` (the tile sets the size; the photo fills it in an overlay). The Read
  Label viewfinder was shot mid-presentation (faded); the test waits for the sheet to land. The
  454 s of the first test was a cold simulator launch (a Spindump attachment at launch), not the
  sheets.
- `scan-ui-2` (exit 65): the whole `FloodlightScanUITests` class, **17/19**. The two
  AccessibilityL correction captures failed ("Timed out while evaluating UI query"; the app never
  went idle after Correct Model opened): **a layout loop** in the timeline, ported as-is from the
  prototype — the "Today" label was centred under a MEASURED tick with an alignment guide, and at
  AX sizes the label is wider than the dots before the tick, so it widened the stack, which moved
  the tick, which moved the label. The prototype's own AXL capture used `simctl` screenshots,
  which never wait for idle, so it went unnoticed there. Fixed: the tick's x is computed from the
  dot count; only the label's own width is measured. Captures reviewed (light/dark ×
  Default/AXL): fixed the Read Label viewfinder in light appearance — its brackets, status and
  photo button took the sheet's LIGHT colours on the black camera (the dark override applied via
  `.environment` reaches child views, not the view's own properties); it now reads the dark look
  explicitly.
- `scan-ui-3` (exit 65): void — a second copy of the run collided with the first in the same
  derived data ("database is locked"); both stopped, rerun as `scan-ui-4`.
- `scan-ui-4` (exit 65 — **46/55**; paused mid-run by the user, then read): the correction ×4
  (incl. both AXL — the layout-loop fix holds) and Read Label light ×2 recaptures, CoreLoop 9/9,
  GymsFlows, MachineDeletion, ScanMachineLabel scanning, AskAI default flows incl. routine setup
  adding two machines directly and the offline error re-arming the shutter. 9 failures, all test
  mechanics of the new chrome except two:
  - AX identity ×4, AX generic scan, AX routine scan: `reach(use)` wants the button above a
    tab-bar margin; the commit is pinned at the sheet's foot → `pinned(use)`.
  - Create-new ×2 (`ScanMachineLabelUITests`, AskAI manual suggestions): the tap on "None of these
    — create new" landed on the pinned **Use This** and accepted the preselected model (the row
    ends the list, half under the bar — ticket 06's lesson). The tests scroll it clear first.
  - Edited label: the name field (y 763–788) starts under the pinned "Use This Machine" on a
    catalog match; a tap there commits the sheet. The test scrolls it clear first (`scan-ui-6`
    exit 65 showed the frame; `scan-ui-7` **exit 0**).
- `scan-ui-5` (exit 65, 8/11): all AX identity tests, AX generic scan, manual suggestions and both
  ScanMachineLabel tests pass. Still failing: `testAllThreeGeneratedTemplatesInPopulatedListAccessibility`
  and `testScanMachinesDuringRoutineSetupAccessibility`, both stalling on the AI routine FORM
  (reaching `routineEquipment.dumbbells` / `routineAddGym` after the keyboard is dismissed),
  before any scan screen. **Pre-existing:** `scan-baseline-1` ran both on the unchanged ticket-06
  tip (`/tmp/wt-floodlight/gyms`, `d45d5c5`): **exit 65, the same two failures at the same step**.
  They passed in ticket 06's `gyms-ui-1`, so this is environment drift on the simulator or a
  flaky reach, not ticket 07; left for the AI routine area (ticket 01 area 9). The default-size
  routine scan (direct add ×2, counts, preferences kept) passes.
- `scan-unit-3`: **exit 0 — 66/66** (`ScanMachineTests` 11, `AIGymTests`, `EquipmentLifecycleTests`,
  `MachineCreationTests`, `CatalogMatcherTests`) from NEW derived data
  (`/tmp/wt-floodlight/dd-scan-clean`) — the clean-build check on the final code.
- **Every targeted test has passed in its final form** (FloodlightScan 19/19 across `scan-ui-2`
  + `scan-ui-4` on the final product code; the rest in `scan-ui-4`/`-5`/`-7`) except the two
  pre-existing AX routine-form tests above.
- Captures: `../captures/07/` (90 PNGs): consent, camera, identifying, result (catalog match,
  generic toggle, new model, ambiguous, generic, uncertain), error, no key, Change exercises,
  Added, Read Label (viewfinder, results), Correct Model (open, picked, the past-workouts
  question) — light/dark × Default/AXL; from `scan-ui-2`, with the correction and light Read
  Label shots from `scan-ui-4` (after their fixes). Contact sheets:
  `/tmp/wt-floodlight/results/scan-sheets/final-*.png`.
- Noted, deliberate: on a catalog match with the duplicate warning, the first viewport shows the
  photo, the stamp, the identity and the warning; the name field is one scroll away.
- Not exercised: the real camera and a real Terra call (fixtures only), VoiceOver by a person,
  Reduce Motion by a test (each animation's gate read in code: stamp, sweep, instrument, flow dot,
  flash, count-up, timeline, shake).

Scope (DEVELOPMENT: new feature + shared sheets — the scan sheet opens from the gym page, the
machine form, mid-workout Add Machine and AI routine setup; the correction sheet from the gym
page and machine page): build; unit tests for the new Domain rules and the identification and
lifecycle neighbours; every scan/correction UI flow above; captures light/dark × Default/AXL.
Full UI suite deferred to the whole-redesign release candidate (ticket 01 step 4). Simulator
WT-Floodlight (iOS 27.0); logs, exits and result bundles `/tmp/wt-floodlight/results/scan-*`.

## Progress

- 2026-09-27: resumed in a fresh session; verified branches (scan = gyms tip `d45d5c5`, pushed,
  clean; main `a0364f2`; nothing merged or installed). Read the prototype Scan area, the real
  scan/correction code and `AskAIUITests` / `ScanMachineLabelUITests`; prototype captured into
  `../reference/prototype-scan/`. User decisions 1–4 recorded. Ticket written (`d0f1bef`).
- 2026-09-27: Domain `ScanMachine` / `ModelCorrection` (+ `EquipmentIdentityResolution.exactMatches`)
  with `ScanMachineTests`; the Scan pieces (`Features/Gyms/Scan/`), the Scan Machine sheet in both
  modes, Read Label, Correct Model, the exercise picker (also the form's "Choose exercises");
  the gym page and routine setup add directly, "Choose a catalog model" opens the machine form
  once the scan sheet has closed (`a637e62`). `AskAIUITests` updated (Cancel by `scanCancel`,
  routine scans end on `scanDone`, the error's Take another photo re-arms the shutter); new
  `FloodlightScanUITests` (16 captures + 3 flows).
- 2026-09-27: paused by the user mid-verification, resumed; verification complete (above).
  Next: Codex review 07 in a visible Orca terminal (prompt `../codex-review-07-prompt.md`;
  report `../codex-review-07.md`).
- Decision record: user decision 1 changes where a Scan Machine scan is confirmed (the sheet's
  Add, not the form) — D56's confirmation stays (Add is the tap). Record it with the D54 entry
  before merge, as ticket 05 did for D47.

## Codex review 07 — response (round 1)

Report: [codex-review-07.md](../codex-review-07.md) — not clear; three medium. All accepted.

1. **Clearing Maker or Model removed both editors.** An empty field resolves to generic for a
   moment, and the editors were shown only for a specific resolution. They now follow the AI's
   specific answer, whatever it currently resolves to; only "Use generic identity" hides them.
2. **Changing the identity could make the two modes save different names.** The movement
   prefill ran once, at the answer. `ScanMachine.reconciledLabel` (unit test
   `anUneditedNameFollowsTheIdentityAndATypedOneStays`) now runs whenever the catalog match
   changes: an unedited name follows the current match's movement, or returns to the AI's own
   label; a typed name is kept. So the field shows what direct Add saves and what the form's
   own model default produces. UI test `testEditingMakerAndModelKeepsTheFieldsAndTheNameFollows`
   (form mode): clear Model → both editors remain, "Generic"; type "Insignia Series Shoulder
   Press" → "Matches catalog", the name follows, the form receives the same name and model.
3. **Correction tests did not prove the history boundary.** They now read the History detail's
   snapshot equipment line ("Chest Press 2 · <model at log time>", D23) before and after:
   future-only leaves it; cancelling the question and then the sheet leaves it and the machine's
   model; confirming rewrites it to exactly "Chest Press 2 · <chosen>". "Sheet closed" now
   means the sheet's own commit is gone (the machine page exists under the sheet too).
   Writing them showed **the earlier passes of `testPastCorrectionAsksThenApplies` were
   vacuous**: the scope tile's accessibility label is also "Apply to Past Workouts Too", so
   `app.buttons["Apply to Past Workouts Too"]` tapped the TILE, which only dismissed the question
   (iOS 27 shows it as a popover on the tile, with no Cancel button). The test now selects the
   question's button by excluding the tile's identifier, and dismisses the question by a tap
   outside it. The product was not changed for this (a speculative delayed dismissal was tried in
   `scan-ui-13` and reverted once the cause was found).

Verification (round 2): `scan-ui-8` (exit 65): `ScanMachineTests` 11/11, the maker/model test
and future-only passed; the past test failed on test mechanics (a tab tap during the sheet's
dismissal; a Back tap lost; then the label collision above) — `scan-ui-9`…`-14` isolate them;
`scan-ui-14`: future-only, `testCaptureCorrectionLightDefault` and `…DarkAccessibility` pass;
`scan-ui-15`: **exit 0**, `testPastCorrectionAsksThenApplies`. The fixes move no captured pixel
except the result's maker/model fields, whose visible default state is unchanged.
