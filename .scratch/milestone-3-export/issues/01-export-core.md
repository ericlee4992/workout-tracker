# 01 — Export core: snapshot value types, JSON and CSV encoders

Status: resolved
Blocked by: —

Build the whole export as pure logic over value types, with one thin SwiftData-reading
collector. No UI in this ticket.

## Files

- `WorkoutTracker/Domain/ExportSnapshot.swift` — `Codable` value types mirroring the export
  shape in `../spec.md` (JSON section). Value types only: no `@Model` reference escapes here.
- `WorkoutTracker/Domain/ExportCollector.swift` — builds an `ExportSnapshot` from a
  `ModelContext`. Touches SwiftData, imports no UI.
- `WorkoutTracker/Domain/ExportCSV.swift` — pure `ExportSnapshot → String` renderer.
- `WorkoutTracker/Domain/ExportJSON.swift` — pure `ExportSnapshot → Data` encoder.
- `WorkoutTrackerTests/ExportTests.swift`

## Acceptance criteria

- [x] `ExportSnapshot` is `Codable` and round-trips: `decode(encode(x)) == x` for a snapshot
      exercising every optional (no gym, no machine, free-weight tag, draft set, active workout).
- [x] **D28** — the collector includes every user-created exercise/model plus exactly those
      seeded rows referenced by machines, entry snapshots, template items, gym-exercise memory
      or rest overrides. A store with the 1877-row seeded catalog and one logged workout
      exports at most a handful of catalog rows.
- [x] **D29** — every set carries `weight`, `unit`, `weightKg`; no value in either format is a
      converted display value and no `≈` appears anywhere.
- [x] **D30** — draft sets, zero-completed-set entries and an unfinished workout all appear,
      flagged.
- [x] **D31** — every timestamp is ISO 8601 with a UTC offset; the formatter is injectable so
      tests pin a fixed timezone.
- [x] **D32** — CSV is RFC 4180: CRLF terminators, UTF-8 BOM, fields containing `"`, `,`, CR or
      LF quoted with inner quotes doubled. Verbatim user text (no formula-injection prefixing).
- [x] CSV rows are ordered workout `startedAt` → workout id → entry `order` → set `order`, and
      the header row matches the 27 columns in `../spec.md` exactly, in order.
- [x] CSV context columns read entry snapshots (D23), never live rows. A test renames a gym
      after logging and asserts the exported row keeps the old name.
- [x] JSON is pretty-printed with sorted keys and omits nil optionals rather than emitting
      `null`; `schemaVersion` is 1.
- [x] Numbers serialize locale-independently (`.` separator) — a test runs under a comma-decimal
      locale.
- [x] Empty store exports a header-only CSV and a JSON with empty collections, not an error.

## Resolution (2026-08-11)

Landed as `Domain/ExportSnapshot.swift` (value types + `ExportDateFormat`),
`Domain/ExportCollector.swift` (the one SwiftData reader), `Domain/ExportCSV.swift`,
`Domain/ExportJSON.swift`, `Domain/ExportFile.swift` (naming/staging, moved here from ticket 02
because a filename is part of the format). Tests: `WorkoutTrackerTests/ExportTests.swift`
(encoders) with the RFC 4180 reader in `ExportTestSupport.swift`.

Two things worth knowing:

- Timestamps are formatted **once, at collection time**, and live in the snapshot as strings.
  Formatting per renderer would let the two files disagree, and an ISO 8601 `Date` round-trip
  truncates sub-second precision, so `decode(encode(x)) == x` would have been false.
- D28 is deliberately **non-transitive**: a referenced model's `exerciseIDs` may name exercises
  nothing else references, and following those links drags in much of the catalog.
