# User taste brief — every recorded design preference, choice, rejection and complaint

Scope: the user's own words and choices about looks, layout, wording, colour, icons, density
and interaction, gathered from `work-record/`, `docs/` (DECISIONS, SPEC, archive handoffs) and
the user's auto-memory. Paths are relative to the repo root
`/Users/ericlee06/orca/projects/Health App/` unless absolute. "Q" = verbatim quote as recorded;
"P" = the record's paraphrase (no verbatim quote exists). Only recorded facts appear here. Where
a line is an agent/reviewer finding rather than the user's view, it is labelled as such.

Context facts the designer needs:

- The user's phone is an **iPhone 15 Pro Max (iPhone16,2), 430 pt wide**
  (`work-record/cardio/claude-compact-start-outdoor-review.md:140-145`;
  `work-record/cardio/issues/05-compact-start-and-outdoor.md:66-67`). The test simulator is 402 pt.
- The user is a single person using the app one-handed at the gym. They report plainly from the
  device and react to real captures, not descriptions.
- Today's request (2026-09-24) removes the constraints on theme: "Feel free to completely change
  from current theme." Everything below records what they chose *before* that request. It is
  evidence of taste, not a list of locked constraints.

---

## 1. Chronological log

### Before the visual redesign: how they work, and interaction taste

| Date | What the user said or chose | Source |
|---|---|---|
| 2026-08-08 | Q: "when you actually start creating, start by showing the UI so I have a sense of what it looks like." Wants to react to the look and flow early. | memory `ui-first-development.md` |
| standing | P: prefers **seeing the UI** (simulator screenshots) over descriptions of it. | `docs/archive/STATE-2026-09-17-before-codex-setup.md:1071`; `work-record/milestone-8-history-and-charts/issues/01-progress-charts.md:33` |
| 2026-08-10 | Asked for set deletion without knowing it already existed behind a row menu. The team concluded "That *is* the fault" and added swipe-to-delete. **Lesson: hidden affordances count as missing.** | `work-record/milestone-2-core-loop/issues/18-drop-sets-and-set-deletion.md:28-31` |
| 2026-08-11 | Q: "being able to take a picture of the machine name (when adding machine) and the app either automatically finds the machine…" | `work-record/photo-machine-capture/spec.md:9-10` |
| 2026-08-12 | Q: "…instead of having to add leg press separately twice, i should be able to choose betwen single/double leg press… Basically I'm saying i should be able to make presets." | `work-record/exercise-presets/spec.md:9-13` |
| 2026-08-22 | Barbell: Q: "choose a barbell (then the app auto-calculates the weight…) or just manually input the total weight." | `work-record/barbell-bar-weight/spec.md:3-6` |
| 2026-08-22 | **Rejected automation.** Auto-appending the next set row was built, tried on the phone and removed the same day. Q: "Whenever I complete a set, it automatically adds next set. Delete this." Kept: carry-forward on a row the user adds. SPEC now says rows are "only ever created deliberately". | `work-record/next-set-autofill/issues/01-auto-add-next-set.md:5-19`; `docs/SPEC.md` Recording experience ("Speed bar") |
| 2026-08-24 | Zones felt one zone too high. The user chose to shift the boundaries +5 points rather than raise the max. | `docs/DECISIONS.md:54` (D45) |
| 2026-08-25 | Rest alarm: Q: "I don't think this should be a complicated problem." They reframed it as "the notification already fires at the right instant; can it just be audible?". **Taste: prefers simple, direct solutions.** | `docs/archive/STATE-2026-09-17-before-codex-setup.md:569-571` |
| 2026-08-25 | Supersets: chose to **group entries** and to rest after the last member. | `work-record/milestone-8-history-and-charts/issues/04-supersets.md:39-40`; D48 |
| 2026-08-27 | Q: "The lock screen works, and superset also correctly functions." (Live Activity accepted functionally; no design comment recorded.) | archive STATE `:730` |
| 2026-08-29 | Q: "drag works, and screen looks the same." (drag-to-reorder exercise cards) | archive STATE `:686` |
| 2026-09-03 | Milestone-9 asks: rename a workout mid-workout; a chart button in a History session; separate barbell/dumbbell exercises ("go with your way"); Q: "Add calendar button in history section…" (their reference screenshot was a month grid with a **green check** on workout days); Q: "At the end of workout show things like graph (like apple fitness)." They wanted the graph at finish **and** in History, total calories, and **NO effort rating**. | `work-record/milestone-9-history-and-summary/spec.md:7-16, 41, 52-53` |
| 2026-09-04 | Q: "lets get rid of all those unnecessary placeholder texts". Offered three scopes and chose **A**: tutorial paragraphs go; one-line consequences stay. | `work-record/milestone-9-history-and-summary/issues/06-remove-helper-copy.md:5-6` |
| 2026-09-04 | Q: "The heart rate graph at the end of the workout looks **messy**. It should look **clean like the one from Apple Fitness**. … Just replicate its graph shape." | `work-record/finish-graph-and-plain-numbers/spec.md:9-10` |
| 2026-09-04 | Q: "when it displays total volume it uses the **wavy equal sign**. Don't use that; **just show number**. In fact there are other places that use this or use the word 'estimated'. Just get rid of any of those." This became D52: plain numbers on every screen. | `work-record/finish-graph-and-plain-numbers/spec.md:11-13, 50`; `docs/DECISIONS.md:61` |
| 2026-09-06 | Ask AI: chose **a button first**, not an automatic send. | `work-record/scanner-accuracy/issues/05-ask-ai-escalation.md:6` |
| 2026-09-10 | Q: "delete added machines from gym (whether mid workout, or just at gym tab)". The record notes "**The user's word is Delete**" (not "Archive"). | `work-record/machine-deletion/issues/01-delete-machines.md:5-6, 18` |

