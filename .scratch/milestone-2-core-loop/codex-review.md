# Independent cross-review — Milestone 2 tickets

Overall verdict: **the ticket set is not ready for implementation**. Several foundational ambiguities can cause irreversible historical misclassification, and the dependency graph contains an actual ownership cycle.

## Critical

### 1. Tickets 04 and 09 have a template-start ownership cycle

**Files:** [04:3–5](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/04-core-logging-loop.md:3>), [09:3–5](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/09-template-resolution-and-drift.md:3>)

**What’s wrong:** Ticket 04 promises starting a persisted workout “empty or from template.” Ticket 09 owns persisted templates and template-based startup, but is blocked by 04. Ticket 01 creates only the schema, and Ticket 02 seeds no templates.

**Why it matters:** Ticket 04 cannot meet its stated scope without implementing part of 09. Ticket 09 then inherits overlapping behavior and likely rewrites it.

**Suggested fix:** Make Ticket 04 explicitly empty-workout-only. Give Ticket 09 all template startup behavior. Better still, split 09 into:

1. Template CRUD and ordinary startup.
2. Gym/machine resolution.
3. Drift detection and mutation choices.

---

### 2. The documents disagree about whether equipment context belongs to a set or an entry

**Files:** [SPEC:52](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:52>), [SPEC:74–76](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:74>), [DECISIONS D2](</Users/ericlee06/orca/projects/Health App/docs/DECISIONS.md:10>), [04:11](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/04-core-logging-loop.md:11>)

**What’s wrong:** The locked behavior says machine and gym are optional “on every set,” but the proposed schema puts gym on `Workout` and machine on `ExerciseEntry`. The prototype also edits equipment at entry level.

Changing equipment after completing some sets would retroactively relabel those completed sets unless special behavior is added.

**Why it matters:** Snapshots, prefill, and machine/model PRs cannot be historically honest if one entry contains sets performed on different machines.

**Suggested fix:** Resolve this before Ticket 01 starts:

- Either put equipment context and snapshot identity on `SetRecord`; or
- Declare `ExerciseEntry` an indivisible equipment segment, freeze its context after the first completed set, and create a new entry whenever equipment changes.

Add an acceptance test for changing machine after one set has already been completed.

---

### 3. Snapshot display strings are insufficient for historical queries

**Files:** [01:11](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/01-swiftdata-schema-and-store.md:11>), [05:3](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/05-history-and-snapshots.md:3>), [06:11](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/06-prefill-and-previous-performance.md:11>), [SPEC:40](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:40>)

**What’s wrong:** Ticket 01 snapshots gym, machine, and model names, but not stable historical IDs. Ticket 06’s model-layer queries will therefore be tempted to follow the mutable live `MachineInstance.model` relationship.

If a machine’s model is corrected for future workouts only, old sets will silently move into the new model’s PR/history layer even if their displayed label remains old.

**Why it matters:** This violates the product’s central historical-integrity guarantee.

**Suggested fix:** Snapshot scalar UUIDs as well as display strings:

- `exerciseID`
- `machineInstanceID?`
- `equipmentModelID?`
- `gymID?`
- relevant free-weight tag/load type
- display names used by history

Historical prefill/PR queries must group by snapshot IDs, not live relationships. Define exactly when snapshots are captured and what “apply to past” rewrites. Test rename, archive, relationship becoming `nil`, future-only correction, and apply-to-past correction.

---

### 4. The schema cannot represent active-workout recovery

**Files:** [01:3](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/01-swiftdata-schema-and-store.md:3>), [04:3,12–13](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/04-core-logging-loop.md:3>), [SPEC:74–76](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:74>)

**What’s wrong:** The schema sketch has no persisted workout lifecycle state. Nothing distinguishes active, finished, and canceled workouts or resolves multiple unfinished workouts.

“Finish moves the workout to history” is not a meaningful store operation without such state.

**Why it matters:** Deterministic force-quit recovery—the non-negotiable acceptance case—cannot be implemented from the schema Ticket 01 promises.

**Suggested fix:** Add, at minimum:

- `startedAt`
- `finishedAt?` or an explicit stored lifecycle state
- deterministic active-workout selection/invariant
- `SetRecord.completedAt?` as completion state
- explicit cancellation deletion/cascade semantics

Test by saving, destroying the container/context, reopening the same disk store, and refetching. A fetch from the original context is not a persistence test.

---

### 5. Assisted and bodyweight e1RM is mathematically wrong or undefined

