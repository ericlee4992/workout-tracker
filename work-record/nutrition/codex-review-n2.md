# Nutrition N2 — independent Codex review, round 1

Reviewed 2026-11-09. Claude implemented; Codex reviewed **`git diff b911247..a3dae63`** on
`ericlee4992/nutrition-02-data`, initially clean at `a3dae63232b1db9c146b806c76d2a30841d24dee`.
During review HEAD advanced to `da9c0a5ed1ab67b1af71eb9b521b81e1c55bcf2d`, changing only STATE. Product source
is unchanged. Independent builds/tests used a pinned `git archive a3dae63` snapshot in `/tmp/codex-n2/source/`.

Read AGENTS, STATE, the N2 brief/ticket, nutrition data rules, the relevant decisions and migration/verification
procedures. Standards and Spec were reviewed independently using the code-review and SwiftData skills. Import was
explicitly dropped by the user; JSON encode/decode compatibility is the applicable round-trip requirement.
Only this report was written in the repository. No implementation edits, commit, push or merge.

## Spec

**No confirmed product defects or missing approved behavior.**

- The six new models have UUID IDs, defaulted or optional attributes, optional inverse relationships and no unique
  constraints. SavedFood links nullify; SavedMeal owns its items through cascade. FoodEntry and SavedMealItem store
  independent serving/nutrition snapshots. The body-weight constructor and setter preserve entered value/unit and
  normalized kilograms. Unreadable serving-options data reads as no options.
- Dated goals and new records for changes match D70 and N3. The absence of `updatedAt` is intentional for this model.
  N3's approved fixed lose/maintain/gain calorie adjustments supersede the early proposal's variable rate; no missing
  rate field is identified. NutritionMath applies serving multiplication, local-calendar day/meal filtering, 4/4/9
  macro calories, grams-to-servings conversion and the latest goal effective before the next local midnight.
- Export v12 maps the new stored fields, including source, Health IDs, entered/normalized body weights and goal
  inputs/overrides. Dates use ExportDateFormat. Collections and meal items have UUID ordering tie-breaks. Deleted
  SavedFood links export as absent IDs through optional relationship access. Empty serving options are intentionally
  omitted. The new top-level collections/counts are optional; the v11 compatibility and v12 round-trip tests pass.
  CSV remains the sets/cardio ledger. No separate `isEstimated` field contradicts D78.
- This is an additive model-registration change; existing model definitions are unchanged. Automatic lightweight
  migration is supported by the fixture tests and real app-launch rehearsal below. The approved fingerprint changes
  deliberately while the shipped fingerprint remains pinned; all six new enums and the serving-options payload are
  included in the format guard. No additional schema requirement for the approved N3–N9 work was identified.

**Spec: 0 findings.**

## Standards

### 1. P3 — Document the JSON export change in the public overview

**Location:** `README.md:51–54`; the omission is recorded at
`work-record/nutrition/issues/02-nutrition-data.md:105`.

The README still describes workout export without the new nutrition collections or v12 format. The ticket waives
an update because “nothing visible changes,” but AGENTS requires the README to be updated on the same branch when
app behavior changes, not only when screens change. A user inspecting the public overview cannot discover that this
branch's JSON backup now carries foods, saved meals, nutrition goals and body weights.

**Fix:** add a brief unreleased note describing the v12 JSON additions and that CSV remains sets/cardio. Do not imply
nutrition screens or Import already exist, or that this format is already in TestFlight. No screenshot refresh is
needed for this data-only change.

No other confirmed standards violation or actionable smell. **Standards: 1 finding, P3.**

## Verification assessment

The migration tests provide useful evidence, but two names overstate their assertions:

- `NutritionMigrationTests.swift:50–92` checks table counts and selected sums/names, not every row and field. The
  independent row comparison below supplies broader old-data preservation evidence.
- `NutritionMigrationTests.swift:95–109` saves new nutrition rows and checks metadata compatibility; it does not
  refetch/reopen those rows. It is not a standalone reopen-fidelity test.

These are coverage limits, not additional observed product defects. Export tests exercise both populated and absent
optionals, round-trip equality, empty collections and older decoding. They do not directly challenge equal-primary-key
sort ties or export after deletion; those paths were inspected in source, alongside the domain deletion test.

## Verified

Independent execution on **WT-iPhone27** `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`, iOS 27.0. Preparation ran first,
**exit 0**. The simulator's Application Support, Preferences and Documents were backed up before testing.
Artifacts: `/tmp/codex-n2/`; test runner `verify.sh`, PID `64125`; rehearsal `rehearsal.py`, PID `65566`
(both completed). The existing Orca “Test progress (Claude r2)” tab was reused; no new terminal was opened.

