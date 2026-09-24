# 01 — Whole-app visual direction

Type: prototype
Status: ready-for-human — visual proposal, no production implementation

## Request and boundary

September 24: the user requests a complete redesign, finding the app clean but sometimes messy,
missing details and boring. They explicitly allow replacing the theme and ask to see visuals
before implementation. This is a new task, superseding signing/device acceptance as the current
session's work. No Swift, assets, tests, schema, installed binary or phone data changed.

Base: clean main `a0364f2c93ebb0ebbfd1e28b8847aa79b304d0fd`, verified against live origin/main.
Proposal branch: `ericlee4992/redesign-visual-proposal`. No build, install or API request.
No independent clearance or native accessibility pass is claimed for the proposal.

## Proposal

[Interactive study](../visuals/workout-redesign.html): 36 selectable screen/state compositions,
local simulated actions, sample data. The `design` canvas is unavailable; the user explicitly
accepts artifacts/images, so an interactive browser mock is used instead of implementing SwiftUI
previews. It is intentionally not a product build. Lucide stands in for native SF Symbols.

Recommended direction **Focus**: warm paper / forest ink, a green action accent that becomes
lime in dark appearance, compact contextual controls, editorial template names, a numbered
template library, table-like set entry and a finish receipt. Light and dark follow the host;
the design controls can force either. Home alternatives differ in structure, not just color:

```text
A / Focus                 B / Library               C / Journal
Workout + settings        Workout + settings        Workout + settings
small gym picker          small gym picker          small gym picker
┌ LAST USED TEMPLATE ┐    Start lifting / cardio    3 sessions (dominant)
│ large name / 01    │    Templates + New           recent-session timeline
│ muscle context    │    01 name / exercises        Start lifting (primary)
│ Open template ★   │    02 name / exercises        Start cardio (secondary)
└───────────────────┘    03 name / exercises        Templates / compact row
Start lifting / cardio    Ask AI for Templates      Tab navigation
Templates / compact rows  Last session
Ask AI for Templates      Tab navigation
Tab navigation
```

Focus is recommended; Library is for direct template browsing; Journal makes recent completed
training the organizing element. Journal is a proposed composition, not an automatic training
schedule, coaching recommendation, readiness score or new domain model.

## Screen jobs, states and hierarchy

Each row names the job, dominant element and reading order. Supporting rows/actions are
secondary. Detailed editors use established form patterns rather than decorative containers.

