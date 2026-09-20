# 05 — Integration verification and independent Claude review

Type: task
Status: claimed — integration and independent review in progress

Specification: [AI gym spec](../spec.md).

## Acceptance

Build/domain/UI/captures, live API evidence, independent Claude review and fixes, branch push, ff-only merge/push and verified remote tip; honest installed/unverified state.

## Evidence

Pending implementation and verification.

## Verification scope / review

See spec implementation decisions S1–S8/R1–R6/M1–M5. Domain checks: request/response failure and cancellation, generic machine resolution/export/records isolation, mixed/cardio-only create/edit/start, snapshot immutability, every drift resolution, atomic week save, input bounds and unavailable IDs. UI: key/consent reachability, scanner confirm/manual correction/error/cancel, weekly draft/edit/save, template edit/start, explicit planned-cardio start, finish/discard and active replacement. Default and AccessibilityL captures of changed screens. Independent Claude findings/fixes linked from ticket 05; author cannot self-clear.

## September 20 checkpoint

Implementation `7dc1622`, follow-up review fixes in progress. Actual build exits: build/build2/build3 all 0; clean build2 built plist confirms new OpenAI camera/photo disclosure. Initial domain run: exit 65, 763 total, 757 passed, six failures (five stale export-version expectations and the intentionally reopened cardio-only template gate). Corrected run: **767/767 passed, 0 failed/skipped, exit 0**, `results/verified-units.xcresult`.

Installed-era synthetic fixture generation from `8c71d27`: 1/1 passed, exit 0; SQLite backup integrity ok; migration passed in verified units. No phone store touched.

AI UI run: 9 cases, 7 passed, 2 failed; failure records in `results/ai-ui.xcresult`. Routine failures: keyboard remained over controls, default-size scrolling bounced past a toggle, AXL taps left toggles off and generation had no available equipment. Added explicit keyboard Done, focus state and toggle-value assertions; narrowed rerun to two weekly routine cases. First rerun could not build because new template error needed its SaveAsTemplateFlow switch case; fixed and rerun under `results/routine-fix2.*`.

Live Responses smoke with production request shapes: initial key 429 resolved by user funding; model gpt-5.6-terra confirmed. Synthetic weekly draft and three public corpus photos returned complete structured results. Recognition is fallible: g010 whole-machine view produced conflicting wrong-looking movement labels across low/medium/high effort; no full-machine accuracy pass is claimed. h072 printed model read consistently; h108 small SKU misread at low effort, medium returned legible movement name instead. Medium selected; prompt stresses mechanical evidence and no completion of unreadable codes. Retake/manual corrections retained. This is a private-trial limitation, not public-release clearance. Raw public/synthetic responses in ignored `results/live*.json`; no credentials or private photo sent to artifacts.

Claude initial code review at `7dc1622`: H1 stable editable row identity, H2 save idempotence, H3 editable-draft validation and H4 shared exact-model resolution require fixes. Implemented, pending re-review. M1 unknown-plan preservation/export DTO, M2 legacy text consent, M3 seeded recognition catalog, M4 migration field/export coverage, M5 transport/rest/atomic-start tests, M6 old-template logging unchanged and M7 empty-target retry also addressed/in progress. Review authored in separate `review-ai-gym-code` checkout at `09e9787`.
