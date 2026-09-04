# 06 — Remove the explanatory helper copy

Status: resolved — awaiting Codex review
Blocked by: 05
Added 2026-09-04 after the milestone-9 install: "lets get rid of all those unnecessary placeholder
texts". Offered three scopes; the user chose **A**.

## What to build

Remove the gray tutorial paragraphs — `Section` footers and alert `message:` text that explain a
screen rather than state a consequence. **Keep**, because they are honesty or safety markers:
- delete confirmations that name what is destroyed (workout, set, entry);
- the "(estimated)" zone marker (D45) and the ≈ on converted axis labels and values (D9/D25);
- the equipment picker's per-layer notes in Previous Performance (they label three different data
  sources, not a tutorial);
- short functional hints that gate an action ("Link at least one exercise this model serves",
  "Can't find the machine's model? Add it", the model-correction choice explanation);
- "It was not renamed. Rename it from History…" — it IS the alert's content.

## Acceptance criteria

- Copy only: no model, Domain, or identifier changes; `git diff --stat` touches only `Features/`.
- Every UI class green (structure changes to `Section`s can move rows).
- The screenshots of the finish sheet, History detail and chart show no gray paragraphs.


## Resolution (2026-09-04)

32 footer/message clauses removed across 17 files (104 deletions, `Features/` only), plus the
chart's converted-units footer and its now-unused `footer(days:)`, and the equipment picker's
now-unused `isFrozen`. Kept: delete-impact confirmations, "(estimated)", ≈ on axis labels and
values, the Previous Performance layer notes, the three functional hints, and "It was not renamed…".
No test referenced any removed string. **643 unit green; all 36 UI green** (three chunks on this
commit). Screenshots `finish-heart-rate` / `history-heart-rate` / `workout-summary` show no gray
paragraphs.

**Lesson, recorded because it cost a rebuild:** a regex that removes a property "up to the next
`    }`" ate the whole `body` of `MachinePickerSheet`. Structural deletions get exact-string
matches or a brace-balanced scan, never a non-greedy multi-line regex.


## Codex review 06 — response (2026-09-04)

`codex-review-06.md`: 2 high, 3 medium, 1 low. Codex was right that several cuts were consequences
wearing tutorial clothes. Each comes back as ONE short line at the action boundary, never a
paragraph:

- **kg axis could hide converted lb values (high).** `unitSuffix` now shows `(≈kg)` whenever any
  plotted point was entered in another unit; plain `(kg)` only when nothing was converted.
- **"Finish It & Start New" lost its warning (high).** Dialog message: "Only its completed sets
  are kept."
- **Save as Template said nothing (medium).** The naming alert's message: "Saves exercises, sets and
  target reps — not weights or rest times." The permanent gray paragraph stays gone.
- **Safety/provenance lines (medium).** Export: "This phone holds the only copy until you export."
  Equipment sheet, only once a set is completed: "A completed set locks equipment; a change
  continues in a new entry." History Add Exercise: "Recorded as defined today, without equipment."
  Preset rename: "Logged sets keep the old name." Model rename: "History keeps the captured name."
- **Sparse-series caveat (medium) / unused `days` (low).** When fewer than four days are drawn:
  "Only N days logged — read the shape with caution." — which is also what `days` is for.

Copy only, again. 643 unit green; UI classes for the touched screens re-run below.


## Codex review 06b — response (2026-09-04)

Standards clear; one high left: `bestUnit` is the heaviest set's unit, but Volume sums every set
and the e1RM can be won by a different one, so a kg axis could still hide an lb contributor.
`ProgressPoint` now carries `enteredUnits` (every set that day) and `e1rmUnit` (the winning set);
the axis suffix and the Volume value use the contributor for the metric on show. Unit test builds
a day whose heaviest set is kg and whose e1RM is won by an lb set. 644 unit green; chart UI 6/6.
