# Ticket 11 — store-format guard, round 4

Reviewed `git diff 86d8ab7..HEAD` and relevant parts of `git diff main..HEAD` in `/Users/ericlee06/orca/workspaces/Health App/public-beta`, branch `ericlee4992/beta-11-schema-guard`. HEAD: `d199e6dd29a755428f05c59468fae7f6ace2c17b`; baseline: `86d8ab713543d505edbdbe24843b56c8e40526d3`; main: `ba6cc20f078951df910120916db7605cdd893f4e`. The working tree was clean before review. Standards and spec were checked separately. Only this report was written; no builds, tests, simulators or devices were run.

## Findings, ranked P1–P3

None. All three round-3 P3 findings are resolved; no new actionable finding was identified.

## Standards

The evidence/checkpoint finding is resolved:

- `WorkoutTrackerTests/StoreFormatGuardTests.swift:30–33` distinguishes shipped builds 1–3 from planned build 4 and identifies the later conformance-only change.
- `work-record/public-beta/issues/11-safety-copy.md:54–57` correctly bounds the historical empty diff to `936b18f..052c212`. That diff is empty for `Models.swift`, `Cardio.swift` and `WorkoutSensorSample.swift`; the same files from build 1 to HEAD differ only by the `CardioDistanceSource: CaseIterable` addition and its comment. The text explicitly distinguishes source evidence from measurement of shipped binaries.
- `docs/STATE.md:6,14–17` now records round 4 pending, attributes the full unit suite to `86d8ab7`, and leaves merge/archive/upload as future steps. The ticket's round-3 checkpoint (`:95–100`) agrees.

No substantive standards violations or code-smell findings in the fixes.

## Spec

Both wording findings are resolved:

- **Structure diagnostic — `WorkoutTrackerTests/StoreFormatGuardTests.swift:55–59`:** a mismatch establishes a changed pinned structure and says the update “may change” storage. It no longer guarantees migration. The release stop, ticket-11 safety copy and migration-review instructions remain.
- **Catalog exclusion — `WorkoutTrackerTests/StoreFormatGuardTests.swift:93–95`:** the comment correctly explains that an obsolete catalog area stays saved and hides categorized models until the filter is cleared. This matches `ModelPicker.swift:80–84` and `CatalogBrowsing.swift:248–252`; uncategorized models remain eligible. Catalog vocabulary remains outside the closed-enum pin and requires manual review. No reset behavior was added.

The optional strengthening is correct at `WorkoutTrackerTests/StoreFormatGuardTests.swift:148–150,158–160,171–173`. Each fixed sample is first read through its production getter, then its backing `Data` is cleared before the production setter runs. The setters encode their supplied values independently (`WorkoutTracker/Domain/Cardio.swift:163–165,197–203`). `expectShape` requires nonnil output (`StoreFormatGuardTests.swift:195–198`), so a no-op setter now fails instead of reusing seeded bytes; the subsequent JSON comparison still checks the emitted shape. The planned-cardio checks already use the same reset pattern.

No missing requirement, unintended product change or new regression was found in this round. These remain pinned-contract and sample-codec checks, not exhaustive format-change detection, migration tests or save/reopen persistence tests. First-launch rewrites and catalog changes still require manual review. The automatic safety copy remains deferred as authorized.

## Verification evidence inspected

- `/tmp/wt-floodlight/results/11/guard5.status` contains **0**. `guard5.log:267` records **TEST SUCCEEDED**. `xcresulttool` reports **4 passed, 0 failed, 0 skipped**, including `storedCardioPayloadsReadAndWriteThroughTheAppsPaths()`, with no runtime warnings. This is the supplied post-edit guard run.
- `unit-full2.xcresult` reports **1020 passed, 0 failed, 0 skipped**; the 1032 device executions include parameterized runs. `unit-full2.log:2873,2881` records the 1020-test pass and **TEST SUCCEEDED**. The bundle contains audio-session runtime warnings. No separate `unit-full2.status` file was present. As recorded by the user and ticket, this is full-suite evidence at **86d8ab7**, not a full-suite run of HEAD.
- `git diff --check 86d8ab7..HEAD` and `git diff --check main..HEAD` pass. The round-3 code delta is confined to test setup; production code is unchanged from the full-suite baseline. The targeted post-edit guard run is proportionate under DEVELOPMENT's verification-scope policy.

Standards: 0 findings. Spec: 0 findings. No P1, P2 or P3 remains from round 3.

Verdict: clear
