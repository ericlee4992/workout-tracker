# Codex cross-review — milestone 3 export

**Verdict: do not merge or install this branch yet.** The overall split (one SwiftData collector,
pure renderers, value-type snapshot) is good, but there are three high-severity fidelity defects:
an in-progress entry loses its chosen context, a user-authored catalog link can be omitted, and a
CRLF inside user text makes the CSV structurally invalid. These are precisely the failures D28,
D30, and D32 were meant to prevent.

## Findings

### High — a draft entry loses the equipment and gym the user already chose

**Files:** `WorkoutTracker/Domain/WorkoutSession.swift:173-183,255-259`;
`WorkoutTracker/Domain/ExportCollector.swift:225-242`;
`WorkoutTrackerTests/ExportFidelityTests.swift:175-190`

`addEntry` initializes only the provisional exercise snapshot fields. Until a first set completes,
`chooseEquipment` changes only the live `machine` / `freeWeightTag`. The collector nevertheless
always reads `snapshotMachineID`, `snapshotModelID`, `snapshotGymID`, and
`snapshotFreeWeightTag`. Thus exporting mid-workout can turn an entry the user explicitly assigned
to a gym and machine (or free-weight tag) into a context-free entry in both JSON and CSV. The
fidelity test creates exactly this state but only checks the workout/set flags, not its context.

This violates D30 (draft state must not be silently dropped) and the milestone's full-context
promise; it also defeats D23's honesty by exporting neither the historical snapshot (none exists
yet) nor the current truth.

**Smallest fix:** while `snapshotCapturedAt == nil`, keep every provisional snapshot context field
synchronized on entry creation and equipment changes. Alternatively, have the collector use live
context only for uncaptured entries. Add a service-level regression test that asserts all gym,
machine/model, and free-weight fields for a real active draft entry.

### High — D28 can drop a user-authored link stored on a seeded model

**Files:** `WorkoutTracker/Domain/EquipmentLifecycle.swift:71-99`;
`WorkoutTracker/Domain/ExportCollector.swift:126-148`

D27 deliberately lets a user create an exercise and append its ID to a seeded model's
`exerciseIDs`; the reconciler treats that appended edge as user data. The collector includes a
seeded model only when a machine or history snapshot currently names it. A reachable counterexample
is: create a custom movement linked to seeded model A, then correct the only machine to model B
(future-only, with no history on A). The custom exercise exports, but model A and therefore the
user's link do not. Re-import cannot reconstruct which station the user attached the movement to.

This violates D27 and D28's central promise that shipped catalog bulk may be omitted but user data
may not.

**Smallest fix:** also mark a seeded model referenced when its `exerciseIDs` contains any
user-created exercise ID. This is not following shipped catalog links transitively; it preserves a
user-authored edge. Add the counterexample above as a collector test.

### High — an embedded CRLF is not quoted and corrupts the CSV

**File:** `WorkoutTracker/Domain/ExportCSV.swift:98-106`

`escaped` iterates Swift `Character`s and compares each one with `"\r"` or `"\n"`. Swift treats a
CRLF pair as one grapheme (`"\r\n"`), so neither comparison matches. A note containing a Windows
newline but no comma or quote is emitted unquoted; a strict reader sees the embedded CRLF as a new
record. This is a direct D32/RFC 4180 violation and can shift or split every subsequent row.

**Smallest fix:** test Unicode scalars (or a newline `CharacterSet`) for CR and LF instead of
iterating extended grapheme clusters. Add round trips for lone CR, lone LF, and CRLF. The existing
test at `WorkoutTrackerTests/ExportTests.swift:303-308` covers only LF.

### Medium — collection truncates every timestamp to whole seconds

**File:** `WorkoutTracker/Domain/ExportSnapshot.swift:225-243`

`.withInternetDateTime` omits fractional seconds. The snapshot therefore loses precision from
workout start/finish, snapshot capture, set completion, and preference/memory/override update
times. This is not merely cosmetic: canonical duplicate rows use `updatedAt` and only then UUID as
their tie-break (`WorkoutTracker/Domain/CanonicalRow.swift:8-20`). Two real updates in the same
second can resolve to the opposite row after import. The ticket's resolution note says it avoided
`Date` because a JSON round trip truncates precision, but formatting before encoding only moves the
loss earlier and makes the value-type equality test unable to see it.