**Files:** [07:3,9–10](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/07-pr-computation.md:3>), [DECISIONS D14/D17](</Users/ericlee06/orca/projects/Health App/docs/DECISIONS.md:22>), [open assisted UX decision](</Users/ericlee06/orca/projects/Health App/docs/DECISIONS.md:42>)

**What’s wrong:** Merely selecting the lowest Brzycki result does not make assisted e1RM valid. At the same 20 kg assistance, Brzycki produces a lower number for five reps than ten; inversion would claim five reps is the better performance. Pure bodyweight has no stored load from which to calculate e1RM.

**Why it matters:** Ticket 07 can ship objectively false PRs while satisfying its current acceptance criteria.

**Suggested fix:** Until effective resistance is defined:

- Keep per-rep-count minimum-assistance records.
- Do not calculate assisted or pure-bodyweight e1RM.

Alternatively, snapshot bodyweight and define effective load, such as bodyweight minus assistance or bodyweight plus added load. Record that as a locked decision first. Add a test proving more reps at equal assistance cannot rank worse.

---

### 6. The union omits the core machine-first logging interaction

**Files:** [SPEC:27–28](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:27>), [DECISIONS D7](</Users/ericlee06/orca/projects/Health App/docs/DECISIONS.md:15>), [02:10](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/02-seed-catalogs.md:10>), [03:10–12](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/03-gym-and-machine-creation.md:10>)

**What’s wrong:** Ticket 02 creates model-to-exercise links, but no ticket consumes them to implement:

- Pick a single-exercise machine → automatically select its exercise.
- Pick a multi-exercise station → prompt for the exercise.

The SwiftData tickets also never explicitly preserve the prototype’s per-entry free-weight tag.

**Why it matters:** Milestone 2 would omit the main equipment-aware speed interaction and could lose barbell/dumbbell/cable/smith/bodyweight context during migration.

**Suggested fix:** Add a machine-first logging slice with persisted free-weight context and acceptance cases for single-exercise, multi-exercise, and free-weight selection.

## Important

### 7. Ticket 01 is not a stable foundation for its dependents

**Files:** [01](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/01-swiftdata-schema-and-store.md:3>), [SPEC model sketch](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:67>)

**What’s wrong:** Later tickets require fields not assigned to any schema owner: workout lifecycle, gym/machine archival, free-weight context, snapshot IDs, rest-duration ownership, ordered entries/template items, and drift-suppression settings.

SwiftData to-many relationships should not be treated as the authoritative order when prefill depends on “same index.”

The CloudKit checklist also omits deliberate inverses and delete rules. Apple notes that ambiguous inverses need to be explicit and that CloudKit does not support the `deny` delete rule. [Apple SwiftData CloudKit guidance](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)

**Suggested fix:** Enumerate the complete milestone-2 schema in Ticket 01, including scalar `order` fields, optional relationships with explicit inverses, and deliberate deletion/archive behavior. Alternatively, explicitly assign each additive field to a later ticket.

---

### 8. `GymExerciseMemory` has no deterministic no-unique-constraint design

**Files:** [SPEC:77](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:77>), [04:11](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/04-core-logging-loop.md:11>), [09:3](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/09-template-resolution-and-drift.md:3>)

**What’s wrong:** It conceptually has a unique `(gym, exercise)` key, but unique constraints are forbidden. Neither ticket specifies duplicate reconciliation or deterministic selection.

**Why it matters:** Template resolution can return different machines depending on fetch order, particularly after future CloudKit merges.

**Suggested fix:** Store scalar gym/exercise/machine UUIDs plus `updatedAt`; perform application-level upsert; resolve duplicates deterministically by `updatedAt` and UUID; and test a store containing duplicate memory rows.

---

### 9. “Seed exactly once” contradicts release-driven catalog updates

**Files:** [SPEC:25,96](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:25>), [02:3,9](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/02-seed-catalogs.md:3>)

**What’s wrong:** A first-launch-only seed cannot install later catalog additions or metadata/link corrections. Without uniqueness constraints, naive reruns can duplicate records. “Major manufacturers, popular lines—small at first” is also not measurable.

**Why it matters:** Existing installations can become permanently stranded on the first catalog version.

**Suggested fix:** Require versioned, idempotent reconciliation by fixed catalog UUID:

- insert missing seeded records;
- update explicitly mutable seeded metadata;
- preserve user-created records and historical references;
- recover from partial seeding;
- never duplicate.

Test first seed, identical rerun, partial store, and v1→v2 update.

---

### 10. Optional-gym logging and app-preference fallback are missing

