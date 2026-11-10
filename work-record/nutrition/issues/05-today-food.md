# N5 — Today's food parts

Type: feature
Status: **done — Codex clear (round 2), merged** (2026-11-10) — approved in the user's plan "S6 → N3 → N4 → N5" (2026-11-09); built overnight under the user's standing permission (2026-11-10)
Blocked by: N3, N4
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch (when built): `ericlee4992/nutrition-05-today` off `main`.
Spec: [nutrition](../spec.md); design: [ui-evolution](../../ui-evolution/spec.md) rounds 2 and 5. Decisions: D71.

## Goal

Today shows the day's food beside the training (S2).

## Scope

- **Day rings:** each day's ring fills toward that day's calorie goal in protein · carbs · fat colours (real per-entry
  macros, not a fake split); dashed = nothing logged; faint = days ahead; the workout disc stays inside. Key under the
  row: "Calories toward goal · Worked out". Header: "3 workouts · 5 days logged".
- **Fuel card:** "1,048 cal left" as the headline (over goal: "120 cal over"), **Eaten** and **Burned** beside it, one
  bar toward the goal split by the macros' calorie shares; Protein leads with "47 g to go", Carbs and Fat compact.
  Burned = the day's workout calories known to the app now; Health's active energy joins in N9. **Burned never changes
  the goal or "left"** (D71).
- **Today's log:** foods by meal (calories and macros) and the day's workouts with calories burned; tap to edit (N4).
- **Moved here from N4 (the user, 2026-11-10):** edit a logged entry (servings, meal, numbers) and delete it, with
  Undo; Today's totals update after a log / Undo (N4's acceptance 1).
- **Log food pill:** black, above the tab bar, on Today only; opens Log Food (N4). *Built in N4 (the user, 2026-11-10).*
- **No goals yet:** the fuel card asks to set goals (opens N3) and still shows Eaten.
- AX sizes: rings become one row per day ("Pull Day, Indoor Run · 2,140 of 2,288 cal"); the fuel card stacks.

## Added 2026-11-09 (the user, with N3)

- **No goal yet → an invitation, not empty numbers:** Today's food area says "Set your goals" (wording to approve) and
  opens Personal details → Nutrition goals. Existing testers never see the onboarding step (N3), so this is how they
  meet goals.

## Acceptance

1. Totals, left/over and ring fills match the entries and the dated goal (unit tests incl. a goal change mid-week).
2. Burned shown and never added (test).
3. Captures (default / AccessibilityL, light / dark, with and without goals, over goal); Today UI test; Codex clear.

## Code map

- Today (S2); `Domain/WeekSummary.swift`; prototype `Screens/Soft/SoftTodayTop.swift`, `SoftTodayScreen.swift`.

## Progress

**Built (2026-11-10, night — Claude, on branch `ericlee4992/nutrition-05-today` off `main` `c03bd12`).** Screens from the
approved prototype (`SoftTodayTop.swift` `SoftFuelCard` / `DayRing`, `SoftTodayScreen.swift`); the user asleep, so the
captures are for the morning rather than approved first (the user's overnight permission).
- **Domain `FoodDay.swift`:** `FoodDay` (eaten, entry count, the goal in force that day, burned; left / over, fill 0…1,
  4/4/9 macro shares, grams to go), `FoodDayMath` (`day`, `week`, `burned(by:)` — the workout's active energy, else its
  cardio segments', nil when no sensor; `daysLogged`). `FoodLog.update(entry…)`, `delete(entry) → DeletedEntry`,
  `restore` (same id, numbers, times, Health sample id, and its food while it exists).
- **Today:** rings fill toward each day's own goal in the macro hues (dashed = no food, whether or not trained; faint =
  ahead; the workout disc stays); key "Calories toward goal · Worked out"; header "1 workout · 3 days logged"; AX rows
  add "1,752 of 2,763 cal" / "No food logged". **Fuel card** under the rings: "1,698 cal left" (over: "402 cal over"),
  "of 2,763 today", Eaten / Burned, the bar in macro shares, Protein with "59 g to go" / "Goal reached", Carbs and Fat
  compact; without a goal "1,065 cal eaten" + **Set your goals** (opens Nutrition goals). **Today's log:** a panel per
  meal ("Breakfast · 485 cal", entries "1 jar · P 22 · C 52 · F 9 g" + calories; a nameless entry reads "Manual Add"),
  then today's workouts (caption adds "· 320 cal" when measured). **Edit entry** sheet (Cancel / Save): meal chips,
  servings ±½, per-serving calories / protein / carbs / fat (unchanged fields keep stored values), **Delete Entry** →
  "Deleted Banana" toast with Undo (5 s, the same timer rule as N4).
- **Own decisions (for the morning):** no goal → a logged day's ring reads full in its macro split; Burned shows "0"
  when nothing was measured; edits are explicit (Save), Undo is for delete; Burned = the app's workout calories (N9
  adds Health); every entry is queried (a date-bound @Query cannot follow midnight).
