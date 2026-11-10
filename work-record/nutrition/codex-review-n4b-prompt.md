# Codex review — nutrition N4, round 2

Same terminal, same rules as round 1 (`work-record/nutrition/codex-review-n4-prompt.md`). Your round-1 report:
`work-record/nutrition/codex-review-n4.md` (not clear). Review the fixes: `git diff <round-1 HEAD 29abf9f>..HEAD`.

Fixes, by your finding:
1. **Toast timer** — `LogFoodView` `.task(id:)`: returns on cancellation and clears only its own receipt. UI regression
   `LogFoodFlowUITests.testASecondLogKeepsItsOwnUndo` (two quick logs, Undo only the second, expiry, a fresh Undo).
2. **Lossless edit** — `EditableNumber` / `EditableServing` (`Domain/FoodLog.swift`): an unchanged field saves the stored
   value exactly; `AddFoodView` / `AddFoodNutritionView` use them. `FoodNumber.text` keeps two significant digits below
   0.01 (never "0" for 0.004). Test `editingOneFieldKeepsTheOthersExactly` (1/3 cup, 0.004 g, 68.333 cal through
   update).
3. **Invalid servings** — `ServingText.parse` returns nil for an amount that is not a positive finite number ≤ 1,000,000
   ("1/0 cup", "-2 g", "0 g", "0/2", "1/2/3", "+1", "(0 g)", overflow); a text starting with a letter is unit-only;
   `FoodNumber.parse` takes plain digits with one separator only (no "1e3", ≤ 1,000,000). Manual Add's Log stays
   disabled for a non-blank serving that does not parse (no silent default). Test
   `aServingThatIsNotAPositiveAmountIsRefused`. Policy decided by Claude: "1e3 g" reads as 1 × "e3 g" (a unit text),
   not scientific notation.
4. **Reduce Motion** — every Food view reads `accessibilityReduceMotion`: no animation for `withAnimation`, opacity for
   the toast transition and the numeric/symbol content transitions, no animated tab scroll. Not exercised at runtime.
5. **README** — a "Food logging" item; a Log food picture (`docs/readme/log-food.png`, from
   `LogFoodUITests.testCaptureReadme`).
6. **Test plans** — `LogFoodUITests`, `LogFoodFlowUITests` in TodayTrain, `NutritionGoalsUITests` in ProfileAI;
   `scripts/test-plans.py --check` exit 0.
7. **Captures** — Selected food's lower part with Other nutrition facts expanded (`n4-selected-facts-*`).

New in this round (the user, 2026-11-10): **Delete Food…** for My foods — `SelectedFoodView` "…" menu (My foods only),
alert "Delete Food" / "Food already logged and meals with it are kept.", the `deleted` flag before the model goes,
`FoodLog.delete(_ food:)`; `FoodLog.undo` skips a food/meal that is no longer live (a toast's Undo after its food was
deleted still removes the entry); LogFoodView drops the toast whose food was deleted. Tests:
`deletingOneOfMyFoodsKeepsWhatWasLoggedAndUndoStillWorks`, and the Delete step at the end of
`testAddFoodMakesOneOfMyFoodsAndTheBookmarkSavesIt`.

Per AGENTS' reviewer rule (round 2: UI behaviour and UI test code changed): build; Unit plan; UI classes
`AAAWarmUpUITests`, `LogFoodUITests`, `LogFoodFlowUITests` (2 workers; rerun failures serially). Claude's evidence:
scratchpad `unit3.xcresult` (FoodLogTests ×10), `ui4.xcresult`.

Write `work-record/nutrition/codex-review-n4b.md` in the same form; end with exactly `Verdict: clear` or
`Verdict: not clear`.
