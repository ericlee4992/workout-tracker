# 08 — Rest timer: real per-exercise durations

**What to build:** Rest durations stop being hardcoded. Each exercise can carry its own working-set and warmup-set rest durations, falling back to a global default (2:00 working / 1:00 warmup). Completing a set auto-starts the timer with the right duration; a local notification fires when rest ends (permission requested on first completed set, not app launch).

**Blocked by:** 04.

**Status:** ready-for-agent

- [ ] Per-exercise warmup/working rest durations persist and are editable from the exercise's entry in the active workout
- [ ] Global defaults used when no per-exercise value is set
- [ ] Timer auto-starts with warmup vs working duration based on the completed set's type
- [ ] Local notification on timer end; permission first requested after the first completed set