| Scope | Result and evidence |
|---|---|
| Build for testing, Full plan | **exit 0**, succeeded, 0 errors, 31 warnings; `build.xcresult`, `build-summary.json` |
| Unit plan, serial | **1163/1163**, 0 failed/skipped, **exit 0**; `unit.xcresult`, `unit-summary.json` |
| AAAWarmUpUITests + ExportUITests, serial | **2/2**, 0 failed/skipped, **exit 0**; `ui.xcresult`, `ui-summary.json` |
| Simulator migration rehearsal and baseline comparison | Completed **exit 0**; details below; `rehearsal/result.json`, command log and comparison reports |

Counts and outcomes were read directly from xcresults and shell-status files. The Unit plan includes the requested
NutritionModelTests, NutritionMigrationTests, NutritionExportTests, StoreFormatGuardTests, SchemaTests, ExportTests,
ExportFidelityTests and SafetyCopyTests, as well as LegacyStoreMigrationTests.

**Fixture identity:** independently decoded `Z_METADATA.Z_PLIST` and hashed the sorted entity-version hashes. The
result is `9569f6fdb6ee5ee8c69173946f9cd5d62c0b09787a961bc10340b83b23fefeba`, matching the shipped pin across
15 entities (`fixture-metadata.json`). This proves the fixture's structural format, not that it is a capture from a
particular tester's phone.

**Independent rehearsal:** installed executable hashes were checked against each built binary. The baseline uses
the prior independently built `a0c0384` binary; its difference from `b911247` is only the N1 report/ticket, so app,
widget, project and resource source are identical. Each build received a fresh copy of PreNutrition.store as its
only `default.store` before launch.

- Baseline made **zero copies**; N2 made **exactly one**. Its copied primary store is byte-identical to the fixture.
  A subsequent ordinary N2 launch made no additional copy.
- Before→after comparisons return **exit 1 for both builds**, solely because unfinished workout `Z_PK 19` changes
  `ZSENSORMAXHEARTRATEBPM` from nil to 185 and `ZSENSORMAXHEARTRATEESTIMATED` from nil to 0.
- Baseline-after→N2-after returns **exit 0**: every compared old row is unchanged. Six new nutrition tables are present
  and empty. There are no missing tables/rows or changed existing column definitions. Preferences are unchanged.
- This reproduces the author's attribution. Unchanged `CardioRecorder.refresh()` at `CardioRecorder.swift:173–177`
  writes those two monitor values when resuming a workout; the launch screenshot shows the fixture's unfinished
  workout open. The difference is pre-existing launch behavior, not an N2-specific migration change.
- DEVELOPMENT calls `compare_stores.py` a same-schema tool. Its use here is bounded: all 15 existing tables retain
  identical `PRAGMA table_info` definitions (`schema-comparison.json`), and the comparator normalizes `Z_ENT` by
  entity name. The six additions were separately inspected as empty. This is not a general claim that the tool
  validates arbitrary migrations.
- Original simulator data was restored while shut down and verified **byte-for-byte**, then checked again after boot.
  Both checks pass. The N2 binary remains installed; it was not launched against the restored original data.

**Author evidence inspected directly**, under
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/f473a23d-3eaa-41a2-9817-2ebe24bda24e/scratchpad/`:
`n2-export.xcresult` **4 logical tests / 40 executions**, `n2-unit.xcresult` **1163 passed**, and
`n2-exportui.xcresult` **2 passed / 1 skipped**, all with passing result bundles. The skip is BackupExportUITests,
which requires `WT_BACKUP_EXPORT=1`. No separate numeric shell-status files were available for these author runs;
the ticket records exit 0. Author `rehearsal/compare.txt`, `compare-main.txt` and `compare-main-vs-n2.txt` contain the
same differences and successful baseline comparison reproduced independently above.

## Not verified

No physical-device installation or migration, actual build-8/9 TestFlight container, CloudKit synchronization,
Health read/write integration, full UI suite, or nutrition-screen behavior (future tickets). Import does not exist
and was explicitly removed from N2. No separate new-nutrition-row reopen-fidelity probe beyond the existing tests;
do not infer that from the migration test's name. Gate S and the combined release checks remain for R.
This report does not establish merge, installation on the user's phone or release.

## Known flaky

None seen in the selected independent tests. Unit results contain 54 audio-session runtime warnings; UI results
contain none. The 31 build warnings have no locations in changed files. The two deliberate rehearsal comparison
failures are explained baseline differences, not flakes or waived migration failures.

Spec: **0 findings**. Standards: **1 P3 finding**. Update the public overview and re-review that documentation change.

Verdict: not clear
