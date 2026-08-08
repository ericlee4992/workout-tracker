Overall verdict: **not ready**.

## 1. First-pass findings disposition

| # | Status | Evidence / remaining gap |
|---:|---|---|
| 1 | resolved | `issues/07-core-logging-loop.md` is empty-workout-only; template startup moved to `15-templates-crud-resolution.md`. The ownership cycle is gone. |
| 2 | partially resolved | D19, `SPEC.md`, and ticket 07 freeze equipment at entry level. D2 still says machine/gym are optional “on sets,” contradicting D19. |
| 3 | partially resolved | D23 plus tickets 07/10/11 add snapshot UUIDs and snapshot-keyed queries. `loadType` is not snapshotted, so later exercise/catalog changes can reinterpret old PR/volume eligibility. |
| 4 | resolved | `SPEC.md:75–77` and ticket 07 define lifecycle, completion state, disk-backed recovery, deterministic active selection, finish, and cancel. |
| 5 | resolved | D20 and ticket 12 remove assisted/bodyweight e1RM and define direction-aware records. |
| 6 | resolved | Ticket 08 owns single/multi-exercise machine selection and persisted free-weight context. |
| 7 | partially resolved | Ticket 02 enumerates most fields, ordering, inverses, and delete rules, but still omits later-required persisted state: rest overrides/end time, template provenance, catalog version, and explicit draft numeric optionality. |
| 8 | resolved | `SPEC.md:78`, ticket 07, and ticket 15 define scalar IDs, timestamp/UUID selection, application upsert, and duplicate handling. |
| 9 | resolved | D24 and ticket 04 specify versioned, idempotent reconciliation with partial-store and upgrade tests. |
| 10 | resolved | Tickets 05, 07, and 15 cover app preference, optional defaults, no-gym workouts, and fallback precedence. |
| 11 | partially resolved | Ticket 07 defines explicit saves and disk-backed mutation tests, but explicitly allows in-progress keystroke loss, contradicting `SPEC.md:59`’s non-negotiable “every change” guarantee. |
| 12 | partially resolved | D25/ticket 03 fix the conversion constant, recomputation, invalid values, and storage precision. Display precision, rounding mode, and locale behavior remain unspecified. |
| 13 | resolved | Ticket 11 defines completed-history filtering, type-aware indexing, populated-but-uncompleted rows, one-tap completion, and dirty-row protection. |
| 14 | partially resolved | D20/D21 and ticket 12 define most eligibility and volume rules, but its global “finite positive load” requirement excludes plain bodyweight and zero-assistance/zero-added sets. |
| 15 | resolved | Ticket 07 owns capture; ticket 10 owns rename/archive and past-versus-future model correction with snapshot-ID assertions. |
| 16 | partially resolved | D22/ticket 14 fix ownership, precedence, persistence, and notification replacement. Failure-set duration and whether undoing the originating set cancels its timer remain undefined. |
| 17 | partially resolved | Ticket 16 defines structure, values, write sets, and suppression. Values-only drift cannot trigger the prompt; differing completed reps have no target-reduction rule. |
| 18 | partially resolved | The chain is substantially parallelized, but ticket 15 unnecessarily depends on 08 rather than 07, and parallel tickets 08/09 have overlapping history ownership. |
| 19 | partially resolved | The rewrite splits the original bundles, but tickets 02, 07, and 15 remain larger than credible single-session slices. Ticket 14 is borderline. |
| 20 | resolved | Custom exercises moved to ticket 06; the marked whole-view conversion control moved to ticket 09. |
| 21 | resolved | `SPEC.md:46` and ticket 09 derive `kg`/`lb`/`Mixed` from logged sets. |
| 22 | resolved | Optional city is now documented in `SPEC.md:72` and ticket 05. |
| 23 | resolved | Ticket 01 explicitly creates the test target and sanctions the project-file edit. |
| 24 | partially resolved | Most criteria now have fixtures/fakes/exact transitions. Ticket 03 still lacks exact formatting expectations; ticket 16 cannot assert exact target reps without a reduction rule. |

## 2. New findings by severity

### Critical

1. **Ticket 02’s “no later schema” claim is false.** Tickets 04, 14, and 15 require catalog-version state, exercise rest overrides, timer/permission state, and workout-template provenance. Gym archival is also required by tickets 02/10 but `Gym` has no `archived` field. Enumerate these fields or allow additive schema tickets.

2. **Historical classification remains mutable.** D23 snapshots IDs and labels, but not `loadType`. Ticket 04 may update seeded exercise metadata, so an old set can move between weighted/bodyweight/assisted eligibility. Snapshot `loadType` and make record/volume queries use it.

3. **Free-weight history has no context key.** Ticket 08 persists barbell/dumbbell/etc.; tickets 11–13 group only by machine/model/exercise UUID. Barbell and dumbbell records collapse together, and neither gets same-context prefill. Add the frozen tag to snapshot grouping and define its layer semantics.

### Important

4. **Ticket 12 rejects records it promises to compute.** “Finite positive load” excludes plain bodyweight, zero assistance, and zero added weight. Its 12-rep cap also conflicts with D20’s uncapped “bodyweight = most reps.” Make eligibility and caps load-type-specific.

