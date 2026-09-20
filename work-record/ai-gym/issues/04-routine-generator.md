# 04 — Optional Ask AI weekly routine generator

Type: task
Status: ready-for-agent

Specification: [AI gym spec](../spec.md).

## Acceptance

Secondary button; staged inputs/equipment, validated Terra plan, editable weekly sessions, atomic save. No load guesses. Error/cancel/invalid output coverage.

## Evidence

Pending implementation and verification.

## Verification scope / review

See spec implementation decisions S1–S8/R1–R6/M1–M5. Domain checks: request/response failure and cancellation, generic machine resolution/export/records isolation, mixed/cardio-only create/edit/start, snapshot immutability, every drift resolution, atomic week save, input bounds and unavailable IDs. UI: key/consent reachability, scanner confirm/manual correction/error/cancel, weekly draft/edit/save, template edit/start, explicit planned-cardio start, finish/discard and active replacement. Default and AccessibilityL captures of changed screens. Independent Claude findings/fixes linked from ticket 05; author cannot self-clear.
