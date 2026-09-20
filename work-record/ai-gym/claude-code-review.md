# Claude independent code review — AI gym recognition and weekly routines

Reviewed: implementation **7dc1622** against base **17e42a0**, for `work-record/ai-gym/spec.md`
(including "Implementation decisions after independent spec review"), tickets 01–05, and my earlier
`claude-spec-review.md`. Author is Codex; this is the T6 independent review. Read-only: every
changed source file and its callers were read; **no build, simulator, test or network job was run**
(the implementer's jobs own the machine). Build/unit results quoted by the implementer were not
re-verified here. **UI captures and live-feature verification are pending and are not cleared by
this review.**

Accepted as decided, not re-litigated: Terra only; AI-first label/whole-machine identity with
confirmation; exact normalized brand+model comparison done locally, no model IDs sent or accepted
(S3/U1 preference rejected by user choice); generic machine keeps `model = nil`; Ask AI below
Templates; weekly mixed routine; extras checklist; no AI weights or guides.

**Verdict: not clear to merge.** The safety spine is sound (see "Checked, no finding"), and no
finding corrupts existing history. H1–H4 are defects in the new flows that should be fixed and
re-reviewed before the UI/live pass; M-items should be fixed or explicitly accepted in ticket 05.

## High

### H1. Day editor mutates an index-based `ForEach` — probable crash on Remove / reorder
`AIRoutineSheet.swift:168-178` and `:184-188` iterate `day.strength.indices` / `day.cardio.indices`
with `id: \.self` and hand `$day.strength[index]` bindings to Pickers/Steppers, then call
`remove(at: index)` and `.onMove` on the same array. SwiftUI re-evaluates the removed row's
bindings against the shortened array → index out of range. The draft week (a paid generation) is
lost. The cardio `ForEach` also emits three sibling views per index without a container.
Fix: give `AIRoutineStrength`/`AIRoutineCardio` a local `id` (not encoded to the wire — wrap in an
editor row type) and use `ForEach($rows)`, as `CardioPlanEditor.swift:8` already does. Add a UI test
that removes the first of two exercises and reorders. Confirm in the pending live UI pass.

### H2. "Save templates" can run twice → a duplicated week
`AIRoutineSheet.swift:50,151-157`: `save()` is synchronous, then `dismiss()`. The toolbar button
stays tappable during the cover's dismissal; a second tap inserts another 1–7 templates (duplicate
names are deliberately legal, so nothing stops it). Fix: `@State saved` guard set before the call,
button `.disabled(saved)`; unit-test that calling the guarded path twice yields one week.

### H3. The user's own edits are validated — and reported — as AI output
`AIRoutinePersistence.save` re-runs `validated(for:)` (`AIRoutine.swift:137`) on the edited week:
- The exercise Picker (`AIRoutineSheet.swift:170-172`) offers every option, including ones already
  in the day → duplicate → Save fails with "AI returned an incomplete or invalid result."
- Same message if the user removes every row of a day, clears a name, or makes two names equal.
- The 125 % duration cap (`AIRoutine.swift:110-112`) blocks a user who deliberately adds a set:
  "The suggested routine exceeds your session length. Try again…" — there is nothing to try again.
Spec: sessions "can be reviewed/edited before saving". Fix: split validation — AI-response rules
(count == days, duration estimate) apply at generation only; save-time rules are structural
(known IDs, bounds, non-empty day, non-empty name) with user-facing messages naming the day; filter
the Picker to unused options plus the row's current one. Tests for each edited-state outcome.

### H4. Exact-model path can create duplicate or blank user-space models at Add
`GymsView.swift:713-717` creates an `EquipmentModel` whenever `identified.identity == "specific"`
and no unique match exists. Problems:
- `matches.count > 1` (two rows with the same normalized brand+model — e.g. a user-space copy of a
  seeded model) is treated like zero matches and a **third** copy is inserted. Each copy is its own
  D1 "same model elsewhere" layer, so identical machines split model history.
- The proposal's Manufacturer/Model fields are user-editable (`IdentifyEquipmentSheet.swift:112-113`)
  but never re-validated: clearing one still saves a model with an empty/whitespace string
  (`validated()` only runs on the raw AI reply, `:168`). Values are stored untrimmed.
