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

## Direction B — "Soft" (exploring, 2026-11-07)

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
