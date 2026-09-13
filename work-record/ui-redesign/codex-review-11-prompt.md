Round 1 (T6) of UI-redesign ticket 11 — the per-exercise muscle icons removed from every row, the
template tile's icons reduced to five muscle FAMILIES, and a new template detail screen (tap a
tile → its exercises as a list → Start). Grade it against .claude/skills/ios-design/REVIEW.md
(read SKILL.md's rules and REFERENCE.md too); the ticket supplies the composition record:
work-record/ui-redesign/issues/11-icons-and-template-detail.md (the user's words, job/state
sentences, the wireframe, the tells answered). Boundary: main..HEAD on branch
ui-redesign-11-icons-and-template-detail (main = 55d6562).

Files: Domain/MuscleFamily.swift (new, pure: the 14 seeded groups → 5 families; Core, Neck,
Full Body → none), Domain/Supersets.swift (memberLabels(groupIDs:) — a pure version of the
workout's A/B labels for template rows), Domain/WorkoutTemplates.swift (TemplateTargets.summary,
the detail row's caption), Features/Design/MuscleGroupStyle.swift (keyed by family; MuscleFamilyStrip),
Features/Start/WorkoutStartFlow.swift (new: the start flow lifted out of StartWorkoutView as a
ViewModifier so the pushed detail can run it with its own dialogs), Features/Start/TemplateDetailView.swift
(new), Features/Start/StartWorkoutView.swift (tile opens the detail; HeroCapsuleLabel now internal),
the three rows that lost their icon (ActiveWorkout/ExercisePickerSheet.swift ExerciseRow,
ActiveWorkout/ExerciseEntryCard.swift, History/WorkoutDetailView.swift), tests
(WorkoutTrackerTests/MuscleFamilyTests.swift, ThemeTests.swift; RedesignScreenshotUITests
test04_startTemplates + test04_startLargeText), docs (SPEC.md visual-system paragraph, D54 amended).
Captures: work-record/ui-redesign/screenshots/11/ — 04-start-templates (tile with family icons,
default), 04-template-detail (default), 04-start-axl + 04-template-detail-axl + -axl-2 (the same
at AccessibilityL, the detail scrolled to its last row), 02-active-workout, 05-history,
06-gyms-and-exercises (rows without icons).

Walk REVIEW.md items 1–12 and report each with a checkable answer. Particular attention:
- Item 1/2: the detail's bold element is the Start capsule at the THUMB (safeAreaInset above the
  tab bar); the list is the eye's landing. Edit is a toolbar word. Anything else competing?
- Item 3: the detail is a List — the family icon strip in a clear row, the exercise rows in one
  card-coloured container, a spacer section so the last row clears the pinned capsule. A card in
  a card anywhere? Is the spacer section a tell?
- Item 6: the family icons keep the muscle colours (their meaning); the superset chip is amber as
  a STATE (the workout's same chip). Measure the family tile pairs (colour on colour at 14 %).
- Item 8/11: `startEmptyWorkout` unchanged; `templateTile.<name>` now OPENS the detail instead of
  starting — no UI test tapped a tile before (verify: grep the UI tests). New identifiers:
  `startTemplate`, `editTemplate`, `templateDetail`, `templateFamilies`, `templateExercise.<name>`.
  New strings: the row caption "N sets · r, r, r reps" (TemplateTargets.summary) and "Start" on
  the capsule — the ticket flags the caption for the user's decision; is "Start" an existing
  string in the repo's history (the template rows' button before ticket 10)?
- The start flow refactor (WorkoutStartFlow): does the pushed detail's "already in progress"
  dialog and the drift dialog behave exactly as the Start screen's did (heart-rate banking
  before finish, codex-review 05/05b)? The modifier is applied on the Start List AND the detail —
  two instances of state; can both fire for one tap?
- A template deleted from the tile's long-press menu while its detail is on the stack: the
  detail guards `isDeleted`; is the navigationDestination(item:) binding safe?
- Item 9: the detail at AXL — the capsule wraps, the chip stacks over the name, the strip wraps.

Do NOT run xcodebuild or simctl (the simulator is in use). Report by severity with file:line, or
say "clear" in one paragraph. Do not modify source files. Write to work-record/ui-redesign/codex-review-11.md
