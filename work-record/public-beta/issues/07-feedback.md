# 07 — Feedback section

Type: task
Status: next — the user's order of 2026-10-03 (07 → 06 server half → 05 + 08 draft); branch created, no code yet
Blocked by: — (03's server half is merged; feedback works signed out, so 03's app half is not needed)
Implementer: Claude; Reviewer: Codex (as for 01–03).
Branch: `ericlee4992/beta-07-feedback` off `main`.
Spec: [spec.md](../spec.md) → *Feedback*. Decision: D60.

## Goal

Testers send feedback from inside the app; the developer can read it.

## Scope

- **Settings → Send Feedback:** category (Bug / Idea / Other), message (required, up to 4,000 characters),
  optional screenshot from Photos, and a visible footer of what is attached: app version and build, iOS version,
  phone model, and the account when signed in. A line states what is sent and to whom. Works signed out.
- **Server:** `POST /v1/feedback` stores the text and metadata in D1 and the screenshot in R2 (PNG/JPEG, up to
  5 MB). Signed-out submissions limited to 10 per day per hashed IP. Account deletion deletes the account's
  feedback and screenshots.
- A `server/scripts` command (and README steps) to list recent feedback and fetch a screenshot.
- TestFlight's built-in feedback stays on; nothing to build for it.

## UI first

Sample captures of the form (Default and AccessibilityL, light and dark) approved before wiring.

## Acceptance

- [ ] Approved captures in `../captures/07/`.
- [ ] Server tests: validation, size and type limits, rate limit, deletion cascade.
- [ ] Sending from the Simulator and the phone, signed in and out; the developer reads it with the script.

## Verification scope

Server unit tests; targeted app UI tests for the form; captures.

## Comments
