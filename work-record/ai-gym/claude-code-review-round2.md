# Claude independent code review, round 2 — AI gym fixes

Reviewed: fix commit **3f75187** (`ericlee4992/ai-gym-and-routines`) against **7dc1622**, for the
findings in [round 1](claude-code-review.md) (H1–H4, M1–M7, lows) and for regressions. Review
branch `ericlee4992/review-ai-gym-code-round2` is cut from 3f75187; round 1's report is already in
that history (52731d1) and the earlier review branch (09e9787) is untouched. Read-only: the full
fix diff and its callers were read. **No build, simulator, test or network job was run**; the
implementer's quoted results (build, 767 domain tests, routine-fix2 UI passes, live smoke) were not
re-verified here.

## Two separate verdicts

**Code-only clearance: CLEAR.** Every round-1 High and Medium finding is resolved in source, with
tests for each, and I found no regression that blocks. Remaining items below are Low and may be
fixed or accepted in ticket 05.

**Evidence / UI clearance: NOT GIVEN — still pending.** Required before merge to `main`:
1. Exit codes and TEST lines (not summaries) of the serial final-domain run and `integration-ui-v2`
   at the final source commit, recorded in ticket 05.
2. Default + AccessibilityL captures from the **latest** source for: photo consent, proposal
   (each of the four resolution banners), routine inputs, week preview, day editor, template detail
   with planned cardio/rest, template editor rest toggle + cardio targets, active workout planned
   cardio row, entry card "Target:" caption, Settings permissions (3 toggles). routine-fix2
   captures predate later changes and do not substitute.
3. Built-plist inspection of the two usage strings after a clean build (DEVELOPMENT, Plists).
4. Live recognition is accepted as a **fallible private-trial limitation** (g010 whole-machine
   miss); no accuracy pass is claimed or cleared. The confirm/edit/"uncertain" paths are what make
   that safe, so they must appear in the UI evidence.
No phone install is cleared: M5 of the spec review (current-build launch confirmation, fresh
backup) still stands.

## Round-1 findings — disposition

| # | Status | Evidence in 3f75187 |
|---|---|---|
| H1 index-based `ForEach` crash | **Fixed** | Rows are `Identifiable` with `id` excluded from `CodingKeys` (`AIRoutine.swift:129-142`); editor uses `ForEach($day.strength)` / `($day.cardio)` and removes by id (`AIRoutineSheet.swift:175-197`). UI test `testEditingGeneratedWeekKeepsRowsAndSavesOnlyOnce`. |
| H2 double Save | **Fixed** | `saved` guard set before the call, reset on failure, button disabled (`AIRoutineSheet.swift:56,157-164`). |
| H3 user edits validated as AI | **Fixed** | `validated(for:edited:)` skips day-count and duration in edited mode and gives day-named user messages (`AIRoutine.swift:95-122`); Picker filters used exercises. Test `editedRoutineMayExceed…`. |
| H4 duplicate/blank models | **Fixed** | Single `EquipmentIdentityResolution.resolve` (`EquipmentIdentification.swift:50-69`) used by the proposal and again at Add (`GymsView.swift:711-721`): ambiguous/blank → model-less, trimmed values, banner states which outcome applies (`IdentifyEquipmentSheet.swift:105-112`). Unit test covers catalog/ambiguous/blank/new. |
| M1 plan erased on unknown row | **Fixed** | `CardioPlanStorage` decodes per row, re-appends unknown rows on write, refuses to overwrite non-array data, comment states the consequence (`PlannedCardio.swift:21-43`); UI flags it and the editor blocks Save; export has its own `CardioPlan` DTO plus `unreadableCardioPlanData`. Test present. |
| M2 suggestions outside consent | **Fixed** | Third flag `openai.exerciseConsent.v1`, alert before first send, guard inside `suggestExercises`, revoke abandons the request, Settings toggle + footer (`GymsView.swift:1044-1185`); UI test restored. |
| M3 user exercise names / no guard | **Fixed** | Seeded-only candidates and allow-list; consent guard in `identify` (`IdentifyEquipmentSheet.swift:160-165`). |
| M4 migration reads | **Fixed** | Fixture test now reads `confirmedEquipment`, `cardioPlanData`, every entry's `plannedRepsBySet/plannedRestSeconds`, and round-trips an export of the migrated store. |
| M5 test gaps | **Fixed** | Rest precedence, status/transport mapping, cancellation, planned start/replay, consent UI tests (`-uiTestTerraNeedsConsent` now used). Start/link moved into `CardioSession.start(plannedTargetID:)` with one save (`Cardio.swift:268-297`). |
| M6 Target caption on old templates | **Fixed (see L1)** | Caption requires a rest prescription (`ExerciseEntryCard.swift:53`). |
| M7 stuck "Started" | **Fixed** | `Workout.canStart` treats a missing or ended-empty segment as startable; failures surface through the recorder's error alert. |

Round-1 lows also closed: template error type, rest 0⇄nil (explicit toggle), link-less model
fallback + proposal dead end, sorted ID arrays, unit-system default for targets, `/tmp` writer moved
to `work-record`, GPS test now uses a GPS-tagged source, brace/schema-11 comment, STATE/tickets.

## New observations (all Low — none block code clearance)

- **L1. Caption rule is a proxy.** `plannedRestSeconds != nil` stands in for "authored
  prescription": switching a generated item to "Use exercise rest default" silently removes its
  Target caption, and adding rest to an old template adds one. Acceptable for the trial; a
  dedicated flag would be honest. Capture both states.
- **L2. `AppPreferences.canonical(in:)` inside the isolated save** (`AIRoutine.swift:158`) inserts
  a fresh preferences row when none exists and is called once per day in the loop. On a real store
  a row always exists after first launch, and `canonical(of:)` tolerates duplicates, but hoist it
  above the loop and read-only-fetch rather than insert in this context.
- **L3. Reasoning effort raised to medium** (`TerraAPI.swift:18`) with the 60 s timeout and 8000
  output-token cap unchanged; a 7-day plan could hit either and surface as "took too long"/invalid.
  Record observed latency in ticket 05.
- **L4.** Synthesized `Equatable` on routine rows now includes the local `id`, so a decoded routine
  never equals a hand-built one; only matters for future tests.
- **L5.** `confirmedEquipment` still mixes equipment and cardio raw values; old Anthropic Keychain
  item and dead Anthropic client code remain; 429 billing vs rate-limit still one message; photo
  JPEG render still on the main thread; preview Cancel still discards without confirmation.
- **L6.** Generated-mode validation no longer requires distinct session names (round-1 rule
  dropped, not just relaxed for edits). Harmless given UUID identity; note it in the spec line R2.
- **L7.** D56 is still prose; add D57 (template targets, rest precedence, unknown-row rule) and D58
  (routine generator, three consents) rows before closing ticket 05.

## Regression sweep — no finding

Cardio start without a plan id is unchanged; plan link and segment insert share one save; template
start copies raw plan data then re-IDs known rows (unknown rows carried, never started); drift and
editor paths still preserve cardio/rest/equipment/supersets; export stays append-only and optional;
no new entity, no enum in a `#Predicate`; consent keys are cleared only under `-uiTestReset`;
fixtures remain gated by `fixtureIsEnabled`; `TerraRoutineSmoke.json` holds no key or personal
profile; request still `store:false`, single attempt, key in header only.
