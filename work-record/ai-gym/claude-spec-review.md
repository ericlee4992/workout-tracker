# Claude independent spec review — AI gym recognition and weekly routines

Reviewed: `work-record/ai-gym/spec.md`, tickets 01–05 and DECISIONS D56 at **14ca62c**, against
source at that commit, AGENTS/STATE/DEVELOPMENT, DECISIONS D1–D54/T1–T8, and the scanner
cross-reviews (`work-record/scanner-accuracy/codex-review-02…05d`, `photo-machine-capture/codex-review{,-2}`).
Read-only: no build, simulator, test or network use. Author of the spec is Codex; this is the T6 review.

**Verdict: the product scope matches what the user authorized, but the spec is not yet
implementable safely. Fix S1–S8 in the spec/tickets before ticket 02/03 code starts.** Ticket 01
can start now with the S6/S7 amendments. The five tickets are 1–2 sentences each; the failure
modes below are exactly the ones this repo's earlier reviews kept finding (absent callers,
rebuild-erases-fields, export omissions, whole-frame leaks, untracked tasks), so each ticket needs
the named acceptance tests added, not just the fix sentence.

Scope check against the user's authorization — all present: Terra only, private trial, one-step
label-or-whole-machine with confirm, generic machine without a false model, optional Ask AI below
Templates, weekly lifting + cardio editable routines, supplemental equipment checklist, no AI
weights or guides. No out-of-scope additions found.

## Blocking — correctness and history

