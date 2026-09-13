# 15 — Delete a template from its detail (the tile's long-press menu deleted the wrong one)

Status: in progress (branch `templates-15-delete-in-detail`)

The user (2026-09-12, on the phone): "when deleting template it doesnt work propery. when i press
and hold a template and click delete it deletes the other template. just have delete button
appear when you open the template."

## The bug

Ticket 10 put Edit and Delete on each tile's `.contextMenu`. The grid of tiles is ONE List row;
a `contextMenu` inside a List row is presented by the List, which attributes the press to the
row — and with several context menus in one row, the one that fires is not reliably the tile
under the finger. Not reproduced in the Simulator (no UI test long-pressed a tile — the
ticket-10 review noted only that Edit/Delete "stay on the long-press menu"); the user saw it on
the phone with two templates. Cause not chased further: the user asked for the menu to go.

## Built

- `StartWorkoutView`: the tile's `.contextMenu` removed (Edit was already on the detail's
  toolbar since ticket 11); the tile only opens the template.
- `TemplateDetailView`: a "Delete Template…" red text button (`deleteTemplate`, `Theme.danger`,
  44 pt) as the last row, under the exercises and above the pinned Start — destructive never
  primary; a confirmation alert "Delete Template" / Delete / Cancel with one consequence line,
  "Workouts already logged from it are kept." (D23: a plan is not a record). On Delete the
  detail pops. **New copy** — "Delete Template…" and the consequence line — by the user's
  request ("have delete button appear when you open the template").
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
