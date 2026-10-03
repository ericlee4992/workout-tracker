# 02 — Onboarding walkthrough

Type: task
Status: resolved — implemented, **Codex clear (2 rounds)**, merged to `main` (`4823d46`, fast-forward, the user's
go-ahead) 2026-10-02. Scope revised 2026-10-02: welcome page + guided tour on sample data (spec Q8b)
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

### Guided tour prototype and the isolation finding — 2026-10-02 (Claude)

`Features/Onboarding/Tour.swift`: `TourStep` (8 steps, proposed captions), `TourController` (@Observable),
`.tourAnchor(_:)` / `.tourAnchor(_:when:)` (each control reports its **global** frame into the controller — preferences
do not leave toolbar items or full-screen covers), `TourOverlay` (dims all but the highlighted control with a violet
outline, a measured caption card above or below it with "n of 8", **Skip Tour** and **Next / Done**; swallows every
other tap; VoiceOver focus moves to the caption; Reduce Motion drops the animation). `RootView` draws the overlay and
selects each step's tab; `StartWorkoutView` scrolls the highlighted control into view. Anchors: gym picker, the Start
pair, the first template tile, Ask AI, the Settings gear, the first gym card, the first History row, the first
Exercises row. Prototype: DEBUG launch argument `-tourPrototype` on the throwaway UI-test store
(`-uiTestReset -uiTestDesignSample -uiTestDesignHistory -uiTestDesignGyms -uiTestDesignExercises`).
`FloodlightTourUITests` (dark, light, dark AccessibilityL; 8 steps each, then the tour ends): **3/3 passed**; sheets in
[captures/02-tour-prototype/](../captures/02-tour-prototype/). First run highlighted whole lists on steps 5–7 and only
the Templates header on step 3 — retargeted to first rows / the first tile.

**Isolation finding (side-effect inventory, 2026-10-02).** Every system-side guard in the app is keyed to
`-uiTestReset`, not to the store in use. A sample store in a normal launch would still drive the real HealthKit,
ActivityKit, notifications, Watch link, audio, location, Keychain, UserDefaults and OpenAI. Worst paths if the tour
opened a workout screen: `coordinator.monitor(for:)` ends a running real workout's heart-rate session and saves a
partial HKWorkout (`WorkoutHeartRateCoordinator.swift:109-110`); stop/cancel saves an HKWorkout even for a cancelled
sample (`HealthKitHeartRateProvider.swift:138-148`, `ActiveWorkoutView.swift:852`); a new Live Activity ends the real
card (`WorkoutActivityController.swift:165-171`); the rest notification has one fixed identifier
(`RestTimer.swift:32-67`); Export overwrites the real "last export" (`ExportView.swift:294-295`); Ask AI / Identify use
the real key; an unfinished sample workout is auto-opened by `RootView.recoverActiveWorkout`.
`DesignSampleFixture.seed(in:)` has no store guard (seeds any store without workouts).

**Design that follows (proposed for implementation):** the tour **points and explains; it never performs**. The
overlay blocks every tap except Next / Skip (a tap on the highlight advances; it is not passed to the control); the
tour itself only selects tabs, scrolls, and (if added) pushes store-only pages; **no step opens a workout, the camera,
AI, Export, a sheet or Settings**. The sample world: a fresh **in-memory** `ModelContainer`
(`ModelConfiguration(isStoredInMemoryOnly: true)`), catalog reconciled, `DesignSampleFixture.seed(in:)` base only (no
live, no settings seed), created when the tour starts and released when it ends; the real `RootView` is rebuilt on
the user's own container afterwards. Defence in depth while a tour runs: `RootView.recoverActiveWorkout` is skipped;
`DesignSampleFixture.seed` asserts an in-memory store; the tour does not start while a real workout is running
(it offers "Finish your workout first"). Tests: a unit test that the sample container is in-memory and the real store
is untouched after a tour; a UI test that every non-highlighted control is blocked.

### Implementation — 2026-10-02 (Claude)

The user's choices (2026-10-02): the tour on sample data; one welcome page, then the tour; keep the 8 steps with a
non-interactive **picture of logging** on step 2; the captions as proposed.

- **Removed** the A/B/C walkthrough prototype (`OnboardingView`, `OnboardingPages`, `OnboardingPrototype`, its UI
  test) and the `-tourPrototype` flag. `OnboardingIllustration` keeps only `.welcome` and `.logging`.
- **`WelcomeView`**: the dumbbell and the five families, **Stacked**, the tagline, **Show Me Around** (primary) and
  **Skip**; a full-screen cover over the real app.
