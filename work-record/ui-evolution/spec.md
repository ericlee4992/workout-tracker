# UI evolution — saved directions (not implemented)

Status: exploring. **No app code has changed.** Each direction below is a design the user has seen in the
Simulator prototype (`DesignPrototype/`) and chose to keep for later. Implementation happens only after the user picks
a direction and approves tickets (Claude implements, Codex reviews, per AGENTS.md).

Context: the 2026-11-06 impeccable critique of the whole app (25/36; snapshot
`.impeccable/critique/2026-11-07T02-17-03Z__workouttracker-features.md`). The user asked that the project's
ios-design skill not limit this exploration. Off-limits so far: the live set table, the muscle figures, Settings.
Kept: the red Cancel beside minimize (the user's 2026-10-10 choice).

## Direction A — "Floodlight Mono" (saved 2026-11-07: "I like mono. let's save it")

Prototype: commit `743eb54`, tag `design/floodlight-mono-2026-11-07`. Launch `-accent mono`.

- **Colour:** violet removed. One monochrome action: flood `#F4F6F8` on ink in dark, ink `#0B0C0E` on white in light.
  On the ink rest slab the action is flood in both schemes. Kept hues: muscle families, heart-rate pink, destructive
  red, the yellow "New best" highlighter. (Sand `#E6D5BC`/`#6E5A3E` was the alternative shown.)
- **Live workout:** buttons flat (no hard offset shadow). Finish Workout at the bottom (where the rest slab lives;
  rest takes the slot while resting) — the prototype also shows Finish at the top for comparison; not yet decided.
- **Cardio:** Pause | End as two equal buttons with a gap; the end button reads just "End"; after End, the slot
  becomes Finish Workout.
- **Workout tab:** the template done longest ago leads with one Start; Start Lifting / Start Cardio as a quiet pair;
  "Other templates"; New Template… / Ask AI as plain rows; "This week" last.
- **Template detail:** Delete Template… moves into a "…" menu beside Edit; the machine line is hidden when it only
  repeats the exercise name.
- **Finish screen:** new bests first (the best set big, "was …"), then a receipt-style summary (Time · Exercises and
  sets · Volume · Calories active/total · Heart rate avg/max), then View in History / Save as Template. A comparison
  with last time that shows a drop of more than 25 % is hidden.
- **Week strip:** trained days as tinted tiles (no solid slabs), today a solid outline (dashes only mean "not logged
  yet"), one summary sentence; at AX sizes a list of trained days.
- **Large text:** the rest slab is one row.

Open for this direction: Finish top vs bottom; Progress tab and History rows (badge reduction) not yet shown.

## Direction B — "Soft" (saved 2026-11-07: "save the previous design just in case I come back to it")

Prototype: commit `b92c74c`, tag `design/soft-2026-11-07`. Launch `-look soft` (or FLOOD | SOFT in the pill). The
user later judged it too close a copy of the reference ("I didn't mean to copy the design entirely"); kept for
reference only. Direction C (a blend that keeps our identity) is being worked out from independent proposals by
Fable 5.1 and ChatGPT Astra (`work-record/ui-evolution/proposals/`).

The user liked the feel of a calorie/macro tracker's design and plans to add calorie/macro tracking so the app is
all-in-one. Explored in the prototype as a second look (`-look soft`; FLOOD | SOFT in the pill). The style is
borrowed, not the other app's screens or branding; the content and muscle figures are this app's own.

- **Look:** light ground `#F5F5F7` with a faint warm wash at the top; white cards (radius 24) lifted by a wide faint
  shadow, no outlines; SF Pro only (bold titles, semibold figures); Mono action (black pills in light, white in
  dark); quiet macro hues (protein coral, carbs amber, fat blue) only on their small icons and rings; dark variant on
  black with graphite cards.
- **Structure (proposal):** tabs Today · Train · Progress · Profile in a floating capsule, and a separate black **+**
  (Start workout / Log food / Log weight / Scan food). History, Gyms and Exercises move into Profile → Training.
- **Today:** week strip of day rings (calories vs goal; dashed = nothing logged), calories card (eaten / goal, tap
  for "left"), Protein · Carbs · Fat cards with rings, Training (the next template with Start), Today's log (foods
  with calories and macros, and the day's workout with calories burned).
- **Progress:** body weight vs goal with Log weight, weight trend (90D/6M/1Y/All), calories this week vs goal,
  Strength (each lift's best set and change; opens the exercise page).
- **Log food:** All / My foods / My meals / Saved, "Describe what you ate", recently logged with + (adds to Today),
  Manual Add / Voice Log. **Scan food:** camera mock with Scan food / Barcode / Food label and a result to log.
  **Log weight:** a sheet with the figure and ± steps.
- **Workout screens:** Train (Direction A's layout in Soft type), the live workout re-skinned (same set table), the
  finish receipt.

Open: tab structure (is Profile the right home for History/Gyms/Exercises?), the nutrition feature's scope
(database, AI photo estimate via the existing server, barcode), and whether Soft replaces Floodlight or is a theme.

## Direction C — "Blend" (exploring, 2026-11-07)

From two independent proposals (`proposals/fable.md` "Floodlight, daylight"; `proposals/astra.md` "Open Floodlight"),
both briefed to keep our identity and borrow only the reference's feeling. Prototype `-look blend` (FLOOD → SOFT →
BLEND in the pill; the slider icon switches Blend's variants).

- **Kept:** SF Pro Expanded titles and figures, ink / cool-white grounds, Mono, muscle figures, the live set table,
  red Cancel, the finish receipt.
- **Borrowed, in our materials:** air (cards lifted on a soft shadow in light mode only; dark keeps graphite +
  hairline), figure-over-goal (`1,240 /2,288` in Expanded Black), the day at the top (our day tiles; ink = trained, a
  tan underline = food logged), a "+" a thumb away.
- **Refused:** the warm page wash, plain type, smooth icon rings, dashed day circles.
- **Ours, new:** the cardio ring's ticked dial as the one ring type (24 ticks calories, 12 ticks per macro, only type
  inside); nutrition is typographic (P / C / F monograms in Expanded Black) in an earthy family (protein crimson,
  carbs tan, fat slate) that never shares a row with the muscle hues; meals as receipt rows.
- **Variants (the user: "show me both"):** tabs Today · Train · Food · Progress (Fable; Gyms/Exercises/History under
  Train → Library) or Today · Train · Progress · Library (Astra); the + as a black circle opening 2×2 ink slabs
  (Fable) or a labelled "+ Add" bar on Today/Progress opening a list (Astra); macros as ticked dials (Fable) or
  segmented bars (Astra). Food logging: one-tap + with Undo (the user's choice).
- **Screens:** Today (day tiles, calories, macros, Training card, Meals receipt), Food (diary with P/C/F chips, saved
  foods), Library, Progress (Body · Strength · Fuel), Log food (meal chips, search/describe, recent with one-tap +,
  Scan / Manual / Voice), the ink quick add, Train (+ Library section), the live workout (lifted cards in light).

## Direction B, round 2 — Soft as the base (2026-11-07)

The user: "I actually like the cleanliness of SOFT… default to that design (its font, color, box, shape) and develop
to fit our app instead of copying the reference's layout." Kept as they were: **Profile**, **Train**, and Today's
**Training** card and **Today's log**. Changed:

- **Today, top (redesigned, ours):** *This week* — one column per day around a baseline: training rises above it
  (a bar in the muscle families trained, height = minutes), food hangs below it (calories against the goal, a tick
  at goal depth); the date sits on a Mono capsule for today; one summary line. *Fuel card* — "1,048 cal left" as the
  headline, Eaten / Burned beside it, one bar toward the goal split by the macros' calorie shares, Protein leading
  with "47 g to go", Carbs and Fat compact. Replaces the reference-like day circles, calorie ring and macro rings.
- **Progress:** the shipped model (pinned charts + Add Chart) with anything pinnable: exercises (best set), workouts
  per week, training volume, running distance, body weight, weight trend, calories, protein, macros. Each card: title,
  what it measures, the figure, its change, a chart; "…" to Move Up / Remove. Add Chart: Training · Body · Nutrition.
- **Fifth tab:** Gyms (default) or Exercises, switchable in the pill (slider icon). History stays under Profile.

## Direction B, round 3 — tabs (2026-11-07)

The user: "History tab is now gone. I want to keep it… the + button is only needed for logging food… at most 5
tabs." Both layouts built (the user: "build both"; Soft's slider in the pill switches them):

- **A (recommended):** Today · Train · History · Progress · Profile.
- **B:** Today · Train · Food · History · Progress; Profile behind an avatar at the top of Today.
- **Both:** Train's top bar carries **Templates | Gyms | Exercises** (Gyms and Exercises are no longer tabs; settings
  move to Profile). **History** is a daily journal: each day's workouts (with their muscle families) and a food line
  ("1,240 cal eaten · 1,048 under goal"), plus the calendar. The floating + is gone: a black **Log food** pill sits
  above the tab bar only on Today (and on Food in B); each meal on Food has its own +.
- Open: Profile still lists History, Gyms and Exercises under "Training" (kept as the user asked to keep Profile the
  same; in layout A they duplicate the tabs and could go).
