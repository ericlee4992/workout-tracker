# Stacked — Open Floodlight

## The idea

Stacked becomes a training log with room for the rest of your day. Keep its broad, emphatic typography, ink-and-white contrast, anatomical figures and precise logging instruments; give them more open ground and fewer enclosing boxes. Borrow the reference’s ease through spacing, quiet secondary information and gentle light-mode elevation. Training remains the first recognizable object on Today, while nutrition becomes a compact, readable ledger beneath it. Compared with today’s app, the screen feels less densely armored. Compared with the reference, it feels athletic, typographic and specific to your equipment—not like a calorie dashboard with workouts appended. This evolves the saved Mono direction; it does not introduce a separate Soft theme.

## Keep / borrow / refuse

| Keep | Borrow | Refuse or adapt |
|---|---|---|
| Expanded Black titles; Expanded Heavy figures | More breathing room around the main number | Standard-width typography everywhere, as in `soft-2.png` |
| Muscle figures, unchanged in shape and family colours | Clear separation of content groups | Tiny anatomy used as decoration beneath a dominant calorie dashboard |
| Mono commands and flat live controls from `saved-mono-direction-1.png` | Reference’s calm secondary controls | Pill shapes on every object; a separate black plus bolted to navigation |
| Segmented training rings and receipt summary | Big actual value, quieter goal from `ref-5745.png` | Four food rings, day circles and carousel dots repeating the same shape |
| Ink dark mode and cool near-white light mode | Soft elevation for selected light surfaces | Warm atmospheric wash; shadows around every row |
| Live table, PREVIOUS, draft dashes, check circles, yellow best marker | Easier scanning outside the table | Any rearrangement of the table to fit the new aesthetic |

## Tokens

Values below are proposal tokens, not measured implementation results.

| Role | Light | Dark |
|---|---|---|
| Ground | `#F2F3F5` | `#060708` |
| Surface | `#FFFFFF` | `#181A1E` |
| Field / raised surface | `#E9ECF0` | `#24272D` |
| Primary ink | `#0B0C0E` | `#F4F6F8` |
| Secondary ink | `#555A63` | `#ADB3BD` |
| Divider | `#DCE0E5` | `#353A42` |
| Action / on-action | `#0B0C0E` / `#FFFFFF` | `#F4F6F8` / `#0B0C0E` |
| Destructive | `#B72F20` | `#FF7565` |
| Heart rate | `#C41D58` | `#FF4F86` |
| Protein / carbs / fat | `#795445` / `#71602D` / `#50687D` | `#C8A08D` / `#C7B677` / `#9DB3C7` |

Macro colours are muted clay, grain and slate, confined to small markers and progress rails. Names and numbers stay primary ink. Family colours remain the existing, brighter anatomical palette, including their existing light variants. Never assign a nutrient to a muscle, tint a body with macros, or put both palettes into one ring. Yellow remains the live “New best” highlighter; violet does not return as an action colour.

| Type role | Face, width, weight; default scale |
|---|---|
| Screen title | SF Pro Expanded Black; Large Title, 34 pt |
| Featured workout / section | SF Pro Expanded Heavy; Title 2, 22 pt / Headline, 17 pt |
| Hero figure | SF Pro Expanded Heavy, tabular digits; 40 pt, scaling with Large Title |
| Supporting figure | SF Pro Expanded Heavy, tabular digits; Title 2, 22 pt |
| Body / buttons | SF Pro standard; Regular / Semibold, 17 pt |
| Label / goal / unit | SF Pro standard Medium; 13–15 pt, scaling with text size |

Use 20 pt screen margins; 24 pt between sections; 16 pt group padding; 8 pt between related lines; 4 pt number-to-unit gap. Controls have at least 48 pt hit areas, primary actions at least 56 pt height. Radii: 18 pt content surfaces, 12 pt fields and rectangular buttons; capsules reserved for brief toolbar actions and native navigation. Preserve live-table geometry.

Light: only the featured workout surface gets a shadow, black at 5%, y=6, blur=20, no outline. Lists use internal 1 pt dividers and no shadow. Dark: no shadows; graphite establishes groups, with a 1 pt divider-colour edge only where surfaces would merge. The rest slab stays black with flood-white controls in both modes.

## Three signatures

1. **The training masthead.** A large Expanded workout name with the unchanged muscle figures at useful size underneath. It sits directly on the ground on Today; Train encloses it with its actionable details. Anatomy remains an identifier, not wallpaper.
2. **Measured marks.** Preserve the broken-ring geometry of `today-app-cardio.png`. Nutrition uses straight segmented rails with the same square-ended rhythm, each explicitly labelled with grams and goal. They share a drawing language without pretending calories are sets. Rails stop at the goal; an excess stays visible numerically, without a red failure state.
3. **The receipt.** Right-aligned values, left-aligned names, restrained separators: extend the finish receipt in `saved-mono-direction-2.png` to meal review and daily totals. Stacked records what happened rather than awarding generic badges.

## Screens, top to bottom

### Today

`Today + date/settings → compact weekday strip → training masthead → nutrition ledger → today's entries → navigation`

