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

### Review-fix verification continuation

Commit `3f75187` implements H1–H4 and M1–M7 changes. Routine UI diagnosis fixed: focused `routine-fix2` **2/2 passed, exit 0**, default and AccessibilityL generation→edit→atomic-save→tile refresh→template start→explicit planned cardio recording. New deletion/reorder/double-submit and manual-model-consent UI cases added for the next run.

Review-fix full units (`review-units`) found only one failing test (two assertions): it ended a target immediately, which intentionally allows retry of empty cardio under M7; corrected the test to end at an injected +60 seconds. Initial final-units/integration-ui rerun scheduling accidentally overlapped after a queued controller was stopped while its child had already started; both owned jobs were explicitly interrupted. Their partial outputs are **not verification evidence**. Replaced the queue with one serial Python controller (`results/verify-serial.py`, PID in `verify-serial.pid`, active child/commit in `active-verification.json`) running `final-domain` then `integration-ui-v2`. Each subprocess exit is captured directly. Result/log paths match those names in `results/`.

Additional policy choices: authored edits may exceed requested session duration (generation still validated to its budget); malformed/unknown future cardio targets are preserved, flagged, and exported as raw fallback alongside a stable DTO; model-only text AI has a separate revocable consent; no custom exercise names sent with photos. Old Anthropic transport remains only for historical protocol tests/offline-scanner fixtures, unreachable with a real key. Old Anthropic Keychain entry is left untouched and never read as an OpenAI credential. No public backend or phone install claimed.

### Independent code clearance and final checks

Claude round 2 at `3f75187` independently reports **code CLEAR**, resolving all H/M findings. Evidence/UI clearance remains pending. Final serial domain run: **773/773 passed, 0 failed/skipped, exit 0**, actual summary inspected (`final-domain.xcresult`). Adjacent integration UI continues, followed by latest-source resolution-state captures. See active-verification.json for current process.

Accepted Low observations for private trial: target caption intentionally accompanies a rest prescription (the template detail always retains reps); canonical preferences may be created only if missing in isolated save, and a launched app already has one; local editor UUIDs participate in Equatable but never wire encoding or persistence identity; equipment provenance combines explicit tagged choices; old Anthropic key/client retained but unreachable with a live key; 429 billing/rate limits share a sanitized message; JPEG rendering is bounded but currently on main actor; Cancel deliberately discards an unsaved draft. Distinct session names are requested in the prompt but not required for edited or generated plans (UUID identity). D56–D58 now record these decisions in the decision table. These do not relax any history/secret/consent or review gate.

Live seven-day request at medium effort completed in 10.14 s, 2,212 total tokens, seven sessions; three-day request completed in 9.0 s. This verifies bounded live requests, not exercise-program effectiveness. h108 exposed an additional semantic issue: despite instructions, Terra called a brand plus generic movement text a specific model. Added a shared deterministic guard: a model name made solely from known exercise names and generic equipment/position words is model-less even if AI labels it specific. Branded series names and legible model codes remain eligible for exact resolution. Both proposal and final Add use it; regression test reproduces the live answer. This prevents the observed false shared-model identity rather than relying on prompt compliance.

### Final regression evidence

`final-targeted`: **29/29 domain tests passed**, exit 0, after movement-only model-name guard and unique compatible machine startup. `integration-ui-v2`: **23/24 passed**; sole failure was an ambiguous test-only Cancel selector, fixed by scoping it to Scan Equipment; the restored manual-model-consent case subsequently passed in `ai-final`. `ai-final`: **18/20 passed**; two AccessibilityL identity cases waited for an offscreen lazy Form button before scrolling. The test now waits for the visible proposal field, then scrolls to the action. `ai-corrected` did not launch (simulator Busy/preflight), so no result is credited. After a non-erasing boot, `ai-corrected2`: **4/4 passed, exit 0** (both failed identity cases plus default/AXL full routine flows).

Visual QA found a single-line model field truncating at AccessibilityL; proposal text fields now wrap and have a keyboard Done control. A new actual UI regression reproduced a hand-edited name being overwritten by the catalog default: expected Press by window, got Seated Chest Press (`edited-label-red2`, 1 failed, exit 65). The first attempt ran **0 tests** and is explicitly not evidence; installed/built runner binary hashes matched, and restarting the runner made discovery execute the test. Fixed by keeping local user-edit provenance (excluded from JSON coding) and honoring it in MachineEditorSheet’s D3 ownership rule. `label-units`: **23/23 passed**, exit 0; the edited-label UI case is green in the pending final UI/capture run. No existing model/label history was rewritten.

Built app camera/photo usage strings re-inspected; both disclose consented OpenAI photo transmission. Credential-file permissions 0600; exact-key scan of tracked files found zero matches. OpenAI’s current data-controls page was checked; app copy correctly says provider policies apply and does not claim zero retention.

`label-ui`: **5/5 passed, exit 0** (edited label, specific identity Default/AXL, Settings Default/AXL). `preservation-units`: **23/23 passed, exit 0**; unknown future cardio rows now retain their positions when known rows change. `review-captures`: **4/4 passed, exit 0** (ambiguous identity Default/AXL with wrapping fields, existing-template default-rest editor and unchanged logger Default/AXL). Actual xcresult summaries and exit files inspected. All previously failing selected UI cases have successful focused reruns; no skipped cases are claimed as passing. [Gallery](../gallery.html) contains the collected real UI captures.

The signed generic-iOS build succeeded, exit 0 (`results/device-build.log` / `device-build-exit.txt`), with the existing ignored local signing configuration copied from main. Binary freshness/signature/profile checks follow before handoff; no installation or phone-store access occurred. Phone remains on installed `8c71d27`.
