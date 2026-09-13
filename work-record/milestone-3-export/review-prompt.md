# Cross-review request — milestone 3 (CSV/JSON export)

You are reviewing work written by Claude, per decision **T6**: solo project, so this is the only
independent check that exists. Be adversarial. Prior Codex passes on this repo found real defects
that broke the product's historical-honesty thesis — look for the same class of thing.

## What to read first

1. `CLAUDE.md`, then `docs/STATE.md`, `docs/SPEC.md`, `docs/DECISIONS.md` (D28–D32 are new).
2. `work-record/milestone-3-export/spec.md` and `issues/01..03` — what this milestone claims to do.
3. The change itself. It is **uncommitted** on branch `milestone-3-export`: `git status --short`
   lists the modified files, and every new file is untracked (so `git diff` alone will not show
   it — read the files listed below directly).

## What is new

- `WorkoutTracker/Domain/ExportSnapshot.swift` — Codable value types + `ExportDateFormat`
- `WorkoutTracker/Domain/ExportCollector.swift` — the only SwiftData reader
- `WorkoutTracker/Domain/ExportCSV.swift`, `ExportJSON.swift`, `ExportFile.swift`
- `WorkoutTracker/Features/Settings/ExportSection.swift`, `ShareSheet.swift` (wired into `GymsView`)
- `WorkoutTrackerTests/ExportTests.swift`, `ExportFidelityTests.swift`, `ExportTestSupport.swift`
- `WorkoutTrackerUITests/ExportUITests.swift`

## Questions worth attacking

1. **Fidelity.** Is there any user-created datum the export drops? Walk the schema in
   `Domain/Models.swift` field by field against `ExportSnapshot` and say what is missing and
   whether its absence is defensible. Catalog browsing state and `seededCatalogFingerprint` are
   deliberately omitted — argue with that if you disagree.
2. **D28 (referenced catalog rows only).** Can a store exist where a *referenced* seeded row is
   omitted, so the file cannot be interpreted? Deleted models, archived machines, entries whose
   snapshot points at a row that no longer exists, templates pointing at seeded exercises.
3. **D23.** Does anything in the CSV read a live row where it should read the entry snapshot?
   The one intentional live lookup is `manufacturer` (the snapshot has no such field).
4. **Correctness of the file itself.** RFC 4180 edge cases, the BOM, CRLF, embedded newlines in
   notes, non-ASCII names, empty store, a store with only an active workout. Is the CSV parseable
   by a strict reader? Is the JSON re-importable without ambiguity (nil-omitted optionals, arrays
   of optional Ints in `targetRepsBySet`)?
5. **Numbers and dates.** Any path where a display-formatted (locale-dependent, rounded, or ≈)
   value could reach a file? Any timestamp that loses its offset or its meaning?
6. **The UI path.** `ExportSection` builds the file synchronously on the main actor from the
   environment's `ModelContext`. What happens with a large store? Is the failure path honest? Is
   the staged temp file handled sanely (it deletes the directory on each export — what if a share
   is still in flight)?
7. **Tests.** What does the suite claim that it does not actually prove? `ExportTestSupport.swift`
   contains a hand-written CSV reader — is it wrong in a way that would hide a writer bug?

## Output

A markdown file at `work-record/milestone-3-export/codex-review.md`: findings ranked by severity,
each with file/line, why it matters (name the decision it violates), and the smallest fix. Say
plainly if something is fine. Do not change code.
