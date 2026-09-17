# 17 — Finish summary, second design pass

Status: resolved — design exploration closed; user retained current screen with a metric reorder

## Request and scope

2026-09-17: “Let's work on finish summary now.” The previous task was read-only state recovery.
This task starts the finish-summary design pass; the user has not selected a composition.
Optional focus question offered balanced recap / lifting first / heart rate first. Pending reply,
balanced is the proposed default, with all three structures rendered for comparison.

Branch: `ericlee4992/finish-summary-second-pass`, based on `c7ef99b`.
Worktree: `/Users/ericlee06/orca/workspaces/Health App/finish-summary-second-pass`.
No application, test, schema or installed-phone change.

## Current-screen evidence and constraints

Read ticket 03, current `WorkoutFinishedSheet`, `HeartRateSummarySection`, `ZoneTimeCard`,
SPEC's finish-summary / design sections, D44/D45/D52/D54 and the iOS-design skill and references.
Inspected real default/AccessibilityL captures in `screenshots/03/`: the large confirmation and
two actions precede all the metrics; at AccessibilityL almost all the initial viewport goes to
confirmation/actions. The six independent tiles give all the numbers equal weight. The graph,
zones and lifting results are much farther down.

Keep frozen summary values, entered-unit history, missing-sensor omission, total-calorie gating,
load-aware best sets, zone basis and the existing low/high graph calculation. No new product
copy. Done stays available in the toolbar. View in History and Save as Template retain their
existing behavior; after template creation the existing saved-template message replaces its
button. Empty/discarded still says Nothing logged / Nothing to save and the existing explanatory
sentence, with no saved-workout actions or metrics. No product decision is reopened yet.
SPEC's prescribed tile order would need an explicit layout amendment after the user's pick;
D44's data contract and D54's visual system remain.

## Job, states and bold element

- Saved with sensor, A: this screen exists so the user can glance at the whole workout and
  leave in one tap; the eye lands on the workout time in the top metrics group. Confirmation,
  volume, heart-rate numbers and bottom actions step down.
- Saved with sensor, B: this screen exists so the user can assess the lifting session and
  leave in one tap; the eye lands on total volume at the top. Time is supporting, exercises
  immediately follow, and health details continue below.
- Saved with sensor, C: this screen exists so the user can inspect the recorded heart-rate
  session and leave in one tap; the eye lands on average heart rate over the top graph. Zones
  follow the graph, and lifting results continue below.
- Saved without sensor: same summary job with absent health content removed; A keeps workout
  time first, B uses total volume when positive (otherwise time); C falls back to A rather
  than reserving space for absent data. No zero or empty sensor card.
- Saved without positive volume: omit total volume; B falls back to workout time. Exercise
  lines retain best-set rules for assisted/bodyweight loads.
- Discarded: this screen exists so the user can understand nothing was saved and leave in one
  tap; the eye lands on Nothing to save, with Done in the toolbar and no results/actions below.
- Template saved: composition stays fixed, with the existing Saved as template message in the
  action area instead of its button. No new accent or hero.

## Three structures (initial viewport)

```text
A — balanced recap           B — lifting first          C — heart rate first
Nice work       Done         Nice work       Done       Nice work       Done
✓ Workout saved              ✓ Workout saved            ✓ Workout saved
3 exercises · 10 sets …       3 exercises · 10 sets …     3 exercises · 10 sets …
Workout details              ┌ 9,740 lb HERO       ┐     Heart rate
┌ 48:12 HERO | 9,740 lb ┐     │ Total volume       │     ┌ 126 BPM HERO       ┐
│ time       | volume  │     │ 48:12              │     │ Avg. heart rate    │
│ active     | total   │     │ Workout time       │     │ floating HR bars   │
│ average HR | max HR  │     └────────────────────┘     │ clock ticks + AVG  │
└─────────────────────┘     Exercises                   └────────────────────┘
Heart rate                  ┌ Chest press + best ┐      ┌ Time in zones      ┐
┌ floating HR bars    ┐     │ Pulldown + best    │      │ stacked bar        │
│ clock ticks + AVG   │     │ Lateral raise+best │      │ durations          │
└─────────────────────┘     └───────────────────┘      └────────────────────┘
Time in zones …             Workout details …           Workout details …
```

All content scrolls. A continues zones → exercises → actions; B continues health metrics →
graph → zones → actions; C continues metrics → exercises → actions. Top figures use the only
Large Title/hero. Default pairs use equal columns; at AccessibilityL they stack. Confirmation
is two short lines without the 84-point ring or its own card. Exercise rows share one container
and separators. Buttons are neutral, full-width at the bottom; Done is always in native chrome.

Tradeoffs: A exposes the overall numbers soonest but still places exercise detail below health;
B brings best sets into the first viewport but delays heart rate; C brings graph/zones forward
but delays lifting. Neutral View in History is deliberate: inspecting this recap is the task,
and leaving it should not visually outweigh its content.