- **`OnboardingCoordinator`** (app level, `@Observable`): `shouldShowWelcome` — not answered (`onboarding.welcomeSeen.v1`),
  no workouts, and under `-uiTestReset` only with `-uiTestOnboarding` (so the ~230 existing UI tests never see it;
  `-uiTestOnboardingFresh` clears the flag for a test); `startTour(realContext:)` refuses while a real workout runs
  ("Finish your workout first."), else builds the sample world and starts the tour; `endTour()` drops both.
- **`TourSampleStore.make()`**: an **in-memory** container, the bundled catalog, `ensureUnitPreference`, and
  `DesignSampleFixture.seed(…, launchVariants: false)` — the new parameter makes the seed ignore every launch-argument
  variant (no live workout, no Gyms/History/Exercises extras), whatever the app was launched with.
- **`WorkoutTrackerApp`**: while a tour runs, `RootView().modelContainer(sample).environment(tour).id(sample)`;
  otherwise the user's `RootView` with the welcome cover. `RootView.recoverActiveWorkout` does nothing in the tour.
- **Settings → Help → Show Tour** (`showTour`), with an alert when the tour cannot start.
- The step-2 picture is decorative, not hit-testable, and left out at accessibility sizes so the caption and its
  buttons stay on screen.

**New strings (the user approved the captions; these are new and listed for the user):** Show Me Around · Skip ·
Help · Show Tour · Finish your workout first. · The tour could not start. · Skip Tour · Next · Done · "n of 8".

**Tells (revised design).** Same container everywhere — absent (one caption card; the welcome text sits on the
ground). Chips — absent. All-caps labels — absent. Middle dots — absent (sample "Life Fitness · Signature" in the
picture is the app's own machine-detail format). Accent overuse — the accent is the welcome's primary button, the
tour's Next and the highlight outline (one per step; the outline marks the step's one subject). Equal-weight blocks —
absent. Phone-sized website — absent. Above the fold — one caption per step. Control dressed as primary — Skip / Skip
Tour are plain text. Default-size-only — captured at AccessibilityL: every caption and button whole; **known:** at
AccessibilityL step 6 the highlighted History row sits partly under the tab bar (History does not scroll it up).

**Evidence (simulator WT-Onboarding, iOS 27):** build exit 0. `OnboardingTests` (unit) **6/6**: the welcome rule
(5 cases), the sample world in memory with the base sample only (6 finished workouts, 0 unfinished, Iron Temple,
3 templates), the user's on-disk store untouched by making it, the tour start/end lifecycle and the welcome flag,
refusal while a real workout runs, Skip remembered. `FloodlightTourUITests` **7/7**: welcome + 8 steps + back on the
user's empty store (dark, light, dark AccessibilityL; captures), Skip remembered across launches, no welcome with
workouts, the tour blocks the Settings gear and the History tab and a tap on the highlight advances it, Settings →
Show Tour runs on the sample (Iron Temple) and returns to the user's store. Captures: [captures/02/](../captures/02/).