### UI redesign, first pass (tickets 01–09, 2026-09-10/11)

| Date | What the user said or chose | Source |
|---|---|---|
| 2026-09-10 | **Complaint that started the redesign.** Q: "the app seems a bit **boring**, with **mostly texts** and it essentially doesn't have a **clean UI design**." | `work-record/ui-redesign/spec.md:5-6`; D54 "Why" (`docs/DECISIONS.md:63`) |
| 2026-09-10 | **Direction the user chose:** bold, dark, card-based ("Apple Fitness / Hevy family"); rounded cards, big numbers, one accent colour, coloured chips. Dark only, one warm accent (orange/coral) for actions and completed sets. Richness: muscle-group colours and icons, stat tiles and progress rings, motion (set-complete animation, haptics, animated rest ring), illustrated empty states. The whole app, screen by screen, workout screen first. **Settings gets its own screen behind a gear**; an app icon is generated. | `work-record/ui-redesign/spec.md:7-15, 68-78` |
| 2026-09-10 | Q: "i dont see any screenshots" after a chat delivery the tool reported as successful. The fix was to also open the images in Preview, or later in Orca's embedded browser. **Always make sure the images actually reach them.** | memory `show-screenshots-two-ways.md`; `work-record/ui-redesign/issues/17-finish-summary-second-pass.md:34-35` |
| 2026-09-10 | **Claude "Coral" vs Codex "Ink / Amber"**, both built to the same brief and shown on a side-by-side board of 15 screens. **The user chose Codex's Ink / Amber.** No reason was recorded. | `work-record/ui-redesign/issues/01-design-system.md:9-17`; board https://claude.ai/code/artifact/8d3aa889-2a2b-44ae-8d37-7620377bd3f9 |
| 2026-09-10 night | Start (gear button, resume banner) and the Settings screen: Q: "looks good". | `work-record/ui-redesign/issues/04-05-start-and-settings.md:39-40` |

### Second pass under the ios-design skill (tickets 10–18)

