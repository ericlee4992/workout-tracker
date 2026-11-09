# Nutrition N1 — independent Codex review, round 3

Reviewed 2026-11-09. Target: **`a0c0384abde18d4bd113fba493720db575da828c`**, diff
`e8935eb..a0c0384`, against round 2's report and the ticket's “Codex round 2” fix mapping. Claude implemented;
Codex independently reviewed the Spec and Standards axes and ran the verification below.

**Checkout scope:** at the start, this workspace was already on `ericlee4992/nutrition-02-data` at
`d02aad9512fb1dbb6a6076e3243cf3a34c6c4a6c`, one N2 WIP commit beyond the requested N1 fix. The requested
`e8935eb..HEAD` range was inspected for scope; N2's model registration, nutrition files and migration fixture are
excluded from this N1 verdict. A `git archive a0c0384` snapshot under `/tmp/codex-n1c/source/` was used for the build,
tests and probe source, so concurrent N2 work cannot change the reviewed binary. Its commit is recorded in
`/tmp/codex-n1c/source-commit.txt`.

This reviewer wrote only this report in the repository. Concurrent N2 test edits were left untouched. No
implementation edits, commit, push, merge or installation on a physical device were performed by this reviewer.

## Spec

**No findings. All three round-2 P1 findings are addressed.**

1. **Stale rollback files — resolved.** `WorkoutTracker/Domain/SafetyCopy.swift:193–200,222–229,263–273`.
   Each swap records its own tag and uses it for staging and set-aside filenames. Earlier unswept files cannot be
   mistaken for the current transaction's originals. The adapted probe keeps cleanup failing so old backups really
   remain: a subsequent successful restore returns exactly the selected copy. An additional forced move-in failure
   in the subsequent restore returns `[before, logged-after-restore]`, preserving the current data instead of
   substituting the earlier backup.
2. **Unreadable journal — resolved.** `SafetyCopy.swift:249–252,333–339`.
   An existing journal's read/decode error now propagates to the blocked launch outcome. The probe makes the journal
   unreadable with permissions `000`: launch stays blocked, no primary store is opened/created, and the set-aside
   original remains byte-identical. Restoring readability and retrying recovers both original rows.
3. **Relocated container — resolved.** `SafetyCopy.swift:249–273`.
   Recovery takes the current `storeURL` and resolves journal filenames beside that store. It checks every original
   is still in place or set aside before making changes. Moving the entire interrupted fixture, including its journal
   and backups, now recovers `[after, before]` and clears the journal only after recovery.

The repeated-recovery control also passes: two consecutive failed rollback attempts stay blocked with the journal
retained; a working retry recovers both original rows. Source review confirms that already-returned originals remain
in place on another retry, remaining tagged originals are restored, and copy-only side files are removed before the
journal is consumed. Existing unit tests continue to cover original swap failures, cancellation, request consumption,
normal restoration and copy behavior.

**Spec: 0 findings.**

## Standards

**No findings.** Changes remain in the persistence module and its tests. The recovery callers pass the current store
location, comments describe the data-loss consequences, and tests use closed SQLite fixtures for the affected file
operations. The four new logical tests cover unswept leftovers, unreadable/damaged journals and container relocation.
No UI source or UI test code changed in `e8935eb..a0c0384`; the round-2 UI and README fixes remain intact. No unrelated
modernization or file-split finding.

**Standards: 0 findings.**

## Verified

Independent execution on **WT-iPhone27** `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`, iOS 27.0, from the pinned
snapshot. `scripts/prepare-test-simulator.sh` ran first, **exit 0**. Commands and results are under
`/tmp/codex-n1c/`; runner `verify.sh`, PID `90587` (completed). The existing Orca “Test progress (Claude r2)” tab
was reused; no new terminal was opened.

| Scope | Result and evidence |
|---|---|
| Build for testing, Full plan | **exit 0**, succeeded, 0 errors, 31 warnings; `build.status`, `build.xcresult`, `build-summary.json` |
| SafetyCopyTests, serial, `-test-iterations 10` | **exit 0**, **28 logical tests / 290 executions**, 0 failures/skips/runtime warnings; `safety.status`, `safety.xcresult`, `safety-summary.json` |
| Three prior recovery reproductions plus repeated-recovery control | **exit 0**, all pass with safe outcomes; stale-backup case additionally checked with a failing later restore; `spec-recovery.swift`, `.log`, `.status` |

The harness was repointed at the exact `a0c0384` production `SafetyCopy.swift`, prepended byte-for-byte. Its synthesized
journal/file names were updated for the new tagged format; assertions now require the safe outcomes described above.
It does not open a store after receiving `.blocked`. The original round-2 harness and artifacts remain under
`/tmp/codex-n1b/`. The repeated suite's device-level count is 290 because one of the 28 logical tests has two
parameter cases. Result bundles were read directly with `xcresulttool`, alongside shell exit files.

Author evidence was also inspected directly under
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/b075476f-cb86-4797-a96b-088b73936c7a/scratchpad/m/`:

- `n1r3-safety.xcresult`: **exit 0**, 28 logical tests / **290 executions**, 0 failures/skips.
- `n1r3-unit.xcresult`: **exit 0**, **1144 logical tests** / 1160 device-level executions, 0 failures/skips.
- `n1r2-ui2.xcresult`: **exit 0**, **17/17**, 0 failures/skips. This prior UI evidence was inspected rather than rerun,
  per AGENTS' later-round rule and the user's instruction: the pinned N1 fix has no UI behavior or UI test changes.
  It covers warm-up, SafetyCopyUITests and CoreLoopUITests. Round 2's independent **8/8** focused UI evidence also
  remains applicable; unchanged captures were not retaken.

Extracted author summaries are saved as `n1r3-*-author-summary.json` and `n1r2-ui2-author-summary.json` in
`/tmp/codex-n1c/`.

## Not verified

N2 and its new schema are **not reviewed or cleared by this report**. No independent full Unit plan or UI suite was
rerun this round beyond the named SafetyCopyTests scope; author full-unit and prior UI results were inspected.
No physical-device migration, actual iCloud/computer backup restore, human VoiceOver session, or power-loss durability
experiment. Probes use real closed Core Data SQLite stores and synthesized interrupted states; they do not kill an
iOS process mid-write. Round-2 limitations for the new blocked/cancel-error screen rendering and restored-alert
persistence remain unchanged. This is review clearance, not evidence of merge, installation, release or approval of
new wording.

## Known flaky

No failures, retries or skips in the independent repeated SafetyCopyTests run; no runtime warnings there. The three
previous defects no longer reproduce with the updated source and assertions. Historical unrelated UI flakes remain
outside this scope; none were used to waive a result.

Spec: **0 findings**. Standards: **0 findings**. Round-2 findings resolved for `a0c0384`.

Verdict: clear
