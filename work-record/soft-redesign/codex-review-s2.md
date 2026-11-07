# S2 independent review — five tabs

Reviewed 2026-11-07 by Codex; implementation by Claude.

## Scope

Requested diff: `git diff 64401d2..5c97a55`, S2 only, stacked on S1. Branch `ericlee4992/soft-02-tabs`. Review began at `421b8da`; HEAD moved to `2966c66` during setup. The only changes after `5c97a55` are the review prompt and STATE, so the reviewed and tested product/test code is unchanged. No implementation files were edited, committed or pushed.

Read the S2 ticket, D68/D63, guided-tour ticket/header, relevant callers and UI-test changes, and the approved prototype's layout A/Today/Train implementation. Native TabView, training-only Today, and deferral of Train's internal reorder to S3 are accepted differences. Earlier design proposals and the ios-design skill were not used.

## Spec findings

### 1. P2 — Keep the Train switch out of pushed detail pages

**Location:** `WorkoutTracker/Features/Train/TrainView.swift:46`, `:75–76`; changed shared title helpers at `WorkoutTracker/Features/Exercises/ExercisesView.swift:449` and `WorkoutTracker/Features/Gyms/GymsPieces.swift:769`.

The Train binding is injected into the entire selected navigation subtree. The shared `exercisesInlineTitle` and `gymsInlineTitle` helpers are also called by `ExerciseDetailView.swift:112`, `GymDetailView.swift:87`, `MachineDetailView.swift:57` and `MachineDeletion.swift:112`. Those destinations inherit the binding and therefore replace their own principal title with Templates / Gyms / Exercises. For example, open Train → Gyms → a gym → a machine: the machine's inline title is replaced, and choosing a different segment destroys that pushed stack. This contradicts the new TrainView header's explicit root-only behavior (“leaves with a push”) and S2's requirement to move existing Gyms/Exercises flows unchanged.

**Fix:** opt into the switch only at the three root toolbar call sites, or clear/narrow the binding at destination boundaries. Preserve ordinary destination titles. Adjust `TabNavigation.swift:14–16` so tests that re-enter Train with a retained push return to the root before selecting a section; otherwise fixing the product will expose the helper's assumption that the switch exists on every page. Verify roots and pushed pages at default/AccessibilityL, including switching away and back.

### 2. P2 — Invalidate Today when the calendar day changes

**Location:** `WorkoutTracker/Features/Today/TodayView.swift:49`, `:76–77`, `:147`.

The header, weekly summary and “Today's log” read `.now`/`Calendar.current` only during view evaluation. There is no observable date, TimelineView, day-change/timezone notification or activation refresh feeding this screen. With no active workout or store mutation, leaving Today visible across midnight leaves yesterday's date pill and finished workouts displayed under “Today's log” until another event happens to recompute it. A timezone change can similarly leave day membership stale. This is a source-traced issue; the review did not change the machine clock to reproduce it.

**Fix:** keep one observable current-date/calendar snapshot for the screen and refresh it at the local day boundary, on foreground activation and significant calendar/timezone changes. Use that snapshot consistently for the header, week and log. Exercise midnight/week rollover and timezone changes with an injected clock/calendar. Workouts belonging to their **start date** is correct and matches History; do not change that rule.

## Standards / verification findings

### 3. P2 — Complete the UI-test navigation rewrite

**Locations:** `WorkoutTrackerUITests/FloodlightSettingsUITests.swift:190,212`; `RedesignScreenshotUITests.swift:67,76`; `FloodlightWorkoutTabUITests.swift:179`; `AskAIUITests.swift:160,237,260,267`.

Settings is now the Profile tab root, but the settings persistence tests still tap the first navigation-bar button as if it were the old Back button. There is no parent page to return to. The unit-system capture helper and appearance propagation test make the same assumption; one also explicitly queries the removed `navigationBars["Settings"]`. Separately, AI flow tests still wait for `navigationBars["Workout"]` after saving/cancelling routines, although the Templates root is now titled Train. These stale assertions prevent the tests from reaching the persistence, unit-retention, theme-propagation and gym-memory assertions they are meant to verify.

