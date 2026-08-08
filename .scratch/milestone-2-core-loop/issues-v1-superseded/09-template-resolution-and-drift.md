# 09 — Template resolution + drift prompt

**What to build:** Templates become real and gym-aware. Starting a template at a gym creates a workout whose exercises resolve to the last-used machine at that gym (via GymExerciseMemory); exercises with no memory at this gym start machineless. Finishing a workout that deviated from its template offers the four-option drift prompt: update template / update values only / update both / keep original (suppressible in settings).

**Blocked by:** 03, 04.

**Status:** ready-for-agent

- [ ] Templates persist (name, ordered exercises, target sets/reps)
- [ ] Starting "Push Day" at gym A picks gym-A machines; at gym B picks gym-B machines — same template
- [ ] Drift detection: added/removed exercises or changed set counts vs the template trigger the prompt
- [ ] All four prompt options behave per SPEC; a settings toggle suppresses the prompt
- [ ] Save-as-template offered when finishing a from-scratch workout