This weakens D30 full fidelity and D31's claim to preserve the instant.

**Smallest fix:** include fractional seconds at adequate precision in `ExportDateFormat`, and test
non-integral dates plus two canonical rows updated within one second.

### Medium — exported `modelName` is actually a full display name

**Files:** `WorkoutTracker/Domain/Models.swift:86`;
`WorkoutTracker/Domain/WorkoutSession.swift:506-519`;
`WorkoutTracker/Domain/ExportCollector.swift:225-239`;
`WorkoutTrackerTests/ExportTests.swift:43-51`

Snapshot capture writes `model.displayName` (`manufacturer + modelName`) into
`snapshotModelName`. Export then labels that value `modelName` beside a separate, live
`manufacturer`. A real row is consequently like `Life Fitness,Life Fitness Insignia Chest Press`,
not the shape the hand-built encoder fixture tests. If a user-created model is renamed, the row can
also combine today's manufacturer with yesterday's full display string. The milestone table is
internally contradictory: `work-record/milestone-3-export/spec.md:78` says model name is live, while
lines 89-91 correctly say only manufacturer is live and model name is the snapshot.

This makes the CSV/JSON schema ambiguous for a future importer and muddies D23's intentional
live-vs-snapshot boundary.

**Smallest fix:** if the stored datum is intentionally the display string, rename the exported
field/column to `modelDisplayName` and correct the spec/tests. If the contract truly requires raw
model name, add an explicit raw-name snapshot field (with a migration/fallback for existing rows).

### Medium — CSV cannot represent an empty active workout or a zero-set entry

**File:** `WorkoutTracker/Domain/ExportCSV.swift:32-43`

Rows are emitted only inside the set loop. A just-started workout with no entry, or an entry after
its only set was deleted, disappears from CSV entirely. JSON retains it. The current test always
adds the automatic draft set, so it does not exercise the counterexample.

This conflicts with D30's statement that the in-progress workout and entries with no completed
sets export, and with `docs/SPEC.md:86` saying both files carry everything the user created. It is
also a format-design conflict: “one row per set” has no natural representation for an object with
no set.

**Smallest fix:** decide explicitly before schema v1 ships. Either define sentinel/object rows (a
breaking change), or narrow D30 and the “both files” claim so JSON is the complete backup and CSV
is the complete set ledger. Add an active-workout-with-no-entries test whichever contract wins.

### Medium — export is synchronous on the main actor with no busy state

**Files:** `WorkoutTracker/Features/Settings/ExportSection.swift:75-95`;
`WorkoutTracker/Domain/ExportCollector.swift:35-45`

A tap fetches and materializes the whole store, including all 1,877 seeded models/exercises before
filtering them, renders, and writes the file synchronously from the SwiftUI view. A large history
can visibly freeze the app and there is no progress indication. The failure path itself is honest
and inline, which is good.

**Smallest fix:** save the view context, collect/render through a background `ModelActor` using the
same `ModelContainer`, and expose an `isExporting` state that disables both buttons and shows
progress. Add a modest large-store timing/UI-responsiveness test rather than asserting a specific
phone-dependent duration.

### Low — the filename contract contradicts locked D31

**Files:** `WorkoutTracker/Domain/ExportSnapshot.swift:246-252`;
`WorkoutTracker/Domain/ExportFile.swift:21-24`; `docs/DECISIONS.md:39`

D31 says offset-bearing export timestamps apply “including in filenames,” but the implementation
and milestone spec produce `YYYY-MM-DD-HHmm` with no offset. Local time is used, so this is not a
UTC conversion bug, but two identically named files from different offsets are ambiguous and the
repo has two sources of truth.

**Smallest fix:** either include a filename-safe offset (for example `+0900`) and update the spec,
or deliberately amend D31 to say payload timestamps include the offset while filenames use local
wall time only.

### Low — JSON's blanket “no null” claim is false for optional array elements