**Files:** [SPEC:44,52](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:44>), [DECISIONS D2/T7](</Users/ericlee06/orca/projects/Health App/docs/DECISIONS.md:10>), [03:3,9](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/03-gym-and-machine-creation.md:3>), [04:3](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/04-core-logging-loop.md:3>)

**What’s wrong:** Ticket 04 always starts at “the current gym,” Ticket 03 effectively requires a gym default unit, and no ticket supplies an editable persisted app preference.

**Why it matters:** Home/context-free workouts cannot be logged, and the documented app-preference fallback may be unreachable.

**Suggested fix:** Require:

- a “No gym” start option;
- optional gym default unit;
- persisted app unit preference;
- tests for machine → gym → app precedence, including no gym and machineless entries.

---

### 11. Continuous persistence is underspecified and under-tested

**Files:** [SPEC:58](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:58>), [04:3,9–12](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/04-core-logging-loop.md:3>)

**What’s wrong:** The ticket does not define whether it relies on SwiftData autosave or explicit saves, nor does it cover set/exercise insertion, deletion, reordering, notes, rest edits, or incomplete text input.

The prototype stores weight and reps as editable strings. A numeric-only persisted field cannot preserve intermediate input such as empty text or `1.` across a force-quit.

**Why it matters:** “Every change” can pass a happy-path manual test while still losing structural edits or in-progress input.

**Suggested fix:** Define accepted-edit boundaries and explicit `ModelContext.save()` behavior, or document a bounded debounce if the non-negotiable wording is changed. Add a table-driven recovery test for every mutable field and collection operation using a newly opened disk-backed container.

---

### 12. Unit normalization has no executable contract

**Files:** [01:10](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/01-swiftdata-schema-and-store.md:10>), [04:9](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/04-core-logging-loop.md:9>), [CLAUDE:19–21](</Users/ericlee06/orca/projects/Health App/CLAUDE.md:19>)

**What’s wrong:** No ticket defines the lb→kg constant, recomputation timing, invalid values, rounding policy, or stale-derived-value prevention.

**Why it matters:** `normalizedKg` can disagree with the entered value after a unit or weight edit, corrupting PR comparisons and later charts.

**Suggested fix:** Put one pure conversion function in `Domain/`, use exact `1 lb = 0.45359237 kg`, recompute atomically on value/unit changes, reject nonfinite values, and keep full precision in storage. Test kg identity, lb tolerance, edits in both directions, and exact as-entered prefill.

---

### 13. Ticket 06 does not guarantee the promised one-tap speed bar

**Files:** [SPEC:38,57](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:38>), [06:3,9–10](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/06-prefill-and-previous-performance.md:3>), [prototype copy button](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Features/ActiveWorkout/ExerciseEntryCard.swift:186>)

**What’s wrong:** The prototype requires one tap to copy previous values and a second tap to complete. “Same-index” does not define raw order versus per-type order, completed-set filtering, or protection against a late query overwriting user input.

**Why it matters:** An implementation can satisfy the current criteria while still violating the explicit one-tap-confirmation requirement.

**Suggested fix:** Require input fields to arrive populated while completion remains false. Source only completed sets from the most recent finished workout before the current workout, define set-type/index matching, copy the original value and unit, and never overwrite a dirty row. Test inserted warmups, fewer previous sets, incomplete sets, machine changes, and late query results.

---

### 14. PR and volume eligibility is incomplete

**Files:** [07:3,9–13](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/07-pr-computation.md:3>), [SPEC:39,48](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:39>), [open volume decision](</Users/ericlee06/orca/projects/Health App/docs/DECISIONS.md:43>)

**What’s wrong:** Ticket 07 never says only completed, valid sets count. It mentions volume exclusion but neither defines volume nor resolves the milestone-2 dumbbell rule. Assisted and bodyweight volume are also undefined.

**Why it matters:** Draft rows can become records, and later history/charts can embed inconsistent volume assumptions.

**Suggested fix:** Require `completedAt != nil`, positive reps, valid finite load, warmup exclusion, and explicit failure-set participation. Record the dumbbell/bodyweight/assisted volume rules in `DECISIONS.md` before implementation. Test Brzycki at reps 1, 12, and 13, invalid drafts, ties, and every load type.

---

### 15. Snapshot capture and model correction have no owning ticket

**Files:** [04](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/04-core-logging-loop.md:3>), [05:3,11–12](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/05-history-and-snapshots.md:3>), [SPEC:40](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:40>)

**What’s wrong:** Ticket 01 creates snapshot fields, but Ticket 04 never requires populating them. Ticket 05 assumes snapshots exist and tests only machine rename. No ticket implements the locked past-versus-future model-correction prompt.

