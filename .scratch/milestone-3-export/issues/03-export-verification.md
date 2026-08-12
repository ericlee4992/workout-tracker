# 03 — Export verification: fidelity over a realistic store

Status: resolved
Blocked by: 01, 02

Ticket 01's tests cover the encoders. This ticket proves the *collector* against a store built
the way the app builds one, and puts the UI on the XCUITest path.

## Acceptance criteria

- [x] A test seeds the real catalog (`CatalogSeeder`), creates a gym, a machine, a template, and
      logs a workout through the same domain services the app uses (`WorkoutSession` et al.),
      then exports and asserts: every completed set appears exactly once, snapshot context is
      preserved, and the catalog rows included are only the referenced ones (D28).
- [x] A test asserts the CSV's completed rows reconcile with `RecordsMath` volume — summing
      `weightKg × reps` over rows where `completed == true`, `setType != warmup`, and
      `loadType == weighted` reproduces the app's volume for that workout (D21). This is the
      check that catches a silently dropped or duplicated row.
- [x] `WorkoutTrackerUITests` covers: Gyms tab → export section visible, summary states what
      there is to export, tapping **Export CSV** presents the share sheet holding the written
      file (and dismissing it returns to the app with no error). Keep it one test — the UI suite
      already runs ~7 minutes. *(Amended during the work: the summary is asserted against the
      empty store, "0 workouts · 0 sets", rather than logging a workout first — see Resolution.)*
- [x] Full suite green, re-run independently (STATE.md working agreement).

## Resolution (2026-08-11)

`WorkoutTrackerTests/ExportFidelityTests.swift` (collector against a store carrying the real
seeded catalog, workouts logged through `WorkoutSession`) and
`WorkoutTrackerUITests/ExportUITests.swift`.

Scope adjusted, deliberately: the UI test runs against the **empty** store (asserting the summary
reads "0 workouts · 0 sets", that tapping Export CSV presents the share sheet holding a
`workout-tracker-*` file, and that dismissing surfaces no error) rather than logging a workout
first. Re-walking the logging flow would have doubled a suite that already takes ~7 minutes to say
something the unit tests say precisely and in a second. It still caught the real defect (the
`.sheet`-on-`Section` bug in ticket 02) — which was the point of having it.

Suite after this ticket: 242 unit + 10 UI tests; **250 unit** after the codex-review fixes below.

## Codex cross-review (2026-08-11)

`codex-review.md` — verdict "do not merge yet", three high findings, all real. Fixed on this
branch: draft-entry context, the D27 user link under D28, and CRLF quoting; plus timestamp
precision, the `modelName` → `modelDisplayName` rename, per-export temp staging with a completion
handler, a strict CSV test reader, and D30/D31 amendments. The review's remaining medium
(synchronous export on the main actor) is a deliberate deferral: a scale test now covers 1,800
sets, and moving collection onto a `ModelActor` is exactly the cross-context concurrency that
produced the `CONTINUATION MISUSE` crash in milestone 2 — not worth it for a personal-sized store
without evidence of a real freeze.
