# Soft redesign — Phase 1 (look and navigation)

Status: **tickets proposed 2026-11-07 — awaiting the user's approval before S1 starts.**
Decisions: [D67](../../docs/DECISIONS.md#november-7--soft-redesign-and-nutrition) (Soft look), D68 (tabs),
D76 (one release, per-ticket merges). Design source: [ui-evolution spec](../ui-evolution/spec.md) Direction B rounds
2–5 and Direction A's workout refinements; [build plan](../ui-evolution/build-plan.md).

## What and why

The user approved the **Soft** design in the Simulator prototype ("I like the current design now, and would like to
start building", 2026-11-07): the cleanliness of a calorie tracker's look, developed for this app rather than copied
from the reference's layout. Phase 1 changes how the app looks and how it is navigated; **it changes nothing the phone
stores** (view preferences stay in UserDefaults, like D63's Progress pins). Phase 2 ([nutrition](../nutrition/spec.md))
adds food tracking on top of it, and **both phases ship to testers together** (D76).

## Reference

The prototype is not in `main`. Read it from the record tag:

```sh
git show design/soft-approved-2026-11-07:DesignPrototype/Sources/Look/SoftLook.swift
git ls-tree -r --name-only design/soft-approved-2026-11-07 DesignPrototype/Sources/Screens/Soft
```

Launch for a visual check: check out the tag in a scratch directory, build
`DesignPrototype/RedesignPrototype.xcodeproj` (scheme RedesignPrototype), run with `-look soft -softLayout profileTab`.
The prototype's model and sample data are fakes; only its look and layout are approved.

## Rules for every ticket

- **The look:** SF Pro only (bold titles, semibold figures); light ground `#F5F5F7` with a faint warm wash at the top;
  white cards (radius 24) on a wide faint shadow, no outlines; dark mode on black with graphite cards and a hairline;
  the **Mono** action (black pills in light, white in dark); flat buttons. Macro hues (protein coral, carbs amber, fat
  blue) are reserved for nutrition (Phase 2). Kept: muscle-family colours and figures, heart-rate pink, destructive
  red, the yellow "New best" highlighter, the red Cancel beside minimize (2026-10-10).
- **The live set table keeps its layout** — colours and type only.
- **Copy:** D52 plain numbers, as-entered units, frozen history and the consent/recognition rules stand. New visible
  strings are listed in their ticket and can be vetoed. Accessibility identifiers the UI tests read are kept where the
  element survives; a test that follows a moved element is changed in the same ticket.
- **Appearance:** Settings → Appearance (System / Light / Dark, D59) stays.
- **Large text:** every changed screen is captured at the default size and AccessibilityL, light and dark.
- **Process:** one branch per ticket off `main` in this workspace; Claude implements; Codex reviews to "clear" in the
  visible Orca terminal; the user's go-ahead before each merge (`git merge --ff-only`, push, confirm the remote).
  `main` carries unreleased work until the combined release (D76).

## Tickets

| # | Ticket | Blocked by |
|---|---|---|
| [S1](issues/01-soft-look.md) | Soft look app-wide | — |
| [S2](issues/02-five-tabs.md) | Five tabs: Today · Train · History · Progress · Profile | S1 |
| [S3](issues/03-workout-refinements.md) | Workout refinements (Train order, finish receipt, cardio Pause \| End, template "…") | S2 |
| [S4](issues/04-history-and-progress.md) | History journal and Progress pin-anything (training metrics) | S2 |

Nothing in Phase 1 is shipped on its own: no tester build and no Developer-only build (the user, 2026-11-07).