- **New strings (for the user's OK):** "N days logged", "Calories toward goal", "cal left" / "cal over" / "of X today" /
  "cal eaten", "Eaten", "Burned", "g to go", "Goal reached", **"Set your goals"**, "Per serving", "Delete Entry",
  "Deleted <name>", "No food logged", "X of Y cal".
- **Fixture:** `-uiTestFoodDiary` (with `-uiTestFoodSample`): today's breakfast, lunch and a calories-only snack, the
  earlier days of the week; back-dates a `-uiTestPersonalDetails` goal to the week; `-uiTestFoodOver` adds a big dinner.

**Evidence so far:** build exit 0; `FoodDayTests` 6 × 10 = 60/60 (`n5u.xcresult`); `TodayFoodUITests` 6/6 (2 workers,
`n5ui.xcresult`; first run 2/6 — a meal panel's identifier hid its rows', moved to the header; same-minute fixture
entries ordered); captures light/default + dark/AXL looked at (`n5shots/N5-*.png`). Unit plan **1,206 definitions / 1,222 executions, 0
failed** (`n5unit.xcresult`). Regression UI (warm-up, TodayUpNext, LogFoodFlow, NutritionGoals; 2 workers): 23/24
(`n5reg.xcresult`) — the one failure, N4's "2 servings" check read right after the second tap (Codex saw it flake in
N4 round 1 too); now waits up to 5 s; `LogFoodFlowUITests` 5/5 after (`n5reg2.xcresult`).
Verified: the above. Not verified: runtime Reduce Motion, VoiceOver by a person, the full UI suite. Known flaky: N4's
clone keyboard/idle stall (none seen here).

## Comments

**Round 1 (`codex-review-n5.md`): not clear — 1 P2.** Without a goal the fuel card dropped Burned (D71 shows it beside
Eaten either way). Fixed: the no-goal card shows "1,065 cal eaten" with **Burned** beside it (stacked at AX) and Set
your goals under them. The diary fixture adds a measured "Morning Run" today (320 cal). New test
`testBurnedShowsWithAndWithoutAGoalAndIsNeverAdded` (Burned 320 with and without a goal; left + eaten = the goal);
no-goal capture at dark/AXL added. `TodayFoodUITests` **7/7** (`n5ui3.xcresult`, 2 workers); captures looked at
(`n5shots3/`). Codex's follow-up (not a finding): a date-bounded entry query for long histories.

**Round 2 (`codex-review-n5b.md`): clear** — reviewer's Unit 1,206 / 1,222 executions, TodayFoodUITests 7/7 + warm-up
(`/tmp/codex-n5/round2/`). Merged into `main` by the user's standing permission. **For the morning:** the new strings
above, and the own decisions (no-goal rings full; Burned "0" when nothing measured; Undo for delete only).

