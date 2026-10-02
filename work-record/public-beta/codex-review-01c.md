# Ticket 01 — Prepare review, round 3

Reviewed 2026-10-02 by Codex. Implementation diff: `52e5e6d..c38cbb8`.
Branch: `ericlee4992/beta-01-paid-team`; actual HEAD:
`55a7bbfdb63d3532c8c77175f26b1f8ee403657c`. HEAD adds only the round-three prompt.
Local `main` remains `bab270b`; the working tree was clean before this report.

## Round-two dispositions

1. **R2.1 — Resolved: the lost-rep-edit capture now fails the required round trip.**

   Gate S now requires restoration into the disposable Simulator, export through the app, and
   value comparison (`issues/01-paid-team-testflight.md:53–58`;
   `docs/DEVELOPMENT.md:229–234`). `verify_container.py:13–18` correctly describes `--export`
   as an IDs/counts check that cannot detect changed values.

   I reran my own round-two complete and truncated WAL copies using the supplied build-for-testing
   and **only WT-Backup-01**, UDID `A3D88C6F-6426-427A-9A0E-CF11A93798B1`:

   | Input | `simulator_export.sh` | UI test result | `compare_exports.py` |
   |---|---:|---|---|
   | Complete WAL | 0 | 1 passed, 0 failed, 0 skipped | 0, equal |
   | WAL truncated to its 32-byte header | 0 | 1 passed, 0 failed, 0 skipped | 1, changed set reps |

   The second export reported the exact lost edit: workout `F6A7AB07…`, entry `12CDF0DA…`,
   set `CE7203A7…`, **phone reps 20 versus restored reps 120**. Counts stayed 24 workouts and
   343 sets. This uses the unchanged real app-written phone export and my previous reproducer,
   independently confirming Claude's reported 20-versus-27 case. The new normalization defect
   below is separate from this resolved numeric-value case.

2. **R2.2 — Resolved: close-before-capture is explicit.**

   Phase A now requires launch/inspection, user closure, and a successful process query before
   capture (`ticket:82–84`). D5 requires the same (`125–126`). DEVELOPMENT `233–234` applies
   the rule to every raw capture after launch; Gate S `50–52` explicitly says a failed query
   establishes nothing. No phone operation was performed during this review.

## New finding

3. **P2 — Timestamp normalization changes the meaning of literal user text.**

   **Evidence:** `scripts/container-tools/compare_exports.py:31–38` parses every string matching
   the timestamp regex, regardless of its location. Workout notes and names are literal strings
   (`WorkoutTracker/Domain/ExportSnapshot.swift:230,240`), copied without date interpretation
   by `WorkoutTracker/Domain/ExportCollector.swift:259,263`.

   **Reproduction on copies of the real export:** changed only one workout's `notes`:

   - Phone: `2026-10-02T08:00:00-04:00`
   - Round trip: `2026-10-02T12:00:00Z`
   - Actual result: **exit 0, `equal: true`**, although the saved text differs.

   There is also a false failure: identical notes containing the valid literal text
   `2026-99-02T08:00:00Z` produce **exit 1 with `ValueError: month must be in 1..12`**.
   Such text is allowed in notes; it is not a malformed export timestamp.

   **Failure scenario:** a capture loses an edit to date-shaped notes or names, but normalization
   erases the textual difference and lets Gate S pass. Conversely, unchanged date-shaped text can
   prevent verification entirely. This contradicts the comparator's claim to compare every
   exported preference/history value.

   **Suggested fix:** make normalization aware of the export schema/path. Normalize only actual
   timestamp fields, including nested timestamp collections; compare notes, names, labels and
   other user text literally. Add both reproductions above, plus equivalent-offset controls on
   actual timestamp fields. Do not infer a field's type solely from the shape of its string.

## Standards and failure handling

No additional blocking finding in the Simulator runner or UI test:

- `BackupExportUITests.swift:13–19` checks its explicit environment gate before creating or
  launching the app. Ordinary test runs skip this test.
- `simulator_export.sh:17–23` checks the Simulator name, input store, and built app's bundle ID
  before uninstalling. Its guard accepts names beginning with `WT-Backup`; this review used only
  the specific Simulator authorized in the prompt.
- Lines `31–32` copy only the restore set, excluding the captured temporary export. The successful
  test therefore creates a fresh export rather than reusing the phone's captured JSON.
- Lines `35–45` overwrite the log and require the export marker, a successful Xcode exit code,
  and a passing test summary. A skipped or missing test cannot count as success.
- I exercised the actual shell script with mocked device/build commands, without accessing any
  Simulator: success exited 0; skipped test, absent test, and Xcode failure despite success markers
  each exited 1; uninstall failure exited 149; wrong Simulator name exited 2. Failed runs can leave
  an older output file, so the documented exit-code gate remains essential.

Apart from finding 3, the comparator retains value/type differences, missing keys, array order,
`appVersion`, and `schemaVersion`. The export collector uses stable ordering with tie-breakers for
its entity arrays, so retaining their order is appropriate. My controls confirmed that equivalent
offsets in `startedAt` pass, ordinary changed notes fail, changed app/schema versions fail, and
only top-level `exportedAt` is ignored as documented.

## Evidence and limits

Scratch evidence: `/tmp/wt-beta01-codex-review-r3/` (mode 0700).

- `full-roundtrip.json`, `truncated-roundtrip.json`, their `.xcodebuild.log` files, and
  `full-comparison.json` / `truncated-comparison.json` hold the independent integration evidence.
  I checked actual script exit codes and queried both `.xcresult` bundles: each reports one passed
  test, no failures/skips, on the authorized WT-Backup-01 UDID. Paths are in `xcresult-paths.json`.
  Sandboxed result-summary attempts failed because of the report cache; approved retries succeeded.
- `normalization-results.json` and the named `.stdout`/`.stderr` files record the comparison
  reproductions and controls. `mock-script-results.json` records the shell failure checks.
- Hashes of both input container copies stayed identical to their round-two sources. Original
  backups and phone/account state were untouched. No other Simulator was operated.
- The supplied build-for-testing was reused; no new product build or full UI suite was needed.
  Actual phone copy commands, paid signing and TestFlight remain pending operational gates.
- WT-Backup-01 now contains the **deliberately stale test copy** from the truncated-WAL case;
  it is not production data. It has not been erased because this review is not clear. Follow the
  ticket's disposable-Simulator cleanup when the review clears.

Only this report was changed in the repository.

Summary: R2.1 and R2.2 resolved. No new blocking standards finding; one new P2 comparison finding.

Verdict: not clear
