# N16 — Pick a day on Today: see it and log food to it

Type: feature
Status: **built — in Codex review** (2026-11-20; the user approved the prototype without the Back to Today strip)
Implementer: Claude; Reviewer: Codex (a Paseo Codex agent in this workspace), to "clear".
Branch: `ericlee4992/today-pick-day` off `main` `cb364043` (Paseo worktree `~/.paseo/worktrees/1qmeipq9/today-pick-day`).
Decision: **D92** (approved 2026-11-20). Builds on D68 (Today), D70 (dated goals), D77 (Up next), N5 (Today's food), N10 (a day's
food page, `DayFoodView`), D82/D83 (scans).

## The ask (the user, 2026-11-20)

"next update for the app: being able to select the days on the today page so that you can go back and edit your food
logging"

## What exists already

- **Editing a past day already works, but it's hard to reach:** History's food line (and a food chart's day) opens
  `DayFoodView` (N10). That page shows the day's fuel card against that day's goal and its food by meal, with edit,
  delete and Undo. What's missing: reaching a day from Today, and **adding** food to a past day. Every log path writes
  at now (`FoodLog.log(at: .now)`), apart from a library photo, which keeps its own date (D83(9)).
- Today's rings ("This week", `TodayWeekRings`) are not buttons. The week is the locale's calendar week (Sunday first
  here), so on the week's first day yesterday is in last week.
- A logged row shows no time, and the edit sheet changes servings, meal and numbers only (no date or time).

## The proposal (D92, proposed)

1. **Tap a ring to pick a day.** Past days and today are buttons; future days are not. The picked day's date label is
   filled black. Today, when another day is picked, keeps an **outline**, so the two differ by shape and not only by
   colour. At AccessibilityL each day is a row: the picked row is shaded with a check, and today's row says "Today".
2. **Today becomes that day** (option A below). The large title reads "Tuesday" over "November 17, 2026", and the inline
   title reads "Tuesday, Nov 17". The fuel card shows that day against **its own goal** (D70), reads "cal under … of N
   goal" (as N10's page does), and counts Burned from that day's workouts only (Health's active energy is read for
   today only, N9b). "Tuesday's log" lists the day's food by meal (tap to edit, delete with Undo) and the day's
   workouts. **Up next is hidden** on a past day because it belongs to today; a running workout's **Resume stays** on
   every day. Pending scan cards show on today only.
3. **The pill logs to that day:** "+ Log to Tuesday". Log food's title gets a "Tuesday, Nov 17" line, and everything
   logged from there (a recent food's +, a selected food, a meal, Manual Add, an online result) lands on that day.
   **The time is the meal's usual time:** Breakfast 8:00, Lunch 12:30, Snacks 3:30 PM, Dinner 6:30 PM. Rows show no
   time, so the time only orders entries within a meal and is the time Apple Health receives. The meal chip is still
   preset by the current time of day.
4. **A way back:** a black "Today" button beside the past day's title (option A), or a strip under the week ("Showing
   Tuesday, Nov 17 · Back to Today", option B). Tapping today's ring also goes back.
5. **How far back:** this week only, or earlier weeks too (option B). Earlier weeks use the header's ‹ › and a
   horizontal swipe on the week. The title becomes "Last week", then "Nov 1 – 7". Moving a week picks the same weekday
   in that week, never past today. **Recommendation: earlier weeks.** With this week only, Sunday's yesterday is out of
   reach, and fixing yesterday is the most common case.
6. **When the pick resets (proposed, not in the prototype):** the pick survives tab switches. Leaving the app and
   coming back on another calendar day, or after an hour away, returns to today. If "today" is shown, it follows the
   clock past midnight (as Today does now). A picked past day stays picked across midnight.
7. **Scan food on a past day (open):** in the prototype the camera is hidden on a past day, and so are Log food's
   camera and its "Estimate …" row, because those paths log at now. Proposed for the real build: show them, and log a
   camera photo or a description to the picked day at the meal's time. A **library photo keeps its own date** (D83(9))
   unless the user picked a day, in which case the picked day wins. That is a change to D83(9), so it is listed for the
   user.

### Options in the prototype (the orange switcher)

| Question | A (proposed first) | B |
|---|---|---|
| Tapping a day | **Today shows the day** (above) | Opens the day's page (`DayFoodView`, N10's page) with a "Log to Tuesday" pill; Today itself stays on today |
| The way back | **"Today" button** by the title | "Back to Today" strip under the week |
| How far back | This week only | **Earlier weeks** (‹ › and swipe) — recommended |

