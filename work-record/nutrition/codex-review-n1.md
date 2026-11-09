# Nutrition N1 — independent Codex review

Reviewed 2026-11-09. Claude implemented; Codex reviewed `git diff 52c1270..a0b17ab` on
`ericlee4992/nutrition-01-safety-copy`. Checkout was initially clean at
`a0b17ab8aff38ec7005ecb6fc830d63f5cbc02ae`. During review, HEAD advanced to
`581c43865629dfb5ce13c681b7e679db634c2447`; that commit changes only `docs/STATE.md`, which was reread.
Product source and test scope are unchanged.

Read the N1 brief and ticket, original public-beta ticket 11, relevant specifications, D28, DEVELOPMENT's backup
and verification rules, and the code-review, SwiftUI, SwiftData and iOS design skills. Standards and Spec were
checked independently and reconciled against source and artifacts. Per the user's instruction, this review resumes
the interrupted Codex review: existing results were inspected, including fresh `xcresulttool` reads of the result
bundles. No build, test or rehearsal was rerun. Only this report was written in the repository; no commit or push.

## Spec

### 1. P1 — Preserve the current store until replacement commits

**Location:** `WorkoutTracker/Domain/SafetyCopy.swift:178–183`; launch handling at `:220–224`.

The ticket promises staging “so a failure part-way leaves today's data.” After staging, restore deletes every current
store file before moving replacements individually. A deletion or move failure can leave a missing or mixed store.
The deferred cleanup consumes the restore request, and launch catches the error and permits opening. With the primary
file absent, `storeNeedsCopy` returns false and opening creates an empty database. The Settings message “Your data is
unchanged” is then false.

**Evidence:** `/tmp/codex-n1/restore-failures.swift` starts byte-for-byte with the current production
`SafetyCopy.swift`. Its FileManager stand-in rejects the first move from `.restoring-*` after staging succeeds.
`restore-failures.log` records two original rows, an `.open` outcome carrying a restore failure, the primary file and
request both absent, and **zero rows after reopening**. The old safety copy survives, but the newer row is lost.
The repository test `aRestoreThatFailsKeepsTodaysDataAndIsNotRetried` injects only a staging-copy failure and misses
this replacement phase.

**Fix:** retain the complete current file set until a recoverable replacement transaction commits. Persist enough
recovery state to resolve interrupted swaps before any container can open; do not open a missing/mixed store after
catching a replacement error. Test failures during deletion/movement and restart at interruption points. Report the
actual recovery outcome.

### 2. P2 — Do not dismiss cancellation while restoration remains armed

**Location:** `WorkoutTracker/Domain/SafetyCopy.swift:151–152,160`; `WorkoutTracker/App/StoreGate.swift:45–47`.

The ticket offers “Cancel Restore,” and the review brief requires the request to be cleared either way. Cancellation
suppresses every removal error, while StoreGate unconditionally clears its pending UI state. If unlink fails, the
user can resume logging after Cancel, but the surviving request restores old data on the next launch and discards
those entries. The same suppressed cleanup error can repeat an already completed restore on a later launch.

**Evidence:** the same source-exact harness rejects removal of `restore-pending.json`; its log confirms cancellation
returns normally while `pendingRestore` still decodes the request. The gate's unconditional UI dismissal is visible
in the source. This probe completed its reproduction assertions; no separate shell-status file was retained.

**Fix:** propagate cancellation/consumption failures and durably disarm the request before allowing normal operation.
Keep the waiting screen with an actionable error if Cancel fails. Add coverage for both user cancellation and
launch-time request consumption.

No unsupported scope expansion found: files-only, metadata compatibility, next-launch restoration and Try Again are
recorded ticket decisions. **Spec: 2 findings; worst P1.**

## Standards

### 3. P2 — Isolate the pending-restore screen from covered controls

**Location:** `WorkoutTracker/App/WorkoutTrackerApp.swift:161–172`.

The waiting state is only a visual overlay. The underlying app is not disabled or hidden from accessibility.
The saved accessibility tree contains the covered Profile controls and reports `Train exists=true enabled=true`.
This leaves unrelated controls exposed during a state intended to prevent further logging, contrary to the project's
accessibility requirement. Existing tour handling at `:200–210` explicitly disables its underlying app and notes that
the UIKit tab bar also needs a selection guard.

**Evidence:** `ax-probe.xcresult` passes its one diagnostic test; `pending-restore-accessibility.txt` records the tree.
The scratch test was inspected: it confirms the pending screen, reads the tree/enabled state, then cancels. It does
**not** demonstrate VoiceOver activation or an actual data write; those are not claimed as reproduced.

**Fix:** disable underlying actions and hit testing, isolate accessibility focus to the pending screen, and guard native
tab selection where needed. Preserve Cancel Restore and the restored-data alert. Verify covered controls cannot
activate while waiting, rather than checking only that the overlay exists.

### 4. P3 — Update the public overview before merging

**Location:** `README.md:51–65` (feature overview; unchanged in this diff).

AGENTS explicitly requires a README update on the same branch when app behavior changes. N1 introduces automatic
copies and a Profile restore flow, but the public overview omits them.

**Fix:** document the migration trigger, local newest-two retention and next-launch restore behavior, clearly marked
as unreleased. Refresh any screenshot depicting the changed state if applicable; do not imply this is in TestFlight.

No additional actionable smell, unrelated modernization or file-split finding. **Standards: 2 findings; worst P2.**

