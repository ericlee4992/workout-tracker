# 02 — Onboarding walkthrough

Type: task
Status: ready-for-agent (after 01)
Blocked by: 01
Implementer: Codex (default, AGENTS.md); Reviewer: Claude — or the reverse, decided at the start and recorded here.
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

## UI first

Mock the pages with sample content and show Default and AccessibilityL captures, light and dark, for the user's
approval before wiring the first-launch gate (the user's standing preference).

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