**Files:** `WorkoutTracker/Domain/ExportSnapshot.swift:130-139`;
`WorkoutTrackerTests/ExportTests.swift:153-157`; `work-record/milestone-3-export/spec.md:119-120`

Synthesized Codable correctly emits `null` for a nil slot in `[Int?] targetRepsBySet`; omitting the
element would shift later set targets and be ambiguous. The “no `null` anywhere” test passes only
because its fixture contains no template. The format itself remains re-importable here: `[8, null,
10]` is the only unambiguous representation.

**Smallest fix:** specify that nil *object properties* are omitted while optional array positions
use `null`, and add a `[8, nil, 10]` JSON round-trip test.

### Low — the hand-written CSV reader is permissive enough to hide writer regressions

**File:** `WorkoutTrackerTests/ExportTestSupport.swift:30-63`

The reader accepts a quote in the middle of an unquoted field, arbitrary characters after a
closing quote, EOF with an unclosed quote, and bare CR/LF record endings. It also does not require
27 fields per data row. Those are invalid under the claimed dialect, so a malformed writer can
still “round-trip” in tests. It did not itself hide the CRLF defect above—the missing CRLF fixture
did—but it can hide adjacent quoting defects.

**Smallest fix:** make the test parser a throwing state machine that rejects those cases and assert
27 columns per row, or validate generated fixtures with a genuinely independent strict parser.
Also add a data-level non-ASCII test that parses the BOM-bearing bytes, not only `render` without
the BOM.

### Low — temp-file lifetime relies on an assumption rather than activity completion

**Files:** `WorkoutTracker/Domain/ExportFile.swift:34-58`;
`WorkoutTracker/Features/Settings/ShareSheet.swift:9-16`

Deleting the shared `Exports` directory before every write is safe while the sheet remains visibly
modal, but the code never observes `UIActivityViewController` completion. It therefore cannot
prove that a downstream activity has finished consuming a URL when the user dismisses and starts
another export. The current behavior also deletes the earlier staged file even when the new write
later fails.

**Smallest fix:** stage each export in a unique subdirectory, install
`completionWithItemsHandler`, and remove that export's directory only on activity completion (or
retain a small bounded set and clean it on a later launch).

## Field-by-field fidelity audit

| SwiftData model | Result |
|---|---|
| `Exercise` | `id`, `name`, `loadType`, `equipmentTypeTags`, `muscleGroup`, `isSeeded` all export. Inverse entry/template relationships are reconstructable from their owning objects. Fine. |
| `EquipmentModel` | `id`, `manufacturer`, `modelName`, `exerciseIDs`, `equipmentType`, `isSeeded` all export **when the row passes D28**. Machine inverses are reconstructable. The user-added-link omission above is not defensible. |
| `Gym` | `id`, `name`, `city`, `defaultUnit`, `notes`, `archived` all export. Machine/workout inverses are represented by IDs elsewhere. Fine. |
| `MachineInstance` | `id`, `label`, `defaultUnit`, `archived`, `gymID`, `modelID` all export, including archived and otherwise unused machines. Fine. |
| `WorkoutTemplate` | `id`, `name`, and nested items export. Fine. |
| `TemplateItem` | `id`, `order`, `targetSets`, `targetReps`, `targetRepsBySet`, and exercise ID/name export; template ownership is nesting. Optional array slots use JSON `null`, which is correct but undocumented. |
| `Workout` | `id`, start/finish, notes, source-template ID/name, snapshot gym name, live gym ID, and nested entries export. `restEndsAt`, `restStartedAt`, and `restStartedBySetID` are omitted. That is defensible as transient timer state that should not resume from an old backup, but the exclusion should be explicit because “the object graph” currently implies otherwise. Dates lose fractional precision as noted above. |
| `ExerciseEntry` | `id`, `order`, all D23 snapshot fields, and nested sets export. Live `exercise`/`machine`/`freeWeightTag` are intentionally superseded by snapshots for frozen history. That is correct after capture, but it loses current truth for drafts as described in the first finding. |
| `SetRecord` | `id`, `order`, `type`, `reps`, as-entered value/unit, normalized kg, and completion timestamp all export. Entry ownership is nesting. Fine apart from timestamp precision. |
| `GymExerciseMemory` | `id`, all three referenced IDs, and `updatedAt` all export, including duplicates. Fine apart from timestamp precision. |
| `AppPreferences` | All behavior-bearing settings export: unit, drift suppression, rest defaults, catalog version, notification marker, selected gym, `updatedAt`. The row `id` is omitted; that is defensible for a canonical singleton with no product identity, though it is an exception to the spec's “every id” wording. Catalog browsing fields are deliberately omitted and are defensible display-only state. `seededCatalogFingerprint` is derived from the bundle and is correctly omitted. |
| `ExerciseRestOverride` | `id`, exercise ID, both optional durations, and `updatedAt` all export, including duplicates. Fine apart from timestamp precision. |

