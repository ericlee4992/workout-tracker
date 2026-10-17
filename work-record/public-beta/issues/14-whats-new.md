# 14 — In-app "What's New" for big changes

Type: feature
Status: needs-triage — requested by the user 2026-10-17; build it before the first update that has a big change
Blocked by: —
Spec: [spec.md](../spec.md). Decision: [D62](../../../docs/DECISIONS.md). Related: [DEVELOPMENT → TestFlight build
checklist](../../../docs/DEVELOPMENT.md#testflight-build-checklist); onboarding (ticket 02) for the existing first-launch flow.

## Request (the user, 2026-10-17)

"for things like fixing small bugs or adding small features, just the description on "What to Test" is fine.
However, for big new additions or changes to the app, when they first open the app, I want a window to pop up that
shows/describes the new features."

## Scope as understood

- When the app first opens after an update that has a What's New entry, show a one-time sheet describing the new
  features (title, a few short items, optionally an image), then never again for that version/build.
- Updates without an entry (small fixes) show nothing; the TestFlight "What to Test" note covers them.
- Not on a fresh install (the onboarding tour covers new people) — to confirm.
- Possibly a way to see it again later (e.g. Settings) — to decide.

## To decide in the design (with the user)

- Look: a sheet in Stacked's design (ios-design skill), with real captures at Default and AccessibilityL.
- Keyed per build number or per marketing version; how entries are written (in code, per release).
- Interaction with onboarding and with a workout in progress (never interrupt a live workout).

## Comments