The largest content is **Push Day**, with muscle figures, gym, and a compact Start command. No exercise inventory here; tap the name for the template. During a session this becomes Resume with elapsed time. After completion it becomes the saved workout and duration; on a rest day it quietly offers Train. This block stays shallow enough to reveal nutrition at default size.

Weekdays use plain dates and tiny square training marks, with an underline for the selected date. They select a day, not score dietary compliance. No seven miniature rings.

Nutrition is one white/graphite surface: `1,240 / 2,288 kcal eaten`, then three horizontal rows for Protein, Carbs and Fat with amounts and rails; Log food at its foot. Training remains the larger heading. With no food entries, say “No food logged”; do not present missing logging as confirmed zero intake. The day’s workout and meal entries follow as one chronological list. Burned calories remain labelled separately from food intake.

### Train

`Train + History → gym selector → next template surface → Start Lifting / Start Cardio → other templates → this week's muscle tally`

Keep the strong next-workout lead in `saved-mono-direction-1.png`. One filled Start inside it; the other start options are quiet, equally sized controls. Other templates become full-width rows with anatomy, name and last-used date. No competing tile grid. Empty state leads with Start Lifting and a secondary Create template action.

### Live workout

`minimize + red Cancel / session title → elapsed time and sets → compact sensor strip → existing exercise tables → rest accessory`

Use Mono typography and skin from `saved-mono-direction-2.png`. Preserve every table column, marker and field. Remove decorative shadows from surrounding controls. Keep Cancel written out beside minimize; let the title occupy a second line when necessary. Place Finish in the trailing toolbar, spatially separate from Cancel and consistently available while resting. The black bottom slab belongs to rest, retaining +15s and Skip. Cardio keeps the segmented timer and separated, equal-sized Pause / End controls from saved Mono. No nutrition prompts during a session.

### Finish

`saved confirmation + family ring → new bests → receipt → View in History / Save as Template`

Follow `saved-mono-direction-2.png`: best set is the hero; receipt lists time, exercises/sets, volume, active/total calories, average/maximum heart rate. Without a best, duration leads. No forced celebration for incomplete data and no meal suggestion between finishing and dismissal.

### Progress

`Progress → Strength / Body / Nutrition selector → selected summary and chart → supporting records`

Default to Strength, preserving existing exercise charts from `today-app-exercise-progress.png`; remember the chosen section. Body leads with latest weight and measurement date, trend below, Log weight adjacent. Nutrition leads with average logged intake, coverage such as “5 days logged,” then daily bars and a goal line. Missing days are gaps, not zero bars. Use the calm chart framing in `ref-5747.png`, without its repeated change cards or predicted goal date. Do not overlay strength and weight on incompatible axes.

### Log food

`date + meal → search → Recent / Saved / Meals → food rows → review receipt → Add food`

Borrow the immediate search access in `ref-5756.png`. Each row shows food, serving and calories; selecting it opens editable quantity and macros. Manual entry is always available. Add commits the reviewed serving; confirmation offers Undo. Avoid ambiguous instant additions from a tiny plus. Keep the commit reachable above the keyboard.

### Scan food

`Close + Scan food → camera → Food / Barcode / Label → shutter → review receipt`

Borrow the practical camera hierarchy of `ref-5755.png`, using a dark solid control shelf and square corner guides. A photo estimate is labelled Estimated; identified items, quantities and macros are editable before Add. Failed recognition or unavailable camera offers manual entry. Scanner modes describe the proposed experience, not a claim that recognition services exist.

### Quick add and navigation

Four tabs: **Today · Train · Progress · Library**. History is a named Train header destination and reachable from Today’s workout entries. Library contains Gyms, Exercises, Foods and Meals; gym selection also offers Manage gyms. Settings retains its existing gear entry and contents. Do not bury training tools in Profile as `soft-1.png` suggests.

A labelled **+ Add** accessory sits above the tab bar on Today and Progress, opening four full-width sheet rows: Log food, Scan food, Log weight, Start workout. It is secondary on Today while Start leads. Train already has explicit commands. This avoids copying the detached circle and 2×2 launcher in `ref-5753.png`.

## Dark mode, large text and risks

Dark mode retains genuine ink ground and bounded graphite groups; softness comes from spacing, not gray fog. At AccessibilityL, macro rows put the amount beneath the name, goals wrap, date selection becomes a compact date control, receipt values stack, and toolbar titles get their own line. Preserve the table’s existing accessibility layout. The permission overlay in `today-app-live-workout.png` means that capture cannot validate the whole live screen. This proposal has no new rendered accessibility proof.

The copying risk is cumulative: warm wash plus rounded day cells plus macro cards recreates the reference even with Expanded type. Reject that combination. The blandness risk is removing anatomy and making every heading standard SF; keep the masthead and measured marks visible. The density risk is importing the full workout and food diary onto Today; summaries navigate to detail. Before implementation, compare actual light/dark and AccessibilityL mockups using identical data. Check new colour contrast and keyboard reachability; these remain design validation tasks.

Status: done
