# Nutrition N1 — independent Codex review, round 2

Reviewed 2026-11-09 on `ericlee4992/nutrition-01-safety-copy`, initially clean at
`e8935eb020b8ab25267ca3005b2c083c46632108`. Scope: `git diff 7e532e6..e8935eb`, against
`codex-review-n1.md` and the ticket's “Codex round 1” fix mapping. Claude implemented. Codex independently reviewed
the Standards and Spec axes, built, reran affected tests, and inspected author artifacts. This reviewer wrote only
this report; probes and results are under `/tmp/codex-n1b/`. No implementation edits, commit, push or merge by this
reviewer. At final inspection, concurrent working-tree edits appeared in SafetyCopy.swift and SafetyCopyTests.swift,
and this report had been staged externally. Those subsequent edits are not covered: this verdict is for `e8935eb`.

## Spec

### 1. P1 — Do not reuse another transaction's rollback files

**Location:** `WorkoutTracker/Domain/SafetyCopy.swift:220–221,250–254,264–267`.

The post-commit sweep ignores removal failures, leaving `.replaced-*` files behind. A process exit between commit
and sweep can also leave them. The next restore uses the same names: its attempt to set current data aside fails
because the old destination exists. Recovery then mistakes that stale file for the new transaction's original,
deletes today's store and substitutes data from before the earlier restore. This violates the ticket's promise that
a failed swap rolls back to the current data.

**Reproduced:** a real SQLite fixture has `before` in its copy and `before, after` in its current store. The first
restore commits while an injected cleanup error retains its `.replaced-*` files. After logging `logged-after-restore`,
a second restore fails: rows change from `[before, logged-after-restore]` to `[after, before]`. The launch permits
opening with a restore-failure message, despite current data having changed. Neither the requested copy nor the
pre-attempt data is the resulting store.

**Fix:** give each transaction its own staging/rollback identities and record ownership in the journal. Resolve or
reject leftover files before beginning another transaction; never infer that a fixed `.replaced-*` name belongs to
the current restore. Test consecutive restores after failed or interrupted post-commit cleanup.

### 2. P1 — Keep the store closed when an existing journal cannot be read

**Location:** `WorkoutTracker/Domain/SafetyCopy.swift:243–246,305–313`.

`restoreWasInterrupted` sees the journal, but `recoverInterruptedRestore()` suppresses its read error with `try?` and
returns success. Launch reports that the restore was undone and proceeds. If interruption left the primary store
under its `.replaced-*` name, opening creates a new empty database while the unresolved journal remains.

**Reproduced:** construct the interrupted state after setting aside the current files, make the journal unreadable
with permissions `000`, and run the production launch function. Outcome is `.open`, the journal still exists, and
reopening returns **zero rows**. The recoverable original is still set aside; it was not restored before opening.

**Fix:** distinguish absence from failure to read an existing journal. Propagate read errors into `.blocked`, retain
the journal and backups, and require successful recovery before opening. Add the unreadable-journal case alongside
the existing rollback-move failure test.

### 3. P1 — Recover relative to the store's current location

**Location:** `WorkoutTracker/Domain/SafetyCopy.swift:217–218,247–259`.

The journal persists an absolute `storeFolder`. If the container directory moves between interruption and recovery,
the journal travels with the data but still points at the old directory. Recovery finds no originals there, silently
skips them, deletes the journal and permits opening the actual store without restoring its set-aside files. This
contradicts the next-launch recovery guarantee for a copied/relocated app container.

**Reproduced:** move the complete interrupted fixture directory, including SafetyCopies and the set-aside original,
then launch using the new store and copies URLs. Outcome is `.open`, the journal is removed, and reopening returns
**zero rows**. This is a filesystem relocation simulation, not an observed iOS update or device-backup restore.

**Fix:** pass the current store URL into recovery and resolve validated relative filenames there. Verify the expected
original file set is recovered before clearing the journal; missing files must block rather than count as success.
Test recovery after relocating the entire container.

All three cases use the current production source byte-for-byte as the prefix of
`/tmp/codex-n1b/spec-recovery.swift`. The log records each result; shell status is **0**, meaning the reproduction
assertions completed, not that these paths are safe. A control case with two failed recovery attempts followed by
a working retry preserves `[after, before]`.

**Round-1 disposition:** the original single move-in failure now rolls back correctly, but the overall P1 recovery
requirement remains open because of the three cases above. Cancellation and request consumption now propagate errors;
StoreGate keeps waiting when cancellation fails. The adapted original probe confirms the current two rows survive a
move-in failure and Cancel throws while the request remains armed. **Spec: 3 findings; worst P1.**

## Standards

