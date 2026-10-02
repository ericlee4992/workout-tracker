# Ticket 01 — Prepare review, round 4

Reviewed 2026-10-02 by Codex. Implementation diff: `55a7bbf..42735a7`.
Branch: `ericlee4992/beta-01-paid-team`; actual HEAD:
`03222293deff29e996095f232b095ebf09571a0f`. HEAD adds only the round-four prompt.
The working tree was clean before this report.

## Standards

No new findings. `compare_exports.py:62–71` carries schema paths through objects and arrays,
and normalizes dictionary values only at the explicitly listed timestamp map. Its comparison
still preserves dictionary keys, array order, missing fields, and value/type differences.
Only top-level `exportedAt` is ignored (`104–105`). The ticket's round-three response accurately
describes the fix.

## Spec — prior finding resolved

**Round-three P2: date-shaped user text normalized — resolved.**

`scripts/container-tools/compare_exports.py:34–46` lists the timestamp paths explicitly;
`51–71` restricts parsing to those paths and keeps unparseable values literal. Notes, names
and labels no longer acquire timestamp semantics from their contents.

I checked every `dateFormat` call against the JSON nesting and property names in
`WorkoutTracker/Domain/ExportSnapshot.swift`. All **22 timestamp paths** are present and
correct; no custom `CodingKeys` changes those names.

| Timestamp group | ExportCollector.swift | ExportSnapshot.swift |
|---|---|---|
| Preferences: birth date, update, two history-repair dates (4) | 451–455 | 123–129 |
| Workout start, finish, history edit (3) | 257–260 | 227–234 |
| Entry snapshot/reclassification and set completion (3) | 331, 349, 419 | 287, 312, 340 |
| Sensor checkpoint sample date (1) | 290 | 266, 457–467 |
| Cardio dates, intervals, distance-span timestamp map, route dates (9) | 301–318 | 265, 417–449 |
| Gym memory and rest override updates (2) | 426, 438 | 352, 365 |

The remaining timestamp call is root `exportedAt` (`ExportCollector.swift:96`), intentionally
excluded as the export's own creation time. The `distanceSpans[].updatedAt.*` rule correctly
normalizes map values while preserving source keys.

## Independent verification

Ran **63 targeted checks, all with the expected exit codes**, using scratch files under
`/tmp/wt-beta01-codex-review-r4/` (mode 0700). The harness, individual outputs, path inventory
and subprocess exit codes are in `checks.py`, `results.json`, `path-inventory.json`, and the
named `.stdout`/`.stderr` files.

| Check | Result |
|---|---|
| Saved round-three notes: `2026-10-02T08:00:00-04:00` versus `2026-10-02T12:00:00Z` | Exit 1; changed text detected |
| Identical notes containing `2026-99-02T08:00:00Z` | Exit 0; no traceback |
| Equivalent timezone offsets at each of the 22 timestamp paths | All exit 0 |
| Changed instant at each of those paths | All exit 1 |
| Date-shaped text changes across eight notes/name/label paths | All exit 1 |
| Unparseable timestamp-field values: identical versus changed | Exit 0 versus exit 1 |
| Changed app version, schema version, and ordinary notes | Each exits 1 |
| Changed top-level export creation time | Exit 0, as intended |
| Saved complete-WAL round-trip export versus phone export | Exit 0; equal |
| Saved truncated-WAL round-trip export versus phone export | Exit 1; lost rep edit remains detected |

The last two checks reused the actual app-written exports independently produced in round
three. No new Simulator run or app build was needed: this round changes only Python
normalization and review documentation. Prior integration and failure-handling evidence remains
applicable; no other implementation behavior changed in this diff.

## Scope of clearance

All findings from reviews 01, 01b and 01c are resolved. No new findings.
This clears **ticket 01's Prepare implementation and reviewed procedure**. It does not claim
that phases A–E, device copy preflight, paid signing, deletion/restoration, or the TestFlight
backup bridge have been executed; their recorded gates remain mandatory.

Only this report was changed in the repository. No phone, Apple account, original backup or
Simulator was operated this round. The ticket's WT-Backup-01 cleanup remains to be performed
by the implementing session after this clearance; this review did not merge or install anything.

Verdict: clear