**Why it matters:** Ticket 04 can create permanently blank snapshots, and the riskiest historical mutation is untested.

**Suggested fix:** Make Ticket 04 capture snapshots at the agreed log boundary. Give Ticket 05 explicit cases for gym rename, machine rename, model rename, archive, future-only correction, and apply-to-past correction.

---

### 16. Rest-timer defaults and storage ownership contradict the source documents

**Files:** [SPEC:56,73](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:56>), [DECISIONS D13](</Users/ericlee06/orca/projects/Health App/docs/DECISIONS.md:21>), [08:3,9–12](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/08-rest-timer-durations.md:3>)

**What’s wrong:** Ticket 08 invents a 1:00 global warmup default even though SPEC gives one global 2:00 default. It places overrides on `Exercise`, while the model sketch places rest durations on `TemplateItem`.

It also does not say whether timer end state survives relaunch or how pending notifications behave when a set is uncompleted, a new timer starts, or the user skips/adds time.

**Why it matters:** Two agents can implement incompatible sources of truth, and a product default is being changed without a decision-log update.

**Suggested fix:** Lock and document a precedence hierarchy, such as template-item override → exercise override → global defaults. Persist/reconstruct the absolute end time and replace or cancel pending notifications appropriately. Test through injected clock and notification-scheduler interfaces; keep notification permission as one manual integration test.

---

### 17. Template drift actions are not defined well enough to implement

**Files:** [SPEC:54](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:54>), [09:9–12](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/09-template-resolution-and-drift.md:9>)

**What’s wrong:** “All four options behave per SPEC” is circular: the SPEC only names them. It never distinguishes structure from values, and the stated template schema has no target weight, making “update values only” unclear. Suppression also has no defined automatic action.

**Why it matters:** All four implementations can differ materially while claiming compliance.

**Suggested fix:** Define:

- which fields are “structure” and which are “values”;
- whether order, reps, rest, set types, and weights participate in drift;
- the exact write set for each option;
- what suppression does by default.

Then create one state-transition test per option.

---

### 18. The dependency graph over-serializes independent work

**Files:** [03:5](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/03-gym-and-machine-creation.md:5>), [06:5](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/06-prefill-and-previous-performance.md:5>), [07:5](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/07-pr-computation.md:5>), [09:5](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/09-template-resolution-and-drift.md:5>)

**What’s wrong:**

- Gym creation needs 01, while catalog-backed machine creation needs 02.
- Ticket 06 needs completed persisted workouts from 04, not Ticket 05’s history UI.
- Ticket 07’s pure calculation core does not need Ticket 06; only sheet integration does.
- Ticket 09 redundantly names 03 even though 04 already transitively depends on it.

**Why it matters:** The current graph effectively forces `01 → 02 → 03 → 04 → 05 → 06 → 07`.

**Suggested fix:** Split gym and machine/model creation; make 06 depend on 04; split pure PR computation from its sheet integration; remove redundant blockers.

---

### 19. Tickets 01, 04, 05, and 09 are not one-agent-session slices

**Files:** [01](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/01-swiftdata-schema-and-store.md:1>), [04](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/04-core-logging-loop.md:1>), [05](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/05-history-and-snapshots.md:1>), [09](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/09-template-resolution-and-drift.md:1>)

**What’s wrong:** These are horizontal bundles:

- 01: ten-model schema, app migration, store setup, prototype removal, and test infrastructure.
- 04: lifecycle, form persistence, unit logic, memory, recovery, finish, cancel, and template startup.
- 05: history queries, two screens, snapshots, rename, archive, and picker filtering.
- 09: template CRUD, resolution, drift engine, four update modes, settings, and save-as-template.

**Why it matters:** They cannot be independently demonstrated or reviewed at useful intermediate boundaries.

**Suggested fix:** Split them around demonstrable behavior. The most urgent splits are 04 and 09; Ticket 05 should separate snapshot-backed history from equipment lifecycle/correction.

## Minor

### 20. Several promised behaviors are silently absent

**Files:** [SPEC:20](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:20>), [SPEC:46](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:46>), [02](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/02-seed-catalogs.md:3>)

**What’s wrong:** No ticket implements user-created exercises or the whole-view visibly marked conversion toggle.

**Why it matters:** Both are source-of-truth product behaviors, and neither is explicitly deferred beyond milestone 2.

**Suggested fix:** Add an Add Exercise slice with name/load type/tags. Assign the conversion toggle to Ticket 05 or explicitly defer it in SPEC/DECISIONS.