### S1. "Model-less machine with confirmed exercise links" has no storage and no caller (ticket 02)
`MachineInstance` (`Models.swift:166-200`) has no exercise links; every reader resolves through the
model: `WorkoutSession.exercisesFor(machine:)` (`WorkoutSession.swift:272-279`),
`MachineBrowseRow.init` (`CatalogBrowsing.swift:468`), the New Machine default label/preset logic
(`GymsView.swift:633,666`), and `AddByMachineSheet.swift:115-117` (model-less → full picker). As
written, a confirmed generic chest press would save, then behave as an unlinked "Uncategorized"
machine — the confirmed mapping silently does nothing (this repo's recurring absence-of-a-caller bug).

Fix, in the spec: add `MachineInstance.exerciseIDs: [UUID] = []` (scalar, defaulted, CloudKit-safe,
same shape as `EquipmentModel.exerciseIDs`). Define one resolver — model links first, then instance
links, de-duplicated, in order — and route **all four** readers above plus the routine generator's
"saved machines contribute exercises" through it. Instance links must be editable on the machine's
edit screen (the user owns the ticks; an AI mistake must be fixable without delete/recreate).
Acceptance tests: machine-first add auto-fills for a one-link generic machine; chooser for several;
browse grouping shows its body area; links survive model correction to/from nil.

### S2. Generic machines must never get a synthesized `EquipmentModel` (tickets 02, D35 interaction)
D35's existing create-new path makes a user-space model from OCR text. If the AI path reuses it with
AI text ("Generic Chest Press"), two generic chest presses at different gyms that the user (or a
de-dup) attaches to one row share `snapshotModelID`, and D1's "same model elsewhere" layer plus
`.model` record keys (`RecordsMath.swift:258-260`, `PreviousPerformance.swift:198,235,304`) conflate
them — the exact harm D4/D33 exist to stop. Verified good news: all three sites use `if let modelID`,
so `model == nil` correctly yields machine + exercise layers only, no shared nil bucket.

Fix: state explicitly that the AI path creates a user-space model **only** when brand and model text
are both visibly printed (evidence quoted back in the proposal) and the user confirms; otherwise
`model = nil`. The AI's descriptive guess ("chest press, plate-loaded") may prefill the machine
**label** only. Test: two AI-generic machines → distinct machine keys, no `.model` key, no
cross-machine prefill (D11).

### S3. "Exact catalog identity" must be resolved by the app's matcher, not by a model-returned UUID
The catalog has **1877 models** (`SeedCatalog.json` v5). Sending them per photo is ~75 KB of prompt
and exceeds strict-schema enum limits; letting the model free-type a UUID is unvalidatable. D53's
measured rule — the model transcribes, `CatalogMatcher.rank` decides, D33's three-part preselect
gate and "none of these" stay — had zero wrong preselections on the corpus, and the scanner reviews
(02, 02b, photo-capture 1–2) show every shortcut around the matcher preselected a wrong UUID.

Fix: the recognition response schema is `{visible_brand, visible_model, visible_lines[],
evidence: "label"|"machine_only"|"unreadable", machine_kind, exercise_ids[] (enum of the 90 sent),
needs_new_angle}`. Brand/model/lines go through `CatalogMatcher.rank` unchanged; preselect only
under D33; `evidence != "label"` can never preselect a catalog row (a whole-machine silhouette is
not identity evidence — Life Fitness siblings score 75–79% on *text*). D56 should say this in one
sentence so D33 is amended, not bypassed. 90 exercise ids fit a strict enum (existing
`ExerciseProposalAPI.schema` pattern; keep its parse-side validation and cap of 6).

### S4. Template edits and drift updates will erase the new cardio/rest targets (ticket 03)
Both writers rebuild items from a lossy intermediate:
- `WorkoutTemplateService.replaceItems` (`WorkoutTemplates.swift:196-216`) deletes every item and
  recreates from `TemplateItemDraft`, which carries only exercise, reps, superset.
- `TemplateDriftService.apply` (`TemplateDrift.swift:177-190`) deletes every item and recreates from
  `TemplateDriftItem` (it already drops `supersetGroupID` on this path — pre-existing, worth a
  separate note in deferred-work).
So after ticket 03, opening the editor and tapping Save, or choosing "Update template" at finish,
silently strips rest targets and **deletes every cardio item**. Also `create`/`replaceItems` throw
`noExercises` for a cardio-only day, and `saveAsTemplate`/`workoutSnapshot` ignore cardio.

Fix: spec the shape. Recommended: `TemplateItem` gains optional `restSeconds: Int?`,
`cardioActivityRawValue: String?`, `cardioTargetSeconds: Int?`, `cardioTargetMeters: Double?`,
`cardioTargetUnitRawValue: String?` (item is lifting iff `exercise != nil`, cardio iff activity raw
value set; one `order` sequence keeps mixed-day ordering). Extend `TemplateItemDraft` to an enum or
carry all fields; drift compares **lifting rows only** and its rebuild must carry cardio items and
rest targets through untouched; "at least one lifting or cardio item" replaces `noExercises`.
Acceptance tests: edit-save round trip preserves every new field; each of the four drift
resolutions preserves cardio items and rest; cardio-only template creates, starts, exports.
Raw-value strings (not enums) in storage and **no enum captured in a `#Predicate`** (DEVELOPMENT:
launch crash).

### S5. Planned cardio inside a running workout is undefined, and finish semantics can lose it (ticket 03)
`WorkoutTemplateService.start` only creates `ExerciseEntry` rows. The spec says "expose planned
cardio and require explicit Start" but not where the plan lives. Reading it live from
`sourceTemplateID` breaks when the template is edited/deleted mid-workout (D23 froze
`sourceTemplateName` for this reason). Creating a `CardioSegment` up front is worse:
`makeContainer` recovery (`Models.swift:864-867`), HealthKit session start and summary would treat a
plan as a performed segment.

Fix: a small additive `PlannedCardio` model on `Workout` (id, order, activity raw, target
seconds/meters/unit, `startedSegmentID: UUID?`), created at template start, never read by
summary/records/export-as-performed; Start calls the existing `CardioSession.start` once and stamps
`startedSegmentID`. Rules to state: one running segment at a time (existing invariant); unstarted
plans are dropped at finish and do not keep an otherwise empty workout alive (A2 `discardedEmpty`);
targets never prefill `manualDistanceValue` or elapsed time; drift prompt ignores unstarted cardio.
Add `PlannedCardio` to `WorkoutTrackerStore.modelTypes` and export (append-only).

Rest targets: D22 says per-exercise override → global, "TemplateItem carries no rest". State the new
precedence explicitly: **template-item rest (for entries started from that item, snapshotted onto
the entry as `plannedRestSeconds`) → per-exercise override → global**; heart-rate rest mode (D43)
still wins where the exercise uses it; drop sets still start no timer (D26). Without the entry-level
snapshot the timer has no way to find the template value (`RestTimer.swift:100-115` reads only
override/preferences).

## Blocking — privacy and consent

### S6. Shipped strings become false the moment a whole frame is sent (tickets 01/02)
- `INFOPLIST_KEY_NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription`
  (`project.pbxproj:627,630,661,664`): "The photo is read on device and discarded."
- `AskAISettingsSheet` footer: "never the whole photo — to Claude with this key".
- `docs/SPEC.md:28,101` (on-device / "offline except opt-in Ask AI taps (D53)").
Codex-review-05b already flagged SPEC contradicting the network features once. Fix: ticket 01 owns
rewriting all three; usage strings must say a photo may be sent to OpenAI when you choose AI
identification. Changing build-setting plist keys needs a clean build and inspection of the built
plist (DEVELOPMENT, Plists).

### S7. Consent, key and legacy-path rules need to be concrete (ticket 01)
- **Consent storage:** spec says "feature-specific and revocable" but not where. Use two
  `UserDefaults` (device-local, not SwiftData — consent must not sync via a future CloudKit store or
  ride in the export) flags with a consent-copy version; bump re-asks. Revoking must cancel any
  in-flight request. Deleting the key does not imply consent and vice versa. Per D45's corollary,
  both must be reachable from Settings **and** from the missing-key/missing-consent screen in each
  flow; add UI tests for the reach paths, not just the gate.
- **Old Anthropic path:** D56 says "Terra only". Decide and write down: remove the D53 box-crop
  Claude escalation and "Suggest exercises with AI", or keep them. Recommended for one model/one
  consent story: route both existing protocols (`PlateTranscriber`, `ExerciseProposer`) to the new
  client or delete them; delete the `anthropic-api-key` Keychain item on first launch of the new
  build so an unused secret is not left on the phone; keep `Config/anthropic.key` tooling untouched.
  If kept, Settings must show two keys and two disclosures — not recommended.
- **Key hygiene:** new account name under the same service, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
  (existing pattern is right), never echoed back, in-memory stand-in under `-uiTestReset`. Error
  sanitizing must strip the response body's echoed request and any `Authorization` header from
  logs/`localizedDescription`; test that a 401 body containing the key prefix is not surfaced.
  The Mac tooling key path must be in `.gitignore` **before** the file exists in any checkout; add a
  test/CI grep for `sk-` in tracked files.
- **Model id:** `gpt-5.6-terra` appears only in the spec; I cannot verify it offline. Ticket 01's
  first live step should list models with the key and record the exact id; keep it one constant.
  STATE already records the first live call failing `429 insufficient credit` — the client must map
  that to a readable "billing" error distinct from rate-limit, and **not retry** either.

### S8. Whole-frame send: state the image pipeline so metadata and scope are provable (ticket 02)
Existing `LabelCrop.jpeg` re-renders pixels through `UIGraphicsImageRenderer` → `jpegData`, which
drops EXIF/GPS; library photos from `UIImagePickerController` arrive as `UIImage` (no metadata
file). Spec should require that path (re-render, never pass through original `Data`/PHAsset bytes),
a max side (recommend 1568 px long edge for label legibility; measure on corpus) and a unit test
that the output JPEG has no `{GPS}`/`{Exif}` location dictionaries via `CGImageSource`.
Also state the things a whole-gym frame adds that a plate crop never had: **people and screens in
frame**. Consent copy should say so in plain words; nothing technical can remove them.
Request invariants to test (reuse the scanner's counting-ledger pattern, `AskAIFixtureLedger`):
zero calls before consent + explicit tap; one tap = one call; `store: false` present in the body;
rescan/cancel/dismiss cancels the `Task` **and** a late reply is dropped by request token (review
05 High, 05b Medium were both this); every new fixture flag goes through
`WorkoutTrackerStore.fixtureIsEnabled` (review 05 Medium). Timeout: the old 8 s was sized for a
plate crop on Claude; a full frame + reasoning model needs a measured value and a visible Cancel.

## High — routine generator (ticket 04)

- **R1. Machine-restricted eligibility.** "Saved active gym machines contribute supported
  exercises" must use the S1 resolver and exclude archived machines and archived gyms. With no gym
  selected, state the behaviour (recommend: checklist-only equipment). Bodyweight exercises are
  always eligible. Send `id | name | muscle group | equipment tags` only — no machine labels, gym
  name, city, notes, or history. Height/weight are optional, sent only if typed, and **not
  persisted** unless the spec says where (recommend: not persisted; no schema).
- **R2. Validation is the safety boundary; enumerate it.** Reject/clip: unknown or duplicate ids,
  exercises outside the sent list, 1–7 sessions and sessions == requested days, ≤ N items/session,
  sets 1–10, reps 1–50, rest 0–600 s, cardio seconds ≤ session minutes, distance bounds per
  activity, outdoor activities allowed only if the user ticked them, names trimmed/length-capped,
  any weight/load/instruction/free-text field → **schema has none** (`additionalProperties: false`)
  and parse ignores extras. Reps for `bodyweight` "most reps" exercises and assisted exercises are
  still just reps — fine — but the generator must never emit a load type or set type.
  Whole-response rejection vs per-item drop: recommend drop invalid items, reject a session left
  empty, and show "N items removed" so the user is not shown a silently thinner plan.
- **R3. Atomic save.** `WorkoutTemplateService.create` saves per template
  (`WorkoutTemplates.swift:88`). Add a batch create that inserts all, saves once, and on throw
  `context.rollback()`; test with a failing third template that zero templates exist afterwards.
  Name collisions with existing templates: allow (ids are identity) but suffix for the grid.
- **R4. "Planned equipment context" vs D6.** Spec wants generic portability *and* a record of the
  gym it was generated for. Concretely: `WorkoutTemplate.generatedForGymID: UUID?` +
  `generatedAt: Date?` (provenance only, exported). At start, D6 resolution is unchanged; an item
  whose exercise has no resolvable machine at the selected gym starts with `machine = nil` exactly
  as today and the detail screen shows a plain "no machine here" chip — never blocks start, never
  auto-substitutes. Do not store machine ids on template items (would reopen D6).
- **R5. Supplemental equipment checklist** maps to existing `EquipmentTag` cases + the
  `CardioActivity` list; no new taxonomy, no persistence beyond a device-local last-used
  convenience (UserDefaults), or none. Say which.
- **R6. No explanations** — the existing `ExerciseProposal.reason` pattern must not be copied into
  the routine schema; for recognition, "evidence" is a closed enum plus quoted visible text, not prose advice.

## High — migration, export, verification (tickets 03/05)

- **M1. Fixture gap.** Test fixtures are `LegacyStore.store` (5239ef2) and `PreCardio.store`. The
  phone runs **8c71d27** (post-cardio, export schema 10). Before any model change, generate a store
  fixture from 8c71d27-era code with templates (incl. supersets), a model-less machine, cardio
  segments and an unfinished workout, commit it, and add a migration test that opens it with the
  new schema and asserts old templates start identically (same entries/sets), machines keep
  `model`, and `exerciseIDs == []`. There is no `VersionedSchema`; this is inferred lightweight
  migration, so **every** new stored property must be optional or defaulted and new models fully
  optional-relationship. Run `LegacyStoreMigrationTests` for all three fixtures.
- **M2. Export.** Bump to schema 11, append-only: `Machine.exerciseIDs`; `TemplateItem` rest/cardio
  fields; `Template.generatedForGymID/At`; `plannedCardio` on workouts (or document it as
  deliberately transient — but D30 says nothing is silently dropped, so export it flagged). D28
  reference collection (`ExportCollector.swift:145-191`) must add instance-linked exercise ids or a
  seeded exercise referenced only by a generic machine vanishes from the backup. CSV: confirm no
  column is repurposed; cardio plans do not belong in the set ledger.
- **M3. Verification scope.** Ticket 03 changes workout lifecycle + persistence + template start —
  that is DEVELOPMENT's "broader suites / escalate" row, not "new feature". Spec's plan (full domain
  suite + targeted UI) is acceptable only if the targeted set names: template create/edit/start,
  all four drift resolutions, finish/discard-empty, replace-active-workout flow, cardio start/stop,
  export. Otherwise run full UI once at the integration tip. Record per-ticket scope in each ticket.
- **M4. Per-ticket review.** Tickets route all independent review to ticket 05. The repo's lesson
  ("worst defects were in the fix for the previous round") and the user's stored preference
  (ticket → build → review to clear → next) argue for a Claude review after 02 and after 03 at
  minimum, because 04 builds on both. Add that gate to tickets 02/03.
- **M5. Install.** Signing expires 2026-09-24 07:16 UTC and launch/history on the current install is
  still unverified (STATE). Spec correctly defers install; ticket 05 should additionally require a
  fresh export/backup **after** the user confirms the current build opens, before any schema-changing install.

## Medium — UI

- **U1. Scanner framing.** Current viewfinder is a plate-shaped box with ROI crop (SPEC:28, review
  03 orientation bug history). Whole-machine capture needs a stated composition: recommend one
  camera, box kept as a guide, and the AI path sends the full upright frame; on-device D33 read of
  the box still runs first at zero cost and, if it preselects, **no AI call is made** (keeps D53's
  measured on-device-first invariant and saves money). Spec currently reads as AI-always; confirm
  intent — "AI-first" in ticket 02's title conflicts with offline-usable manual/on-device paths.
- **U2. Proposal screen** must show: what was read (quoted text), catalog candidates with "None of
  these" (D33), generic path labelled plainly (e.g. "No model — this gym's machine"), editable
  exercise ticks, and nothing saved until Add on New Machine. "Needs a new angle" is a state with
  Retake and Enter manually, not an error alert.
- **U3. Ask AI row** below Templates: secondary style, not amber capsule (D54: two amber starts are
  already the deliberate maximum). Hidden vs disabled when no key: show it, route to key/consent
  (D45 corollary). Full-screen flow needs its own `workoutStartFlow`-free presentation (DEVELOPMENT:
  dialogs attached to covered List do not present).
- **U4. AccessibilityL** captures for: consent sheet, proposal, staged inputs, editable sessions
  with mixed lifting/cardio rows, template detail with planned cardio + rest caption, active
  workout planned-cardio Start row. `TemplateTargets.summary` is a frozen string (D54) — adding rest
  to it is a copy change; keep rest as a separate caption.
- **U5. Generation cancel/back:** leaving the staged flow cancels the request; returning never
  shows a stale plan (same token rule as S8).

## Low / documentation

- D56 is appended outside the decision tables and lists "D6/D22 expand" without the concrete new
  rules; after S3–S5 are settled, write them as table rows (D56 recognition, D57 template targets/
  rest precedence, D58 routine generator) so later agents can cite them.
- Spec line "exercise migration fixtures" is a typo for "exercise **the** migration fixtures" —
  make it M1's concrete requirement.
- Tickets lack the repo's usual sections (failed approaches, verification scope, review links).
  Expand each with the acceptance tests named above before handing to the implementer.
- `TemplateDriftService.apply` dropping `supersetGroupID` on rebuild is pre-existing; record in
  `deferred-work.md` or fix inside ticket 03 since the same function is being changed.

## Checked, no finding

- Nil-model history safety: `RecordsMath.swift:258`, `PreviousPerformance.swift:198,235,304`,
  `WorkoutSession.swift:867-873` all conditional — model-less machines cannot share a model layer.
- `correctModel(of:to:scope:)` already supports `nil` and past/future scope (D10) — reuse for
  "AI said exact, user later disagrees".
- Existing request-token + `askTask` cancellation and the counting ledger are sound patterns to copy.
- No HealthKit data in routine inputs; no calendar/coach/weights/guides in scope; additive-only
  schema intent; store=false; no hidden retries; private-trial key never in binary — all consistent
  with D5/D53 and the user's authorization.
