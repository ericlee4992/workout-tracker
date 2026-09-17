Design task (not a review): the ACTIVE WORKOUT screen's second pass — ticket 16. Read, in order:
.claude/skills/ios-design/SKILL.md and REFERENCE.md (the brief, rules, tokens, the tells);
work-record/ui-redesign/issues/16-active-workout-second-pass.md (Step 1's job/state sentences —
use them as given; Step 2/3 are Claude's three directions, which the user has seen);
the current screen as built (your own ticket-02 design, on the phone):
work-record/ui-redesign/screenshots/11/02-active-workout.png and
work-record/ui-redesign/screenshots/11/02-active-workout-axl-2.png, source
WorkoutTracker/Features/ActiveWorkout/{ActiveWorkoutView,ExerciseEntryCard,RestTimerBar,HeartRateBar}.swift;
and Claude's directions: work-record/ui-redesign/canvas/active/active-workout-directions.png
(build.py and the .dc.html files beside it show the phone-artboard format and the fixture).

The user's reaction to Claude's three: "Out of those, I just like current design the most. Can
you also have Codex design as well, just so I can compare?" So: design 2–3 directions of your own
for the same screen. At least one should EVOLVE the current design (the user likes it) — fix its
hierarchy problems rather than restructure: today the elapsed-time hero, the amber Add Exercise
button, the amber completion ring, the amber Skip and the set ticks all compete; the rule is one
dominant treatment per state (logging: the current set; resting: the rest countdown). One may be
bolder. Known bug to design out: the rest bar's "Skip" and "+15s" wrap mid-word at AccessibilityL.
Keep every visible string and control that exists (Cancel, the editable title, Finish, minimize,
gym, elapsed, sets done, heart rate + zone + calories, machine row, PREVIOUS/WEIGHT/REPS columns,
set rows with unit chip and completion, Add Set, Add Exercise, Add by Machine, the rest timer
with +15s and Skip) — the design adds shape, colour and motion, never words.

Deliverable: phone artboards, 390 × 844, one .dc.html per direction (and one for the resting
state of your leading direction), in work-record/ui-redesign/canvas/active-codex/, named
CodexA.dc.html, CodexB.dc.html (CodexC.dc.html optional), CodexARest.dc.html. Format: copy the
shell of work-record/ui-redesign/canvas/active/DirectionA.dc.html exactly (the <head> with
<script src="./support.js">, <x-dc>, <helmet><style>…</style></helmet>, then <div class="phone">);
inline the CSS you need (start from _common.css, which is beside your folder); NO fake status
bar, NO fake keyboard; SF Symbol stand-ins as small inline SVGs; the app's tokens only (ink
#0B0D10, card #171B21, elevated #222832, fill #2B323C, text #F6F3EC, secondary #B5B9C2, amber
#FFB45E with #15110B on it, danger #FF5E7A, zone colours as in Features/Design/ZoneColors.swift).
Same fixture as Claude's: Iron Temple, 12 min, Seated Chest Press on "Chest Press · Life Fitness
Insignia Series" with set 1 done 60 lb × 10, set 2 current, set 3 planned, then Lat Pulldown;
heart rate 128 bpm, zone 3, 142 cal; rest 1:58 running in the resting boards.
Also write work-record/ui-redesign/canvas/active-codex/README.md: for each direction, its one-line
idea, what steps down and what is bold in each state, and its main trade-off (an honest one).
Render check: /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome --headless=new
--disable-gpu --hide-scrollbars --force-device-scale-factor=2 --window-size=390,844
--screenshot=<png> file://<a plain html copy of the artboard body with the same CSS> — look at
each PNG before you finish (Claude's build.py shows the extraction). Do NOT modify app source;
do not run xcodebuild or simctl. When finished, write
work-record/ui-redesign/canvas/active-codex/DONE.md (one paragraph).
