# Ticket 01 — Prepare review, round 2

Reviewed 2026-10-02 by Codex. Fix diff: `git diff 37efb6c..8e60704`.
Actual branch: `ericlee4992/beta-01-paid-team`; HEAD:
`52e5e6d829747f523e5ebf07c8c3b7c1ad1d6848`. The only change after `8e60704` is the
round-two prompt. Local `main` remains `bab270b`. The working tree was clean before this report.

## Standards — round-one findings

1. **Resolved — installer overwrote the team references.**
   `scripts/install-on-device.sh:239–251` now writes `WT_DEVELOPMENT_TEAM` to the ignored
   Local.xcconfig and preserves an existing bundle ID. I extracted only `write_team_id` and ran it
   against temporary files: new configuration, existing configuration with a custom bundle ID and
   unrelated setting, and repeated invocation. All exited 0; repeats were identical; the copied
   project stayed byte-identical. `bash -n scripts/install-on-device.sh` exited 0. The whole installer
   was never run.

2. **Resolved — stale STATE.**
   `docs/STATE.md:44–67` now names the correct checkout/branch, distinguishes implemented Prepare
   work from pending review/merge and phone operations, records the renewal deadline, and identifies
   WT-Beta01's copied personal data and cleanup requirement. This fixes the operational handoff
   problem identified in round one.

No new blocking standards findings. The app and Xcode configuration did not change in this round;
the previously inspected build evidence still applies, so no new app build was run.

## Spec — round-one findings

3. **Resolved — Support request lacked a fresh-backup gate.**
   Ticket `issues/01-paid-team-testflight.md:90–100` requires Gate P, same-day Gate S, and recorded
   acceptance of possible interruption before requesting ID deletion. Continued use after the backup
   requires explicit acceptance of the re-entry risk. B3 stops if a current backup cannot be obtained
   after invalidation. `apple-support-request.md:6–10,45–47` carries the same conditions and no longer
   guarantees Support's answer or timing. Gate S's remaining verification issue is tracked below.

4. **Resolved — device preflight could be bypassed and ignored its probe.**
   Gate P (`ticket:57–61`) requires a file and nested directory with a space in its name, exact path/hash
   comparison, and recorded command forms. Both B2 (`92`) and D1/D2 (`113–117`) require it independently
   of A. `compare_trees.py:29–43` compares the supplied tree without the restore-set filter. My tests:
   identical tree exit 0; changed byte, missing file, extra file, wrong nested path, and missing root
   each exit 1. Actual phone execution is correctly left pending.

5. **Partly resolved — stable source and completeness of the capture.**
   Gate S (`ticket:47–55`; `docs/DEVELOPMENT.md:220–223`) now requires an export, confirmed app
   termination, two matching captures, and no reopening before the protected step. D5 (`ticket:121`)
   closes the app before its post-launch capture. These materially fix the original write-race risk.
   However, the new export check still passes the original lost-rep-edit reproduction, and A omits
   the close-before-capture step. See R2.1 and R2.2.

6. **Resolved — TestFlight backup could run new code first.**
   `docs/DEVELOPMENT.md:248–252`, ticket `138–142`, `spec.md:191–195`, and D60
   (`docs/DECISIONS.md:215`) now require the installed TestFlight build's exact commit, installation
   without launch, Automatic Updates off, and stopping if deletion is required. The ticket records
   upload commits and compares signed application identifiers. The bridge is explicitly unproven
   until exercised on the phone; that pending phase is not a Prepare failure.

## Remaining findings

### R2.1 — P1: `--export` still accepts the lost-value WAL case

**Evidence:** `scripts/container-tools/verify_container.py:102–120` compares workout/set UUIDs and
table counts only. It never compares exported reps, weights, units, timestamps, relationships, or
other values. The docstring at `13–17` nevertheless says it detects omitted history “for everything
the export covers.” Ticket `205–213` substitutes deletion of a set for the round-one reproduction,
which lost a committed **edit to an existing set** without changing IDs or counts.