---

### 21. Ticket 05 repeats the prototype’s misleading workout unit badge

**Files:** [05:9](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/05-history-and-snapshots.md:9>), [prototype HistoryView](</Users/ericlee06/orca/projects/Health App/WorkoutTracker/Features/History/HistoryView.swift:61>), [SPEC:44–46](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:44>)

**What’s wrong:** The prototype displays the current gym default as the workout’s unit badge. A workout can contain both kg and lb sets.

**Why it matters:** It falsely implies that the workout used one unit.

**Suggested fix:** Derive `kg`, `lb`, or `Mixed` from actual logged sets, or omit the summary badge.

---

### 22. Ticket 03 adds an undocumented city field

**Files:** [03:3](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/03-gym-and-machine-creation.md:3>), [SPEC Gym sketch](</Users/ericlee06/orca/projects/Health App/docs/SPEC.md:71>)

**What’s wrong:** Ticket 03 requires optional city, while SPEC defines name, default unit, and notes. The prototype has city, but the SPEC—not the prototype—is the source of truth.

**Why it matters:** This is unlogged scope/model expansion.

**Suggested fix:** Either add city to SPEC/DECISIONS or remove it from the ticket.

---

### 23. Ticket 01 assumes test infrastructure that does not exist

**Files:** [01:12](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/01-swiftdata-schema-and-store.md:12>), [project target definition](</Users/ericlee06/orca/projects/Health App/WorkoutTracker.xcodeproj/project.pbxproj:50>), [CLAUDE:7](</Users/ericlee06/orca/projects/Health App/CLAUDE.md:7>)

**What’s wrong:** The project has only an application target. A test target requires project configuration; synchronized folders merely avoid registering each new source file.

**Why it matters:** Ticket 01 contains hidden project-setup scope, and all later unit-test criteria depend on it.

**Suggested fix:** Explicitly include creation of `WorkoutTrackerTests`, permit the one-time project-file edit, and provide the expected `xcodebuild test` command.

## Nit

### 24. Several acceptance criteria are not objectively testable

**Files:** [01:12](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/01-swiftdata-schema-and-store.md:12>), [02:3](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/02-seed-catalogs.md:3>), [03:3](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/03-gym-and-machine-creation.md:3>), [08:12](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/08-rest-timer-durations.md:12>), [09:12](</Users/ericlee06/orca/projects/Health App/.scratch/milestone-2-core-loop/issues/09-template-resolution-and-drift.md:12>)

Phrases such as “identical values,” “major manufacturers,” “appears everywhere,” “notification fires,” and “behave per SPEC” need exact fixtures, expected fields/screens, tolerances, or injectable collaborators.

**Suggested fix:** Replace each with deterministic test setup and expected results. Keep only OS authorization presentation as a manual check.

## Verdict by ticket

| Ticket | Verdict | Required before pickup |
|---|---|---|
| **01 — Schema/store** | **Not ready** | Resolve set-vs-entry context; add lifecycle, snapshot IDs, ordering, archival/delete rules, and test-target scope. |
| **02 — Seeding** | **Not ready** | Replace “exactly once” with versioned idempotent reconciliation and define a measurable seed fixture. |
| **03 — Gym/machine creation** | **Not ready** | Split dependency where useful; preserve optional defaults; define user-model exercise links and machine auto-fill/multi-exercise behavior. |
| **04 — Core logging** | **Rewrite/split** | Remove template startup; define lifecycle, explicit durability, snapshot capture, optional gym, equipment-change behavior, and complete mutation coverage. |
| **05 — History/snapshots** | **Not ready** | Add historical IDs, correction behavior, honest mixed-unit summary, and split equipment lifecycle from history rendering. |
| **06 — Prefill/history** | **Not ready, but close** | Remove false blocker on 05 and define completed-workout filtering, index/type semantics, dirty-row protection, and true one-tap prefill. |
| **07 — PRs** | **Not ready** | Resolve assisted/bodyweight e1RM and volume decisions; filter unfinished/invalid sets; add boundary/tie cases. |
| **08 — Rest timer** | **Not ready** | Reconcile defaults and storage ownership; define durable timer/notification replacement behavior and deterministic tests. |
| **09 — Templates/drift** | **Rewrite/split** | Resolve cycle with 04; define the four mutations and suppression semantics; split CRUD/resolution/drift. |

**Ready as-is: none.** Ticket 06 is the closest structurally, but its current acceptance criteria still permit the wrong prefill behavior.