## Prototype (built 2026-11-20)

Built in the app itself (N13's and machine-settings 01's precedent), so the approved views become the real ones:

- **Views to keep** (with defaulted parameters, so Today is unchanged without the flag): `TodayWeekRings` gains
  `title`, `selected`, `onSelect`, `onPreviousWeek` / `onNextWeek` (with `onSelect` nil the rings are not buttons and
  the panel keeps its `todayWeek` id as before), and `todayDay.<yyyy-MM-dd>` ids per day. `LogFoodPill` gains `title`.
  `TodayView` gets the past-day layout (title, fuel card `isToday`, Burned, Training, the log's header, empty line and
  scans, the pill), all keyed on `shownDay` (`dayPick?.selectedDay ?? now`).
- **`WorkoutTracker/Features/Today/TodayDayPrototype.swift`: PROTOTYPE, throwaway.** The pick state, the week math for
  earlier weeks, logging at the picked day, the seed, the switcher, the strip and the Today button. The hooks are each
  marked `PROTOTYPE (nutrition 16)` and do nothing without the flag: `TodayView` (state, switcher, the day page's
  destination), `DayFoodView` (the Log pill), `LogFoodView` (subtitle; camera and Estimate hidden on a past day; three
  log calls), `SelectedFoodView` (two log calls), `SelectedMealView` (one), `WorkoutTrackerApp.prepare` (the seed).
- **`WorkoutTrackerUITests/TodayDayPrototypeUITests.swift`: PROTOTYPE, throwaway**, removed with the file above.
- **Sample world:** the food diary (this week's Sunday–Thursday logged, today's breakfast, lunch and snack plus a
  320-cal run) and the design sample's workouts. The seed adds **three earlier weeks of food**, with one day in five
  empty (the dashed ring), and back-dates the goal before them. Logging really writes to the sample store, which is
  reset on every launch.

**Run:** `xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker -destination 'platform=iOS
Simulator,id=47D21838-69A6-4BCB-AE90-B0D9C0AAA70B' -derivedDataPath build/dd-prototype build`. Install
`build/dd-prototype/Build/Products/Debug-iphonesimulator/WorkoutTracker.app` on WT-iPhone27 and launch it with
`-uiTestReset -uiTestDesignSample -uiTestFoodSample -uiTestFoodDiary -uiTestPersonalDetails -todayPickDayPrototype`.
The orange "Prototype · …" capsule switches the three options and Appearance. Capture-only arguments:
`-todayPickDayPrototypeDay <days back>` picks a day, `-todayPickDayPrototypePage <days back>` opens a day's page,
`-todayPickDayPrototypeOpens page`, `-todayPickDayPrototypeBack strip`, `-todayPickDayPrototypeRange earlier`, and
`-todayPickDayPrototypeCapture` hides the switcher.

