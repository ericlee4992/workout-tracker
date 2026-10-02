You are the independent reviewer (AGENTS.md T6) for public-beta ticket 02 (onboarding: a welcome page, then a guided
tour of the real app on temporary sample data). Claude implemented it. Repository:
/Users/ericlee06/orca/workspaces/Health App/public-beta, branch ericlee4992/beta-02-onboarding.
Diff under review: `git diff main..HEAD` (main = 68e2a99).

Read first: AGENTS.md; work-record/public-beta/issues/02-onboarding.md (design, the user's choices, the isolation
finding and design, implementation, evidence); work-record/public-beta/spec.md → Onboarding and Q8b; D60 in
docs/DECISIONS.md; .claude/skills/ios-design/SKILL.md and its REVIEW.md (screen review rules); DEVELOPMENT →
Verification scope. Captures: work-record/public-beta/captures/02/ (welcome-tour-*.png sheets and per-step PNGs).

The central safety claim: the tour can never reach the user's real data or system state. It runs RootView on an
in-memory sample ModelContainer (TourSampleStore), blocks every tap except Next/Skip (a tap on the highlight
advances), never opens a workout, camera, AI, Export, a sheet or Settings, and returns to the user's store.
Every system-side guard in this app is keyed to `-uiTestReset`, not to the store (see the ticket's isolation finding:
HealthKit saves, Live Activity, the fixed rest-notification identifier, UserDefaults/Keychain, OpenAI). Try hard to
break that claim: any path by which, during a tour, a workout screen opens, an unfinished workout is recovered,
something is written to the real store/defaults/keychain, a notification/Live Activity/HealthKit/Watch/location
session starts, a sheet or menu opens under the overlay (VoiceOver, keyboard, hardware buttons, Siri/App Intents,
Lock Screen commands, deep links, scene restoration, backgrounding mid-tour), or the sample container leaks or
persists. Check also: the welcome gate (`shouldShowWelcome`, `-uiTestOnboarding`, `-uiTestOnboardingFresh`) and
that ~230 existing UI tests cannot see the welcome; `DesignSampleFixture.seed(launchVariants:)` keeps every existing
fixture behaviour when true; the anchors/scroll hooks in StartWorkoutView, GymsView, HistoryView, ExercisesView don't
change behaviour without a tour (the ScrollViewReader wrap, conditional modifiers and view identity); RootView's
recover guard; Settings → Show Tour and its alert; accessibility (VoiceOver order/focus, Dynamic Type — the known
AccessibilityL step-6 issue, Reduce Motion); the ios-design rules and tells; test adequacy and the regression
scope; the three pre-existing UI failures' attribution (the ticket says they fail identically on main).

Rules: do not modify any file except the report; no phone, Apple account or ~/WorkoutTracker-Backups writes; if you
run the app or tests, use only the simulator WT-Onboarding (2CEC4AD8-F702-421F-B3B2-D68C302A3453). Write the report
to work-record/public-beta/codex-review-02.md: numbered findings with severity (P0 data loss … P3 nit), file:line,
the failure scenario, a suggested fix; then a last line that is exactly "Verdict: clear" or "Verdict: not clear".
