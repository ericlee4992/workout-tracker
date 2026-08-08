# 14 — Rest timer: durations, persistence, notifications

**What to build:** Rest per D13/D22. Precedence: per-exercise override (persisted, editable from the entry's menu: separate warmup/working values) → global defaults (2:00 working / 1:00 warmup, editable in settings). Completing a set starts the timer with the duration for that set's type (failure sets use the working duration, D22); the absolute end time persists on Workout.restEndsAt so relaunch mid-rest reconstructs the countdown. Un-completing the set that started the current timer cancels it. The permission-requested marker lives in app preferences. One pending local notification at a time: starting a new timer, skipping, or ±time replaces/cancels it. Notification permission first requested after the first-ever completed set.

**Blocked by:** 07.

**Status:** resolved

- [x] Timer logic behind injected clock + notification-scheduler protocols; unit tests use fakes (permission prompt itself: one manual check)
- [x] Tests: warmup vs working duration selection; override beats global; +15s/skip reschedules/cancels the pending notification; new completion replaces prior timer; relaunch mid-rest resumes correct remaining time; timer end while suspended → no stale UI
- [x] Un-completing a set does not start a timer

## Comments

Resolved 2026-08-08. `Domain/RestTimer.swift` provides a clock- and notification-injected
state machine. Duration precedence is the latest per-exercise override over editable global
defaults (warmup separate; working and failure shared). Completing a set persists an absolute
`Workout.restEndsAt`, records the source in the additive CloudKit-safe optional scalar
`Workout.restStartedBySetID`, requests notification permission once after the first-ever
completion, and replaces the single pending local notification. +15 seconds reschedules;
skip/finish/cancel clear persistence and notification; un-completion cancels only when its set
started the current timer and never starts one. Relaunch/foreground reconstruction uses the
absolute end and atomically clears expired state.

ActiveWorkoutView is wired to the service in both completion directions and on scene resume;
RestTimerBar delegates +15/skip/expiry to persisted actions. Global duration steppers live in
Gyms settings, and each active entry menu opens a warmup/working override editor with explicit
global fall-through. Five fake-driven tests cover precedence, failure behavior, replacement,
permission-once, extension/skip, source-aware un-completion, disk-backed relaunch, and suspended
expiry. The system permission sheet remains the ticket's documented one-time manual device check.
