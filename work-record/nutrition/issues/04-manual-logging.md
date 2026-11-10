# N4 — Log Food: search, recent, saved, quick add, selected food, one-tap + with Undo

Type: feature
Status: **approved** (the user, 2026-11-09: "S6 → N3 → N4 → N5", recorded in STATE); My meals included (N2)
Blocked by: N2
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/nutrition-04-log-food` off `main`.
Spec: [nutrition](../spec.md). Decisions: D69.

## Goal

Log food by hand quickly: from recent and saved foods with one tap, or by entering a food once and reusing it.

## Scope

- **Log Food sheet:** meal chips (Breakfast / Lunch / Dinner / Snacks, defaulting by time of day); a search field over
  the user's own recent and saved foods (online search joins in N8; "Describe what you ate" joins in N7 through the
  food-describe flow); tabs All / My foods / My meals / Saved; recently logged with a **+** that logs one serving to
  the chosen day and meal, with an **Undo** toast; Scan (N7) and Manual Add entry points.
- **Selected food:** servings and measurement, calories, protein / carbs / fat, other nutrition facts (collapsed),
  Save to My foods, Log.
- **Manual Add:** name, serving, calories and macros (macros optional; the calories–macros mismatch is shown, not
  blocked). **Quick add:** calories (and optional macros) without a name.
- **Entries:** edit (servings, meal, numbers) and delete, with Undo; Today/History show the result (N5/N10).
- **My meals:** save a group of entries as a meal and log it in one tap — only if confirmed in N2.
- Not in scope: Voice Log (in the prototype, not chosen).

## Acceptance

1. One-tap + logs exactly one serving and Undo removes it (UI test); totals update.
2. Manual Add / Quick add / Selected food log the numbers entered, in the entered units (unit tests for scaling).
3. Editing a saved food leaves past entries unchanged (N2 rule; test).
4. Captures at default and AccessibilityL, light and dark; Codex clear.

## Code map

- New `Features/Food/` (Log Food, Selected food, Manual Add); `Domain/` food helpers (N2).
- Prototype: `Screens/Soft/SoftProfileAndAdd.swift` (Log food), `SoftModel.swift` (sample shapes only).

## Progress

**Structure (the user, 2026-11-10, D81):** tabs All / My foods / My meals / Saved foods; **My foods** = created by
the user via **Add food** at the bottom of that tab (two-step form like the user's reference: brand (optional),
description, serving size, servings per container (optional) → Next → calories, protein, carbs, total fat, saturated
fat, … → Save food); **Saved foods** = bookmarks from anywhere (incl. My foods); **Manual Add** (All tab) logs a
one-off entry, creates no food, name optional — **Quick Add merged into it**. Meals kept (preset by time). Wording of
the first mock approved. Data: `SavedFood` + "made by the user" + optional servings per container (additive, pre-R).

**The user (2026-11-10):** N4 adds Today's **"Log food" pill** now (N5 builds Today's food area around it); the Log
Food screens are **mocked with sample data and shown first**, then wired.

**Handoff (2026-11-10):** mock v1 at `5f36999` (pill, Log food with chips/tabs/search/recent +/Undo/My meals,
Selected food, Manual Add, Quick Add; `LogFoodUITests`; captures in the old session's scratchpad — re-run the test to
regenerate). Rework to D81 next (see STATE → Next), then show the user, then wire.

**Mock v2 (2026-11-10, D81) — sent to the user for approval:** tabs All / My foods / My meals / Saved foods
(chosen tab scrolls into view at AXL); All = Recently logged + Manual Add; My foods = the user's foods + **Add food**
(two steps: Brand (Optional), Description, Serving size, Servings per container (Optional) → **Next** → "Nutrition",
Per serving: Calories, Protein, Carbs, Total fat, Saturated fat; then Fiber, Sugar, Sodium → **Save food**); Saved
foods = bookmarks; Selected food: bookmark in the bar (save / remove), **Edit** on one of My foods (the Add food form
filled in), "Servings per container" shown when set; Manual Add = Name (Optional), Serving (Optional), calories and
macros, no "Save to My foods" (creates no food); Quick Add removed. My meals / Saved foods tabs have no bottom command.
Empty states (mock switch `-logFoodMockEmpty`): My foods "No foods yet" / "Add a food once, then log it in one tap." /
Add food; Saved foods "No saved foods" / "Tap the bookmark on any food to keep it here."
New strings for the user's OK: the tab "Saved foods", Add food / Next / Nutrition / Per serving / Save food, field
labels and prompts above, Edit food, the two empty states, "Save to Saved foods" / "Remove from Saved foods"
(VoiceOver labels). Step 2 offers only the facts `SavedFood` already stores (N2); more (e.g. cholesterol, potassium)
would need fields — ask. Serving size is one text field in the mock; wiring parses it into `(value, unit)`.
Verification (mock): `build-for-testing` exit 0; `LogFoodUITests` 4/4 passed (2 workers, `n4b.xcresult` in the
session scratchpad); captures light/Default + dark/AXL looked at. Not verified: anything stored (nothing is wired).

**Create meal (the user, 2026-11-10: "add Create meal to the mock"):** My meals gets **Create meal** at the bottom (same
pattern as Add food) → one screen: Name ("e.g. Usual breakfast"), "Foods" with the total calories and a servings
−/+ per food (− at ½ serving becomes remove), "Add foods" with a search and every food with a + (again = one more
serving), **Save meal** (disabled until a food is in). Empty My meals: "No meals yet" / "Save foods you eat together,
then log them in one tap." / Create meal. Later N5: "Save as meal" on a Today meal. `LogFoodUITests` 4/4 passed
(`n4c.xcresult`). Not in the mock: editing or deleting a meal; the meal's usual slot (`SavedMeal.usualMeal`).

**Meals edit/delete + usual meal (the user, 2026-11-10: "You should be able to edit or delete saved meal. Create meal
can let you pick one. Looks good"):** Create meal gains **Usually for** chips (Any / Breakfast / Lunch / Dinner /
Snacks → `SavedMeal.usualMeal`); My meals lists the chosen meal's own first; logging still goes to the chosen meal chip.
Tapping a meal opens its page ("Usually for Breakfast", total as the hero + macros, Foods with ×servings, **Log to
…**); **Edit** → "Edit meal" (the Create meal form filled in); "…" → **Delete Meal…** (like a template's). The user
approved the mock ("Looks good") — read as also accepting step 2's eight facts and no bottom command on Saved foods.
`LogFoodUITests` 4/4 passed (`n4d.xcresult`). Next: wire.

**Wired (2026-11-10, the user: "start wiring. ignore the backup steps for this"):**
- **Data (D81):** `SavedFood.createdByUser` (false) + `servingsPerContainer` (optional) — additive; `isSaved` now means
  Saved foods (bookmark); guard `approvedFingerprint` → `038a4fcb…`; export v12 `SavedFoodRow` gains both as optionals
  (v12 unreleased, not bumped). Backup steps skipped by the user's instruction; the shipped-format fixture still opens
  (`NutritionMigrationTests`).
- **`Domain/FoodLog.swift`:** `FoodNumber` (comma decimals, blank/negative refused), `ServingText` (parse "1 jar (250 g)",
  "100 g", "1/2 cup", "jar"; the unit kept verbatim), `FoodDraft`, `MealDraftItem`, `FoodLogReceipt`; lists (recent by
  last used, My foods / Saved foods by name, all, meals with the chosen meal's first, search over name + brand); `log`
  food (servings) / meal (one entry per item, `.myMeal`), `logManual` (blank name → `.quickAdd`, no food),
  `undo` (deletes exactly the receipt's entries, restores last used), `createFood` / `update` / `setSaved`,
  `saveMeal` (create or replace items) / `delete` (cascade; entries stay).
- **Screens on stored data** (`Features/Food/`): Log food (`@Query` foods + meals; + logs with a check and a 5 s Undo
  toast; logging from Selected food / Manual Add / a meal page pops back to the toast; "Your foods" header while
  searching All; system "No results" for an empty search), Selected food (servings ½ steps, bookmark, Edit for My
  foods), Add/Edit food (Next needs a description + serving; Save needs calories; other numbers blank or numbers),
  Manual Add (Log needs calories), Create/Edit meal (Save needs a name + a food), meal page (Log, Edit, Delete Meal… with
  a confirmation). `FoodSampleFixture` (`-uiTestFoodSample`) replaces the mock data.
- **Moved to N5 (where entries are listed):** editing/deleting a logged entry, and Today's totals (acceptance 1's
  "totals update"). N4 proves the data with unit tests and the list order in UI tests.
- **New strings since the approved mock (for the user's OK):** All empty "Nothing logged yet" / "Foods you log appear
  here."; "Your foods" (search header on All); "Couldn't save" (save-error alert, with the system's message); Delete
  Meal alert "Food already logged from it is kept." / Delete / Cancel; toast for a nameless Manual Add "Logged 250 cal to
  Lunch"; meal page subtitle "Usually for Breakfast". Open question: Delete Food… for My foods (not in the mock).
- **ios-design tells:** same container on everything — absent (lists for lists; panels only for the hero and forms);
  chips — deliberate: the meal and "Usually for" are choices; all-caps labels — absent; middle-dot metadata —
  deliberate: a food line "brand · cal · serving"; accent overuse — absent (violet only for the logged check, the
  bookmark state and the toast); equal stacked blocks — absent; phone-sized website — absent; above the fold — the
  list starts in the first viewport; control as primary — absent (Manual Add / Add food / Create meal secondary; one
  primary per pushed screen); default-size-only layout — absent (AXL captures; fields stack, commands scroll).

**Evidence (wiring):** `build-for-testing` exit 0. Unit plan **1213 passed, 0 failed** (`unit2.xcresult`; includes
`FoodLogTests` 13, `NutritionExportTests`, `NutritionMigrationTests`, `StoreFormatGuardTests`). UI: `LogFoodFlowUITests`
4 + `LogFoodUITests` 4 — first run 5/8 (two captures tapped a now-disabled Next; one looked up "2" instead of "2
servings"), tests fixed, the three reran 3/3 (`ui2.xcresult`); final run of both classes **8/8 passed, exit 0**
(`ui3.xcresult`, 2 workers). Two tests were slow in that run (Add food 238 s vs 40 s before; AXL capture 411 s): each
stalled once right after tapping the first Add food field — "App event loop idle notification not received" (60 s) +
spindump. The spindump's app main thread is idle in its run loop (73.8K cycles over 102 samples), not blocked — read
as a clone/keyboard idle-signal flake, not an app hang; noted for the reviewer.

Verified: unit plan 1213/0; `LogFoodFlowUITests` 4/4 and `LogFoodUITests` 4/4; captures light/Default + dark/AXL
looked at (`ui2shots/`). Not verified: Today totals and entry edit/delete (N5); a migration rehearsal on a device
(skipped by the user's instruction). Known flaky: the idle-signal stall above. Scratchpad:
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/d3ab4aaa-bbbb-43da-8c54-44b94b2255ab/scratchpad/`.

## Comments
