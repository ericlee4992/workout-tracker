Round 1 (T6) of UI-redesign ticket 08 — the Exercises tab and the pickers/sheets on the Ink /
Amber design system (which YOU built; Claude built this ticket, so you review). Ticket:
work-record/ui-redesign/issues/08-exercises-and-sheets.md; the plan: work-record/ui-redesign/spec.md
(ticket 08 and the constraints — copy policy, ids/strings the tests read). Boundary: main..HEAD
on branch ui-redesign-08 (main = f2bfa7a, ticket 07).

Files: WorkoutTracker/Features/ActiveWorkout/ExercisePickerSheet.swift (ExerciseRow + the
picker), Features/Design/MuscleGroupStyle.swift (MuscleIcon's tile is now a @ScaledMetric —
shared with Start's template cards and History's detail header), Features/Exercises/ExercisesView.swift, Features/ActiveWorkout/AddByMachineSheet.swift,
MachinePickerSheet.swift, BarPickerSheet.swift, WorkoutTrackerUITests/RedesignScreenshotUITests.swift.
Screenshots: work-record/ui-redesign/screenshots/08/ (07-exercises, 07-exercises-axl).

Scope:
1. ExerciseRow lost its " · "-joined subtitle: body area and tags are separate elements now.
   Does any test, or VoiceOver, depend on the joined string? Is a row with FOUR tags
   (barbell · dumbbell · cable · smith) still one line at the default size? At accessibility
   sizes the chips STACK under the name (AnyLayout) and each is `fixedSize` — see
   07-exercises-axl.png; a four-tag row becomes five stacked chips: acceptable? The chips carry `tag.label` — is a chip per tag noise on a
   74-row list, or right?
2. The load-type chip is in the ACCENT (`Chip(tint: Theme.accent)`): amber marks "not the
   default load type" — the same colour the primary actions use. A problem?
3. MuscleIcon on every row of a 74-row searchable list: any cost (MuscleGroupStyle.resolve is a
   dictionary lookup) or a visual monotony worth flagging?
4. `.listRowBackground(Theme.card)` on Sections that contain a `.buttonStyle(.plain)` Button
   row with a `.contextMenu` (ExercisesView) — tap/long-press surfaces unchanged?
5. Sheets: the plan says "sheets' primary actions `.primary`". Most are toolbar Save/Add/Done
   and were left as toolbar buttons; only "Use this bar" is in-list and is `.primary`. Accept
   that reading, or do you want the Forms' toolbar actions restyled?
6. Copy policy — new `Text("…")`? Filter ids, the "Search exercises" prompt, `noExercisesMatch`,
   `createExerciseFromSearch` unchanged?
7. Gates: ExercisePreset (reads `exerciseOption.*`, preset chips), DumbbellCounterpart
   (`staticTexts["Bench Press"]` inside `exerciseOption.Bench Press` — the name is still a
   staticText child?), CoreLoop create-from-search, Barbell (`barCustomApply` now `.primary`,
   still `.disabled` until valid).

Do NOT run xcodebuild or simctl (the simulator is in use). Review by inspection; verification is
in the ticket. Report by severity with file:line, or say "clear" in one paragraph. Do not modify
source files. Write to work-record/ui-redesign/codex-review-08.md
