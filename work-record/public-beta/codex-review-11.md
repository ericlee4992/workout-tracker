# Ticket 11 — deferral and store-format guard review

Reviewed `git diff ba6cc20..052c212` on `ericlee4992/beta-11-schema-guard`, 2026-10-14. `main` resolves to `ba6cc20f078951df910120916db7605cdd893f4e`. HEAD advanced from `2e46e6d` to `052c2128616424bfb2b3392445a5ed53706f21bb` during initial inspection; the additional commit only changes build numbers to 4. This report covers both commits. No builds, simulators, or devices were run; only this report was modified.

## Findings, ranked

### P2 — The guard does not cover every stored-format change promised by the deferral

**Spec axis — `WorkoutTrackerTests/StoreFormatGuardTests.swift:21–26`; `work-record/public-beta/spec.md:218`; `docs/DEVELOPMENT.md:277–278`.**

The test fingerprints Core Data entity descriptions, not every format of the data stored inside them. A concrete counterexample already exists in this app: `CardioSegment.intervalsData`, `routeData`, and `distanceSpansData` are opaque `Data?` attributes (`WorkoutTracker/Domain/Cardio.swift:125–127`). Renaming the Codable `CardioInterval.start` member (`:69–72`) without a compatible CodingKey changes the JSON format but leaves the Core Data attribute description and this fingerprint unchanged. Existing intervals then fail decoding and become `[]` at `:196–198`. The guard still passes. The same issue applies to route/span payloads and to application-level repairs that rewrite existing rows. These are not automatic Core Data schema migrations, but they are stored-format/data changes covered by the stated safety goal and DEVELOPMENT's rule at `:271–273`. Apple explicitly distinguishes opaque payload-format changes from structural model changes in [Understanding Versions](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreDataVersioning/Articles/vmUnderstandingVersions.html).

There is also an explicit metadata limit: Core Data's [indexes](https://developer.apple.com/documentation/coredata/nsentitydescription/indexes) are excluded from entity version hashes. The implementation does not separately fingerprint indexes. Index maintenance is distinct from a hash-incompatible entity migration; do not claim that every index change necessarily triggers that migration, or that the current probe proves SwiftData index coverage.

Keep this useful structural guard, but remove the unqualified “any format change” guarantee and add an enforceable check for persisted payload contracts and store metadata excluded from the hash. Document that first-launch data-rewrite changes still require the backup/migration review. Add focused mutation/compatibility cases for those boundaries; the added-model probe alone cannot establish them. The deferral itself is authorized; the problem is relying on broader protection than this test supplies.

### P3 — STATE still schedules the work that was just deferred

**Standards axis — `docs/STATE.md:17`, `docs/STATE.md:76` (inconsistent with the changed `:33–34`).**

The current “Next” still puts ticket 11's design questions before build 4, and the ticket table still says “Ready (5th); design questions first.” Those contradict the accepted deferral in the ticket, spec, DEVELOPMENT, and STATE's updated order. AGENTS.md requires STATE to be the current handoff and existing facts to be updated. Change both stale entries to the deferred trigger, with the guard's review/merge status separately identified, so the next session does not restart the deferred implementation.

## Coverage and evidence

### 1. What the fingerprint establishes

Sorting entity names and hashing their complete hexadecimal version hashes is deterministic and preserves changes to the underlying name/hash dictionary, subject to the ordinary theoretical hash-collision limitation. SHA-256 does not add coverage for metadata that Core Data excluded before hashing.

