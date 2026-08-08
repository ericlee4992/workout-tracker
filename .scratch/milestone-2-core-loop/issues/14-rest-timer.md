# 14 — Rest timer: durations, persistence, notifications

**What to build:** Rest per D13/D22. Precedence: per-exercise override (persisted, editable from the entry's menu: separate warmup/working values) → global defaults (2:00 working / 1:00 warmup, editable in settings). Completing a set starts the timer with the duration for that set's type (failure sets use the working duration, D22); the absolute end time persists on Workout.restEndsAt so relaunch mid-rest reconstructs the countdown. Un-completing the set that started the current timer cancels it. The permission-requested marker lives in app preferences. One pending local notification at a time: starting a new timer, skipping, or ±time replaces/cancels it. Notification permission first requested after the first-ever completed set.

**Blocked by:** 07.

**Status:** ready-for-agent

- [ ] Timer logic behind injected clock + notification-scheduler protocols; unit tests use fakes (permission prompt itself: one manual check)
- [ ] Tests: warmup vs working duration selection; override beats global; +15s/skip reschedules/cancels the pending notification; new completion replaces prior timer; relaunch mid-rest resumes correct remaining time; timer end while suspended → no stale UI
- [ ] Un-completing a set does not start a timer
