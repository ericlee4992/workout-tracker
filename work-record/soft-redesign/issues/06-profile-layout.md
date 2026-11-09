# S6 — Profile like the prototype

Type: change
Status: **approved** (the user, 2026-11-08) — scheduled in Phase 2, **right before N3** (after N1, N2)
Implementer: Claude; Reviewer: Codex.
Spec: [soft-redesign](../spec.md); prototype `SoftProfileAndAdd.swift` (`SoftProfileScreen`, tag
`design/soft-approved-2026-11-07`). Decisions: D68 (five tabs).

## Why

The user (2026-11-08), looking at Phase 1 on the Simulator: "Why does the profile page look different from the design
we had earlier". S2 made the Profile tab by retitling the old Settings page (`SettingsView(title: "Profile")`), so every
setting sits inline; the approved prototype's Profile is a summary: an account card, short grouped rows that open
sub-pages, and Help. S2's ticket wording allowed the shortcut and no review compared it with the prototype (a miss).
The user chose to build it in Phase 2 right before N3, so N3 (Nutrition goals) and N9 (body weight, Apple Health) add
their rows straight into the new layout and Profile is laid out once.

## Scope (proposal — confirm the groups with the user when the ticket starts)

- **Account card** on top: name and sign-in method (or **Sign in** when signed out), opening the account and training
  profile (today's account pages).
- **Settings group:** "Units, rest and appearance" → today's settings (units, appearance, working/warm-up rest, ask to
  update templates); Heart rate zones; Ask AI; Export & backup.
- **Goals & tracking group:** created here, filled by N3 (Nutrition goals) and N9 (Body weight goal, Apple Health).
- **Help:** Show Tour, What's New, Send Feedback; the app version at the bottom.
- The prototype's "Training" group (History / Gyms / Exercises) is **not** built: they are tabs in layout A (D68).
- Every existing setting stays reachable (checklist against today's `SettingsView`); identifiers kept or every test
  updated; captures light/dark × default/AX, side by side with the prototype; the tour's Profile step checked.

## Progress

Not started.

## Comments
