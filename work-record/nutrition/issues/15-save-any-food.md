# N15 — Save any food you open, including from Today's log

Type: feature
Status: **in progress** (was: approved — after [live-workout 03](../../live-workout-fixes/issues/03-chart-from-workout.md)** (the user,
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

## Design (2026-11-13)

**Where a food opens, and its save control** — the bookmark in the bar, the same face as `SelectedFoodView`'s, acting
at once (no Save needed), filled in the action colour when saved:

| Screen | Opens from | Saves |
|---|---|---|
| `SelectedFoodView` | Log food (search, recent, My foods, Saved foods), a barcode | the food (unchanged) |
| `EditEntrySheet` | Today's log, History's day food page | the food behind the entry; none → a new food from it |
| `ScanEntryEditor` | a meal photo / description entry (Today, History) | the meal as ONE meal in My meals |
| `ScanItemEditor` | an item of that meal | the item as a food in Saved foods |
| `SelectedMealView` | My meals | already in My meals (Edit / Delete there) |

**Decisions taken:**

- **The food saved is the one on screen:** the entry's name ("Manual Add" for a nameless one), serving and the numbers
  as they read now; its other facts (fiber, sugar, saturated fat, sodium) come with it. Not "made by the user" (Saved
  foods, not My foods — D81), no database credit (it has none).
- **No duplicate:** the entry is linked to the food (`FoodEntry.savedFood`, an existing field); a second tap toggles it.
- **No stored-format change.** A photo meal and its items have no link field, so their saved copy is found by content
  (same name, serving and numbers). Editing one after saving reads as not saved, and saving again makes a second copy.
  **The user, 2026-11-13: keep it that way (no new link field, so no Gate S)**, after the trade-off was explained.
- **Un-saving deletes nothing logged:** a food leaves Saved foods (`isSaved` false); a food that only ever was a saved
  copy then leaves every list (`SavedFood.isCachedLookup` no longer needs a database id). A meal has no saved flag — My
  meals is the list — so un-saving deletes that meal; entries logged from it stay.
- A photo meal saves usually-for the meal it was logged to; each item is one serving of its portion ("1 cup" → 1 cup,
  blank → 1 serving) with its weight.

**New strings (the user's decision):** "Save to My meals", "Remove from My meals" (VoiceOver labels of the meal
bookmark). The food bookmark reuses "Save to Saved foods" / "Remove from Saved foods".

## Progress

- 2026-11-13 (Claude): `Domain/FoodSaving.swift`, `Features/Food/SaveBookmark.swift`, the bookmark on `EditEntrySheet`,
  `ScanEntryEditor` and `ScanItemEditor` (in its own glass, a fixed `ToolbarSpacer` apart from Save, after the first
  captures showed it fused with Save); `SavedFood.isCachedLookup` no longer needs a database id. The filled bookmark is
  the toolbar's ink, as `SelectedFoodView`'s — right: **the user, 2026-11-13: no violet (the Soft look, D67), no
  visible wording, the icon alone**; the VoiceOver labels stay (spoken only). The user also set that the ios-design
  skill is outdated: match the app's current screens (AGENTS.md).
- Tests: `FoodSavingTests` (8); UI `TodayFoodUITests.testAnyLoggedFoodCanBeSaved` (Banana from a food, the Manual Add
  entry with none; Cancel keeps the bookmark; both reach Saved foods; un-saved Banana leaves it),
  `ScanFoodUITests.testAMealPhotoSavesAsAMealAndAnItemAsAFood` (the meal reaches My meals, the item Saved foods), and
  their dark AccessibilityL capture runs. First run: the meal test looked for `logFoodRow.Poke bowl`; a meal's row is
  `logFoodRow.meal.Poke bowl` (the feature worked — the snapshot showed the meal) — test fixed.
- Captures in [`captures/n15/`](../captures/n15/): the entry sheet before/after saving (light Default, dark
  AccessibilityL), the meal editor and the item screen saved (both). Whole at both sizes.

```
Verified: Unit plan — 1366/1366 passed, exit 0, build/results/n15-unit.xcresult
Verified: TodayFoodUITests (2 new) + ScanFoodUITests (2 new) — 4/4 passed, exit 0, build/results/n15-ui3.xcresult
Not verified: the TodayTrain area plan (pending before merge); on a phone
Known flaky: none seen
```

## Comments

## Codex review N15 — response (round 1)

Report: [`codex-review-n15.md`](../codex-review-n15.md) (not clear: three P2, one P3). All accepted; no schema change.

1. **P3 README:** Today's log entries and a scanned meal's bookmarks are in the overview.
2. **Full content before a match** (`FoodSaving.copies(of:)`, `savedMeal`): a candidate must carry nothing a photo
   item cannot (no brand, barcode, other facts, servings per container, other servings; a meal item also no linked
   food), so a richer food or My meals meal with the same headline numbers is never "this one" and never deleted.
   Regressions: `aRicherMealWithTheSameNumbersIsNotThisOne`, `aRicherFoodIsNotAnItemsCopy`.
3. **The Weight field wins** over a weight inside the portion text (`food(from:)`), for foods, meals and matching.
   Regression: `theEditedWeightIsSaved`.
4. **Saved state over every copy:** an item is saved when any copy is; un-saving takes every saved copy out; saving
   again re-saves the oldest copy (deterministic order) rather than making another. Regression:
   `anUnsavedDuplicateNeverHidesASavedCopy`. Also removed the extra blank line at the end of the two UI test files.

```
Verified: Unit plan — 1370/1370 passed, exit 0, build/results/n15-unit2.xcresult
Not verified yet: TodayTrain area plan (~30 min; asking the user); UI unchanged this round (Domain + README only)
```
