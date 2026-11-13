# N15 — Save any food you open, including from Today's log

Type: feature
Status: **approved — after [live-workout 03](../../live-workout-fixes/issues/03-chart-from-workout.md)** (the user,
2026-11-13; ticket 2 of 2)
Implementer: Claude; Reviewer: Codex, to "clear".
Branch (when built): `ericlee4992/nutrition-15-save-any-food` off `main` after ticket 03 merges.
Decision: **D87** (3–4). Builds on D81 (My foods / Saved foods / My meals), D82/D83 (meal photos), N4/N5.

## The ask (the user, 2026-11-13)

"When click food in today's log, i should be able to save it to saved foods as well. In fact, i should be able to save
any food if i open them."

## Today

A food opened from Log food (`SelectedFoodView`) has the bookmark (Saved foods). A Today log entry opens
`EditEntrySheet` (Cancel / Save, no bookmark); a meal-photo / describe entry opens `ScanEntryEditor` (its items).
Entries from a photo, a description, a label or Manual Add have no `SavedFood` behind them (`FoodEntry.savedFood` nil).

## The user's choices (2026-11-13, D87)

3. **Saving an entry with no food behind it creates a new food from the entry** (its name and numbers per serving) in
   Saved foods; an entry that came from a real food (search, barcode, My foods) bookmarks that food.
4. **A meal photo (several items) saves as one meal in My meals**, with its items; each item can also be saved on its
   own from the item screen.

## To work out (UI-first with captures)

- Where the save control sits on each screen (the bookmark in the bar, as `SelectedFoodView`), and its state when the
  food is already saved; un-saving.
- "Any food if I open them": list every place a food opens (Today's log, the item editor, History's food line, My
  meals' items, …) and cover each.
- A new food from an entry: which fields (serving, brand, the database credit if it came from one), not "made by the
  user" (it belongs in Saved foods, not My foods — D81), and no duplicate when saved twice. No stored-format change
  expected (existing `SavedFood` / `SavedMeal` fields) — confirm; if one is needed, Gate S applies.

## Acceptance

1. Every opened food (incl. Today's log entries and photo items) can be saved to Saved foods and un-saved.
2. An entry without a food creates one; a meal photo saves as a meal in My meals.
3. Unit + UI tests, captures, Codex clear.

## Progress

Not started.

## Comments