**Captures:** [`../captures/16-prototype/`](../captures/16-prototype/) contains `0-today`, `1-past-day` (A: Today
button), `2-strip` (B), `3-last-week` (earlier weeks) and `4-day-page` (B: the day's page), each in light/dark ×
default/AXL (`<name>-<light|dark>-<default|axl>.png`), plus one contact sheet per mode (`sheet-*.png`). The two
tapped-flow shots from the UI test are `5-log-food-to-tuesday-light-default` and `6-logged-to-tuesday-light-default`.

### Verification (prototype scope: build, focused UI test, captures)

**Verified:**
- `xcodebuild build` exited 0 (WT-iPhone27, iOS 27; `build/prototype-build.log`).
- `TodayDayPrototypeUITests` passed 3/3 (exit 0, `build/results/ntd-proto.xcresult`; real taps):
  - pick a past day: the title, the Today button, "Log to <day>", no scan and no Up next;
  - log Banana from Log food, which shows the day's subtitle and no camera: Banana appears on that day, and today's
    Banana count is unchanged;
  - back to Today: "Log food" and the camera are back;
  - earlier weeks: next week is disabled on this week, ‹ goes to "Last week" and picks the same weekday, a swipe goes
    further back, Back to Today returns;
  - the day-page option: "Log to <day>" on the page.
- The 20 captures were looked at: the selection marks, the strip, last week, the day page, and AXL rows with the check.

**Not verified:** no unit tests (prototype). `scripts/sim-ui.sh` snapshots worked, but its taps did nothing on WT-iPhone27
this session: a Train tab tap also did nothing, and restarting the daemon didn't help. The UI test drove the taps
instead.

**Known:**
- An earlier version hung on opening the day page (a SwiftUI navigation update loop: an
  `isPresented` destination whose content read the observable). It now uses `navigationDestination(item:)`, and the
  test passes.
- At AccessibilityL the seven day rows fill the first screen, so a past day's content is below them.
- The prototype back-dates the entry's `createdAt` and the food's "last used" along with `loggedAt` (see below).

## Questions for the user (round 1)

1. Tapping a day: Today becomes that day (A) or the day's page (B)? 2. The way back: Today button or strip? 3. This
week or earlier weeks? 4. Scan on a past day, and a library photo → the picked day? 5. The meal-time rule? 6. (Out of
scope) moving an entry to another day.

## The user's answers (2026-11-20)

"For the Log food and scan button, i just want them to stay the same across the days. 1. Today turns into that day
2. Back to Today 3. Earlier weeks 4. Yes, go the picked day 5. Yes. Again, build the prototype so i can check"

- **Log food and the camera look the same on every day** ("Log food", camera beside it), and log to the day shown.
  (Log food's screen keeps its "Tuesday, Nov 17" line under the title, so it is clear where a food goes.)
- 1 → **Today turns into the day** (A). 2 → **the "Back to Today" strip** under the week (no Today button by the title).
  3 → **earlier weeks** (‹ › and swipe). 4 → **scans log to the picked day** — camera photo, label, Estimate, Manual
  Add from a scan, the barcode's food, and a **library photo too (the picked day wins over its own date; amends
  D83(9))**. 5 → **the meal's usual time** (8:00 / 12:30 / 3:30 PM / 6:30 PM).

### 2026-11-20 — prototype round 2

- The switcher now has Appearance only (the options are decided); the day-page option and the Today button are gone
  (`DayFoodView`'s hook removed; `LogFoodPill` back to its original form).
- Log food's camera and Estimate are shown on a past day again; the scan paths log to the picked day through two more
  marked hooks: `FoodScanFlow` (a meal photo — camera or library — and a label) and `FoodScanQueue.startDescribe`.
  A past day lists its own scans in flight (Today lists today's, as before).
- **Run:** as above, adding `-uiTestTerra` so scans are answered on the phone (the fixture's drawn meal for the
  shutter and the library): `-uiTestReset -uiTestDesignSample -uiTestFoodSample -uiTestFoodDiary
  -uiTestPersonalDetails -uiTestTerra -todayPickDayPrototype`.
- **Captures** (replacing round 1's): [`../captures/16-prototype/`](../captures/16-prototype/) — `0-today`,
  `1-past-day`, `2-last-week` in light/dark × default/AXL; from the UI test (light, default):
  `3-log-food-to-tuesday`, `4-logged-to-tuesday`, `5-scan-logged-to-tuesday`; a sheet per mode.

**Verified:** `xcodebuild build` exit 0; `TodayDayPrototypeUITests` 3/3 (exit 0, `build/results/ntd-proto2.xcresult`,
real taps): pick a past day (title, strip, camera kept, no Up next) → Log food shows the day and its camera → Banana
logged to that day, today unchanged; on a past day with `-uiTestTerra` a camera photo **and** a library photo each log
"Poke bowl" to that day and nothing to today; earlier weeks (next disabled on this week, ‹ → "Last week" with the same
weekday picked, swipe further back, Back to Today). The 15 captures looked at.
**Not verified:** a label scan and Estimate on a past day were not driven (same hook pattern, built); no unit tests
(prototype). **Known:** a scan logged to a past day also leaves its "logged earlier" card on today's log (D83's
existing behaviour for an earlier-day photo) — the real build should drop it when the user picked that day; a label's
time follows the meal it opened with, not one changed on the label screen.

## Real build (after approval)

- **Stored format: no change expected.** `FoodEntry.loggedAt` already exists and decides the day (`NutritionMath.entries(
  _:on:)`). The pick is view state (in memory, or a UserDefaults view preference if it should survive relaunch). So:
  no migration and no Gate S for this ticket.
- **Log at the picked day without back-dating the rest:** `FoodLog.log(at:)` sets `loggedAt`, `createdAt` and the
  food's / meal's `lastUsedAt` to the same date. The real build needs a separate logged-at parameter: `createdAt` and
  `lastUsedAt` stay now, or Recently logged runs backwards. This is a "stale value overwrites newer" defect class.
- **Route every path:** Log food's three calls, SelectedFood (2), SelectedMeal, Manual Add (also from a scan's "Add
  manually"), the online result, `FoodScanQueue` (photo — camera and library — label, describe) and the barcode flow;
  the picked day overrides a library photo's own date (the user, amends D83(9)).
  Pass the day down explicitly instead of through a global, so Log food opened from History's page or Today can't
  read a stale day (here, each pill sets it on tap).
- **Apple Health (D74):** check that `HealthNutritionSync` writes a back-dated entry's sample on its own day and
  follows its edits and deletes.
- **Day boundary:** the reset rule above (6), plus `refreshingNow`, which already keeps "today" current. Test a pick
  across midnight and across a week rollover.
- **Tests:** unit tests for the week offset, the meal times, logging to a day (loggedAt on that day, createdAt and
  lastUsedAt at now) and the reset rule. UI tests for pick → log → back, earlier weeks, and AXL. Remove the prototype
  file, its hooks and its UI test.
- Codex review rounds per the `review-round` skill (a new Paseo Codex agent in this workspace).

## The user's go (2026-11-20)

"lets just get rid of back to today button. people can just click the day. start building" — no Back to Today strip
or button: **today's ring is the way back**. Prototype kept at tag `design/today-pick-day-prototype` (`2bb4bdf1`).

### 2026-11-20 — the real build

- **Prototype removed:** `TodayDayPrototype.swift`, its hooks and `TodayDayPrototypeUITests`; the prototype captures
  are replaced by the real ones.
- **Domain:** `Domain/TodayDayPick.swift` — `TodayDayPick` (the picked day and the shown week; `pick`, `moveWeek`,
  `shownDay`/`showsPastDay`/`logDay`/`shownWeek`, `resetsOnReturn`, `weekTitle`) and `FoodLogDay` (the meal's usual
  time on a picked past day; nil for none or today; `title`). `WeekSummaryMath.summary(…weekOf:)` shows an earlier week
  (its days neither today nor ahead; only that week and the one before read). `FoodLog.log` (food, meal), `logManual`
  and `FoodScan.logLabel` take `loggedAt:` — **only the entry's `loggedAt` moves; `createdAt` and the food's / meal's
  `lastUsedAt` stay now**, so Recently logged keeps its order.
- **The day is passed explicitly** (no shared state): Today snapshots `pick.logDay` into `logDay` when Log food or the
  camera is tapped → `LogFoodView(day:)` (its subtitle, the +, search results, Estimate) → `SelectedFoodView(day:)`,
  `SelectedMealView(day:)`, `ManualAddView(day:)`, `FoodScanFlow(day:)` (meal photo — camera and library, the picked
  day winning over a library photo's date — the label via `LabelFoodView(day:)`, the barcode's `SelectedFoodView`), and
  Today's Manual Add from a scan. `FoodScanQueue` carries `pickedDay` (kept on retry): a picked day's log lists its
  own scans; today lists every scan as before (so a failed one sent from a picked day is never out of sight); a scan
  logged to its picked day leaves no "logged earlier" card.
- **Today:** `@State pick` (kept across tab switches); back to today when the app returns from the background on
  another day or after an hour (`scenePhase`); the rings follow a picked day's week, so a day picked this week stays
  in view when the screen is left open into the next. Title, inline title, fuel card (`isToday: false`, Burned from
  the day's workouts), Training (Resume only), "Tuesday's log" / "Nothing logged on Tuesday.", scans. The pill and
  the camera are unchanged.
- **No stored-format change:** no model or schema edit (`loggedAt` exists). No migration, no Gate S.
- **Apple Health (D74):** `HealthNutritionSync.writeFood` reconciles every entry at its own `loggedAt` with no date
  window, so a back-dated entry is written on its day and follows its edits and deletes — no change needed.
- **Self-check fixes before review:** a failed scan from a picked day was only on that day (errors read as absence) →
  today lists it too; a day picked this week fell out of the rings at a week's end → the rings follow the picked day.
- **README:** Food logging gains "Pick a day"; `docs/readme/today.png` retaken (the week now has ‹ ›).
- **Tests:** `WorkoutTrackerTests/TodayDayPickTests.swift` (15: picking, today's ring back, days ahead, midnight, a
  pick no longer past, week moves and titles, an earlier week's summary, the week rollover, the reset rule, the meal
  times, logging food / meal / Manual Add / label to a picked day with `createdAt` and "last used" at now, unchanged
  without a day). `WorkoutTrackerUITests/TodayPickDayUITests.swift` (6: pick → log → today's ring back, a day ahead is
  no button, camera and library scans to the picked day with nothing on today and no leftover card, earlier weeks,
  captures light Default and dark AccessibilityL); added to the TodayTrain plan (`scripts/test-plans.py`).
- **Captures:** [`../captures/16/`](../captures/16/) — `1-today`, `2-past-day`, `3-past-day-log`, `4-log-food`,
  `5-last-week` in light Default and dark AccessibilityL, and a sheet for each.
- **Known (by design):** an earlier day before any nutrition goal shows "Set your goals" (D70's dated goals, as N10's
  day page).


### Verification (the real build, 2026-11-20)

Scope (DEVELOPMENT → Verification scope, "Ticket done" for a new feature on Today and Log food, touching the scan
flow and a Domain week summary with several callers): the Unit plan + the ticket's area plan, TodayTrain (Today,
Log food, Scan food, barcode, Korean food, Up next, templates — it includes the new class). Captures of the changed
screens light Default and dark AccessibilityL (from `TodayPickDayUITests`).

```
Verified: Unit plan — 1344/1344, exit 0, build/results/n16-unitplan.xcresult
Verified: TodayTrain plan — 86/86 (0 skipped), exit 0, build/results/n16-todaytrain.xcresult (~50 min)
Verified: focused — unit suites 65/65 (n16-unit.xcresult); TodayPickDayUITests 6/6 (n16-ui.xcresult); build exit 0
Not verified: on a phone; Apple Health writing a back-dated entry (code read: no date window, unchanged); a label
  scan and Estimate on a picked day driven in a UI test (unit-tested at FoodScan.logLabel; Estimate by code read);
  the reset after an hour away / on another day in a UI test (unit-tested rule; the scenePhase hook by code read)
Known flaky: none seen
```