| Change | Assessment |
| --- | --- |
| Add/remove a persistent attribute; change optionality or Core Data attribute type | Covered by the generated property's version hash. |
| Add/remove a model in the actual schema | Covered by the entity dictionary. Adding one model is the only mutation exercised by the supplied probe. |
| Rename an entity or persisted property | Names participate in the hashes; a generated model-name change is covered. |
| Relationship destination, inverse, cardinality | Included in Core Data's documented compatibility inputs. |
| Delete rule | Apple's versioning guide lists it as a compatibility input. The current SDK's `NSRelationshipDescription.h:38` hash summary does not explicitly list it; the supplied tests do not exercise it. I have not established a delete-rule bypass or a runtime guarantee across the supported OS versions. |
| Entity/property version hash modifier | Included, not a blind spot. `hashModifier` is available on SwiftData's attribute and relationship macros. |
| `.unique` / uniqueness constraints | Core Data's SDK `NSEntityDescription.h:73–81` explicitly says uniqueness constraints participate in the entity hash. This also remains prohibited by this project's CloudKit-compatible model convention. |
| `originalName` / renaming identifier | A migration mapping hint is not interchangeable with changing the persisted property name. The [renaming identifier](https://developer.apple.com/documentation/coredata/nspropertydescription/renamingidentifier) resolves source/destination mappings; it is not listed among the [property hash inputs](https://developer.apple.com/documentation/coredata/nspropertydescription/versionhash). A rename that changes the generated name is covered, but the evidence does not establish that every isolated mapping-hint edit changes this fingerprint. |
| Indexes | Explicitly excluded from the Core Data entity hash; see finding P2. |
| Method bodies, computed presentation logic, comments | Do not alter the persistent model description and should leave the fingerprint unchanged. Code that changes encoded payloads or rewrites stored rows is not safely classified as an irrelevant code-only edit. |

Structural compatibility inputs are documented in Apple's [versioning guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreDataVersioning/Articles/vmUnderstandingVersions.html); SDK headers were inspected in the installed iPhoneOS SDK. No exhaustive SwiftData mutation matrix was executed, as requested. In particular, the evidence supports a Core Data structural compatibility guard, not a proof about every SwiftData attribute option or every future migration implementation.

### 2. The guard currently uses the shipped model set

`WorkoutTrackerApp.init` calls `WorkoutTrackerStore.makeContainer()` (`WorkoutTracker/App/WorkoutTrackerApp.swift:28–30`). `WorkoutTrackerStore.schema` is exactly `Schema(modelTypes)` (`WorkoutTracker/Domain/Models.swift:847–865`), and `makeContainer` passes that schema to both the configuration and persistent container (`:869–877`). There is no production `VersionedSchema` or `SchemaMigrationPlan` in the reviewed tree.

All 15 production `@Model` declarations are represented in `modelTypes`. An unrelated, unregistered model that is never part of this container is not a missed change to this shipped store. A future alternate container/schema or migration plan would need its own coverage; this test currently reads the type list directly, not a container's actual opened-store metadata.

### 3. Historical baseline: source claim supported, wording needs precision

Both `git diff 936b18f..052c212 -- <model files>` and `git log 936b18f..052c212 -- <model files>` are empty for every production model file. Thus the interval has neither a net change nor an intervening edit/revert to those files. Repository-wide declaration searches at both endpoints found:

- `WorkoutTracker/Domain/Models.swift`: 13 model types, including the shared container construction.
- `WorkoutTracker/Domain/Cardio.swift`: `CardioSegment`.
- `WorkoutTracker/Domain/WorkoutSensorSample.swift`: `WorkoutSensorSample`.

There are **three production model files**, not four as ticket 11 says at `work-record/public-beta/issues/11-safety-copy.md:55`. The fourth current file is the newly added test-only `FormatProbe` at `WorkoutTrackerTests/StoreFormatGuardTests.swift:52`; it is absent from production `modelTypes`. No additional production `@Model` declarations were found.

The pin `9569f6fdb6ee5ee8c69173946f9cd5d62c0b09787a961bc10340b83b23fefeba` is justified as the measured current generated schema with unchanged production model source since build 1. It was not independently extracted from each archived TestFlight binary/store. The literal “every TestFlight build” claim should retain that distinction: equal source is strong evidence, not a measurement of each shipped binary under every OS/framework version.

### 4. Deferral and failure instructions

Ticket 11's decision, spec `:215–218`, and DEVELOPMENT `:270–278` agree: build the automatic copy with the first store-changing update, before opening the old store. STATE records that decision but retains the contradictions identified above.

The assertion message (`WorkoutTrackerTests/StoreFormatGuardTests.swift:33–37`) gives the right order: implement ticket 11's pre-open copy, follow migration rules with a legacy-store fixture from the installed commit, obtain the user's approval, then update the pin. Its categorical assertion that a mismatch means phones “will migrate” is stronger than the evidence: a mismatch establishes model differences and a release stop, not successful migration or the provenance of every old store. Conversely, a matching pin must not waive review of the P2 cases.

### Existing test evidence inspected

- `guard1.log:501–509`: the placeholder assertion fails, prints the exact pinned fingerprint, and the added-model probe passes. This establishes a functioning failure path, not broad mutation coverage.
- `guard2.status`: `0`; `guard2.log`: `** TEST SUCCEEDED **`.
- `guard2.xcresult`, read with `xcresulttool`: **5 passed, 0 failed, 0 skipped**, iOS 27.0 on WT-iPhone27. Both guard tests and SchemaTests' `allRelationshipsAreOptional`, `archivalUsesFlagsAndNeverTouchesHistory`, and `roundTripThroughFreshContainer` passed.
- The probe compares the two entity-hash dictionaries; it does not pass a changed schema through the SHA-256 helper. Its stability assertion repeats the helper in one process, so it does not establish cross-runtime or cross-build stability.

Standards: one P3 finding. Spec: one P2 finding. No P1 finding established.

Verdict: not clear
