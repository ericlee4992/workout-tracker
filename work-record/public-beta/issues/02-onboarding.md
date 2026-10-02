# 02 — Onboarding walkthrough

Type: task
Status: in progress — **scope revised 2026-10-02**: welcome page + guided tour on sample data (spec Q8b); the
walkthrough prototype below is superseded except its page 1
Blocked by: — (listed after 01 for order only: it needs no server and no paid team; started while 01 waits on
Apple's enrollment, the user's go-ahead 2026-10-02)
Implementer: Claude (the user asked Claude to start it, 2026-10-02); Reviewer: Codex, in a visible Orca terminal.
Branch: `ericlee4992/beta-02-onboarding` off `main`.
Spec: [spec.md](../spec.md) → *Onboarding*. Decision: D60. Design: ios-design skill, Floodlight (D59).

## Goal

New testers learn the app in under a minute: a skippable first-launch walkthrough, replayable from Settings.

## Scope

- Four or five pages: (1) **Stacked — Know your numbers. Every machine. Every gym.** (2) logging a set in a live
  workout; (3) gyms and machines — each machine remembered, Scan Machine; (4) history and records; (5) AI and the
  account. Page 5 ends with **Get started** until ticket 03/04 add Sign in with Apple / Google / Not now there.
- Skip on every page; swipe and buttons both work.
- Shown automatically only when the store has **no workouts** and the tutorial version flag (`@AppStorage`,
  versioned) is unset; the developer's phone does not see it automatically. **Settings → Show tutorial** replays
  it any time.
- Illustrations or sample-data screens only — never the user's data. No network.
- Dynamic Type through AccessibilityL, VoiceOver order and labels, Reduce Motion (no parallax/auto-advance).

## Design (ios-design skill, steps 1–4)

**Job, state, bold element.** One state per page (the composition does not change with data; it shows no user
data). *On first launch, each page exists so a new tester learns one idea of the app and moves on in one tap; the
eye lands on the page's headline (top-leading, the largest content type).* The runner-up is the one accent-filled
control, **Continue** / **Get started**, in the thumb zone; the illustration is subordinate to the headline (it
shows, the headline says). **Skip** is a plain text button, top-trailing (chrome, not a call to action).

**Pages (proposed copy — every string is the user's decision):**

| # | Headline | One line | Illustration (sample content, never the user's data) |
|---|---|---|---|
| 1 | Stacked | Know your numbers. Every machine. Every gym. | the weight-stack glyph, the five muscle families |
| 2 | Log a set in a tap | Weight, reps, check. Rest starts on its own. | three set rows, one done, the rest bar |
| 3 | Every machine remembered | Each gym keeps its machines and your numbers on them. | a gym's machine list; Scan Machine |
| 4 | Watch your numbers climb | History, records and new bests — per machine. | a best-set figure, a new-best mark, a week's families |
| 5 | AI does the setup | Scan a machine. Ask for a week of templates. | the Scan Machine and Ask AI rows |

Buttons: **Continue** (pages 1–4), **Get started** (page 5; tickets 03/04 replace it with Sign in with Apple /
Google / Not now), **Skip**. Settings row: **Show Tutorial**.

**Three directions (structure, not colour).** Prototype: launch argument `-onboardingPrototype` (DEBUG only)
opens the walkthrough with an A/B/C switcher.

```
A  Showcase                    B  Poster                      C  One page
┌──────────────────────┐       ┌──────────────────────┐       ┌──────────────────────┐
│                 Skip │       │ ●○○○○           Skip │       │                 Skip │
│ ┌──────────────────┐ │       │ LOG A                │       │ Stacked              │ ← largest
│ │  illustration    │ │ ← 50% │ SET IN               │ ← 40% │ Know your numbers…   │
│ │  (panel, sample) │ │       │ A TAP                │  hero │ ┌──────────────────┐ │
│ └──────────────────┘ │       │ Weight, reps, check… │       │ │ ◉ Log a set…     │ │
│ Log a set in a tap   │ ← bold│  ┌───────────────┐   │       │ │ ◉ Every machine… │ │ ← 4 rows,
│ Weight, reps, check… │       │  │ illustration  │   │ ← 30% │ │ ◉ Watch your…    │ │   one list
│        ● ○ ○ ○ ○     │       │  └───────────────┘   │       │ │ ◉ AI does the…   │ │
│ [     Continue     ] │ thumb │ [     Continue     ] │ thumb │ [   Get started    ] │ thumb
└──────────────────────┘       └──────────────────────┘       └──────────────────────┘
 5 swiped pages; the            5 swiped pages; a giant         no paging: one screen,
 illustration leads the         Expanded Black headline is      the four ideas as one list
 eye, the title names it        the page; small illustration    (Apple's "What's New" shape)
```

**Tells.**
- Same container on everything — absent: one panel per page holds the illustration (a group: sample rows); text
  sits on the ground.
- A chip where a caption would do — absent.
- All-caps label above every section — B's headline is set in capitals deliberately as the poster itself (one per
  page, the bold element), not as a label; A and C absent.
