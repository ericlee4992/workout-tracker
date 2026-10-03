# Ticket 06 — independent server review, round 2

Reviewed `git diff ef76d30..aaf2f79b5ccb474727e4682081d8cf9a080ab6e6` on
`ericlee4992/beta-06-ai-proxy`, 2026-10-03, with the first report, ticket response and existing app validators
as context. Scope remains the server half. Standards and spec checks were also reviewed independently in parallel.

## Verification and disposition of the earlier findings

- `cd server && npx vitest run`: exit 0, **157/157 tests**, four files. `npx tsc --noEmit`: exit 0.
  `git diff --check ef76d30..HEAD`: exit 0.
- Memory-only probes loaded the actual TypeScript functions and reproduced findings 1–5 below. An in-memory
  SQLite probe also checked the reservation predicate with both pause scopes, with/without an existing usage
  row, and with/without the UPDATE-side pause predicate. No source/test files were modified, no mutations were
  written to the checkout, and no live service, deployment, device, credential or desktop work was performed.
- **Earlier #2, timeout: addressed.** One abort signal now covers headers and body consumption, with transport
  classification around both. The fake races both phases against the same signal. Tests now exercise a real
  short deadline for stalled headers and a stalled body, plus a failed body, and check settlement/logging.
  This is meaningful local coverage; no real upstream transport was exercised.
- **Earlier #3, README caps: addressed.** The document now lists the actual per-route body limits and separates
  the 2 MiB decoded JPEG cap from its base64 expansion. **Earlier #4, empty muscle group: addressed**, including
  an app-shaped request fixture.
- **Earlier #5, pause at admission: addressed.** The INSERT selection gates admission atomically. A paused
  selection produces no candidate row, so there is no conflict to execute the UPDATE branch. The ticket's
  claim that removing only the UPDATE-side pause predicate is an equivalent mutation is correct, also confirmed
  by the SQLite probe. Both first-insert and existing-row upload races are covered by the passing Workers tests.
- **Earlier #1, JPEG, and #6, reply bounds: incomplete**, as detailed below. The new single-line rule rejects
  CR/LF/U+2028/U+2029 in row fields while allowing JSON-encoded multiline goals; this addresses fabricated
  lines, without proving immunity to semantic steering. The 300-character proposal-reason cap is an explicit
  new server restriction documented in README, rather than an existing app validation rule.
- CPU and adversarial deployed-model checks are now explicit **pending gates before external testers**. Neither
  was performed here; lowering the image cap and changing serialization is not evidence of Workers Free CPU
  compliance. The exact-size JPEG test inserts zero filler before EOI, so it proves size/transport behavior,
  not that a genuine maximum-size image has been decoded or fits the production CPU budget.
- The ticket records mutation results, but contains no individual mutation logs for independent inspection.
  I reran the unmodified suite and inspected the relevant assertions; I did not independently rerun those
  historical mutations. Passing the existing mutation checks does not cover the additional cases below.

## Standards

1. **P2 — Valid JPEGs ending in `==` base64 padding are rejected.**
   **Location:** `server/src/ai.ts:188–195`.
   Only the last four base64 characters are decoded for EOI validation. When the JPEG byte length modulo three
   is one, that quartet contains just the final `D9` byte; the preceding `FF` belongs to the previous quartet.
   `end < 2` then rejects a valid image as `invalid_input`. The app's JPEG encoder imposes no byte-length
   remainder constraint. Reproduction: insert the legal JPEG comment segment `FF FE 00 05 41 42 43` after SOI
   in the real 633-byte test fixture. The resulting 640-byte JPEG fails, while comment variants producing
   638 and 639 bytes pass. The current positive cases cover only the other two remainders.
   **Suggested fix:** decode enough trailing groups to include both EOI bytes regardless of padding, such as
   the final eight characters. Add genuine-image cases covering all three decoded-length remainders, including
   `==`, and assert the image is forwarded unchanged.

2. **P2 — A truncated frame header with no scan still passes the JPEG check.**
   **Location:** `server/src/ai.ts:183–211`; `server/test/ai.test.ts:338–365`.
   The marker walk returns immediately after reading a SOF's dimensions. It never verifies that the SOF's
   declared segment exists, has valid components, or is followed by a scan header. The actual function accepts
   `/9j/wAD/CAABAAEA/9k=`: **14 bytes** (`FF D8 FF C0 00 FF 08 00 01 00 01 00 FF D9`), claiming a
   255-byte frame segment with no scan or pixels. A tester can still submit obvious non-images to the paid
   upstream despite the round-one fix. Separately, `/9j/wAD/CAABAAEA/9l=` also passes but has nonzero base64
   pad bits: it decodes to the same bytes and re-encodes differently, contradicting the canonical-form claim.
   **Suggested fix:** validate complete segment extents and SOF component structure, and require a structurally
   valid SOS before accepting. Keep the parsing budget explicit; this need not claim to fully decompress JPEGs.
   Check unused bits in the final base64 quartet as well. Add these exact malformed cases and verify rejection
   before a reservation or upstream call.

