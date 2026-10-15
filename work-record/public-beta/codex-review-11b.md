# Ticket 11 — store-format guard, round 2

Reviewed `git diff 052c212..HEAD` (fixes) and `git diff main..HEAD` (whole branch) on `ericlee4992/beta-11-schema-guard`, with HEAD `3b2616c1f4ad30f0aa673ce7ff0499ec1231ac46`, baseline `052c2128616424bfb2b3392445a5ed53706f21bb`, and main `ba6cc20f078951df910120916db7605cdd893f4e`. The working tree was clean before review. Only this report was written; no builds, tests, simulators, or devices were run. Existing result bundles and logs were read.

## Findings, ranked

### P2 — The enum inventory still omits persisted raw strings

**Spec axis — `WorkoutTrackerTests/StoreFormatGuardTests.swift:70–101`.** Ticket 11:71 promises “every stored enum's raw values pinned,” but two String-backed enums are missing from both inventories:

- `RoutineEquipment` (`WorkoutTracker/Domain/AIRoutine.swift:4–5`): `AIRoutinePersistence.save` writes `extras.map(\.rawValue)` to `WorkoutTemplate.confirmedEquipment` at `:144`. This is a persisted `[String]` attribute (`WorkoutTracker/Domain/Models.swift:219`), not merely request metadata. Its eight raw values can change without any guard noticing. The same array also stores `CardioActivity`, which is covered.
- `MuscleFamily` (`WorkoutTracker/Domain/MuscleFamily.swift:11–16`): `ExercisesView.choose` writes `family?.rawValue` to `AppPreferences.exerciseBrowseMuscleGroup` (`WorkoutTracker/Features/Exercises/ExercisesView.swift:251–252`; `Models.swift:718`). `ExerciseCatalog.family(stored:)` reads those strings (`WorkoutTracker/Domain/ExerciseOverview.swift:174–176`). For example, changing the `arms` raw value loses the meaning of an existing `"Arms"` filter: the legacy body-area fallback does not recognize that string. Neither schema hashes nor the current enum/JSON checks detect it.

Add both types and their shipped values to the guard, and update the ticket's count of 12. Inventory string writers as well as enum-typed and `*RawValue` declarations. The explicitly enum-typed properties, including `Exercise.equipmentTypeTags: [EquipmentTag]`, and the current `CardioSegment`/`WorkoutSensorSample` `*RawValue` properties are represented; the omissions are generically named String storage.

### P2 — Payload checks bypass production storage paths

**Spec axis — `WorkoutTrackerTests/StoreFormatGuardTests.swift:124–165`.** Ticket 11:73–74 says the samples “must decode, and today's encoder must still write their shape.” The first three samples decode through a test-local `JSONDecoder`, and all four shapes encode through a test-local `JSONEncoder`. The test never assigns/reads `CardioSegment.intervals`, `route`, or `distanceSpans`, nor calls the planned-cardio writer `CardioPlanStorage.replacing` or either model's `plannedCardio` setter.

The samples match the current implementation, but the guard does not protect those actual paths. For example, changing the decoder's date strategy in the `intervals` getter (`WorkoutTracker/Domain/Cardio.swift:197`) would reinterpret old dates while the test's independent decoder and all three guard layers remain unchanged. Changing the production encoder strategy similarly changes newly stored data without changing the guard's output. This is a code-only stored-format change, not the documented first-launch rewrite exclusion.

Load fixed bytes into each backing `Data` attribute and assert through the production getters; write values through production setters and compare their backing JSON with the fixed samples. Exercise both owners of `cardioPlanData`. Include a plan with absent optional `distance`/`segmentID` and a distance span without `selectedSourceRawValue`: today's fully populated samples also cannot detect a decoder that starts requiring these previously omitted keys. The supplied CodingKey mutation proves the Codable-type check works, but does not exercise these storage seams.

### P2 — New distance-source cases evade the claimed addition guard

**Spec axis — `WorkoutTrackerTests/StoreFormatGuardTests.swift:98–109`.** The test and ticket explicitly include enum additions in changes requiring review (`:68–69`; ticket 11:72). For `CardioDistanceSource`, however, “current” values are computed by filtering the expected list. A new enum case cannot enter that result. The `.mixed.rawValue == "mixed"` assertion checks only that existing case; it cannot detect another one.

An added source leaves the stored String/Data attribute descriptions unchanged, and the fixed GPS payload remains valid. All guards therefore pass. Renames/removals of existing source strings are checked, but additions are not. Enumerate the actual cases independently, using `CaseIterable` or an exhaustive case mapping whose completeness the compiler enforces.

### P3 — The spec still promises the absolute protection rejected in round 1

**Spec axis — `work-record/public-beta/spec.md:218`; related `WorkoutTrackerTests/StoreFormatGuardTests.swift:52–53`.** The whole-branch diff still adds “`StoreFormatGuardTests` fails on any format change.” That is inconsistent with the now-explicit manual-review boundary in the test (`:19–21`), DEVELOPMENT (`:279–280`), and ticket (`:74`). Narrow the spec to the contracts actually pinned and retain manual review for first-launch rewrites and other unguarded changes.