5. **Finished-workout cleanup is undefined.** Ticket 07 captures snapshots only after completion, but does not say whether unfinished rows/entries are deleted at Finish. Tickets 09, 15, and 16 consequently disagree about what history, template capture, and drift consume.

6. **Selecting one active workout does not enforce the invariant.** Ticket 07 chooses the earliest duplicate but leaves the others active and does not define what “Start Workout” does while one exists. Specify cleanup/quarantine and start behavior.

7. **Machine-first logging cannot handle model-less machines.** Ticket 06 permits `model == nil`; ticket 08 requires model exercise links to auto-fill or prompt. Exclude these machines from that path or define an exercise-selection fallback.

8. **Seed reconciliation conflicts with model editing.** Ticket 10 permits model renames without restricting them to user-created models; ticket 04 overwrites seeded metadata on later catalog versions. Disallow seeded-model edits or persist user overrides separately.

9. **Dependency/ownership edges are wrong.** Ticket 08 requires tags to render in history while 08 and history-owner 09 are parallel. Ticket 15 needs ticket 07’s memory behavior, not ticket 08’s UI. Tickets 08, 11, and 14 also concurrently modify the active-workout surface without stated seams.

10. **Ticket 16 makes one of its four actions unreachable.** Drift is structural-only, so a reps-only change never offers “Update values only.” It also does not define how several differing set reps become one target.

11. **Rest semantics omit failure sets.** D22 supplies warmup and working durations only, while ticket 14 starts a timer for every set type. Define failure → working or add a third duration.

### Minor

12. **Source-of-truth text remains stale.** D2 says context is per set; `SPEC.md:40` snapshots unit at entry level; `SPEC.md:49` says the dumbbell rule is undecided; `SPEC.md:57` still describes a single 2:00 default.

13. **Ticket 04’s production catalog is undersized.** Its ≥20-model fixture does not satisfy `SPEC.md:25`/D4’s few-hundred-model v1 catalog. Mark 20 as a test fixture and identify the production-content gate.

### D19–D25 sanity check

| Decision | Verdict |
|---|---|
| D19 | Direction is sound. Define whether freeze is permanent after undoing the first completion and exactly which draft rows move when switching equipment. |
| D20 | Weighted-only e1RM is correct. Clarify the D17 12-rep cap and whether bodyweightPlus records intentionally ignore changing athlete bodyweight. |
| D21 | Internally consistent as a named convention. Remove the stale “undecided” SPEC text. |
| D22 | Precedence is workable, but failure-set fallback is missing. Per-exercise-only overrides also preclude program/template-specific rest by design. |
| D23 | Insufficient: snapshot `loadType` and frozen free-weight context, not only entity UUIDs and labels. |
| D24 | Sound only if mutable seeded fields are allowlisted and seeded-row user edits are prohibited or stored as overrides. |
| D25 | The constant and recomputation rule are correct. It does not solve lexical draft durability or specify display rounding. |

## 3. Per-ticket verdict

| Ticket | Verdict | Specific edit |
|---|---|---|
| 01 — Test target | needs edits | Define how `WT-iPhone` is created or use a reproducible destination that does not depend on pre-existing local simulator state. |
| 02 — Schema/store | needs edits | Add all downstream persisted fields, draft optionality, and `Gym.archived`; remove “later tickets add no schema” unless true. |
| 03 — Unit core | needs edits | Specify precision, rounding mode, locale, and exact kg/lb formatting examples. |
| 04 — Seeding | needs edits | Separate the ≥20 test fixture from the few-hundred-model production catalog and define seeded-field edit/override policy. |
| 05 — Gyms/preferences | needs edits | Define the first-launch app-unit preference. |
| 06 — Machines/models/exercises | needs edits | Define whether model-less machines can use machine-first logging and how their exercise is selected. |
| 07 — Core logging | needs edits | Split lifecycle/durability from snapshot/freeze/memory work; define duplicate-active cleanup, Finish cleanup, switch-machine draft handling, and keystroke durability. |
| 08 — Machine-first | needs edits | Move history rendering to 09; define model-less behavior and free-weight history/grouping semantics. |
| 09 — History | needs edits | Specify completed-only rendering/summary behavior and own free-weight snapshot labels. |
| 10 — Equipment lifecycle | needs edits | Add missing archival schema and restrict seeded-model edits or define persistent overrides. |
| 11 — Prefill/layers | needs edits | Define tagged free-weight prefill and deterministic selection when one workout contains multiple matching entries. |
| 12 — Records core | needs edits | Make eligibility/caps load-type-specific; group tagged equipment; use snapshotted load type; define deterministic ties. |
| 13 — Records UI | needs edits | Add bodyweightPlus behavior and tagged-equipment layer acceptance. |
| 14 — Rest timer | needs edits | Define failure duration, undo behavior, persisted state ownership, and first-ever permission-marker behavior. |
| 15 — Templates | needs edits | Split CRUD from startup/resolution; depend on 07; define template provenance and target-rep cardinality/capture. |
| 16 — Template drift | needs edits | Trigger on values-only drift and define exact rep reduction, incomplete-row handling, new-item targets, and duplicate-exercise matching. |
