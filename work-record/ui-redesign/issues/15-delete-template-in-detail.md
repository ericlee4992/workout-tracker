# 15 — Delete a template from its detail (the tile's long-press menu deleted the wrong one)

Status: resolved — Codex clear after 2 rounds (codex-review-15, 15b); full UI suite **72/72** on `b324a4d`; on `af7a2b7` (the hardening) `WorkoutTemplateTests` 7/7 + `TemplateDetailUITests` 2/2 + the four template captures 4/4; merged to main 2026-09-13

The user (2026-09-12, on the phone): "when deleting template it doesnt work propery. when i press
and hold a template and click delete it deletes the other template. just have delete button
appear when you open the template."

## The bug

Ticket 10 put Edit and Delete on each tile's `.contextMenu`. The grid of tiles is ONE List row;
a `contextMenu` inside a List row is presented by the List, which attributes the press to the
row — and with several context menus in one row, the one that fires is not reliably the tile
under the finger. Not reproduced in the Simulator (no UI test long-pressed a tile — the
ticket-10 review noted only that Edit/Delete "stay on the long-press menu"); the user saw it on
the phone with two templates. **Suspected** cause, not proven (codex-review-15: Apple documents the modifier as attaching a
menu to a view, not how several inside one List row are arbitrated; the ForEach uses model
identity and each closure captures its own `template`, so the alternatives have no evidence).
Not chased further: the user asked for the menu to go, and removing it removes the interaction
whatever the mechanism.

## Step 1 — job, state, bold element

The template detail (ticket 11) exists so the user can see what the template holds and start
it in one tap; the eye lands on the exercise list, the bold element is the pinned Start at the
thumb. Ticket 15 adds a last row — the destructive command — and a confirmation state (the
alert). Start stays the only accent; the red row is the list's tail, below the fold when the
list is long, which is where a destructive command belongs.

## Step 2 — wireframe

Ticket 11's, with one row appended:

```
│ │ Abdominal Crunch       │ │
│ │ 3 sets · 10, 10, 10 …  │ │
│ └────────────────────────┘ │
│   🗑 Delete Template…      │  red text, 44 pt, last
│                            │
│   (● Start  ↗)             │  H, pinned
```

## Step 4 — tells

Inherited from ticket 11 unchanged. Added: the primary never destroys — **absent** (a red text
row, not a filled button); a control dressed as the command — **absent**; two prominent
buttons — **absent** (Start alone is prominent). Survives only the default size:
`screenshots/15/04-template-detail-fixture-axl-2.png` — the row whole at AXL after a scroll.

## Built

- `StartWorkoutView`: the tile's `.contextMenu` removed (Edit was already on the detail's
  toolbar since ticket 11); the tile only opens the template.
- `TemplateDetailView`: a "Delete Template…" red text button (`deleteTemplate`, `Theme.danger`,
  44 pt) as the last row, under the exercises and above the pinned Start — destructive never
  primary; a confirmation alert "Delete Template" / Delete / Cancel with one consequence line,
  "Workouts already logged from it are kept." (D23: a plan is not a record). On Delete the
  detail pops. **New copy** — "Delete Template…" and the consequence line — by the user's
  request ("have delete button appear when you open the template").
- Hardening (codex-review-15): a view-owned `deleted` flag set before the model is deleted —
  `isDeleted` flips back to false once the delete is saved, so the old guards were not a proof;
  the body renders nothing model-backed after the flag.
- `TemplateDetailUITests` (new, 2): with the seeded "Whole Body" and a second template, a long
  press offers nothing; deleting "Second" from its detail removes Second and keeps Whole Body;
  Cancel keeps the template.

## Gate tests

UI: `TemplateDetailUITests` 2, `RedesignScreenshotUITests` `test04_templateFixture` +
`test04_templateFixtureLargeText` (the detail with the button, both sizes), `test04_startTemplates`,
`test04_startLargeText`; unit `WorkoutTemplateTests`; then the full suite.

## Verification (2026-09-12)

`WorkoutTemplateTests` 7/7; captures `test04_templateFixture(+LargeText)`, `test04_startTemplates`,
`test04_startLargeText` 4/4 (`screenshots/15/04-template-detail*.png`: the red Delete Template…
row last, above the pinned Start, at both sizes — with six exercises it is below the fold until
the list scrolls); `TemplateDetailUITests` 2/2 after one test fix (a long press on the tile is
now just a tap — it opens the template — so the probe no longer taps the tile again).

## Codex review 15 — response (2026-09-12)

`codex-review-15.md`: "no demonstrated functional regression"; live-workout source deletion
clear (`sourceTemplate` returns nil, both drift paths continue); design and copy clear (the
History menu item and this row are consistent enough; the consequence line earns its place
under the copy policy). Two P3s, both record: the cause is now labelled suspected (above and
in the code comment); the job/state, wireframe and tells are recorded above. Advisory taken:
the view-owned `deleted` flag. Rerun on `af7a2b7`: `WorkoutTemplateTests` 7/7, `TemplateDetailUITests` 2/2, the four template captures 4/4. Full UI suite on `b324a4d` (the commit before the hardening): **72 tests, 0 failures**.
