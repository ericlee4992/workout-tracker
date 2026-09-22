# AI equipment recognition and weekly routines

User authorized end-to-end implementation 2026-09-20, with tickets and independent Claude reviews. Model locked: `gpt-5.6-terra` for both features. Private trial first; backend/public launch deferred. No model routing or comparative benchmark. No instructional content or visual guides.

## Tickets

1. [Terra transport and consent](issues/01-api-and-consent.md)
2. [Equipment recognition](issues/02-equipment-recognition.md)
3. [Mixed template targets](issues/03-mixed-templates.md)
4. [Weekly routine generator](issues/04-routine-generator.md)
5. [Verification and independent review](issues/05-verification-review.md)
6. [Private device acceptance](issues/06-device-acceptance.md)
7. [Template visibility and scanning](issues/07-template-visibility-and-scanning.md)

## Product contract

- One deliberate photograph of a label OR whole machine invokes AI after explicit OpenAI photo consent. AI proposes identity and supported exercise IDs from the app catalog; app validates them. Show one editable proposal and require confirmation. Uncertain images ask for a new angle; manual catalog/model entry remains usable offline.
- Exact model only when supported by visible evidence and exact catalog identity; otherwise a gym-local machine with unknown model and confirmed exercise links. Two generic chest presses stay different machines, never a shared invented model. Existing history remains frozen.
- Photo stays in memory, resized/reencoded without location metadata, sent only for the requested identification, never stored by the app. Requests use store=false. No hidden retries. Cancel/rescan invalidates old responses. Provider retention is not claimed to be zero.
- OpenAI key uses its own device-only Keychain account, separate from the old Anthropic key. No key in source/build/test logs. Private Mac tooling credential lives outside Git. Settings and missing-key paths are reachable. Consent is purpose-specific and revocable (photos, routine details, manual-model text suggestions).
- A secondary Ask AI button below Templates opens a separate staged routine flow. Existing gym picker, start capsules and template tiles remain. Inputs: goals, experience, days/week, minutes/session, optional height/weight, and confirmed supplemental equipment. Saved active gym machines contribute supported exercises. No HealthKit data sent.
- Generate a coordinated weekly set of 1–7 editable templates, lifting and cardio. No calendar, adaptive coach, weight estimates, explanations or demonstrations. AI returns IDs from eligible exercise/activity lists; app rejects malformed/unknown/unavailable items and excessive values. Nothing is persisted until Save.
- Strength targets include set count/reps/rest; weights remain blank except established same-machine history prefill. Cardio targets describe intended activity/time/distance, never performed distance/time. Starting a template must expose planned cardio and require an explicit Start for recording; never start multiple sensor sessions automatically.
- Preserve generic template portability. For AI-created templates at their original gym, startup uses a remembered active machine, otherwise the sole compatible active machine; it never guesses among several. This prevents losing machine-specific history on a beginner’s first workout. Other templates retain D6. A routine generated for one gym records planned equipment context; at a different gym, unavailable choices are visible/editable rather than silently implying availability. All generated sessions can be reviewed/edited before saving and later through normal template editing.
- Additive CloudKit-compatible schema only; extend JSON export without repurposing columns, exercise migration fixtures, retain old template semantics and history. Save all generated templates atomically.

## UI composition

Workout: existing content, then Templates grid/new tile, then secondary Ask AI row. Entry opens full-screen staged flow: preferences/equipment → Generate → editable sessions → Save templates. Cancel saves nothing. Scanner: camera/photo chooser → explicit photo consent → progress → editable identity/exercise confirmation → return to New Machine → Add. Errors retain manual/retry paths.

Existing screen accents remain dominant; forms/lists and native sheet toolbars use existing tokens. Default and AccessibilityL captures required. User authorized build while asleep and explicitly chose additive button, so routine implementation/design decisions proceed without further approval.

## Verification

Build; full domain suite for additive schema/template lifecycle changes; targeted AI scanner/settings/routine UI and adjacent template/core flows; default/AccessibilityL captures. Full UI escalation if changes cannot be bounded. Live Terra smoke checks with real key and limited public corpus images; report whole-machine physical accuracy separately. Independent Claude spec review and final code/evidence review, fixes re-reviewed. No device install until migration/backup/launch prerequisites can be met.

## Deferred

Public backend/billing/StoreKit, automatic coaching, calendar scheduling, visual guides, retained machine photos, phone provisioning renewal, and existing cardio physical acceptance. Hosted CI investigation remains deferred.

## Implementation decisions after independent spec review

