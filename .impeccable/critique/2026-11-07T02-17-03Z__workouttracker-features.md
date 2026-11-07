---
target: overall design, all screens
total_score: 25
max_score: 36
na_heuristics: 9
p0_count: 0
p1_count: 1
target_identity: "file:/Users/ericlee06/orca/workspaces/Health App/UI_design/WorkoutTracker/Features"
timestamp: 2026-11-07T02-17-03Z
slug: workouttracker-features
---
Method: design review only (detector not applicable, native platform)

Target: whole app (WorkoutTracker/Features), Floodlight look; 33 screens × dark/light default + dark AccessibilityL, WT-Floodlight iOS 27 sample-data fixtures, 2026-11-06. ios-design skill not applied (user's instruction).

## Design Health Score
| # | Heuristic | Score | Key Issue |
|---|---|---|---|
| 1 | Visibility of System Status | 3 | Live clock, 2/15 sets, rest slab, Recording pill; "✱4" unexplained |
| 2 | Match System / Real World | 3 | Gym language; shorthand leaks ("✱4", "kg + lb", "BW + added", "8 Last week") |
| 3 | User Control and Freedom | 3 | Exits exist but sit beside frequent controls |
| 4 | Consistency and Standards | 2 | Finish top (lifting) vs End Cardio bottom; dashed outline = 4 meanings; km vs mi |
| 5 | Error Prevention | 3 | Delete Template… directly above Start |
| 6 | Recognition Rather Than Recall | 3 | Previous values inline, prefilled; badges must be learned |
| 7 | Flexibility and Efficiency | 3 | Templates, presets, +15s; no one-tap start of today's template |
| 8 | Aesthetic and Minimalist Design | 2 | Same stat-strip + card grammar everywhere; NEW BEST inflation |
| 9 | Error Recovery | n/a | No error states captured |
| 10 | Help and Documentation | 3 | Tour, What's New, Feedback, inline notes |
| Total | | 25/36 | Acceptable (69%) |

## Design Specificity Verdict
Authored, not interchangeable: Expanded Black type, family-coloured muscle figures, one violet, segmented rings, Paper-style set table. Weakness: structural sameness — title → three-stat strip → card list on 7+ screens; Progress is one card ×5; few screens have a single focal point.

## Priority Issues
1. [P1] End/cancel/delete controls crowded and placed inconsistently — live header: minimize, red Cancel, title, Finish; cardio adds Pause + End Cardio (Finish vs End Cardio unclear); template detail Delete Template… above Start. Fix: one bottom finish place; quieter Discard away from minimize; clear cardio labels; delete into Edit/menu. Command: layout, clarify.
2. [P2] Workout tab leads with dashboard; two equal violet primaries; templates below the fold; "8 Last week" lacks noun. Fix: next-template hero with one Start; Lifting/Cardio secondary; shrink This week. Command: layout / shape.
3. [P2] Finish receipt buries the new best below six stat tiles and ends on "Last Push Day ↓70%". Fix: lead with new bests; one-line stats; drop/neutralise unflattering comparison for partial workouts. Command: delight, layout.
4. [P2] One visual grammar for everything — dashed outline means add / unlogged value / today / empty; NEW BEST on nearly every card; stat strip opens 7 screens; bold Choose equipment on each unassigned exercise. Fix: dashes only for unlogged values; badge only where the record happened; per-screen heroes. Command: distill, quieter.
5. [P2] Accessibility sizes: week strip drops minutes (deliberate, WeekWidget.swift:76) leaving tall empty slabs; rest slab ~¼ screen; Lifting|Cardio system segment doesn't grow; template muscle row collapses. Fix: vertical day list, one-line rest slab, Look pill segment. Command: adapt, audit.

## Persona Red Flags
- Casey (one-handed mid-set): Finish top-right; Cancel beside minimize; template start needs scroll.
- Sam (accessibility): empty week slabs; fixed segment; cryptic chips; logged vs draft shown by outline only (verify VoiceOver); Progress metric pill label "Metric" (known).
- Alex (power user): no one-tap today's template; Choose equipment buttons to scroll past.

## Minor Observations
- Template detail repeats exercise name as machine name.
- Volume 4,907.01 lb (comparison) vs 4,907 (list).
- km in History/live cardio vs mi in Progress with U.S. customary (maybe D52 as-entered).
- Light mode: heavy solid-black tiles, badges, switches.
- "Test data · set up zones" tiny underlined link.
- Motion & Fitness permission alert over the live workout at first start (simulator).
- Yellow "New best" sits under the Previous column.
- Workout-detail captures were mid-transition (capture timing, not an app bug).

## Questions to Consider
- One big "Next: Push Day" card on the Workout tab?
- Does the home of a set log need a dashboard?
- Finish screen = just your new bests?
- Same place and gesture to end every session?
- NEW BEST once per workout?