3. **P2 — User text can capture the image placeholder substitution.**
   **Location:** `server/src/ai.ts:323–337`.
   `json.replace(IMAGE_SLOT, jpeg)` replaces the first occurrence anywhere in the serialized request. An
   accepted exercise name `__STACKED_IMAGE__` appears in `input_text` before the image URL. The probe shows
   the full JPEG base64 substituted into that exercise name while `image_url` remains
   `data:image/jpeg;base64,__STACKED_IMAGE__`. The request sent upstream is corrupted, spends an attempt,
   and defeats the intended separation between bounded exercise text and image bytes.
   **Suggested fix:** assemble the image value at its known structural position, or replace an exact serialized
   field representation that cannot collide with escaped user text. Do not rely on an unescaped sentinel's
   first occurrence. Test the literal sentinel in an exercise name and assert both candidate text and image
   URL are preserved exactly.

## Spec

4. **P2 — Reply validation still counts app-invalid routines as successes.**
   **Location:** `server/src/ai.ts:259,291–310`; `WorkoutTracker/Domain/AIRoutine.swift:101–119`.
   The round-one response promises refusal of replies “outside the app's bounds” without counting a success.
   The new validator nevertheless accepts a blank-name session with no activities, and a **180-minute cardio
   session for a 10-minute request**. It has no requested-duration parameter and omits the app's nonblank-name,
   nonempty-session and duration checks. Also, `idsWithin` checks uniqueness before uppercasing IDs: two case
   variants of the same UUID pass, although the app decodes them to equal UUIDs and rejects duplicates. The
   probes returned `true` for all three cases. `proxyAI` therefore returns 200 and increments successes before
   the app rejects the reply, consuming one of the ten useful routine requests. The same duplicate-ID defect
   applies to scan replies.
   **Suggested fix:** mirror the omitted routine checks, pass `request.minutes`, use the app's exact duration
   calculation/tolerance, and normalize UUIDs before testing uniqueness. Add endpoint tests asserting
   `502 ai_invalid`, no success increment and released slots for each case.

5. **P2 — Reply string limits reject some replies the app considers valid.**
   **Location:** `server/src/ai.ts:289,295–318`; `WorkoutTracker/Domain/AIRoutine.swift:101`;
   `WorkoutTracker/Domain/EquipmentIdentification.swift:37–38`.
   The new `isString` limits JavaScript UTF-16 code units, while the app's `String.count` limits user-perceived
   characters. For example, a valid routine with a session name of 60 decomposed accented characters
   (`"e\u0301".repeat(60)`) has 60 characters but 120 UTF-16 units. The server rejects it despite the app's
   80-character limit accepting it. The probe confirmed that rejection with otherwise valid targets. The same
   mismatch affects scan fields and can reject legitimate Unicode text copied from a photographed label.
   **Suggested fix:** use bounded grapheme counting for the limits intended to mirror Swift, as the server
   already does for feedback, while retaining a separate byte/body safety cap. Add combining-character and
   supplementary-character boundary fixtures. Keep any deliberately stricter server contract explicit.

6. **P3 — The authoritative spec still promises the stronger relay guarantee.**
   **Location:** `server/README.md:59–63`; `work-record/public-beta/spec.md:125–129`.
   README and the ticket now candidly allow steering within fixed parameters and bounded replies, but the
   linked product contract still says a signed-in tester “cannot use the endpoint as a general-purpose GPT
   relay.” A later implementer/reviewer following AGENTS' source-of-truth rule would still assess the stronger
   guarantee. The newly documented residual risk and deployment gates are therefore not reconciled with the
   authoritative contract.
   **Suggested fix:** update that spec paragraph to the narrowed guarantee and link its pending adversarial
   acceptance gate. Retain the explicit distinction between parameter enforcement and model behavior.

Standards: three P2 findings. Spec: two P2 findings and one P3 documentation finding. The timeout, pause,
empty-muscle-group and README-limit fixes are supported by the passing tests; the remaining cases need fixes
and re-review before the server half is clear.

Verdict: not clear
