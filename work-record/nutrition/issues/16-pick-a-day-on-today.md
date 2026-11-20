# N16 — Pick a day on Today: see it and log food to it

Type: feature
Status: **prototype, waiting for the user** (2026-11-20)
Implementer: Claude; Reviewer: Codex (a Paseo Codex agent in this workspace), to "clear".
Branch: `ericlee4992/today-pick-day` off `main` `cb364043` (Paseo worktree `~/.paseo/worktrees/1qmeipq9/today-pick-day`).
Decision: **D92** (proposed). Builds on D68 (Today), D70 (dated goals), D77 (Up next), N5 (Today's food), N10 (a day's
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

## Questions for the user

1. **Tapping a day:** should Today become that day (A), or should it open the day's page (B)?
2. **The way back:** a "Today" button by the title (A), or a strip under the week (B)?
3. **How far back:** earlier weeks with ‹ › and swipe (recommended, because of Sunday's yesterday), or this week only?
4. **Scan on a past day:** show the camera and Estimate there, and log to the picked day? And should a library photo
   then take the picked day over its own date (D83(9))?
5. Is the meal's usual time (8:00 / 12:30 / 3:30 PM / 6:30 PM) fine, or should Log food get a time row on a past day?
6. Out of scope unless asked: moving an existing entry to another day (the edit sheet has no date).

## Real build (after approval)

- **Stored format: no change expected.** `FoodEntry.loggedAt` already exists and decides the day (`NutritionMath.entries(
  _:on:)`). The pick is view state (in memory, or a UserDefaults view preference if it should survive relaunch). So:
  no migration and no Gate S for this ticket.
- **Log at the picked day without back-dating the rest:** `FoodLog.log(at:)` sets `loggedAt`, `createdAt` and the
  food's / meal's `lastUsedAt` to the same date. The real build needs a separate logged-at parameter: `createdAt` and
  `lastUsedAt` stay now, or Recently logged runs backwards. This is a "stale value overwrites newer" defect class.
- **Route every path:** Log food's three calls, SelectedFood (2), SelectedMeal, Manual Add (also from a scan's "Add
  manually"), the online result, and, if Q4 says so, `FoodScanQueue` (photo, label, describe) and the barcode flow.
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
