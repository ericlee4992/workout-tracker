Round 1 (T6) of UI-redesign ticket 07 — Gyms on the Ink / Amber design system (which YOU built;
Claude built this ticket, so you review). Ticket: work-record/ui-redesign/issues/07-gyms.md; the
plan: work-record/ui-redesign/spec.md (ticket 07 and the constraints — copy policy, ids/strings the
tests read; the scan sheet "tokens only, strings and ids untouched"). Boundary: main..HEAD on
branch ui-redesign-07 (main = bf4d919, ticket 06).

Files: WorkoutTracker/Features/Gyms/GymsView.swift (GymsView, GymRow, GymDetailView.machineRow,
the ModelPickerView "New Model…" button), Features/Gyms/MachineDeletion.swift (DeletedMachinesView).
Screenshots: work-record/ui-redesign/screenshots/07/ (06-gyms, 06-gym-detail, 08-empty-gyms,
07-delete-machine-confirmation).

Scope:
1. GymsView rows are `Button`s appending to a new `path: [UUID]` on the `NavigationStack`
   (History did the same in ticket 06). `navigationDestination(for: UUID.self)` is unchanged.
   Any way into a gym that bypasses the row (deep link `PROTO_SCREEN=gyms`, the Start screen's
   gym picker, a sheet that pushes)? Anything reading `gymRow.<name>` as a link?
2. GymDetailView: machine rows are cards (clear row background) that still carry
   `.machineDeleteActions` (a swipe on a List row) and the `.contextMenu` — does a swipe action
   on a row whose background is clear and whose content is a padded card still reveal correctly
   (the swipe surface is the ROW, the card is narrower than the row by its insets — 0 here)?
   NOTE: the first gate run FAILED here — the id on the bare container propagated to the first
   child (the 40 pt tile) and the test's swipe on it was too short; both cards are now
   `.accessibilityElement(children: .contain)` and the gates pass. Is `.contain` the right
   choice (children still reachable — the scan test reads the model name as a staticText)?
   `machineRow.<label>` / `deleteMachine.<label>` / `restoreMachine.<label>` ids unchanged?
3. The machine-count chip: `gym.activeMachines.count` on every row of the list — a fetch per
   row? Is it cheap enough (relationship already loaded) for a many-gym list?
4. The model chip truncates long display names (`lineLimit(1)`, minimumScaleFactor 0.85) —
   "Life Fitness Insignia Series Chest Press" fits at default size (screenshot); at AccessibilityL
   a chip is the wrong container for a sentence. Should the model stay a caption instead of a
   chip? (The plan says "the model as a chip".) Say which you would ship.
5. "Add Gym…" is `.primary` only when there are no gyms — acceptable, or inconsistent
   with "Add Machine…" always `.primary`?
6. Copy policy: no new `Text("…")`? "No machines yet" moved into `EmptyState` (the test reads
   the staticText); "Nothing deleted" kept; the machine-count chip shows a number with a
   dumbbell symbol and an accessibility label "N machines" — is that new copy?
7. Anything the four gates rely on that changed: MachineDeletion (swipe + alert), ScanMachineLabel,
   AskAI, DumbbellCounterpart (which reads `machineRow.` + `staticTexts["Bench Press"]`).

Do NOT run xcodebuild or simctl (the simulator is in use). Review by inspection; verification is
in the ticket. Report by severity with file:line, or say "clear" in one paragraph. Do not modify
source files. Write to work-record/ui-redesign/codex-review-07.md
