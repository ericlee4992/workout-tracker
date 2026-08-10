## 1. Ticket 17 verdicts

Evidence is against committed `HEAD`, excluding subsequent working-tree edits.

- **A1 — Partially earned.** Initial invalid completion is blocked, but completed fields remain editable. Clear weight/reps after completion and `completedAt` survives; Finish retains the invalid set.
- **A2 — Partially earned.** Bare and draft-only workouts are deleted, including strays, and the sheet avoids using the deleted object. However, finishing an empty template-derived workout with “Update Template/Both” can erase the template before discarding the workout.
- **B1 — Partially earned.** Carry-forward copies the last completed set and leaves the new row uncompleted. Fractional weights are rendered through one-decimal `Format.weight`, then that rounded text is committed on the one-tap completion, violating D9/D25.
- **B2 — Earned.** Non-template Finish completes immediately; D18 remains for actual template drift.
- **B3 — Earned.** The focused row supplies a keyboard Done button, and clearing focus commits the field.
- **C1 — Earned.** Minimise dismisses the cover without finishing; the active query exposes Resume.
- **C2 — Partially earned.** The receipt exists, but “View in History” only changes tabs; it does not open the workout just logged.
- **D1 — Partially earned.** Persistence and the disabled no-gym machine affordance work. If the selected gym is archived from another tab, one-shot restoration leaves the archived gym selected and usable.
- **D2 — Earned.** Gym name/city/unit and machine label/unit are editable; model correction remains in the D10-scoped flow.
- **D3 — Earned.** Selecting a model supplies a label unless the user already entered one.
- **E1 — Partially earned.** Exercise-derived titles use snapshots, but template-derived titles use the template’s current name. Rename/delete the template and old History changes. Gym rendering also has a live fallback.
- **E2 — Earned.** Exercise and set counts pluralize correctly.
- **E3 — Earned.** Durations below 60 seconds render in seconds.
- **E4 — Earned.** The unit badge is inline with stats without shifting the row’s left edge.
- **E5 — Earned.** Set type is a named menu with a meaningful accessibility label.

## 2. New findings by severity

### Critical

- **Completed sets can become invalid afterward.** `ExerciseEntryCard.swift:398-413` commits edits without revalidating or clearing completion; `WorkoutSession.swift:124` preserves anything with `completedAt`. Repro: complete `60 × 10`, erase weight or reps, press Done, Finish; History again contains `— × 10` or `60 × —`.
- **Discarding an empty templated workout can erase its template.** `TemplateDrift.swift:99-148` treats an empty workout as drift and rebuilds the template from an empty result; `:162-163` then deletes the workout. The receipt says nothing was saved while reusable template items are gone.
- **One-tap carry-forward silently changes weight.** `WorkoutSession.swift:301-312` copies full precision, but `ExerciseEntryCard.swift:217` formats it with the one-decimal formatter at `SharedEnums.swift:69-76`. Completing a carried `22.25` row saves a rounded value.

### Important

- **History violates D23.** `HistoryView.swift:11-18,48-51` resolves the live template name; `HistoryRendering.swift:135-140` falls back to `gym?.name`. Historical presentation can change after rename/delete.
- **The guard ignores frozen load type.** `WorkoutSession.swift:402-408` always prefers the live exercise. After a catalog update changes load type, a frozen weighted entry can accept a weightless set while History still classifies it as weighted.
- **Finish errors are reported as empty deletion.** `ActiveWorkoutView.swift:222-245` defaults to `.discardedEmpty`, catches errors, then dismisses and reports “nothing saved.” The workout may still be active; template mutation may already have persisted.
- **Selected-gym archival is stale in-session.** `StartWorkoutView.swift:224-231` resolves only once. Archiving that gym elsewhere does not clear `selectedGym`.
- **Tests miss the dangerous seams.** Adjusted fixtures preserve their original intent, and the A2/B1 tests would fail old code. Missing cases include post-completion invalid edits, fractional carry-forward, empty-template finishing, template/gym renames, frozen-load-type changes, archived selection, finish errors, and C2 deep-linking. The machine-unit UI test does not assert that the chosen unit persisted.

### Minor

- “View in History” is a tab switch, not a link to the specific workout (`RootView.swift:53-59`).
- The requested range includes the unlisted `764aed3` commit.
- `git diff --check` passes. Build/tests could not be independently executed because the environment’s CoreSimulator service/runtime was unavailable.

## 3. Overall verdict

**No — unsafe to dogfood until the three silent data-loss/corruption paths are fixed.**
their original intent: added weight/reps satisfy the new precondition, the lingering-active test still verifies auto-finish, and a separate test covers empty-stray deletion. The new A1/A2/B1 tests fail the old implementation, but miss the loopholes above.
- The requested range contains five commits, including `764aed3`, not four.
- `git diff --check` passed. Build/tests could not be rerun because this environment cannot access CoreSimulator or execute SwiftData macro plugins.

## 3. Overall verdict

**No — unsafe for real-session dogfooding until completed-row validity, empty-template drift, and snapshot-only history are fixed.**
 the empty-template data-loss path and D23 history/load-type violations are fixed.**
