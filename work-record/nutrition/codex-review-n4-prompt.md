# Codex review — nutrition N4 (Log Food: My foods, Saved foods, My meals, Manual Add)

You are the independent reviewer; Claude implemented. Read AGENTS.md first. Checkout
`/Users/ericlee06/orca/workspaces/Health App/UI_design`, branch `ericlee4992/nutrition-04-log-food` (off `main`
`e471c11`). Review `git diff e471c11..HEAD`.

Read first: `work-record/nutrition/issues/04-manual-logging.md` (Progress: the user's structure, the approved mock,
Create/Edit/Delete meal, Wired, the scope moved to N5, new strings), decisions D69, D81 (and D78 no "estimated" flag,
D52 plain numbers), `work-record/nutrition/spec.md`, `work-record/nutrition/issues/02-nutrition-data.md` (the models
and the snapshot rule), DEVELOPMENT's migration rules, `.claude/skills/ios-design/REVIEW.md` for the screens;
swiftui-pro / swiftdata-pro apply (project rules override). The user told Claude to skip the backup steps for this
storage change — do not flag their absence; do check that the change itself is safe.

Check in particular:
1. **Logging and Undo** (`Domain/FoodLog.swift`, `FoodLogTests`): one tap writes exactly one serving to the chosen
   meal; Undo deletes exactly the receipt's entries and restores "last used" (two logs then Undo of the second; Undo
   after the toast's 5 s; Undo after the row moved); meal logs one entry per item from the item snapshot; Manual Add
   creates no food, blank name → `.quickAdd`; `FoodEntry(logging:)` snapshot so editing a food or meal never changes a
   past entry.
2. **Parsing:** `FoodNumber` (comma decimals, negatives, "1e3", huge values), `ServingText.parse/format` round trip
   for an edited food (Edit food fills "Serving size" with `servingText` and re-parses it — can that drift?), "1/0",
   units with digits ("2 x 50 g"), grams in parentheses.
3. **Storage change:** `SavedFood.createdByUser` / `servingsPerContainer`, `isSaved`'s new meaning (bookmark), the
   guard's new `approvedFingerprint` — additive to an existing entity; is the lightweight migration from the shipped
   format still sound (`NutritionMigrationTests` in the Unit plan)? Export v12 `SavedFoodRow` optional fields (v12
   unreleased, so not bumped — agree?).
4. **Screens** (`Features/Food/`): LogFoodView (`@Query` + pure list helpers, search on All over every food, empty
   states, `logged` checks keyed by `PersistentIdentifier`, toast timing via `.task(id:)`, the navigation callbacks
   that pop back and show the toast), SelectedFoodView (bookmark, Edit for My foods only, servings stepper floor),
   AddFoodView / AddFoodNutritionView (validation, edit pre-fill, `onSaved` popping two levels), ManualAddView,
   CreateMealView (draft items, + adds a serving, − removes at ½, edit replaces items), SelectedMealView (delete with
   the `deleted` flag before the model goes, as TemplateDetailView). Accessibility labels/identifiers; AXL layouts.
5. **Fixture:** `FoodSampleFixture` gated by `fixtureIsEnabled` (needs `-uiTestReset`).
6. **Scope:** entry edit/delete and Today's totals moved to N5 (ticket) — is anything in N4's acceptance left unproven?

Per AGENTS' reviewer rule (round 1): build; run the Unit plan; run as UI classes (2 workers): `AAAWarmUpUITests`,
`LogFoodUITests`, `LogFoodFlowUITests`, `TodayUpNextUITests` (Today hosts the pill) — rerun failures serially
before judging. Look at the captures: Claude's under
`/private/tmp/claude-501/-Users-ericlee06-orca-workspaces-Health-App-UI-design/d3ab4aaa-bbbb-43da-8c54-44b94b2255ab/scratchpad/`
(`ui2shots/N4-wired-*.png`, results `unit2.xcresult`, `ui1`–`ui3.xcresult`).

Run on **WT-iPhone27** `47D21838-69A6-4BCB-AE90-B0D9C0AAA70B` (`scripts/prepare-test-simulator.sh <id>` first), paths
under `/tmp/codex-n4/`. Claude runs nothing while you run. Do not modify files other than the report; do not commit or
push.

Write `work-record/nutrition/codex-review-n4.md`: findings P1/P2/P3 with file:line, failure scenario and fix; a
Verified / Not verified / Known flaky block; end with exactly `Verdict: clear` or `Verdict: not clear`.
