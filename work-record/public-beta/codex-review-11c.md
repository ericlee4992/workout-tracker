# Ticket 11 — store-format guard, round 3

Reviewed `git diff 3b2616c..HEAD` (round-2 fixes) and `git diff main..HEAD` (whole branch) in `/Users/ericlee06/orca/workspaces/Health App/public-beta`, branch `ericlee4992/beta-11-schema-guard`. HEAD: `86d8ab713543d505edbdbe24843b56c8e40526d3`; round-2 baseline: `3b2616c1f4ad30f0aa673ce7ff0499ec1231ac46`; main: `ba6cc20f078951df910120916db7605cdd893f4e`. The working tree was clean before review. Standards and spec were reviewed separately and reconciled below. Only this report was written. No builds, tests, simulators, or devices were run; existing result bundles and logs were inspected.

## Findings, ranked

No P1 or P2 finding established. Three P3 findings remain.

### P3 — Round-2 finding #4 is only partly fixed: the diagnostic still guarantees migration

**Spec axis — `WorkoutTrackerTests/StoreFormatGuardTests.swift:53–54`.** The message still says a differing fingerprint means the user's data “would go through a migration on the next update.” This is the exact inference round 2 requested removing. The fingerprint includes index metadata as well as entity version hashes (`:39–44`); a mismatch establishes a changed pinned contract, not that every installed store necessarily undergoes migration. The spec sentence was narrowed, but the diagnostic was not changed. Consequently, ticket 11's blanket “round 2 … fixed” claim (`work-record/public-beta/issues/11-safety-copy.md:81`) is premature.

Replace the migration prediction with a changed-contract/review statement, retaining the release stop and ticket-11 instructions. No production behavior change is needed.

### P3 — The new catalog-filter exclusion claims an automatic reset that does not exist

**Spec axis — `WorkoutTrackerTests/StoreFormatGuardTests.swift:91–92`.** The comment says an unknown `AppPreferences.modelBrowseMuscleGroup` “only resets that browse filter.” In fact, `WorkoutTracker/Features/Gyms/ModelPicker.swift:80–84` passes the saved string unchanged to the filter. `WorkoutTracker/Domain/CatalogBrowsing.swift:250–252` rejects categorized rows whose body areas do not contain it. An obsolete value therefore remains active and can hide categorized results until the user clears the filter; uncategorized rows survive. The clear paths are user actions at `ModelPicker.swift:327` and `:380–385`.

Excluding this field from the **enum** pin is acceptable: it stores catalog vocabulary, not a closed Swift enum, and D24 catalog reconciliation remains subject to manual review. Correct the explanation to state that boundary and the actual stale-filter behavior. Do not add an automatic reset merely to make the comment true.

### P3 — Current handoff and source-equality evidence no longer match HEAD

**Standards axis — `docs/STATE.md:6,14–15`; `work-record/public-beta/issues/11-safety-copy.md:54–56`; `WorkoutTrackerTests/StoreFormatGuardTests.swift:29–31`.** STATE still schedules round 2 as pending/to run, although its report and fixes are committed. The ticket explicitly says `git diff 936b18f..HEAD` is empty for the three production model files; that command now shows the `CardioDistanceSource: CaseIterable` addition in `Cardio.swift`. The test comment repeats unchanged-file evidence and describes builds “1–4” as already shipped, while STATE still has build 4 awaiting archive/upload.

AGENTS.md requires current handoffs to distinguish implemented, tested, merged and installed facts. Refresh the review checkpoint and describe the actual evidence: persisted model declarations and storage codecs are unchanged; `Cardio.swift` has a conformance-only change; the current guard passes; build 4 is planned. These inaccuracies do **not** imply a stored-format regression.

## Round-2 resolution and coverage