Round-1 findings 3 and 4 are addressed; no new confirmed standards defect:

- `WorkoutTrackerApp.swift:241–250` uses a native `fullScreenCover`, with interactive dismissal disabled and the
  pending view marked modal. Its presenter is separate from the restored-data alert. The UI regression checks that
  covered tab/row controls are not hittable and that tapping the tab-bar area does not dismiss the waiting screen.
- `StoreGate.swift:49–58` retains pending state on a failed Cancel and passes the error to the presented view.
  The blocked-restore branch supplies Try Again only, without Continue.
- `README.md:63–65` documents the trigger, newest-two retention, next-launch restore and not-yet-TestFlight status.

The new blocked/cancel-failure strings are listed in the ticket for approval. Rendering and interaction in those two
error states remain UI coverage limitations below, not additional confirmed defects. No unrelated modernization or
file split requested. **Standards: 0 new findings.**

## Verified

Independent runs on WT-iPhone27 `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`, iOS 27.0. Runner:
`/tmp/codex-n1b/verify.sh`, PID `81918`; logs, shell status files and xcresults are in that directory. Preparation
completed with **exit 0**. The existing Orca “Test progress (Claude r2)” tab was reused; no new terminal was opened.

| Scope | Result |
|---|---|
| Build for testing, Full plan | **exit 0**, succeeded, 0 errors, 31 warnings; `build.xcresult`, `build-summary.json` |
| SafetyCopyTests, serial, `-test-iterations 10` | **exit 0**, 24 logical tests / **250 executions**, no failures or skips; `safety.xcresult`, `safety-summary.json` |
| AAAWarmUpUITests + SafetyCopyUITests, serial | **exit 0**, **8/8**, no failures or skips; `ui.xcresult`, `ui-summary.json` |
| Original failure regressions, adapted to current injection points | **exit 0**, both pass; `restore-failures.swift`, `.log`, `.status` |
| Additional transaction probes | **exit 0**, three defects reproduced plus repeated-recovery control passed; `spec-recovery.swift`, `.log`, `.status` |

The unit summary's device-level count is 250: one of the 24 logical tests has two parameter cases and the selected
suite ran ten iterations. Build, unit and UI xcresults were read directly using `xcresulttool`; counts are not inferred
from the progress display. Both scratch harnesses contain the current production `SafetyCopy.swift` unchanged.

Author results also read directly under
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/b075476f-cb86-4797-a96b-088b73936c7a/scratchpad/m/`:
`n1r2-safety2` **24 logical / 250 executions**, `n1r2-unit` **1140/1140**, `n1r2-ui` **8/8**, and `n1r2-ui2`
**17/17**, all passing with shell status **0**. The broader UI result includes CoreLoopUITests. The earlier
`n1r2-safety` reports **23 passed / 1 failed, exit 65**: the request remained after a staging failure. Its subsequent
fix is present in the reviewed code, and the later tests pass.

The four current author pending-screen captures in `m/n1r2-raw/` were inspected: dark Default/AccessibilityL
(`0BABD389-9254-4790-94D5-212468FF254E.png`, `2675BD2F-ECC7-4F7E-9907-7AAF68847D11.png`) and light
Default/AccessibilityL (`03C277FE-2430-45C8-B455-1698548F094B.png`, `83DE8979-D02D-4358-8705-A5BF1223C028.png`).
Their timestamps fall within the round-2 UI run. All text and Cancel Restore fit; no visual regression found.
The independent run's four pending-screen captures were also exported to `/tmp/codex-n1b/captures/` and inspected
at light/dark Default/AccessibilityL; all text and the Cancel command fit. The restore-flow isolation assertions pass.

## Not verified

No full UI suite, phone installation, physical-device migration, iCloud/computer backup restore or human VoiceOver
session. No independent round-2 full-store rehearsal or restored-alert persistence check; round-1 rehearsal predates
these changes, and the ticket's round-2 alert recheck is author-reported. The new blocked-restore and cancel-error
screens have source review but no executed UI fixture/capture here or in the supplied author UI suite. Recovery probes
use closed Core Data SQLite fixtures and synthesized interruption states; they do not kill an iOS process mid-write
or simulate power-loss durability. No merge, installation or release is claimed.

## Known flaky

The completed repeated unit and focused UI runs have no failures, skips or runtime warnings. The 31 build warnings
have no locations in the changed files. The author's earlier armed-request failure was a real
defect fixed before this review, not a flake waived from the result. The three new recovery reproductions are
deterministic. Historical unrelated UI flakes remain outside this scope.

Spec: **3 findings, worst P1**. Standards: **0 new findings**. Resolve and re-review.

Verdict: not clear
