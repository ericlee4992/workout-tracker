# S2 — Five tabs: Today · Train · History · Progress · Profile

Type: change
Status: **in review** (2026-11-07) — Codex round 1; merge waits for the deferred Phase 1 test run
Blocked by: S1
Implementer: Claude; Reviewer: Codex (visible Orca terminal), to "clear".
Branch: `ericlee4992/soft-02-tabs`, stacked on S1 (`ericlee4992/soft-01-look`, not yet in `main`).
Spec: [soft-redesign](../spec.md). Decisions: D68 (reopens D63's tab list and "Settings stays behind the Workout tab's
gear").

## Goal

Replace today's tabs (Workout · History · Gyms · Exercises · Progress) with layout A from the prototype.

## Scope

- **Today** (new, first tab): this week as **day rings** (round 5 — today's date on a black capsule; inside the ring a
  black disc with a dumbbell on lifting days, a runner on cardio-only days; header "3 workouts this week"; AX sizes one
  row per day), the **Training** card (the next template with Start, and Start Lifting / Start Cardio), and the
  day's workouts. In Phase 1 the rings show training only (no calorie fill); food parts arrive in N5. Nothing ships
  before N5 (D76), so no tester sees the training-only version.
- **Train:** the top bar switches **Templates | Gyms | Exercises**. Templates = the current Workout tab's template
  list, New Template…, Ask AI. Gyms and Exercises are today's tabs moved here unchanged.
- **History:** stays a tab (the user: "I want to keep it"); restyled in S1, journal in S4.
- **Progress:** stays a tab (S4 extends it).
- **Profile** (new tab): the account (sign-in, training profile — today's `ProfileView`), then everything in Settings
  (units, appearance, rest alarm, heart rate, Ask AI, export/import, feedback, About). The Workout tab's gear goes
  away. Profile's "Training" list of History / Gyms / Exercises is **dropped** in layout A (they are tabs) — confirm.
- No floating **+**. The **Log food** pill above the tab bar on Today is Phase 2 (N5).
- **Deep links and state:** `RootView`'s tab enum, launch arguments used by the UI tests (`gyms`, `exercises`,
  `progress`), the active-workout presentation, the What's New and tour entry points, Live Activity "open" actions.
- **Tour:** the onboarding tour's steps that point at tabs are rewritten for the new tabs (new strings listed).

## Acceptance

1. Five tabs in the order above at default and AccessibilityL; each opens where the old equivalent did.
2. Starting, minimizing and resuming a workout from Today and from Train behave as from the old Workout tab.
3. Every Settings row is reachable from Profile; no row lost (checklist against today's `SettingsView`).
4. Gyms / Exercises inside Train keep their flows (GymsFlows, Exercises UI tests pass, routed through Train).
5. The tour and What's New still open and point at the right tabs.
6. Captures of Today, Train (three segments), Profile; Codex clear.

## Verification scope

Shared navigation → trace callers of the tab enum and launch routes; run CoreLoop, Gyms, Exercises, Settings, Tour,
What's New, Progress, History UI classes and the workout lifecycle unit tests. Escalate to full UI only if routing
changes cannot be bounded.

## Code map

- `WorkoutTracker/App/RootView.swift` (tab enum `:31`, `tabItem`s `:56–76`, launch routes `:145–149`).
- `Features/Start/StartWorkoutView.swift`, `WorkoutHomePieces.swift` (becomes Train → Templates and Today's Training).
- `Features/Settings/SettingsView.swift`, `Features/Account/ProfileView.swift` (merge into Profile).
- `Features/Onboarding/Tour.swift`. Prototype: `Screens/Soft/SoftTodayScreen.swift`, `SoftTodayTop.swift`,
  `SoftRound3Screens.swift`, `SoftProfileAndAdd.swift`.

## Progress

- **2026-11-07 — implemented.** `RootView`: tabs Today · Train · History · Progress · Profile (native `TabView`,
  not the prototype's drawn bar), default Today. `Features/Train/TrainView.swift`: `TrainSection`, the segmented
  `TrainSwitcher` in each root page's principal bar slot (`InlineTitleOrTrainSwitcher`, replacing the fading inline
  title in StartWorkoutView, `gymsInlineTitle`, `exercisesInlineTitle`); only the chosen part exists (keeping all
  three alive left hidden parts' navigation stacks in the accessibility tree — two `addExercise` buttons).
  `Features/Today/`: day rings (training only; dashed past, faint ahead, a disc with a dumbbell / runner on days
  trained), Training (Resume, or Up next = the template done longest ago with its own Start, plus Start Lifting /
  Start Cardio — same ids as Train's), Today's log (rows open the workout in History). Profile =
  `SettingsView(title: "Profile")`; the Workout tab's gear is gone. Tour: `TourStep.Tab.profile`, the settings step
  shows Profile; RootView applies the tour's first step on appear (the tour's sample app is a fresh RootView).
  Launch routes `PROTO_SCREEN=gyms|exercises|train|progress|profile`.
- **New strings:** tab labels Today, Train, Profile; "Templates" / "Gyms" / "Exercises" (switch); Today: "This week",
  "N workouts", "Worked out", "Training", "Up next", "Start", "Last done <date>", "Not done yet", "No templates yet",
  "Make one in Train.", "Today's log", "Nothing logged yet today.", AX rows "Rest day" / "Ahead"; tour caption "Your
  profile: units, appearance, AI and backups — and this tour again."; Settings' page title "Profile". Open to veto.
- **Profile's "Training" list** (History / Gyms / Exercises) does not exist in the app (it was a prototype idea), so
  nothing to drop.
- **UI tests moved to the new tabs:** `WorkoutTrackerUITests/TabNavigation.swift` (`openTrain(_:)`,
  `openProfile()`); 31 files rewritten mechanically (Workout/Gyms/Exercises tab taps, the `openSettings` gear), the
  four per-file `tab(_:)` helpers, the tour test's spots (read on Train; `settings` = the Profile tab).
- **Verified:** `build-for-testing` exit 0; captures Today / Train / Train→Gyms / Profile light and dark (checked);
  UI `FloodlightTourUITests/testShowTourFromSettings`, `GymsFlowsUITests/testDeleteGymIsConfirmedAndRestorable`,
  `CoreLoopUITests/testCoreLoopFromEmptyStoreToOneTapRepeatSet` **3/3 passed** (third run; the first two runs found
  the tour's first tab and the duplicate `addExercise`, both fixed). The full capture + core-flow run is deferred
  with S1's (the user).

## Comments