- Middle-dot metadata — absent (sample rows use "135 lb × 8").
- Accent on so many things it stops marking — the accent is the Continue button and, as a state, the done set
  and the page indicator's current dot; the illustrations use family colours for families only.
- Equal-weight stacked blocks — absent in A/B (headline leads); C's four rows are a list of like items, deliberate.
- Phone-sized website — C is the risk (hero + list); kept to one viewport at Default.
- More than the job above the fold — each page: headline, one line, one illustration, one button.
- A control dressed as the primary — absent; Skip is plain text.
- Layout only at default size — each page scrolls inside the pager at accessibility sizes; the button stays
  pinned; checked at AccessibilityL in the captures.

## UI first

Mock the pages with sample content and show Default and AccessibilityL captures, light and dark, for the user's
approval before wiring the first-launch gate (the user's standing preference).

## Progress

### Prototype — 2026-10-02 (Claude)

Branch `ericlee4992/beta-02-onboarding` from `main` `68e2a99`. `Features/Onboarding/`: `OnboardingPages.swift`
(content, proposed copy), `OnboardingView.swift` (A/B/C), `OnboardingIllustrations.swift` (sample content from Look
tokens), `OnboardingPrototype.swift` (DEBUG-only host with an A/B/C switcher, launch argument
`-onboardingPrototype [A|B|C]`; `WorkoutTrackerApp` shows it instead of `RootView` only in DEBUG). No first-launch
gate, no Settings row, no data touched yet. Capture test `FloodlightOnboardingUITests` (3 tests: A and B every page
light/dark Default and dark AccessibilityL; C light/dark and AccessibilityL top/scrolled) on simulator
**WT-Onboarding** `2CEC4AD8-F702-421F-B3B2-D68C302A3453`: **3/3 passed**, 34 captures; sheets in
[captures/02-prototype/](../captures/02-prototype/).

Found and fixed while capturing: an identifier on the page container overrode every child's (SwiftUI passes it
down) — removed; Skip's hit area was 35 × 20 pt — now ≥ 44 × 44 inside the button; the stack glyph filled as a
solid blob — replaced by the app icon's dumbbell; A's pages left the lower third empty — centred in the viewport;
B's first page repeated its headline — now one word, STACKED.

## Acceptance

- [ ] User-approved captures recorded under `../captures/02/`.
- [ ] First launch on an empty store shows the walkthrough once; relaunch does not; a store with workouts never
      shows it automatically; Settings → Show tutorial always does.
- [ ] Skip and finishing both set the flag; nothing else changes.
- [ ] Targeted UI tests for the gate and replay; unit test for the gate's predicate.

## Verification scope

DEVELOPMENT targeted scope: the new tests, the Settings UI tests, a launch-path UI test on an empty and a seeded
store; captures. No full suite.

## Comments

**2026-10-02, the user, on seeing the A/B/C prototype:** "is it possible to do a tutorial something like that
actually takes user click thru the app, so that user can see where to actually find features and know what they
do?" Then chose: **tour on sample data** (over point-only on the real app, and learn-by-doing) and **one welcome page,
then the tour** (over tour only, and intro pages + tour). Recorded as spec Q8b and in D60. Next: the isolation design
(every effect outside the store), then a UI-first prototype of the tour's look on the existing sample world.