S1/S2: instance `recognizedExerciseIDs`, shared `supportedExerciseIDs` (model first) used by machine-first logging, browsing and routine eligibility; edit ticks for model-less machines; export includes all referenced exercises. Generic identity NEVER creates a model. Visible specific brand/model may resolve by unique exact normalized strings or create a user-space model only at Add.
S3/U1: reviewer preference for OCR-first and old scored preselection is rejected because user explicitly requested AI as the decision-maker and one-step whole-machine recognition. No model UUID is supplied/accepted from AI. We use exact normalized brand AND model equality, never nearest catalog score, and retain user confirmation and quoted visible evidence. Ambiguous/missing specific identity remains model-less. This explicitly supersedes D33/D53's former ranking UX, not history identity rules.
S4/S5: cardio targets are Codable scalar Data arrays on template and workout (no extra entity); startup snapshots them with fresh target IDs and nil segment links. Explicit Start uses existing recorder and then links the created segment; only one unfinished segment, double starts disabled. Unstarted targets never keep empty workouts alive or enter metrics. JSON exports them explicitly as plans. Strength rest/reps are snapshotted onto entries. Rest precedence: explicit per-exercise override, then planned item rest for working sets, then global; warmup, drop-set and heart-rate gates retain existing rules. All edit/rebuild paths preserve cardio/rest/equipment; lifting drift remains lifting-only. Pre-existing superset rebuild loss fixed in this same writer.
S6–S8: permission strings, SPEC and Settings describe OpenAI/full-frame sends. Consent uses three versioned local UserDefaults flags; it does not sync/export. Key is in separate OpenAI Keychain account; no Anthropic key is read as OpenAI. Legacy plate UI is unreachable; manual model exercise suggestions also use Terra. Reencoding upright pixels at <=1568 px strips metadata. Cancel/rescan invalidate task tokens; no network retries. Live Terra key check passed after user funded credits.
R1–R6: goals/profile are transient and not persisted. No gym name, machine labels, location, HealthKit or history sent. Conservative supplemental equipment mapping excludes unsupported specialty bodyweight stations. Allowed catalog exercise IDs and user-confirmed cardio activities are validated; days 1–7 exactly, <=10 strength/3 cardio per day, 1–10 sets, 1–50 reps, 0–600s rest, cardio 1–180min, names <=80 chars (duplicates permitted), no repeated strength ID/day, no empty days. Invalid response rejects the whole plan visibly. Approximate session duration permits 25% tolerance (45s/set, rest between sets, 60s transition). Separate ModelContext saves all sessions once, rollback on failure. Duplicate names across saved templates remain permitted (UUID identity). No generated loads or prose instructions.
M1–M5: additive schema; migration fixture from installed-source era required; full domain plus explicit adjacent UI coverage, default/AccessibilityL captures and independent feature/code review. No phone install without current-history confirmation and new backup. Prior physical cardio acceptance stays open.

## Design record

The existing Workout state exists to start/resume or select a template; the original amber start capsules keep prominence. Ask AI is a secondary row below the grid. Consent states exist to permit a specific send, with Allow as the only commit action. Proposal exists to inspect/correct identity, then Use; Add on New Machine remains the persistence boundary. Routine inputs exist to state goals/equipment, Generate at the end; preview exists to inspect/edit each session and Save the week. Day editor and normal template editor use staged form fields and Save/Back semantics. Active workout retains its existing logging hierarchy; a planned-cardio row exposes an explicit Start.

```
Workout                    AI routine                 Scanner
Gym card                   Goals / schedule           Consent (first use)
Start Lifting | Cardio      Optional profile           Camera / photo chooser
Templates grid / New       Equipment checklist        AI Proposal
Ask AI (secondary)         Cardio availability        Identity + model outcome
Tabs                       Generate week              Exercise choices
                           → Sessions → Edit → Save    Use → New Machine → Add
```

Existing Theme/system styles and form/list conventions reused. No new cards around single explanatory sentences, no nested cards or decorative chips, no new typography or motion. Existing twin amber start capsules remain the D54 exception; the new action is secondary. Metadata dots are the existing summary convention. Permission/error/consequence text is deliberate and required by the new sends; no exercise instructions added. Dynamic Type uses native wrapping/forms and the existing one-column template grid. Captures cover default and AccessibilityL; long forms are captured at multiple scroll positions. This follows the user's authorized additive design and unattended implementation; no new design choice is held for approval.

## September 22 follow-up

Ticket 07 implements user feedback: immediate visibility of every saved template, entry label
“Ask AI for Templates”, and an in-flow “Scan Machine” action. Select/add a gym in preferences,
scan one label or machine with Terra, review/correct, then Add. Return with goals/settings intact
and equipment availability updated; repeated scans are supported. Explicit gym/machine commits
persist independently of cancelling the routine; week saving remains atomic. D58 amendment in
DECISIONS records this boundary. No schema/API model/history rules change.