| State | Job / dominant element / reading order |
|---|---|
| 01 Focus home | Open the last-used template in one tap; featured template is dominant; title → gym → template → direct starts → remaining templates → AI → tabs. |
| 02 Library home | Pick a template immediately; start lifting is primary; title → gym → starts → full template rows → AI → last session → tabs. |
| 03 Journal home | See recent training then start; weekly completed-session count leads; gym → count → timeline → starts → templates. |
| 04 Active workout | Commit a prepared set in one tap; current exercise/set fields lead; time/HR → progress → exercise/equipment → previous → set table → next exercise. |
| 05 Rest | Know when to resume; rest remaining is the dominant changing number; same workout → timer → +30s/Skip → next exercise. |
| 06 Previous | Compare like equipment; same-machine result leads; identity → result → completed rows → explicitly separate model/any-equipment references. |
| 07 Equipment | Choose physical machine and variation; selected context leads; gym → machine rows → variation → set type → consequence → Use selection. |
| 08 Bar | Enter plates per side without confusing total load; computed total leads; bar → per-side field → total/breakdown → commit. |
| 09 Add exercise | Find a movement quickly; search leads; search → exercises/by machine → compact rows → new exercise. |
| 10 Cardio setup | Choose activity before recording; explicit Start leads; activity rows → selected activity → sensors → Start. |
| 11 Live cardio | Glance at actual distance; distance leads; activity/status → distance → active time/pace/HR/energy → target → Pause/Resume. |
| 12 Finish | Understand what was saved; workout name and receipt lead; name/date/gym → metrics in existing pair order → HR → View Workout → save template. |
| 13 Templates | Find a saved template; named rows lead; title/New → ordered templates → AI. |
| 14 Template | Inspect before starting; name then Start lead; identity → summary → Start → prescribed exercise rows → delete. |
| 15 Template editor | Stage changes with clear Save; fields lead; Cancel/Save → name → reorderable exercise language → cardio target → notes. |
| 16 AI setup | Express preferences and confirm available equipment; Generate leads after inputs; goal → experience → frequency → time → equipment/scan → Generate. |
| 17 AI review | Review the exact requested session count; Save templates leads; count → editable session rows → atomic save → adjust preferences. |
| 18 Gyms | Open usual equipment context; usual gym leads; title/Add → gym feature → other gyms/no-gym. |
| 19 Gym | Find or add a physical machine; Scan leads; metadata → Scan → search → equipment rows → manual add. |
| 20 Machine | Distinguish physical equipment; instance label leads; gym → label/model → exercise/variation/unit/history → add to workout → archive. |
| 21 Scan | Capture machine or label in one path; capture target leads; preview → Take Photo → library/manual alternatives → consent/on-device alternative. |
| 22 Recognition | Correct an AI proposal before Add; editable identity leads; Retake → uncertainty → label/brand/model/exercise/gym → generic alternative → Add. |
| 23 Exercises | Browse movements, not physical machines; search leads; search → muscle filter → exercise/load-type rows. |
| 24 Exercise | Inspect records for a specific variation; best weight leads; identity → context picker → records → chart → variations. |
| 25 History | Open a finished session; month count leads; title/calendar → count → date groups → session rows. |
| 26 Calendar | Select a completed workout by start date; selected day leads; month → marked calendar → selected-day session. |
| 27 Session detail | Inspect frozen recorded facts; session identity leads; date/gym → metrics → exercise/set ledger → HR/zones → save template. |
| 28 Progress | Compare the same equipment/variation over time; selected metric leads; identity/picker → metric selection → value → chart → as-entered session. |
| 29 Settings | Find a preference by task; group labels lead; training → data → proposed appearance controls. |
| 30 AI settings | Manage independent consents; permission toggles lead; key state → key field → three permissions → remove. |
| 31 Rest settings | Set a timer or HR threshold; mode leads; mode → durations → threshold/cap → missing-reading consequence → Done. |
| 32 Export | Save complete data; JSON action leads; full-backup feature → CSV alternative → share-sheet destination. |
| 33 Empty | Start without setup overhead; Start Lifting leads; gym optional → empty invitation → starts → templates/AI. |
| 34 Error | Recover without losing preferences; Try again leads; error → retained-input message → retry/back. |
| 35 Delete | Make consequence and cancel clear; decision title leads; template identity → confirmation sheet → Cancel → destructive command. |
| 36 Lock Screen | Glance at current rest; remaining time leads; system clock → compact activity name → rest/next set → Open Workout. |

## Interaction language

- Set completion changes its row and reveals rest; never creates another set. Add Set is explicit.
- Local mock inputs retain edited set values across completion. New sets copy the last mock row.
- Motion is a short completion response / press response; Reduce Motion suppresses transitions.
- Rest offers +30s and Skip. Preview time is frozen; it does not claim sensor/timer execution.
- Cardio requires Start and supports Pause/Resume in the mock.
- AI count changes the review list and saved template list; no network request or real save occurs.
- Search filters local rows. Larger-text mode stacks start buttons, metrics and set inputs.
- A few lower-level actions show an explicitly labeled preview message, not a fake successful
  device operation. Calendar, machine chooser, bar totals and several editor details are visual
  exemplars, not full domain simulations. Weight chart is illustrated; other metrics show the
  number and an explicit chart-preview placeholder.

## Scope of reopened decisions