Also, changing “will migrate” to “would go through a migration” has not removed the categorical inference from a fingerprint mismatch. The fingerprint now includes index metadata as well as version hashes; a mismatch is a release stop, not proof that every installed store will undergo a hash-incompatible migration. Say the stored contract changed and requires review/copy protection, without predicting migration from this check alone.

### P3 — STATE's ticket-11 correction leaves a contradictory ticket-04 handoff

**Standards axis — `docs/STATE.md:67`, also `:30`.** The exact round-1 ticket-11 stale entries are fixed: Next and the ticket table now defer the copy and schedule guard review/merge. But STATE still says ticket 04's review and Google client ID are pending, and its agreed-order entry still directs client creation. The updated NOW section (`:8–9`) says 04 is merged and Google is configured; ticket 04 records its clear review and configuration. This violates AGENTS.md's requirement to update existing facts and keep a consistent current handoff. Mark those entries merged/configured, with build-4 upload and phone acceptance still pending.

## What is resolved and what the evidence establishes

### Structure and indexes

The pinned value is unchanged in the fix diff: `9569f6fdb6ee5ee8c69173946f9cd5d62c0b09787a961bc10340b83b23fefeba`. For an entity without indexes, the new implementation emits the same sorted `name:hex(versionHash)` lines as the previous dictionary implementation. It appends index data only for nonempty lists. The passing structural test in `guard3.xcresult` corroborates that the current generated model still produces that exact pin on the tested runtime; adding index handling did not silently repin it.

Index names, ordered element property names, and ascending flags now participate. The added-model probe runs through the same SHA-256 helper as the real guard, fixing round 1's probe issue. However, no index mutation was exercised by the supplied evidence: the probe adds a model, and the mutation run changes an enum raw value and a JSON key. This is not an exhaustive index-metadata or cross-runtime stability test. The same-process repeat checks only stability between calls.

`git diff 936b18f..HEAD` remains empty for the three production model files. The revised historical explanation properly distinguishes unchanged source from measuring each shipped binary. Build 4 is still planned, so the test comment's “every TestFlight build so far (1–4)” should be read with that qualification rather than as evidence of an upload.

### JSON samples and limits

There are five production `Data` attributes and four shared payload types:

| Attribute | Current production codec | Sample assessment |
| --- | --- | --- |
| `CardioSegment.intervalsData` | `[CardioInterval]`, default JSON codec (`Cardio.swift:196–198`) | Keys and reference-date seconds match. |
| `CardioSegment.routeData` | `[CardioRoutePoint]`, default JSON codec (`:200–202`) | UUIDs, coordinates, date, accuracy and portion match. |
| `CardioSegment.distanceSpansData` | `[CardioDistanceSpan]`, default JSON codec (`:162–164`) | String-keyed readings/dates and selected source match. |
| `WorkoutTemplate.cardioPlanData` | `CardioPlanStorage` (`PlannedCardio.swift:50–55`) | Fully populated plan matches. |
| `Workout.cardioPlanData` | Same storage helper (`:57–62`) | Same shared format; no separate wire type is missing. |

The production plan writer encodes with default `JSONEncoder` and reserializes sorted JSON (`PlannedCardio.swift:37–47`); comparing parsed objects correctly ignores key order. The plan sample does use the production reader and `hasUnknown`. These are useful contract checks, subject to the production-path and optional-field gaps above.

The first-launch rewrite caveat now agrees across test, DEVELOPMENT and ticket. It should mean “not covered by these format guards,” not literally that no other tests exercise seeding or repairs. Passing guards also do not pin every semantic convention: for example, `Workout.zoneSeconds` positions depend on `HeartRateZone` raw integers/order (`Models.swift:341–345`; `WorkoutSummary.swift:202–203`), beyond this String-enum inventory.

### Existing verification inspected

- `guard3.status`: **0**. `xcresulttool` reports **4 passed, 0 failed, 0 skipped**, WT-iPhone27 / iOS 27.0. This confirms the current samples and unchanged structural pin pass; it does not establish unexecuted mutation cases.
- `mut.log:1256–1270`: the structural guard and added-model probe pass; the payload test fails on missing `begin`, and the enum test reports `WeightUnit` changing from `kg` to `KG`. `:1282` records **TEST FAILED**. Current source and clean Git status confirm the described mutations were reverted.
- `unit-full.status`: **0**. `unit-full.xcresult` reports **1018 tests passed, 0 failed, 0 skipped**; its device count is 1030 runs because four tests have dynamic parameters. This is the supplied pre-fix baseline at `052c212`, not a full-suite run of the revised guards. Existing audio-session runtime warnings are present.
- The whole branch changes tests, documentation/review records and ten build-number settings; it does not change production model/codec implementation. No new production regression was established. The outstanding issues are guard blind spots and handoff/coverage claims.

Standards: one P3 finding. Spec: three P2 findings and one P3 finding. No P1 finding established. Round 1's coverage finding is only partially resolved; its exact ticket-11 STATE contradiction is resolved, with the separate stale ticket-04 entries remaining.

Verdict: not clear
