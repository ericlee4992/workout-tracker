# 02 — Export UI: share the files from Settings

Status: resolved
Blocked by: 01

## Files

- `WorkoutTracker/Features/Settings/ExportSection.swift` — the `Section`, placed in `GymsView`
  under `AppSettingsSection()` (that is where app-level settings already live).
- `WorkoutTracker/Features/Settings/ShareSheet.swift` — `UIViewControllerRepresentable` around
  `UIActivityViewController`.

## Behavior

- Two rows: **Export CSV**, **Export JSON**. Tapping builds the file on the spot, writes it to
  a temp directory, and presents the system share sheet (Save to Files / AirDrop / Mail — the
  "Save to Files → iCloud Drive" path is the backup this milestone is for).
- A footer line states what is in the export and, plainly, that this is the only backup that
  exists: the data lives on this phone alone.
- A counts summary ("87 workouts · 1,234 sets") so the user can see the export is not empty
  before sharing it.
- Filenames: `workout-tracker-YYYY-MM-DD-HHmm.csv` / `.json` (local time, sortable).
- A build failure surfaces as an inline error row, never a silent no-op.

## Why a share sheet rather than `ShareLink`

`ShareLink` evaluates its item eagerly at view-construction time, which would re-run the whole
export on every re-render of the Gyms screen. Generating on tap and presenting the activity
controller keeps the cost where the user asked for it. (`Transferable`'s lazy exporting closure
would also work, but it can run off the main actor, and the collector reads a
`ModelContext`.)

## Acceptance criteria

- [x] Both rows carry accessibility identifiers (`exportCSV`, `exportJSON`, `exportSummary`).
- [x] Export runs off the SwiftData context the app is actually using, not a fresh container.
- [x] The temp file is written with a stable, human-meaningful filename; sharing it twice in a
      session does not collide or leak stale content.
- [x] No UI import creeps into `Domain/`.

## Resolution (2026-08-11)

`Features/Settings/ExportSection.swift` + `ShareSheet.swift`, added to `GymsView` below
`AppSettingsSection()`.

**Bug found by the ticket-03 UI test, worth remembering:** a `.sheet(item:)` attached to a
`Section` inside a `List` never presents. The file was written, the state was set, and nothing
happened — a silent failure that only an end-to-end test could see. The modifier now hangs off a
row inside the section.