| Date | What the user said or chose | Source |
|---|---|---|
| 2026-09-11 | Verdict on the whole first pass, seen on the phone: Q: "it's ok, but I still feel like **the design is not there**", and the Start screen "**seems a bit off**". | `work-record/ui-redesign/issues/10-start-second-pass.md:5-6` |
| 2026-09-11 | Start, round 2. Offered A (hero at the thumb), B (a "today" week strip plus hero), C (gym in the nav bar, two-column template grid). Q: "I like the current format, but the Start Empty Workout button is **too big and looks too mundane**. **Keep the tab-bar icons as they are.** For templates I like **C's design**." | `…/10-start-second-pass.md:66-73`; canvas https://claude.ai/code/artifact/bb03a175-d794-4824-8164-944181e30797 |
| 2026-09-11 | Start, round 3. Choice between an amber capsule with an ink icon disc and an ink card whose only amber is the disc. Q: "I like the start button of the third artboard. Use that, and when in workout the Start Empty Workout button should **just switch to Resume workout**." Result: one hugging 56 pt capsule (`HeroCapsuleLabel`), and no separate resume card. | `…/10-start-second-pass.md:75-83` |
| 2026-09-11 eve | Q: "Currently there is an icon next to every exercise, but **I want them gone. In workout too. They don't match.** But in template it should show an icon but **only for muscle group** (either chest, back, arm, shoulder or leg), based on the exercises in the template. And also, when users click template they should be able to **view the list of exercises** in the template." | `work-record/ui-redesign/issues/11-icons-and-template-detail.md:5-9` |
| 2026-09-11 | New caption "N sets · r, r, r reps" on the template-detail rows. The user asked what it was, then said Q: "keep it". | `…/11-icons-and-template-detail.md:133-136`; archive STATE `:118` |
| 2026-09-11 | Q: "I want to have an option to save as template from history." | `work-record/history-templates-and-zones/issues/13-save-as-template-from-history.md:5` |
| 2026-09-11 | Q: "In history I also want to be able to see time spent in hr zone, **either when you click the graph or just below the graph**." Built **just below**, readable at a glance with no tap. | `…/issues/14-time-in-zones-in-history.md:5-8` |
| 2026-09-11 | Q: "The family icons look **inaccurate and mild**. Can you design it better to actually reflect the families? **Ask Codex to design it as well** with its new Image 2.5 and you design as well. **Show me the designs.**" | `work-record/ui-redesign/issues/12-muscle-family-icons.md:5-7`; `icons/brief.md:3-4` |
| 2026-09-11 | With two reference images: Q: "how about making it **more realistic** like this and **highlighting the muscle**, like these. I think it will be **easier to see** this way." Then Q: "Let's stick with codex's." | `…/12-muscle-family-icons.md:7-9`; `icons/brief.md:53-60`; refs `work-record/ui-redesign/icons/ref/` |
| 2026-09-12 | Q: "when deleting template it doesnt work propery. when i press and hold a template and click delete it deletes the other template. **just have delete button appear when you open the template.**" Long-press menus on tiles were removed. | `work-record/ui-redesign/issues/15-delete-template-in-detail.md:5-7` |
| 2026-09-17 | The user chose the active workout as the next screen. Offered Claude's A (the set is the hero), B (a pager showing one exercise at a time), C (a timeline with the rest inline). Q: "Out of those, **I just like current design the most**. Can you also have Codex design as well, just so I can compare?" | `…/16-active-workout-second-pass.md:5, 66-77` |
| 2026-09-17 | Q: "I like the design of Codex A, **except for current set magnifying**. **I like the rest timer of current.** I also think it would be better if Codex A's **time display is a bit bigger (but not as much as current design)**." | `…/16-active-workout-second-pass.md:79-90` |
| 2026-09-17 | Q: "Actually, **lets just keep the current design.** but just **move the current timer next to gym name** (and also have **timer include seconds**), and make the **total sets completed icon like the one in Codex A**." On the capture: Q: "looks good." The amber Add Exercise and amber Skip were kept by the user's choice. | `…/16-active-workout-second-pass.md:92-110, 125-128` |
| 2026-09-17 | Q: "Let's work on finish summary now." They were offered balanced / lifting-first / heart-rate-first, all with a compact confirmation, no 84 pt ring and neutral buttons at the bottom. They could not see the images in chat and asked to see the current screen. Q: "**I actually like this the most.** but just in workout details, move total volume next to workout time, and have calories on the same row, and also the hr on third row." Then Q: "looks good. install on phone." | `…/17-finish-summary-second-pass.md:7-24, 177`; exploration `git show 5a4c1b2:work-record/ui-redesign/issues/17-finish-summary-second-pass.md` |
| 2026-09-17/18 | The sets-ring bug report was closed. Q: "it actually works." | `…/18-sets-completion-ring.md:86-89` |