D54 is reopened for exploration: palette, light appearance, cards, typography composition,
start-button hierarchy, muscle representation, icon/Live Activity treatment and proposed short
copy. Final direction/copy are not accepted merely because they appear in this proposal.
D58 placement below templates remains; D56 consent/confirmation, D57 explicit cardio Start,
D19/D23 identity snapshots, D20 load-type math, D25 units and deliberate set creation remain.
No new app-name/brand decision. Watch software remains out of the shipped release.

## Design tells

| Tell | Assessment |
|---|---|
| Same container on everything | Absent: rows use separators, metrics use a grid, only structured features/rest/confirmation are grouped. |
| Chip as caption / many chips | Absent: most context is plain text; live/selected state may have one capsule. |
| All-caps label on every section | Absent: uppercase is reserved for template identity, small contextual kicker and history date. |
| Middle-dot metadata | Deliberate: compact existing set/reps/time/equipment context. |
| Accent everywhere | Absent: primary command, selected/completed state and chart marks only. |
| Equal full-width blocks competing | Absent: feature or metric leads; other actions step down. |
| Phone-sized website | Absent: native-style tab navigation, rows and direct set inputs; the feature is one actual template. |
| Too much / too little above fold | Default home inspected at 460 px preview; real iPhone viewport and scroll placement remain implementation gates. |
| Picker dressed as command | Absent: gym/variation context uses disclosure, separate from primary. |
| Default-size-only layout | Mock enlarged-text render inspected; this is not a native AccessibilityL pass. |

The dark-only/amber/copy rules in the old skill are the subject of this user-authorized redesign,
not grounds to silently constrain the new proposal. Metric/snapshot/consent rules are unaffected.

## Verification

Read current SPEC, D54/D56–58, ios-design SKILL/REFERENCE/REVIEW and ticket conventions.
Inspected real existing default and AccessibilityL captures from the September 22 follow-up
(`followup-start-top-default.png`, `followup-start-top-axl.png`). These establish the baseline,
not evidence of the redesigned native app.

Browser check used Chromium 1208 through temporary Playwright, isolated under
`/tmp/wt-design-browser`; no product dependency added. Render wrapper also lives there.
All 36 screens opened at viewport widths 768 and 352 (the latter leaves 320 px inside wrapper),
with no reported horizontal overflow or JavaScript exceptions. All 36 also opened in the
mock large-text mode at the wider viewport. Main interactions checked: complete set does not
append; Add Set does; rest appears; chosen AI session count renders; save receipt appears.
Actual command exit: 0. [Result](../results/browser-check.json), [check script](../results/browser-check.cjs).

Follow-up interaction check also exited 0: edited set weight survives completion, selected
cardio activity survives Start, repeated chart-metric switching does not throw, and all 36
screens have no horizontal overflow in the narrow enlarged-text layout. No JS errors.
[Interaction check](../results/interaction-check.cjs). Documentation links, fragment format/size,
archive byte preservation and diff whitespace checks passed. Product/test/config diff is empty.

Opened and visually inspected the retained [dark home](../visuals/captures/home-dark.png),
[light home](../visuals/captures/home-light.png), [large home](../visuals/captures/home-large.png),
and [active workout](../visuals/captures/active-dark.png) captures. These are browser renders.
No Swift build/tests required or run for this proposal. Native typography, system sheets/glass,
VoiceOver, haptics, keyboard avoidance, genuine AccessibilityL and physical one-hand use remain
unverified. The proposed app has not been built, reviewed, merged or installed.

## Next action

User reacts to Focus / Library / Journal and overall visual direction. Refine visuals first.
Once a direction is accepted, finish detailed state designs (supersets, sensor outages,
permissions, template drift, precise history edits, all picker variants), create implementation
tickets and native default/AccessibilityL captures, then follow targeted verification and Claude
independent review before merge/install. Do not begin product changes on this ticket alone.

## Comments

- September 24: user explicitly asks for visuals first. No request for signing renewal during
  this task. Historical device acceptance remains open in AI gym ticket 06 and cardio ticket 02.
