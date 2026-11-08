# S5 — Today's up next: learn the split, optional "My split", no Start buttons

Type: change
Status: **done — merged into `main`** (`b3c29a9`, 2026-11-08, the user's go-ahead) after Codex round 3 clear
Blocked by: S4 (merged)
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch: `ericlee4992/soft-05-today-up-next` off `main` `40b30d6`.
Spec: [soft-redesign](../spec.md). Decisions: D77 (new); extends D68 (five tabs) and S3's `TemplateStats.dueNext`.

## Why

The user (2026-11-08): Today's Training part repeats Train's Start Lifting / Start Cardio, which Today does not need;
the template card with its Start button is enough — but it should show **what today's template is supposed to be**:
after Pull in a Push / Pull / Legs split, Legs; the same for any split. People without templates, or without a fixed
split, need something useful too.

Today's rule (`TemplateStats.dueNext`, S3) is "the template done longest ago, never-run first". It already follows a
strict rotation, but a rarely used template (Deload, Mobility) or a never-run one (e.g. Ask AI's new week) jumps to
the front, a weekday plan is not a rotation, and someone without templates gets nothing useful.

## The user's decisions (2026-11-08)

- **Pick today's template:** learn the order from history, plus an optional **My split** the user sets in Train
  (ordered templates or weekdays) that Today follows exactly when set.
- **Without templates (or no history yet):** the last workout with **Repeat**, one **Start workout** button, and a
  hint to save a template or Ask AI for a week.
- **When:** a small ticket now, before N1.

## Scope

1. **Today's Training part:** no Start Lifting / Start Cardio when the user has templates — the Up next card with its
   Start button (and Resume while a workout runs, unchanged). Train keeps both Start buttons.
2. **Learned order (domain, pure, unit-tested):** from the finished template workouts of the last ~6 weeks (oldest
   first), take the most recent template T; the suggestion is the template that followed T's previous run (the most
   common follower if they differ, ties to the most recent). Rarely used and never-run templates don't take the slot.
   Fallbacks in order: no usable sequence → `dueNext` among templates used in the window → `dueNext` over all
   templates. A deleted template is never suggested.
3. **"Not today" on the card:** a menu with **Next in order** (skips to the following suggestion for today only) and
   **Choose template…** (any template). The choice lasts until a workout is finished or the day changes
   (`refreshingNow`).
4. **My split (optional), in Train → Templates:** "My split" opens a sheet: **Off** (learned, the default) /
   **In order** (pick and order templates; next = the one after the last done, wrapping) / **By weekday** (assign
   templates to weekdays; a day with none shows **Rest day** on Today with Choose template… still available).
   Stored in UserDefaults as template ids — **a view preference, not workout data: no store change** (so S5 can come
   before N1); a deleted template drops out. Not in export/backup; a reinstall resets it (could move into the store
   with N2 if wanted).
5. **No templates / no history:** a card with the last workout ("Leg Day · Nov 7", its families) and **Repeat** (starts
   a workout with that workout's exercises — reuse Save as Template's mapping without saving a template; to check in
   code, else "Save as template, then start"), **Start workout** (empty), and a one-line hint linking Train → New
   Template / Ask AI. With no workouts at all: Start workout + the hint.
6. Strings listed in Progress before building (e.g. "Up next", "Not today", "Next in order", "Choose template…",
   "Rest day", "My split", "Off", "In order", "By weekday", "Repeat", "Start workout", the hint).

## Acceptance

1. Unit tests: PPL (Push → Pull → Legs → after Pull suggests Legs), Upper/Lower A/B, a rarely used template ignored, a
   brand-new template not taking over, ties, the fallbacks, deleted templates, My split in order (wrap) and by
   weekday (incl. Rest day), and the pin-style decode of the stored split (old/empty data).
2. Today: with templates, no Start Lifting / Start Cardio; Up next shows the learned/split template; Not today works;
   Resume while a workout runs unchanged. Without templates: last workout + Repeat + Start workout.
3. Train: My split sheet — set order / weekdays / Off, persisted across a relaunch.
4. Captures: Today (templates / split / rest day / no templates) and the My split sheet, light/dark, default/AXL.
5. Every UI test that started a workout from Today's buttons right after launch goes through Train (or the card)
   instead; no assertion silently dropped. Codex clear.

## Verification scope

New domain logic → unit tests. Shared start path → **trace every UI test using `startEmptyWorkout` / `startCardio`
after launch** and run those classes plus Today/Train/Tour captures; this is broader than the ticket's size (ask the
user before a run over ~20 min).

## Code map

- `Domain/TemplateStats.swift` (`dueNext`), new `Domain/UpNext.swift` (learned order + split resolution).
- `Features/Today/TodayView.swift` (Training part, `upNext`), `TodayPieces.swift` (the card).
- `Features/Train/TrainView.swift` (My split entry), new `Features/Train/MySplitSheet.swift`.
- UI tests: `WorkoutTrackerUITests/TabNavigation.swift` and callers of `startEmptyWorkout` / `startCardio`.

## Progress