- The only notice that Add will create a catalog model is a grey "Brand Model" line under
  Exercises (`GymsView.swift:564-566`); a matched catalog row is not indicated at all.
- The match rule exists twice (`IdentifyEquipmentSheet.swift:93-100`, `GymsView.swift:617-621`) and
  has no unit test (unique / ambiguous / none / case-diacritic-punctuation).
Fix: one Domain resolver returning `.catalog(model) | .ambiguous | .new(brand, model) | .generic`,
unit-tested; ambiguous → model-less with a plain note (never create); require trimmed non-empty
brand and model else demote to generic; show "Matches catalog: …" / "Will add new model: …".

## Medium

- **M1. Planned cardio decodes all-or-nothing and fails silent.** `PlannedCardio.swift:23-24,29-30`
  use `try?` both ways: one unknown `activity`/`unit` raw value (renamed case, newer build's data)
  makes the whole array read as `[]`, and the next setter (editor Save, `startPlannedCardio`)
  overwrites the stored plan. State the consequence in a comment (AGENTS rule) and decode
  leniently per element (store raw strings, drop/flag unknown rows, never rewrite on read failure).
  Related: `ExportSnapshot.swift:198,265` embed the storage struct directly, so any later change to
  `PlannedCardio` silently changes export schema 11; give export its own DTO.
- **M2. "Suggest exercises with AI" now reaches OpenAI outside both consents.**
  `AskAI.swift:121-125` + `GymsView.swift:1062,1169`: plate text, typed brand/model and the full
  exercise list go to Terra on tap. It has an inline disclosure, but neither revocable toggle
  stops it, the Settings footer no longer mentions it, and its UI test
  (`testSuggestExercisesTicks…`) was deleted while the feature stayed — the Claude-era prompt and
  the re-wrapped parse (`AskAI.swift:188-189`) are untested against Terra. Gate it behind a consent
  flag (or remove it) and restore a fixture test.
- **M3. Recognition sends user-created exercise names.** `IdentifyEquipmentSheet.swift:155` sends
  every `Exercise`; the routine path deliberately restricts unseeded ones (`AIRoutine.swift:37`).
  Consent copy says "the exercise catalog". Send seeded exercises (plus, if wanted, user ones with
  the copy amended). Also `identify()` (`:151`) does not re-check consent itself — add the same
  guard `generate()` has (`AIRoutineSheet.swift:117`).
- **M4. Migration test reads only one of the new array attributes.** `AIGymTests.swift:41-66`
  asserts `recognizedExerciseIDs` but never touches `ExerciseEntry.plannedRepsBySet`,
  `WorkoutTemplate.confirmedEquipment`, `Workout.cardioPlanData` on migrated rows, and never runs
  `ExportCollector` over the migrated store — export reads the new field on **every** old entry
  (`ExportCollector.swift:349`). Add those reads plus an export round-trip to the fixture test
  before any phone install.
- **M5. Test gaps named in the tickets' own scope.** No test for rest precedence
  (`RestTimer.swift:113`: override → planned → global; warmup excluded); none for 401/429/timeout
  mapping or cancellation; `-uiTestTerraNeedsConsent` (`TerraAccess.swift:10`) is defined but no UI
  test uses it, so the consent gates and revoke path are unexercised; planned-cardio start/link
  lives in the View (`ActiveWorkoutView.swift:60-73`) where it cannot be unit-tested — move it to a
  domain service (start once, link, refuse while another segment is unfinished) and test it.
- **M6. "Target: …" caption now appears on every templated entry** (`ExerciseEntryCard.swift:53-56`),
  including workouts from pre-existing templates. That is a change to the core logging card beyond
  the spec's listed surfaces; include default + AccessibilityL captures and get explicit acceptance.
- **M7. A planned target can be stuck at "Started".** If the linked segment is ended at once it
  has no recorded activity; the target keeps its `segmentID` (`ActiveWorkoutView.swift:66`,
  `:117-121`) and cannot be started again. Resolve "started" by looking the segment up; treat a
  missing/empty segment as not started. `cardio.start` failing also returns silently (`:63`).

## Low

- `WorkoutTemplates.swift:95,111`: the template service throws `TerraError.invalidResponse` ("AI
  returned…") for invalid manual cardio, coupling core templates to the AI error type. Add a
  `WorkoutTemplateError` case.
- `TemplateEditorSheet.swift:95-96`: rest 0 ⇄ nil. An AI rest of 0 s means "no timer" until any
  edit turns it into "exercise default". Decide one meaning (suggest validating rest ≥ 15 or
  storing nil for 0 at save).
- `Models.swift:172`: `model?.exerciseIDs ?? recognized` hides instance links behind a model with
  no links (possible for user-space models); same shape gives the proposal screen a dead end
  (`IdentifyEquipmentSheet.swift:101,120,129`). Seeded catalog verified: 0 of 1877 models are
  link-less, so this is user-space only. Fall back when the model's list is empty.
- `GymsView.swift:710,724`: `Array(Set)` order is random per save → export churn. Sort.
- `AIRoutine.swift:146`: `confirmedEquipment` mixes equipment and cardio raw values in one array.
- `PlannedCardio.swift:9`, `CardioPlanEditor.swift:14`: distance target defaults to km regardless
  of the Settings unit system.
- `TerraAPI.swift:47`: 429 billing vs rate limit not distinguished (S7); acceptable copy, note it.
- `AIGymTests.swift:14-26`: `exportWireFixturesForLiveSmoke` writes to `/tmp` on every unit run and
  asserts nothing — move to tooling. `:27-37`: the GPS assertion is vacuous (source has no GPS).
- Old `anthropic-api-key` Keychain item is never deleted; dead Anthropic client code remains
  (`PlateTranscription.swift`, `AskAI.swift`).
- `IdentifyEquipmentSheet.swift:154`: full-size JPEG render on the main thread before `busy` paints.
- `AIRoutineSheet.swift:48`: Cancel discards a generated week with no confirmation.
- `ExportSnapshot.swift:313` brace on the property line; schema comment lacks an "11 —" entry (`:55`).
- Records: `docs/STATE.md` still says "No new product code… claimed"; tickets 02–05 say
  `ready-for-agent` with "Pending" evidence; D56 remains prose rather than D56/D57/D58 rows.

## Checked, no finding

- Transport: `store:false`, single request, no retry, 60 s timeout with visible cancel, key only in
  the Authorization header, response bodies never surfaced in errors, refusal/incomplete rejected.
- Cancel/rescan/dismiss: task cancelled **and** late replies dropped by token in both sheets.
- Consent: two versioned UserDefaults flags, revocable in Settings, revoke cancels in-flight work;
  bypass requires `-uiTestReset` via `fixtureIsEnabled`. Missing-key Settings reachable in both flows.
- Photo: upright re-render ≤1568 px, no original bytes, nothing persisted; plist strings, Settings
  and SPEC now truthful. `.gitignore` covers the key; no key-shaped string in the reviewed diff.
- Identity: generic never creates a model; AI supplies no model UUID; nil-model machines get no
  model layer (test present); all four S1 readers use `supportedExerciseIDs`; links editable.
- Templates: editor round-trip and all four drift resolutions preserve cardio, rest, equipment and
  now supersets; start snapshots plans with fresh IDs; no auto-started sensor session; an
  unstarted-plan-only workout finishes as `discardedEmpty`; plans never enter performed metrics.
- Routine: no gym name, labels, history or HealthKit in the request; profile not persisted; schema
  has no load/prose fields; whole-plan rejection; isolated-context single save.
- Schema/export: additive optional/defaulted fields only, no new entity, no enum in a `#Predicate`;
  export 11 is append-only and includes instance-linked exercises in the D28 reference set.

## Not verified here

Build, the full unit run with the new fixture, UI tests, default/AccessibilityL captures, live
Terra accuracy, template grid refresh after the isolated-context save, and anything on the phone.
Fixes to H1–H4 and chosen M-items need a follow-up cross-review before any merge to `main`.