### Cardio, AI templates (2026-09-17 → 09-22)

| Date | What the user said or chose | Source |
|---|---|---|
| 2026-09-17 | Wants live gym cardio (timer, heart rate, calories, distance) and outdoor runs/rides with GPS routes. One saved workout with **separate lifting and cardio sections**. **Wants design screens before implementation.** | `work-record/cardio-design/issues/01-design-discussion.md:8-11`; `…/18-sets-completion-ring.md:53-59, 81-83` |
| 2026-09-18 | Offered A (inline sections), B (focus on the current activity, with a Lifting \| Cardio switch) and C (session timeline). Q: "Regarding design direction, **lets go with B**." Wants indoor activity choices **aligned with Apple Fitness**. | `…/cardio-design/issues/01-design-discussion.md:69-78` |
| 2026-09-18 | After use: remove the HealthKit **estimate label**; show routes **only in Summary/History** (no map during the workout); put **Start Cardio beside Start Lifting**. | `work-record/cardio/issues/03-ui-refinements.md:6-8` |
| 2026-09-19 | **Disliked** ticket 03's changed Start Lifting appearance: compact text-only buttons, amber primary plus grey secondary. P: "restore its previous design and give Start Cardio the same design, **including its activity logo**." Offered side by side with wrapped titles or stacked single-line capsules; they chose **stacked**. | `work-record/cardio/issues/04-restore-start-capsules.md:6-12, 67-81` |
| 2026-09-19 later | P: "put the original icon capsules **on one row by removing arrows**; **remove the outdoor cardio GPS section**" (the duplicate GPS/manual-distance editor). They fall back to stacking only when labels cannot fit. | `work-record/cardio/issues/05-compact-start-and-outdoor.md:6-19` |
| 2026-09-19 | P: "remove the **Phone motion estimate section** during device-tracked indoor runs; show **no such source/estimate detail**". Rename units to **Metric / U.S. customary**. They chose to apply units to **new cardio only**, preserving existing units. | `work-record/cardio/issues/06-unit-system-and-indoor.md:6-8, 20` |
| 2026-09-20 | AI routines: **no instructional content or visual guides**, no calendar, no coaching, no weight estimates. They chose an **additive secondary button** below Templates. | `work-record/ai-gym/spec.md:3, 21-22, 30`; `docs/DECISIONS.md` D58 |
| 2026-09-22 | After trying it: rename the entry to Q: "**Ask AI for Templates**"; add **Scan Machine** inside routine setup; one AI path for both machine and label. They approved the proposed flow with Q: "lets execute". | `work-record/ai-gym/issues/06-device-acceptance.md:81-85`; `…/07-template-visibility-and-scanning.md:9-21` |
| **2026-09-24** | **Today's request.** The layout is "clean", but "some places are **messy** and could be **missing details**", and the app "feels a little **boring**". Redesign **every** screen, more **interactive, creative, engaging**. Show visuals (an artifact or images) first. They may change the theme completely. | harness-relayed user request |

---

## 2. Distilled: what this user likes and dislikes

### Likes and wants

- **Seeing real pictures and choosing between side-by-side options.** They want the UI first
  and react to captures. They twice asked for a **Codex alternative next to Claude's** "so I can
  compare" (icons, active workout). They pick from boards, or ask to see the current screen
  beside the proposals, which is how ticket 17 was decided. Images must visibly arrive: in chat
  **and** in Preview or Orca's browser.
- **Apple Fitness is their recurring reference**: the finish graph shape, "graph like apple
  fitness" at the end of a workout, an activity list "aligned with Apple Fitness". Hevy and
  Strong were agent-supplied references (the ios-design skill), not quotes from the user.
- **Clean, bold and graphic, not text-heavy.** They picked the more saturated, characterful
  option: Ink / Amber over Coral, and bold family colours over "mild" pastels.