## Mockup method and limitations

The `design` canvas is unavailable in this session. Native SwiftUI views with `#Preview`
definitions are rendered in a separate simulator app (bundle
`com.workouttracker.design.finishsummary`); the WorkoutTracker app is not rebuilt or installed.
Sources and reproduction command: `prototypes/finish-summary/`.
The figures are an illustrative, fixed 48:12 workout (3 exercises, 10 sets, 9,740 lb; 312 active /
380 total CAL; 126 average / 159 max BPM). The graph is illustrative, not a persisted fixture
or a verification of domain math. All directions use identical content and actual Dynamic Type.
The preview buttons are placeholders. This establishes layout only, not feature correctness.
Default/AXL captures cover top, metrics, graph, zones, exercises and actions in `screenshots/17/`.

## Design tells

- Same container everywhere: absent — confirmation and section labels are on the page;
  cards group metrics, graph, zones and a list of exercise results.
- Unneeded chips: absent.
- All-caps section labels: absent; existing BPM AVG graph caption remains.
- Middle-dot metadata: deliberate — existing exercise/set/gym and best-set punctuation.
- Accent everywhere: absent — chart gradient and zone colors carry recorded meanings;
  confirmation and actions are neutral.
- Equal-weight full-width blocks: absent — A groups metrics, B leads with lifting volume,
  C leads with the graph; supporting blocks follow.
- Phone-sized website: absent — native sheet/toolbar, compact result groups, continuous scroll.
- Too much above the job / empty viewport: absent — confirmation is compact, results follow.
- Picker as primary / command as content: absent — no new picker, actions remain buttons.
- Default-size-only: absent in inspected native default/AXL compositions; metric pairs stack,
  exercise/equipment labels wrap and bottom actions remain whole.

## Gates after a selected design is implemented (not run for these previews)

- Successful app build.
- HeartRateSummaryUITests 3; HeartRateUITests 5; CoreLoopUITests empty-finish and View-in-History 2.
- Matching real finish captures in RedesignScreenshotUITests (existing default + AXL 2;
  extend to full blocks and sensor/no-sensor states as needed).
- Existing save-as-template finish coverage; confirm exact methods once implementation scope is set.
- Relevant WorkoutSummary, HeartRateSeries and ZoneBarLayout unit suites if those interfaces change.
- Full local UI suite before merge (currently 72 declared tests; recount after changes).
- Independent Claude review with this ticket, chosen wireframe, diff, captures, evidence and
  ios-design/REVIEW.md; re-review fixes before merge.

## Next action

Render and inspect the native comparisons, then get the user's choice before structural
production changes. The iOS design skill requires: “Done when the user has picked or said to
proceed”; the choice is a design decision, not a request to approve routine development work.

## Design checkpoint — 2026-09-17

Native harness compilation and the final capture command exited **0**. Final render produced
36 simulator PNGs (3 directions × 2 text sizes × 6 scroll anchors), plus default and AXL
comparison boards. Opened the default/AXL top comparisons and representative full-size
metrics, graph, zone, exercise and action captures: labels stay whole and sections remain
reachable. This is visual inspection of a standalone preview, not production XCUITest.
An early capture began before the sheet settled; the harness now explicitly scrolls to each
anchor after presentation and waits before capture. The first and replacement capture runs
briefly overlapped; both completed, and the final capture set was inspected.

[Interactive local comparison](../prototypes/finish-summary/comparison.html) ·
[Default board](../screenshots/17/comparison.png) ·
[AccessibilityL board](../screenshots/17/comparison-axl.png).

`git diff --check` and the new handoff/README local-link checks pass. Production directories
are unchanged; app build/unit/UI suites were not rerun. No independent clearance, merge or
phone installation is claimed. The main checkout has an intentional uncommitted STATE pointer
to this worktree so a resumed session finds the active design. Proposed preference: A, because
it brings the complete metric recap and graph into the initial viewport without choosing
lifting or heart rate as the sole priority. User decision remains pending.

## Comments

2026-09-17: user could not see the local image in chat; opened `comparison.html` in Orca's
embedded browser and verified all images loaded. User then requested the current screen.
Added Current as the first comparison column: ticket 16's real default screenshot and ticket
03's real AccessibilityL screenshot. The current screenshot uses a short test workout, not
the 48-minute proposal fixture; the gallery labels that distinction and keeps Current at the
first viewport when proposal scroll positions change. No production changes.

## Final design choice

The user selected the current shipped screen, with only Workout details reordered into
time/volume, active/total calories, avg/max HR. None of A/B/C was selected. Implementation
continues on `ericlee4992/finish-summary-order`, source commit `4d70d7d`, in
`/Users/ericlee06/orca/workspaces/Health App/finish-summary-order`; its ticket 17 owns subsequent
build, screenshots, review and merge evidence. This branch preserves the rejected exploration.
