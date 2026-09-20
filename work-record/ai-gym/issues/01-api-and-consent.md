# 01 — Terra transport, private credentials and consent

Type: task
Status: claimed — implemented, verification in progress

Specification: [AI gym spec](../spec.md).

## Acceptance

Shared Responses client, strict JSON parsing, cancellation/timeouts, readable sanitized errors, device-only OpenAI key Settings; explicit feature consent. Tests for request shape and errors.

## Evidence

Pending implementation and verification.

## Verification scope / review

See spec implementation decisions S1–S8/R1–R6/M1–M5. Domain checks: request/response failure and cancellation, generic machine resolution/export/records isolation, mixed/cardio-only create/edit/start, snapshot immutability, every drift resolution, atomic week save, input bounds and unavailable IDs. UI: key/consent reachability, scanner confirm/manual correction/error/cancel, weekly draft/edit/save, template edit/start, explicit planned-cardio start, finish/discard and active replacement. Default and AccessibilityL captures of changed screens. Independent Claude findings/fixes linked from ticket 05; author cannot self-clear.

Live credential/model smoke passed 2026-09-20: Responses completed, model gpt-5.6-terra, text OK, 16 tokens. Initial 429 credit_balance_exhausted resolved after user added credits. No key in source/artifacts.
