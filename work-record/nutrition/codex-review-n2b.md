# Nutrition N2 — independent Codex review, round 2

Reviewed 2026-11-09. Claude implemented; Codex reviewed **`git diff a3dae63..0d03918`** against round 1's report.
Checkout: `ericlee4992/nutrition-02-data`, clean at **`0d039185ca10c956bcecd58392ee72a6e1111cb6`** before the
report. Read STATE and the ticket's round-1 response. Standards and Spec were reviewed independently.

No product source, UI behavior or UI test code changed. The substantive changes are the README note and
NutritionMigrationTests; the remaining changes record state, evidence and the prior report. Builds/tests used a
pinned `git archive 0d03918` snapshot under `/tmp/codex-n2b/source/`. Only this report was written in the repository;
no implementation edits, commit, push or merge.

## Spec

**No findings.** Product behavior is unchanged from the round-1 review.

The migration test now opens a second container and refetches each of the three rows it inserted: SavedFood,
FoodEntry and BodyWeightEntry (`WorkoutTrackerTests/NutritionMigrationTests.swift:96–128`). Assertions check the
food relationship, serving-options payload, saved flag, entry source/servings/meal, calculated calories, entered
weight/unit and normalized kilograms. Existing workout and set counts are also checked after reopening.

This addresses the prior reopen-evidence limitation for those three models. It does not claim second-container
coverage for SavedMeal, SavedMealItem or NutritionGoal, nor a process restart or every field. The renamed
`everyTableKeepsItsRowsAndKeyValuesThroughTheMigration` and its revised comment describe count/key-value checks;
the broader row comparison remains the round-1 rehearsal's evidence.

**Spec: 0 findings.**

## Standards

**Round-1 P3 resolved; no new findings.** `README.md:54–56` now describes JSON v12's food log, saved foods,
My meals, goals and body weights. It marks the change unreleased, says the nutrition screens are still being built,
and states that CSV remains sets/cardio. It does not imply Import exists. This satisfies AGENTS' public-overview
requirement for the export behavior change. No screenshot refresh is needed for this data-only change.

The test changes are scoped to meaningful persistence assertions and accurate coverage descriptions. No unrelated
modernization, file-split or heuristic finding.

**Standards: 0 findings.**

## Verified

Independent runs on **WT-iPhone27** `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`, iOS 27.0. Simulator preparation
ran first, **exit 0**. Artifacts: `/tmp/codex-n2b/`; `verify.sh`, runner PID `70543` (completed). The existing Orca
“Test progress (Claude r2)” tab was reused; no new terminal was opened.

| Scope | Result and evidence |
|---|---|
| Rebuild for testing, Full plan | **exit 0**, succeeded, 0 errors, 31 warnings; `build.xcresult`, `build-summary.json` |
| NutritionMigrationTests, serial, `-test-iterations 10` | **exit 0**, **4 logical tests / 40 executions**, 0 failures/skips/runtime warnings; `migration.xcresult`, `migration-summary.json` |
| Prior independent export UI, inspected rather than rerun | **2/2**, 0 failures/skips, **exit 0**; `/tmp/codex-n2/ui.xcresult` and `ui.status` |

Result bundles and independent shell-status files were read directly. The simulator's Application Support,
Preferences and Documents were backed up before the tests and restored while shut down afterwards. Exact file/hash
comparisons pass both before and after reboot (`restore-original.json`, `restore-original.status` **0**;
restore runner PID `70949`, completed).

Author evidence was also inspected directly in
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/f473a23d-3eaa-41a2-9817-2ebe24bda24e/scratchpad/`:

- `n2-migration-r2.xcresult`: **4 logical tests / 40 executions**, passed, no failures/skips. The ticket and review
  request record exit 0; no separate numeric shell-status file was retained alongside this result.
- `n2-exportui.xcresult`: **2 passed / 1 skipped**, passing result. BackupExportUITests is the intentional skip unless
  `WT_BACKUP_EXPORT=1`. No separate author shell-status file was available; the independent prior UI run above has
  its own recorded exit 0.

UI was not rerun, per AGENTS and the user's instruction: the product/UI diff is empty. Round 1's full Unit plan
**1163/1163** and migration rehearsal remain applicable to unchanged product source. That rehearsal verified one
safety copy, no additional copy on an ordinary launch, six new empty tables and no changed old rows relative to the
baseline launch; its two heart-rate checkpoint changes were reproduced on the baseline as well.

## Not verified

No full Unit plan, UI suite or full-container migration rehearsal was repeated this round. No physical-device
migration, actual TestFlight container, CloudKit synchronization, Health integration or future nutrition-screen
behavior. The second-container test is narrower than a fresh-process durability test. Import remains explicitly
outside N2. Release R's device backup/migration and release checks remain outstanding. Review clearance does not
establish merge, phone installation or release.

## Known flaky

None seen. All 40 independent migration-test executions passed without failures, skips or runtime warnings.
No result was waived as flaky.

Spec: **0 findings**. Standards: **0 findings**. Round-1 P3 resolved for `0d03918`.

Verdict: clear
