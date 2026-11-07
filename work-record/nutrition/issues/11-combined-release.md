# R — The combined release (Phase 1 + Phase 2) to testers

Type: task
Status: **proposed** (2026-11-07) — awaiting the user's approval
Blocked by: S1–S4, N1–N10
Implementer: Claude; Reviewer: Codex for the release notes, README and privacy changes.
Spec: [soft-redesign](../../soft-redesign/spec.md), [nutrition](../spec.md). Decisions: D76; D62 (release notes).

## Goal

Ship the Soft redesign and nutrition together as one TestFlight build (build **10** unless another ships first).

## Checklist

1. **Cost re-check:** the food flows' real cost per request (N6) against the limits; the user confirms.
2. **Full UI suite** — release candidate (DEVELOPMENT → *When to run the full UI suite*); about an hour; **ask the
   user first**. Record named failures; known flakes listed in STATE.
3. **What's New** (D62: a big change) and the tester **What to Test** note; the user approves both.
4. **README** and its screenshots (AGENTS: screens and features changed); server README for the new endpoints.
5. **Server deploy:** the N6/N8 flows, the D1 cache migration, `USDA_API_KEY` set by the user, the approved privacy
   page; backup of D1 first (ticket 08's procedure).
6. **App Store Connect:** App Privacy answers updated (diet data, photos), the user confirms; Beta App Review for
   Friends (new data types may be reviewed again).
7. **Gate S** on the user's phone (the stored format changes): USB backup, round trip, then install.
8. **Build:** bump to 10, archive from the recorded `main` commit in `…/Health App/release-build`, upload, Developer
   group, the user's phone check (incl. the safety copy made on first launch, Health permissions), then Friends.
9. Update STATE, SPEC (nutrition and the new tabs), and this ticket with the evidence.

## Progress

Not started.

## Comments