## Checks without additional findings

- Migration detection: the saved source-exact metadata harness covers inferred lightweight migrations adding an
  optional attribute or entity, ordinary launches before/after migration, nil model, unreadable and absent stores,
  and incompatible/matching metadata committed only in WAL while the primary file remains byte-identical. All 18
  checks passed. This is Core Data evidence on macOS; the WAL fixture changes metadata, not the physical schema.
- Startup: the former post-container preparation body is preserved verbatim in `prepare(_:)`. Activity-command
  installation, catalog/fixture work and preferences keep their order. Main UI/container-getter access remains behind
  the nonnil-container guard. Production store opening is gated; activity commands use the installed container;
  the widget does not open the store and the tour uses an in-memory container.
- Copy: space preflight, hidden staging, size checks, manifest, newest-two pruning with pending-copy protection and
  the Application Support destination match the recorded decisions. No backup-exclusion flag was added. Successful
  restoration removes surplus side files and skips copying the restored files again. These do not cure findings 1–2.
- Tests: closed Core Data stores are useful fixtures for file operations and metadata; the separate SwiftData app
  rehearsal supplies integration evidence. Test-plan mapping includes SafetyCopyUITests; the schema guard changes
  its guidance without changing the pinned schema. The wording list is in the ticket; STATE still marks user wording
  approval pending, so this report does not treat it as approved.

## Verified

Reused prior Codex artifacts under `/tmp/codex-n1/`, on WT-iPhone27
`47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`, iOS 27.0. Commands are recorded in `verify.sh` and `ax-probe.sh`.
The saved preparation log reports the simulator ready and booted.

| Scope | Result and evidence |
|---|---|
| Build for testing, Full plan | Succeeded, **exit 0**, 0 errors, 31 warnings; `build.status`, `build.xcresult`, `build-summary.json` |
| Unit plan, serial | **1134/1134**, 0 failed/skipped, **exit 0**; includes SafetyCopyTests, StoreFormatGuardTests and SchemaTests; `unit.status`, `unit.xcresult`, `unit-summary.json` |
| Warm-up + SafetyCopyUITests + CoreLoopUITests, serial | **17/17**, 0 failed/skipped, **exit 0**; `ui.status`, `ui.xcresult`, `ui-summary.json` |
| Pending-restore accessibility diagnostic | **1/1**, **exit 0**; `ax-probe.status`, `ax-probe.xcresult`, `ax-probe-summary.json`; limited observation described in finding 3 |
| Metadata harness | **18 checks passed, exit 0**; `metadata-check.swift`, `.log`, `.status` |
| Restore failure probes | Reproduction assertions completed; source and log inspected; findings 1–2 are demonstrated failures, not passing safety requirements |
| Simulator rehearsal | `rehearsal.status` and `rehearsal2.status` **0**; comparison **exit 0**, every row across 15 tables preserved, preferences unchanged |

The rehearsal scripts/results were inspected: a real app store with 6 workouts, 58 sets and 1 gym was placed in the
app's normal location; forced launch made one copy, ordinary launch made no additional copy, and restoration after
closed-store damage recovered the rows with no second copy or pending request. The final rehearsal records the
simulator's original Application Support, Preferences and Documents restored byte-for-byte and still identical after
boot. `rehearsal2/after-restore-15s.png` visibly retains the “Data restored” alert. This review did not alter the simulator.

Real captures inspected: all four N1 states in `captures-light-default/` and `captures-light-axl/`, plus the author's
eight `safety-copy-{failed,row,confirm,pending}-dark-{default,axl}_0.png` captures. N1 strings are whole at both sizes,
the date/deletion warning fits, and the intended hierarchy remains. Accessibility isolation remains finding 3.

Author evidence was also read directly with `xcresulttool` under
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/b075476f-cb86-4797-a96b-088b73936c7a/scratchpad/m/`:
`n1-unit` **1134/1134** and `n1-ui3` **28/28**, both shell status **0**; `n1-safety3` **18 logical tests passed**
(ticket records ten iterations), `n1-ui2` **6/6**, and `n1-guard` **22/22** have passing result bundles but no separate
shell-status files. The earlier `n1-ui1` reports **3 passed / 5 failed, exit 65**, consistent with the ticket's fixed
missing-restore-row defect. Broader author UI scope covers Settings and Export as well as SafetyCopy/CoreLoop.

## Not verified

No full UI suite, phone install, physical-device migration, actual iCloud/computer backup restore, human VoiceOver
session or real Lock Screen command launch was performed. Backup inclusion is supported by the normal Application
Support location, not a device-backup experiment. The simulator rehearsal forces the trigger using the existing
schema; it does not build the future N2 schema. Process-kill recovery during replacement was not exercised; the saved
move-error reproduction already demonstrates the unsafe path. The accessibility probe is diagnostic scratch code,
not a repository regression test. No claim of wording approval, merge, installation or release is made.

## Known flaky

No failures or retries are reported in the reused final Codex unit/UI summaries. Unit results contain 54 audio-session
runtime warnings; UI results contain four invalid-frame warnings. These are recorded separately from failures.
The earlier author's missing-row failure was a fixed defect, not waived as flaky. Historical unrelated UI flakes
remain outside this scope. The confirmed replacement and cancellation defects are deterministic failure-handling
issues, not flakes.

Spec: **2 findings, worst P1**. Standards: **2 findings, worst P2**. Resolve and re-review.

Verdict: not clear