**Reproduction:** I used copies of `rehearsal/r3-capture/` and the supplied, unchanged, app-written
`rehearsal/export.json`. In the copied store, I checkpointed a different rep value to the main database,
then committed the correct exported value to the WAL. The full capture matched the real export and
the original store. Truncating the captured WAL to its 32-byte header lost that committed correction.

- Full capture versus original: comparison exit **0**.
- Truncated capture with the real `--export`: exit **0**, `export_check.ok: true`.
- A second identical incomplete capture with both `--export` and `--expect`: exit **0**.
- Incomplete capture compared with its restored copy: exit **0**.
- Complete capture versus incomplete capture: exit **1**, `ZSETRECORD` row 32, `ZREPS` changed.

Counts remained **24 workouts, 343 sets, 2 templates, zero unfinished** throughout. This demonstrates
the check's blind spot; it does not claim that two independent device captures necessarily truncate
the same way. Stopping writers reduces capture risk, but the claimed independent check still cannot
distinguish this stale capture from the exported current history. Two matching copies establish equality,
not completeness relative to the live data.

**Failure:** an incomplete capture retaining all IDs/counts is accepted as containing the export even
when an exported value differs. The user can approve deletion on that result, and later comparison
against the same incomplete baseline will also pass.

**Suggested fix:** compare the exported values and relationships against the captured state, with
explicit normalization rules. An alternative is to restore the capture into a disposable Simulator,
produce a fresh app export, and compare its semantic contents with the pre-capture export, ignoring
only identified export metadata. Add the exact existing-row/WAL reproduction above as a regression
case; a deleted-row test is additional coverage. Correct the docstring and ticket evidence to state
what was actually checked and what remains outside export coverage.

### R2.2 — P2: phase A still captures a running app

**Evidence:** `work-record/public-beta/issues/01-paid-team-testflight.md:79–80` prescribes
install → launch → capture → comparison. Unlike D5 (`121`) and DEVELOPMENT (`230`), it never closes
the app after this launch. The earlier Gate S cannot establish that the process remains stopped
after an explicit relaunch.

**Failure:** renewal's post-install copy can race launch-time store writes/checkpointing, making its
preservation result unreliable. The safe pre-install backup remains intact, but this capture does
not establish the post-launch state it is intended to verify.

**Suggested fix:** make A explicitly launch → inspect → close and confirm termination → capture →
compare. State that every raw post-launch capture follows this rule; require a successful process-list
query before treating absence of the app as evidence of termination.

## Verification record

All script executions used copies under `/tmp/wt-beta01-codex-review-r2/` (mode 0700). No phone,
Apple account, Simulator installation, or `~/WorkoutTracker-Backups` operation was performed.
Only this report was written in the repository.

- Reproducer and recorded results: `checks.py`, `results.json`, and per-case `.stdout`/`.stderr`
  files in that temporary directory. The app-written export was copied unchanged. Baseline file
  hashes were unchanged after verification.
- Baseline `verify_container.py --export`: exit 0. Baseline store/preferences comparison: exit 0.
  Deleting one set: both export verification and store comparison exit 1.
- Flipped consent, removed preference key, and missing preferences plist: comparison exit 1 each.
  These confirm the new preference comparison works for the tested current settings.
- Exact tree comparison results are recorded under finding 4. The original `tmp/` probe blind spot
  is addressed by using this comparator rather than `verify_container.py --expect`.
- Installer tests and actual subprocess exit codes: `installer/results.json`. These exercised only
  the extracted function on scratch files, with project bytes checked before and after.
- Read the revised ticket, DEVELOPMENT, Support draft, spec, D60 and STATE together. The gate ordering
  and no-launch bridge now agree across those documents, subject to the two remaining findings above.

Summary: Standards — both prior findings resolved, no new blockers. Spec — three prior findings
resolved, finding 5 partly resolved; remaining findings are one P1 and one P2.

Verdict: not clear
