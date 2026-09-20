# AI equipment recognition and weekly routines

User authorized end-to-end implementation 2026-09-20, with tickets and independent Claude reviews. Model locked: `gpt-5.6-terra` for both features. Private trial first; backend/public launch deferred. No model routing or comparative benchmark. No instructional content or visual guides.

## Product contract

- One deliberate photograph of a label OR whole machine invokes AI after explicit OpenAI photo consent. AI proposes identity and supported exercise IDs from the app catalog; app validates them. Show one editable proposal and require confirmation. Uncertain images ask for a new angle; manual catalog/model entry remains usable offline.
- Exact model only when supported by visible evidence and exact catalog identity; otherwise a gym-local machine with unknown model and confirmed exercise links. Two generic chest presses stay different machines, never a shared invented model. Existing history remains frozen.
- Photo stays in memory, resized/reencoded without location metadata, sent only for the requested identification, never stored by the app. Requests use store=false. No hidden retries. Cancel/rescan invalidates old responses. Provider retention is not claimed to be zero.
- OpenAI key uses its own device-only Keychain account, separate from the old Anthropic key. No key in source/build/test logs. Private Mac tooling credential lives outside Git. Settings and missing-key paths are reachable. Consent is feature-specific and revocable.
- A secondary Ask AI button below Templates opens a separate staged routine flow. Existing gym picker, start capsules and template tiles remain. Inputs: goals, experience, days/week, minutes/session, optional height/weight, and confirmed supplemental equipment. Saved active gym machines contribute supported exercises. No HealthKit data sent.
- Generate a coordinated weekly set of 1–7 editable templates, lifting and cardio. No calendar, adaptive coach, weight estimates, explanations or demonstrations. AI returns IDs from eligible exercise/activity lists; app rejects malformed/unknown/unavailable items and excessive values. Nothing is persisted until Save.
- Strength targets include set count/reps/rest; weights remain blank except established same-machine history prefill. Cardio targets describe intended activity/time/distance, never performed distance/time. Starting a template must expose planned cardio and require an explicit Start for recording; never start multiple sensor sessions automatically.
- Preserve generic template portability. A routine generated for one gym records planned equipment context; at a different gym, unavailable choices are visible/editable rather than silently implying availability. All generated sessions can be reviewed/edited before saving and later through normal template editing.
- Additive CloudKit-compatible schema only; extend JSON export without repurposing columns, exercise migration fixtures, retain old template semantics and history. Save all generated templates atomically.

## UI composition

Workout: existing content, then Templates grid/new tile, then secondary Ask AI row. Entry opens full-screen staged flow: preferences/equipment → Generate → editable sessions → Save templates. Cancel saves nothing. Scanner: camera/photo chooser → explicit photo consent → progress → editable identity/exercise confirmation → return to New Machine → Add. Errors retain manual/retry paths.

Existing screen accents remain dominant; forms/lists and native sheet toolbars use existing tokens. Default and AccessibilityL captures required. User authorized build while asleep and explicitly chose additive button, so routine implementation/design decisions proceed without further approval.

## Verification

Build; full domain suite for additive schema/template lifecycle changes; targeted AI scanner/settings/routine UI and adjacent template/core flows; default/AccessibilityL captures. Full UI escalation if changes cannot be bounded. Live Terra smoke checks with real key and limited public corpus images; report whole-machine physical accuracy separately. Independent Claude spec review and final code/evidence review, fixes re-reviewed. No device install until migration/backup/launch prerequisites can be met.

## Deferred

Public backend/billing/StoreKit, automatic coaching, calendar scheduling, visual guides, retained machine photos, phone provisioning renewal, and existing cardio physical acceptance. Hosted CI investigation remains deferred.
