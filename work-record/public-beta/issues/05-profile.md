# 05 — Profile page and training profile

Type: task
Status: ready-for-agent (after 03)
Next after 07 (the user's order 2026-10-03): mockups for approval + the server side now; 08's policy draft alongside
Blocked by: 03
Implementer: Codex (default); Reviewer: Claude — or the reverse.
Branch: `ericlee4992/beta-05-profile` off `main`.
Spec: [spec.md](../spec.md) → *Profile page*. Decisions: D60 (amends D58), D52, D59.

## Goal

A real profile page for signed-in people, including a saved training profile that prefills Ask AI for Templates.

## Scope

- Profile page from Settings → Account: display name (editable), sign-in method and email, "Member since",
  **today's AI use** against each limit (placeholder until ticket 06 provides `/v1/ai/usage`), the training
  profile, Sign out, Delete account.
- **Training profile:** goals, experience, days per week, minutes per session, optional height and weight —
  the Ask AI for Templates inputs. Stored on the server (`PUT /v1/profile`); height and weight keep the value and
  unit entered (D52), validated against the same bounds Ask AI uses. Deleting the account deletes it.
- Ask AI for Templates prefills from the profile. **Decide in the mock with the user** whether edits made inside
  Ask AI offer "Save to profile" or stay transient (D58's default).
- No profile photo (Q4). No SwiftData schema change.

## UI first

Sample-data captures of the profile page and the training-profile editor, Default and AccessibilityL, light and
dark, approved by the user before wiring.

## Acceptance

- [ ] Approved captures in `../captures/05/`.
- [ ] Server tests: profile validation, unit preservation, deletion.
- [ ] Prefill works in Ask AI for Templates; no change when signed out.
- [ ] Targeted unit/UI tests.

## Verification scope

Server unit tests; targeted app unit and UI tests (Settings, Ask AI for Templates entry); captures.

## Comments