**Fix:** leave Profile through an explicit Today or Train tab action, reopen Profile where the test intends a return visit, and update AI destination assertions to Train or a stable Templates-root identifier. Preserve the assertions that follow rather than deleting them. Search remaining navigation-title and positional Back-button assumptions, not just old tab names. Rerun the affected tests after the rewrite.

## Other checked paths

- Root presents active workouts and finish confirmation above the tabs. Today and Train use the shared workout-start flow/coordinator; Today resolves the remembered gym through `GymSelection.resolve`, including nil/archived → No gym, and resumes through `WorkoutSession.resumableWorkout`.
- History's empty-state Start Lifting selects Train/Templates and sets the request; Templates consumes it on appearance/change. Finish → View in History and Today's finished rows set History's target. Today's oldest/never-run template selection is consistent with the stated ordering.
- The selected Train branch is the only one constructed. Recreating a branch resets its transient navigation/local state, while remembered gym selection is restored from preferences. Root-owned active workout/runtime survives this recreation. Normal presented sheets/dialogs prevent switching underneath them; the exposed switch on pushed pages is finding 1.
- Tour first-step selection is explicitly applied on appearance; subsequent steps map Workout/Gyms/Exercises to the corresponding Train section, and Settings to Profile. Existing tab snap-back and sample-world side-effect guards remain. Profile wraps the existing Settings destinations/sheets in a NavigationStack; settings rows, sign-in/account routes and What's New entry remain.
- The remaining per-file `tab(_:)` callers target History. Native TabView owns visibility of Today versus Train; the duplicate identifiers on those two tabs are not the former opacity-hidden multiple-stack implementation. Runtime checks below state the actual exercised scope.

## Independent verification

Xcode 27.2 (27B52), iOS 27.0 simulator WT-iPhone27 (`47D21838-69A6-4BCB-AE90-B0D9C0AAA70B`). Build and test artifacts are isolated under `/tmp/codex-s2/`.

- `build-for-testing`: **exit 0**, `TEST BUILD SUCCEEDED`; xcresult build status `succeeded`, **0 errors**, **31 warnings**. Evidence: `/tmp/codex-s2/build.log`, `/tmp/codex-s2/build.xcresult`.
- Requested UI run: **in progress at this checkpoint**; unified exec session `91664`, xcodebuild PID `89177`. Log `/tmp/codex-s2/ui.log`, result `/tmp/codex-s2/ui.xcresult`. Three workers, following the project's multi-class UI policy. Final counts/failures will replace this line before delivery.
- `git diff --check 64401d2..5c97a55`: exit 0.

Commands (stdout/stderr redirected to the logs above):

```sh
xcodebuild -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,id=47D21838-69A6-4BCB-AE90-B0D9C0AAA70B' \
  -derivedDataPath /tmp/codex-s2/DerivedData \
  -resultBundlePath /tmp/codex-s2/build.xcresult build-for-testing

xcodebuild test-without-building -project WorkoutTracker.xcodeproj -scheme WorkoutTracker \
  -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,id=47D21838-69A6-4BCB-AE90-B0D9C0AAA70B' \
  -derivedDataPath /tmp/codex-s2/DerivedData \
  -resultBundlePath /tmp/codex-s2/ui.xcresult \
  -parallel-testing-enabled YES -parallel-testing-worker-count 3 \
  -only-testing:WorkoutTrackerUITests/FloodlightTourUITests \
  -only-testing:WorkoutTrackerUITests/FloodlightSettingsUITests \
  -only-testing:WorkoutTrackerUITests/HistoryTemplateUITests \
  -collect-test-diagnostics never
```

The full capture/core-flow run remains deferred by the user. The broader Gyms/Exercises, What's New, Progress and workout-lifecycle coverage is not claimed by this review. Re-review the fixes and their targeted evidence before clearance; the deferred combined Phase 1 acceptance remains a separate merge gate.

Spec: **2 findings**. Standards/verification: **1 finding**. No unrelated modernization requested.

Verdict: not clear