**Adjacent regression run (2026-10-02, WT-Onboarding, load 6.8 → 4.5):** scope per DEVELOPMENT (new feature at the
app root + every screen touched): `WorkoutTrackerTests` (whole target) **930/930**; UI `FloodlightWorkoutTabUITests`
10/10, `FloodlightSettingsUITests` 10/10, `FloodlightGymsUITests` 12/12, `FloodlightExercisesUITests` 10/10,
`ExportUITests` 1/1, `CoreLoopUITests` 8/9, `FloodlightHistoryUITests` 6/8 (exit 65). The three failures, rerun alone
on this branch: `CoreLoopUITests.testModelPickerFiltersAndSearchesDownToOneModel` (:274, "Picking a model should supply
a default label") failed again; `FloodlightHistoryUITests.testCaptureHistoryLightDefault` (:100, "a multi-day series
draws") failed again; `…DarkDefault` passed. **On `main` `68e2a99` (a temporary detached checkout, same simulator):
all three fail at the same lines** (3/3). Not caused by ticket 02; recorded for a separate follow-up (the History
chart passed on 2026-09-29, so likely date-dependent; the model picker is the flake STATE already lists).

## Codex review 02 — response (round 1)

Review: [codex-review-02.md](../codex-review-02.md) — not clear (P1 ×2, P2, P3). All accepted.

1. **P1 — the app under the tour stayed actionable through accessibility.** The tour now renders as a `ZStack` in
   `WorkoutTrackerApp`: the sample `RootView` with `.disabled(true)` and `.allowsHitTesting(false)`, and `TourOverlay`
   above it (no longer an overlay inside `RootView`). **Verified in the accessibility tree** (a throwaway diagnostic UI
   test, deleted): every SwiftUI control under the tour is `Disabled` — VoiceOver and Full Keyboard Access can focus
   but not activate Start Lifting, Start Cardio, Settings, the gym picker — but `.accessibilityHidden(true)` did **not**
   hide them (the tab view is UIKit-backed), so it is not used or claimed. The UIKit **tab bar ignores `.disabled`**
   (its History button stayed enabled): `RootView` now snaps any tab change during a tour back to the step's tab. The
   overlay container carries `.isModal`. Remaining, stated honestly: VoiceOver can *read* the dimmed sample content
   (no activation); a VoiceOver tab switch is reverted at once. Tests: `testTheAppUnderTheTourIsInert` (each control
   `exists && !isEnabled`; taps on Start, the gear and the History tab change nothing; a tap on the highlight advances).
2. **P2 — Next / Skip Tour hit regions.** Both labels now carry `minWidth/minHeight 44`, padding and `contentShape`
   inside the `Button`. Test `testTourButtonsTakeTapsAtTheirEdges` (Next near its top-left and bottom-right edges,
   Skip Tour near its top edge).
3. **P3 — the History highlight under the tab bar at AccessibilityL.** A scroll hook (`ScrollViewReader` with
   `onChange`, then `task(id:)` with a delay and an explicit row id) did not move the `List` under the tour in four
   attempts, so it was removed; the History step now highlights the **month summary card** at the top of History,
   clear of the tab bar at every size (caption unchanged). This changes what step 6 points at — reported to the user.
4. **P1 — the barrier depended on geometry.** `TourOverlay` now draws the dimming and swallows taps for the whole
   tour; with no frame for the current anchor it dims everything and centres the caption (with Skip Tour). Geometry
   only places the highlight and caption. Test `testTapsAtTheVeryStartCannotEscape` taps Start Lifting's spot three
   times immediately after Show Tour: no workout opens.
- Also from the review's notes: the "workout running?" check is now **read-only and fail-closed**
  (`fetchCount` of unfinished workouts; an error refuses with "The tour could not start."). Test
  `testShowTourRefusesDuringAWorkout` (a running workout, minimised; Show Tour → "Finish your workout first.").

**Round-1 fix evidence (final code):** `OnboardingTests` **6/6**; `FloodlightTourUITests` **10/10** (the 7 earlier, now
`testTheAppUnderTheTourIsInert`, plus `testTapsAtTheVeryStartCannotEscape`, `testTourButtonsTakeTapsAtTheirEdges`,
`testShowTourRefusesDuringAWorkout`); `FloodlightHistoryUITests` 7/8 — the one failure is the pre-existing chart check
(:100) recorded above. Captures retaken in `captures/02/` (step 6 = the month card).

**Round 2 (codex-review-02b): clear.** The P3 note — `Tour.swift`'s comment still called the overlay "the only
accessible content" — is corrected (the overlay is the only *activatable* content; the app underneath stays readable to
VoiceOver). Comment-only change after the tested build. During round 2 Codex asked to drive the desktop (Orca computer
use) to test VoiceOver paths; one read-only window listing was approved, further desktop control was declined (it would
drive the user's screen) and the review was relaunched for source and command-line evidence only.

## Acceptance (revised for Q8b)

- [x] Captures of the welcome page and every tour step, Default and AccessibilityL, light and dark, under
      `../captures/02/`; the user saw the prototype and chose the steps, the picture and the captions.
- [x] First launch on an empty store shows the welcome once; relaunch after an answer does not; a store with
      workouts never shows it; Settings → Show Tour always starts the tour (except during a workout, with a reason).
- [x] The tour runs on an in-memory sample world, blocks every other tap, never opens a workout, the camera, AI,
      Export, a sheet or Settings, and returns to the user's own store (unit + UI tests).
- [x] Adjacent suites: unit **930/930**; UI 57/60 — the 3 failures are **pre-existing** (they fail identically on `main`
      `68e2a99` without ticket 02; see below).
- [x] Codex review clear — [codex-review-02b.md](../codex-review-02b.md), round 2, 2026-10-02 (all four round-1
      findings resolved; one P3 comment fixed afterwards). Stated limits: no live VoiceOver / Full Keyboard Access /
      Reduce Motion session, no accessible tab switch at runtime, no forced missing-geometry or scene-restoration run,
      no production-service spies, no device check.

## Verification scope

DEVELOPMENT targeted scope: the new tests, the Settings UI tests, a launch-path UI test on an empty and a seeded
store; captures. No full suite.

## Comments

**2026-10-02, the user, on seeing the A/B/C prototype:** "is it possible to do a tutorial something like that
actually takes user click thru the app, so that user can see where to actually find features and know what they
do?" Then chose: **tour on sample data** (over point-only on the real app, and learn-by-doing) and **one welcome page,
then the tour** (over tour only, and intro pages + tour). Recorded as spec Q8b and in D60. Next: the isolation design
(every effect outside the store), then a UI-first prototype of the tour's look on the existing sample world.