- **2026-11-08 — built** (branch `ericlee4992/soft-05-today-up-next`):
  - Domain: `Domain/UpNext.swift` (`MySplit`, `MySplitStore`, `UpNextOverride`, `UpNext.suggestion/learned/
    nextInOrder/weekday`), `WorkoutTemplateService.repeatWorkout` + `canRepeat`. Unit: `UpNextTests` (13) and
    `WorkoutTemplateTests.repeatStartsTheCapturedStructureWithoutATemplate` — with `TemplateDueNextTests` 25/25.
  - UI: `Features/Today/UpNextReading.swift` (one reading for Today and Train's leading card), Today's
    `TodayUpNextCard` (+ "Not today" menu), `TodayRestDayCard`, `TodayNoTemplateCard`; Start Lifting / Start Cardio and
    the cardio picker removed from Today; `WorkoutStartRequest.repeating`; Train → `My Split…` (`MySplitSheet`).
  - UI-test launches clear `mySplit` / `upNextOverride` with the pins (unless `-uiTestKeepPins`);
    `-uiTestNoTemplates` (sample workouts without templates).
  - UI tests: new `TodayUpNextUITests` (9); `trainStartButton(_:)` in `TabNavigation.swift` replaces 36 direct uses
    of `startEmptyWorkout` / `startCardio` in 15 files (opens Train first when the button is not on screen).
  - **New strings:** "Up next", "Not today", "Next in order", "Choose template…", "Back to plan", "Chosen for today",
    "My split · Last done <date>", "My split", "Rest day", "Nothing in your split today.", "Last workout", "Repeat",
    "Repeat <workout>" (spoken), "Start workout", "Start a workout", "Make a template, or ask AI for a week, in Train.",
    "My Split…", "My Split", "Off", "In order", "By weekday", "Order", "Week", "Add Template", "Rest", and the three
    mode explanations in `MySplitSheet`.
- **2026-11-08 — tested (WT-Floodlight).** Unit `UpNextTests` + `WorkoutTemplateTests` + `TemplateDueNextTests`
  25/25. `TodayUpNextUITests` serial: 9/10 → fixes (the rest-day card's id moved to its title — a container id hid the
  "Not today" menu; My Split stacks its three modes at AX sizes; the no-templates buttons measure full width
  (`fixedSize`) and stack instead of wrapping/truncating; AX captures scroll to the card) → each affected test
  re-run green. Captures checked and sent to the user.
  **Broad check (the user's go-ahead):** 18 classes — every class using `trainStartButton` + `TemplateDetailUITests` +
  `TodayUpNextUITests`, 3 workers: **119/120**. The one failure, `CardioUITests/testCardioAccessibilityCaptureAndSave`,
  failed again alone at `:58` (`cardioTimer` within 10 s after Start in the picker), then passed 2/2 with
  `-test-iterations 2`; the same step fails on and off for the warm-up on `main` since 02:00 (follow-up in S4) and this
  test passed on the `main` build once → intermittent, not S5; added to that follow-up.
- **2026-11-08 — Codex round 1** ([report](../codex-review-s5.md)): 3 × P2, all accepted, fixed:
  (1) a workout finished in this session did not advance Up next (the screen's day snapshot excluded it) —
  `UpNextReading.make` uses the later of the snapshot and the render's clock; (2) Choose template… → Next in order
  restarted from the plan — `UpNext.resolve` continues from the chosen template (a weekday split steps through its
  days); (3) a future-dated finished record cancelled every choice, and expiry used start time — `isCurrent` takes the
  latest COMPLETION not later than now. New unit tests: `UpNextTests.nextInOrderAfterAChoiceContinuesFromTheChoice`,
  `aChoiceExpiresOnARealFinishNotOnFutureHistory`, `UpNextReadingTests.aWorkoutFinishedThisSessionAdvancesTheSuggestion`
  — with the earlier suites **28/28**. `TodayUpNextUITests` gains Choose → Next (Leg → Push); serial warm-up + class **10/10**. Codex round 1's own runs: unit
  25/25, UI warm-up + `CoreLoopUITests` + `TodayUpNextUITests` 19/19.
- **2026-11-08 — Codex round 2** ([report](../codex-review-s5b.md)): #1 and #3 closed; #2 open for the no-history
  case (a new user / fresh AI week / history outside the window: Next in order repeated one template, from a choice
  too). Fixed: the learned chain shows a template not yet shown in that chain (fallback order, then wraps);
  `resolve` seeds the chain with the chosen template. Test `UpNextTests.nextInOrderWalksEveryTemplateWithoutHistory`;
  unit **29/29**; UI serial warm-up + `TodayUpNextUITests` **10/10**.
- **2026-11-08 — Codex round 3 [clear](../codex-review-s5c.md):** the no-history case closed, 0 new findings (its runs:
  unit 17/17 on WT-iPhone27; its reproduction re-run against the fix).
  **Verified:** unit (`UpNextTests`, `UpNextReadingTests`, `WorkoutTemplateTests`, `TemplateDueNextTests`) 29/29;
  `TodayUpNextUITests` 9/9 (+ warm-up); broad check of every class using `trainStartButton` 119/120; captures of every
  Today state and My Split, light/dark × default/AX, checked and sent to the user.
  **Not verified:** a person's VoiceOver pass; the day-boundary refresh driven live (unit-tested, as S4).
  **Known flaky:** `CardioUITests` `:58` cardio start (`testCardioAccessibilityCaptureAndSave`, the warm-up) — S4
  follow-up, also on `main`.

## Comments