| Round-2 finding | Assessment |
| --- | --- |
| P2: missing `RoutineEquipment` / `MuscleFamily` | Resolved. Both shipped lists and independently enumerated current lists are present (`StoreFormatGuardTests.swift:85–89,108`), bringing the inventory to 14 types. The dictionary-key equality check also prevents a mismatch between the two inventories. |
| P2: payload checks bypass production storage paths | Resolved. The test inserts models in an in-memory container and reads fixed bytes through `CardioSegment.intervals`, `route`, `distanceSpans`, and `plannedCardio` on both owners, then checks bytes produced by their setters (`:125–185`). A distance span omits `selectedSourceRawValue`; a plan omits `distance` and `segmentID`; populated variants remain covered. |
| P2: added distance-source cases escape the inventory | Resolved. `CardioDistanceSource` now has synthesized `CaseIterable`, and the guard uses `rawValues(CardioDistanceSource.self)` (`:106`), independently of the expected strings. |
| P3: absolute coverage/migration wording | Partly resolved. `work-record/public-beta/spec.md:218–220` identifies structure, enum values and JSON formats, and retains manual first-launch review. The diagnostic remains incorrect as finding 1 explains. |
| P3: stale ticket-04 STATE entries | Resolved. `docs/STATE.md:30–31,68` now records merged/configured status and separates Simulator acceptance from the pending build-4 phone check. The separate ticket-11 checkpoint issue is finding 3. |

The only production-source change is the `CaseIterable` conformance and its comment (`WorkoutTracker/Domain/Cardio.swift:33–34`). Cases, raw strings, Codable representation, model properties, codecs and runtime selection logic are unchanged. No production regression from this addition was found.

The inventory review found no additional omitted closed String enum or `Data` attribute: five backing attributes use four shared Codable payload types. The remaining persisted strings are names, free text, frozen display snapshots, catalog metadata or catalog fingerprints. Catalog vocabulary and reconciliation need manual review; pinning their complete contents would be a different contract. Likewise, the guard does not exhaustively protect semantic conventions such as `Workout.zoneSeconds` positions, all possible payload values, or arbitrary first-launch rewrites. Its enum inventory is maintained explicitly, not discovered automatically. “Pinned contracts and payload samples” would be the most precise coverage wording.

Optional test strengthening, not another finding: unlike the planned-cardio checks, the three segment checks write values identical to the bytes already seeded. Clearing their backing `Data` before calling the setters would also catch a setter that becomes a no-op. Actual encoder-format drift is checked by the present comparisons. These are codec contract checks, not save/reopen persistence or migration tests.

## Verification evidence inspected

- `guard4.status` is **0**. `xcresulttool` reports **4 passed, 0 failed, 0 skipped**, including the renamed `storedCardioPayloadsReadAndWriteThroughTheAppsPaths()` test. The unchanged structural fingerprint still passes on the tested iOS 27 runtime.
- `mut3.log:265–286` records the production `segment.intervals == intervalValues` assertion failing at test line 144 and **TEST FAILED**. This supports the reported getter-date-strategy mutation. Current `Cardio.swift:198` uses the default decoder again; Git was clean. This is evidence for that mutation, not every codec mutation.
- `mut2.log:35–46,72–76` shows the added `watchGPS` case rejected by the exhaustive label switch and testing cancelled during compilation. It does **not** demonstrate a running enum-test failure. Once a new case's switches compile, synthesized `allCases` includes it and the current guard compares it against the fixed shipped set.
- `unit-full.status` is **0**. The supplied `unit-full.xcresult` at `052c212` reports **1018 passed, 0 failed, 0 skipped**; 1030 device executions include parameterized runs. Existing audio-session runtime warnings are present. This remains pre-fix full-suite evidence, not a full-suite run of HEAD. The targeted guard result supplies the later verification; no broader run was performed for this review.
- `git diff --check main..HEAD` passed. The build-1-to-HEAD production-model-file diff contains only the conformance/comment change described above. The whole branch also bumps the ten build-number settings to 4 and changes tests/documentation/review records.

Standards: one P3 finding. Spec: two P3 findings. All three round-2 P2 findings are resolved; remaining corrections concern documentation and evidence accuracy.

Verdict: not clear
