# 03 — Lifting and cardio template targets

Type: task
Status: ready-for-agent

Specification: [AI gym spec](../spec.md).

## Acceptance

Additive persisted cardio/rest plan targets, editable templates/detail, explicit cardio start from workout plan, migration/export/backward compatibility. Planned values never count as performed.

## Evidence

Pending implementation and verification.

## Verification scope / review

See spec implementation decisions S1–S8/R1–R6/M1–M5. Domain checks: request/response failure and cancellation, generic machine resolution/export/records isolation, mixed/cardio-only create/edit/start, snapshot immutability, every drift resolution, atomic week save, input bounds and unavailable IDs. UI: key/consent reachability, scanner confirm/manual correction/error/cancel, weekly draft/edit/save, template edit/start, explicit planned-cardio start, finish/discard and active replacement. Default and AccessibilityL captures of changed screens. Independent Claude findings/fixes linked from ticket 05; author cannot self-clear.