## D28 edge-case walk

- **Archived machine:** fine. All machine rows export regardless of archive state, and their live
  model relationships mark those models referenced.
- **Entry snapshot referencing an existing seeded row:** fine. Snapshot exercise/model IDs mark the
  existing rows referenced even when the live entry relationships changed.
- **Entry snapshot referencing a row that no longer exists:** no catalog row can be emitted, but
  the entry retains its stable ID and snapshot name; manufacturer is empty by explicit contract.
  The history remains interpretable. A future importer should create a placeholder or seed before
  applying history rather than guess.
- **Template pointing at a seeded exercise:** fine while the relationship exists; it is explicitly
  marked referenced. If the relationship is already null because the row was deleted, the store
  itself has already lost the target—export cannot recover an ID `TemplateItem` never stored.
- **Non-transitive seeded exercise links:** acceptable under D28 only if import seeds the catalog
  before applying the export. The recorded catalog version and stable UUIDs make that intentional
  omission understandable. The user-authored seeded-model link in the high finding is different:
  it is not reproducible from the shipped catalog.

## What is otherwise fine

- Frozen historical CSV context uses entry snapshots; only `manufacturer` is looked up live. No
  display-formatted, locale-dependent, rounded, converted, or `≈` weight reaches either file.
- Apart from the CRLF grapheme bug, CSV escaping/doubled quotes, trailing CRLF, UTF-8 encoding, BOM,
  and non-ASCII preservation are straightforward and correct. A reader that does not strip a BOM
  may expose it in the first header, but D32 explicitly chose that Excel compatibility tradeoff.
- JSON optional object members are omitted and stable IDs/nesting make the represented graph
  unambiguous. Optional array `null`s preserve position rather than introduce ambiguity.
- Empty JSON and header-only empty CSV are handled. An active workout with its normal draft set is
  retained, subject to the missing draft context above; only the truly empty active-workout CSV
  case is unrepresentable.
- The inline failure row is honest. Domain files do not import UI, and the system share sheet is
  wired to the environment's actual store.

## Verification and test-claim audit

- The suite contains **242** Swift Testing cases and **10** UI tests by source count. Ticket 03's
  resolution still says 241, while `docs/STATE.md` says 242; `CLAUDE.md` also still points only to
  D1-D27 and milestone-2 issues. Update these T5 source-of-truth references.
- The claimed exact JSON round trip proves only `ExportSnapshot -> JSON -> ExportSnapshot`; it does
  not prove `SwiftData models -> ExportSnapshot` fidelity. Pre-formatting timestamps and hand-making
  a correct draft context let both collector defects escape it.
- The collector fidelity test proves completed-set count/volume for one happy path. It does not
  prove every model field, draft context, D27 user links, deleted references, raw model-name
  semantics, timestamp precision, empty active workouts, or optional template slots.
- The UI test proves only empty-store CSV presentation and dismissal. It does not exercise JSON,
  a non-empty store, a large-store busy state, file contents, or failure handling. That narrow scope
  is consistent with the amended ticket, but it should not be cited as end-to-end fidelity proof.
- I attempted the requested independent unit run and both generic simulator/device builds. This
  environment cannot connect to CoreSimulatorService; `xcodebuild test` could not find `WT-iPhone`,
  and asset compilation failed with “No available simulator runtimes.” No test or build result was
  independently verified in this review, and no product-code files were changed.
