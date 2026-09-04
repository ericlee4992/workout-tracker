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