- **Big pill buttons with an icon disc.** The amber capsule with a dark icon disc (Start
  Lifting / Start Cardio / Resume / template Start) was chosen, then defended when an agent
  replaced it with plain text buttons. They asked explicitly for an "activity logo" on Start
  Cardio. Peer choices get **equal visual weight**, side by side when they fit (they dropped the
  arrows to make them fit).
- **Grids of tiles for templates** (C's two-column grid, "New Template…" as a tile).
- **Accurate, legible iconography.** Anatomically correct muscle maps with the working muscle
  highlighted, "more realistic… easier to see". The reference style is a neutral body with a
  vivid muscle fill.
- **Glanceable live information in one line**: the gym, the running clock **with seconds**, and a
  small neutral ring with "N/M sets". The clock should be medium-large: bigger than a caption,
  smaller than the old Large Title hero.
- **The current rest bar**: a draining ring with an hourglass, "Rest" over the time, "+15s", and
  amber "Skip".
- **Related numbers paired in equal tiles** (time/volume, active/total calories, avg/max heart
  rate), plus the finish ring and an amber View in History, which they kept over the compact
  alternatives.
- **Information shown without a tap**: zones directly below the graph; tapping a template shows
  its exercise list.
- **Direct, obvious commands where the object is**: Delete inside the opened template, swipe to
  delete a set. Discoverable, not hidden in menus.
- **Plain user words**: "Delete" (not Archive), "Metric / U.S. customary", "Ask AI for Templates".
  They kept one compact stat caption, "N sets · r, r, r reps".
- **Plain numbers.** No ≈, no "estimated", no source/provenance captions on screen.
- **Focus on the current activity** (cardio direction B).
- **Simple mechanisms over clever ones** ("I don't think this should be a complicated problem").

### Dislikes and asked to remove

- "**boring**", "**mostly texts**", "not a **clean UI design**" (09-10); "the design is **not
  there**", Start "**a bit off**" (09-11); "some places are **messy**", "**missing details**",
  "**boring**" (09-24).
- **Explanatory, placeholder or helper text**, and later **visual guides or explanations** in the
  AI flow. Only one-line consequences survived.
- **Qualifiers and technical source text**: ≈, "(estimated)", "Est. 1RM", the HealthKit estimate
  caption, the Phone motion estimate section, the duplicate live distance editor.
- **Messy dense charts.** The old heart-rate chart's 268 bars fused into a red block with an
  average rule. They want Apple's thin floating range bars, few labels and no gridlines.
- **Buttons that are too big or mundane** (the full-width Start Empty Workout) and
  **plain text-only buttons** (ticket 03's Start pair).
- **Icons that "don't match"**: a muscle icon beside every exercise, in lists, in the workout and
  in History. Also icons that are "**inaccurate and mild**": SF-Symbol figures such as a rower
  for "back", in pastel tints.
- **Magnifying the current set row** (Codex A/B), and an oversized elapsed-time hero.
- **Structural rewrites of screens they already use** when shown as alternatives: the
  active-workout pager, timeline and ledger; the finish-summary lifting-first and HR-first
  layouts; the compact receipt without its ring. Each time they kept the current structure and
  asked for precise, small moves ("move X next to Y", "Z on the third row").
- **Maps during a live workout.** Routes belong to the finished Summary and History.
- **Unrequested automation** (auto-added next set: "Delete this").
- **Long-press context menus on tiles** (on the phone one deleted the wrong template).
- **Arrows** on the side-by-side Start capsules (removed so the two fit on one row).
- **Tab-bar icon changes**, as of 2026-09-11: "Keep the tab-bar icons as they are". The current
  icons are `figure.strengthtraining.traditional`, `clock.arrow.circlepath`, `building.2`,
  `list.bullet.rectangle` (`WorkoutTracker/App/RootView.swift:40-52`). Today's "completely
  redesign… every little thing" may supersede this. Ask, or show both.

### Behavioural pattern (important for today's proposal)

They ask for big change ("boring", "not there", now "completely redesign"). Yet in **every**
structural A/B/C round (Start, active workout, finish summary) they kept or returned to the
familiar structure and made precise tweaks. The exception is cardio, a new screen, where they
chose B. The *surface* is what repeatedly failed them: "boring", "mundane", "mild", "don't
match", "messy". The *flows* they know have not. A proposal that changes the visual language
boldly while keeping the recognisable skeletons will likely land better than one that also
reshuffles them. Candidates for "interactive / engaging" that they have not rejected: motion,
animated rings, haptics, richer charts, and B's week strip ("what did I do this week"). B's
week strip was offered in the Start round and passed over in favour of the current format,
but it was never criticised. Also show the current screen next to each proposal. They asked
for that in ticket 17.

---

## 3. Design directions explored, and why each was picked or dropped

| # | Round | Options shown | Outcome and stated reason |
|---|---|---|---|
| 1 | Visual system, 2026-09-10 | **Claude "Coral"**: accent `#FF7A3D`, neutral graphite `#0A0A0C/#1A1A1E/#26262B/#303036`, radius 20/12/10. **Codex "Ink / Amber"**: accent `#FFB45E`, blue-leaning graphite `#0B0D10/#171B21/#222831/#2B323C`, warm white text `#F6F3EC`, radius 24/16/10, Large Title rounded **black** hero, pastel muscle colours. | **Ink / Amber chosen**; no reason recorded. Palette: `work-record/ui-redesign/codex-design-report.md:5-26`; D54. Claude's screens remain in `screenshots/claude/`. |
| 2 | Start, round 1, 2026-09-11 | A hero at the thumb (pinned bottom); B "today" at the eye (week strip M–S dots, "3 workouts · Tue", then hero); C hero at the eye (gym moved into the nav bar, two-column template grid). | Structure kept as it was: gear, title, gym card, action, templates. C's **grid** taken. The hero button was "too big and too mundane". Files `work-record/ui-redesign/canvas/start/Direction{A,ALive,B,C}.dc.html`. |
| 3 | Start, round 2 | Amber capsule with an ink figure disc, or an ink card whose only amber is the disc; a live-state artboard. | **Capsule** chosen. Live state: the same capsule reads "Resume workout" with a pulsing dot; the separate resume card was removed. `canvas/start/{Main,StartAsCard,MainLive}.dc.html`. |
| 4 | Muscle icons, round 1 | Claude hand-drawn SVG silhouettes with cut-lines vs Codex image-model heavy silhouettes (paired pecs, lat V, deltoid caps, flexed bicep, single quad). | Neither chosen. The user redirected with two references to **muscle maps**. `icons/claude/`, `icons/codex/`, `canvas/icons/Round1.dc.html`. |
| 5 | Muscle icons, round 2 | Claude flat two-layer SVG maps vs Codex image-model segmented maps (grey body, highlighted muscle). | **Codex's chosen**: more detailed, like the flat reference. `icons/claude2/`, `icons/codex2/`, canvas https://claude.ai/code/artifact/0abc8068-6d95-497e-8cb8-1907790411b5. |
| 6 | Active workout, 2026-09-17 | Claude A: the set as hero, a rest capsule, everything else demoted. Claude B: a pager (one exercise at a time, exercise strip). Claude C: a timeline (done sets collapsed, rest inline). Codex A: "familiar, quieter" (elapsed time as a caption, small neutral ring, neutral add buttons, **enlarged current row** as the only amber). Codex B: "working row" (no card walls, one enlarged row in a ledger). Revised Codex A2. | All set aside. "I just like current design the most". Codex A was liked except the magnified current set. Final: current screen plus a one-line header (gym chip · clock with seconds · 22 pt neutral ring "N/M sets"). Accepted exception: amber Add Exercise **and** amber Skip. `canvas/active/`, `canvas/active-codex/README.md`; canvas https://claude.ai/code/artifact/83323a4b-0e91-4830-9b2a-125d9ca3642b. |
| 7 | Finish summary, 2026-09-17 | A balanced recap (time hero in the metrics group), B lifting first (volume hero, exercises next), C heart rate first (avg HR hero over the graph). All with a compact confirmation (no 84 pt ring) and neutral, bottom-placed actions. | All rejected in favour of the **shipped** receipt: 84 pt amber status ring, amber View in History, secondary Save as Template, stat tiles. Only the tile order changed. Branch `ericlee4992/finish-summary-second-pass` @ `5a4c1b2`. |
| 8 | Cardio, 2026-09-18 | A inline sections under lifting; B focus (a Lifting \| Cardio switch, a large timer, Pause primary); C session timeline. | **B chosen**. It brings live cardio forward (A needed scrolling at AXL). Prototype branch `ericlee4992/cardio-design-prototype` @ `48608fb`. |
| 9 | Start Lifting / Start Cardio, 09-18 → 09-19 | (a) text-only equal-width pair, amber and grey (ticket 03); (b) stacked matching capsules (ticket 04); (c) side-by-side arrowless capsules that stack only when needed (ticket 05). | (a) **disliked**. (b) chosen over the wrapped side-by-side version. (c) requested later and is **current**. D54 records two amber peer capsules as a deliberate exception. |
| 10 | History zones, 2026-09-11 | Zones revealed by tapping the graph, or shown below the graph. | **Below**: a glance beats a tap. |

---

## 4. Icon history (muscle icons, activity and tab icons, app icon)

**Muscle icons.**

1. Before the redesign there were no muscle icons. Codex's ticket 01 system added `MuscleIcon`:
   SF Symbols for all **14 muscle groups** in tinted rounded squares (36 → 40 pt, pastel colours
   such as Chest `#F4939C`). They appeared on every exercise row, workout card, History detail
   header and on template cards (up to five). Triceps and Biceps shared `dumbbell.fill`.
   (`codex-design-report.md:26`; `issues/01-design-system.md:34`)
2. Ticket 11 (2026-09-11). The user said per-exercise icons "don't match" and wanted them gone
   everywhere. Only templates show icons, one per muscle **family**: Chest, Back, Shoulders,
   Arms, Legs, each at most once, in head-to-toe order. Biceps/Triceps/Forearms → Arms;
   Quads/Hamstrings/Glutes/Hips/Calves → Legs. **Core, Neck and Full Body map to no icon.** That
   was flagged to the user as "easy to add a sixth"; no answer is recorded. They were still SF
   Symbols (`figure.strengthtraining.traditional`, `figure.rower`, `figure.arms.open`,
   `dumbbell.fill`, `figure.strengthtraining.functional`) in pastels, 24 pt on a tile and 40 pt
   in the detail. (`issues/11-…md:13-22`; `icons/brief.md:9-13`)
3. Ticket 12 (2026-09-11 night). The user called them "inaccurate and mild". Round 1 compared
   silhouettes; the user then gave references (`icons/ref/muscle-map-lines.png`: grey line body,
   orange muscle; `icons/ref/muscle-map-flat.png`: flat blue-grey torsos, red/orange muscle
   segments). Round 2 compared muscle maps, and **Codex's** were chosen. Shipped as two-layer
   template images, `Assets.xcassets/MuscleMaps/<family>-{body,muscle}` (512 px, made by
   `work-record/ui-redesign/icons/make-muscle-map-assets.py`). The body is `MuscleBody #5B6472`.
   Family colours: chest `#FF70B6`, back `#4EB9FF`, shoulders `#4DE0D4`, arms `#B891FF`, legs
   `#84D65A`, on a 16 % tint tile, with the map filling 86 %. No amber. Shoulders were moved to
   turquoise to stay clear of amber and warmup yellow. (`issues/12-…md:14-18, 51-62`;
   `icons/codex/README.md`)

**Other icons.**

- **Tab-bar icons**: the user said to keep them (2026-09-11). The cardio prototype's tab chrome
  was "illustrative… not a request to change navigation" (`cardio-design/issues/01-…md:61-62`).
- **Start capsule icons**: `figure.strengthtraining.traditional` (lifting) and `figure.run`
  (cardio), in an ink disc on amber (`cardio/issues/04-…md:16-17`).
- A reviewer flagged the amber-tinted activity symbols in the cardio picker and summary as
  decoration and inconsistent with the white live icon (`work-record/cardio/claude-visual-01.md:50-56`).
  This is a reviewer finding, not a user comment.

**App icon.**

- Before the redesign the slot was empty (`ui-redesign/spec.md:26, 75`). The plan was "a
  generated dark tile with the accent and a dumbbell glyph… not artwork, but not blank".
- Ticket 09 (2026-09-11) added `scripts/render-app-icon.py` (PIL). It draws a 1024² opaque ink
  tile `#0A0A0C` with an amber dumbbell: a bar in deeper amber `#E0933D` and two `#FFB45E`
  plates each side. Codex P3: the shaft now runs under every plate. The plan's coral became
  amber because the user chose Ink / Amber. (`issues/09-…md:21-25, 56-57`)
- The acceptance criteria say "the icon PNG reviewed by the user", but **no user reaction to the
  icon is recorded anywhere**. It is programmer art, and the ink is the Coral plan's `#0A0A0C`,
  not the shipped surface `#0B0D10`. It is a real redesign candidate.
- The Live Activity uses the literals `#0B0D10` and `#FFB45E`, and the heart stays red. The
  user's only recorded comment is functional: "The lock screen works".

---

## 5. Places already flagged as messy or incomplete (agent and reviewer findings, NOT user quotes)

These match the user's "messy / missing details". They are useful input for "every little
thing". Their current status was not re-verified.

- **Native Forms were never themed**: the gym, machine and model editors, NewExerciseSheet,
  ExercisePresetsSheet, EditExerciseLoadTypeSheet, PreviousPerformanceSheet,
  ExerciseRestSettingsSheet, MaxHeartRateSheet, and the Settings list content. They "keep the
  system look" (`docs/SPEC.md:79-81`; `issues/08-exercises-and-sheets.md:25-27`). The scan sheet
  has "tokens only" (`issues/07-gyms.md:24-26`).
- The empty Gyms tab has no text, only "Add Gym…" (`issues/09-…md:19-20`).
- The Start capture shows a lone "New Template…" tile, a grey helper footnote ("Machines resolve
  to your last-used at your gym") and a half-empty viewport
  (`work-record/cardio/screenshots/compact-start-outdoor/start-iphone15promax.png`).
- Active workout: the nav title truncates ("Seated Ches…"). There are two amber commands (Add
  Exercise and Skip). The heart-rate card carries a "Test data · set up zones" link line
  (`work-record/ui-redesign/screenshots/16/02-active-workout.png`).
- Finish grid: the pairs hold only when every metric exists, because missing tiles compact and
  shift the pairs. History detail orders its heart-rate tiles avg/max then active/total, with no
  time/volume tiles, which is inconsistent with the receipt
  (`work-record/ui-redesign/claude-review-17-initial.md:117-131`).
- Cardio (`work-record/cardio/claude-visual-01.md:41-100`, `claude-visual-02.md:39-62`):
  - The route was nearly invisible in History.
  - Activity symbols are amber in some places and white in others.
  - The "Lifting" and "Cardio" History headers use different styles.
  - Add Exercise / Add by Machine stay side by side and wrap at AXL.
  - The floating control card has no backdrop, so content peeks around it.
  - The lifting-side "Indoor Run … Recording" row has no tap affordance.
  - One card holds a single line of text.
  - The header wraps to "No / gym" and "0/0 / sets" at AXL.
  - Durations mix formats ("39s" vs "0:22").
  - "Average pace" can contradict "Current pace".
  - The receipt subtitle orphans "1" from "cardio activity".
- The calendar's workout-day mark changed from the user's reference green check to an amber
  disc in ticket 06. There was no user comment either way (`issues/06-history.md:16-19`).

---

## 6. Standing rules the user set (explicit reopens are needed to break them)

- D52: plain numbers, no ≈ or "estimated" on screen.
- Copy policy: no explanatory paragraphs; one short consequence line only (milestone-9 ticket 06).
  The redesign has so far added "shape, colour and motion, never words". The user themselves
  approved each new string (the caption, "Delete Template…", unit names, "Ask AI for Templates").
- Rows are created only deliberately; no auto-added sets.
- Maps only after Finish; no live source/estimate captions.
- No long-press menus on template tiles; Delete lives in the template detail.
- Visual-system facts in D54 (`docs/DECISIONS.md:63`): dark only, the amber accent, the
  muscle-family maps. The user has now said the theme may change completely, so D54 would be
  reopened explicitly, with the reason recorded (AGENTS.md "Start and resume" step 2).
