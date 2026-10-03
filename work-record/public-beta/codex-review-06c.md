# Ticket 06 — independent server review, round 3

Reviewed `git diff aaf2f79..13fa4eb9bc97f7b2bc7abdf25da1264a04bc757b` on
`ericlee4992/beta-06-ai-proxy`, 2026-10-03, against the previous reports, ticket response and app validators.
Scope remains the server half. Standards and spec checks were also reviewed independently in parallel.

## Verification and disposition of the earlier findings

- `cd server && npx vitest run`: exit 0, **166/166 tests**, four files. `npx tsc --noEmit`: exit 0.
  `git diff --check aaf2f79..HEAD`: exit 0.
- Additional memory-only probes loaded the actual TypeScript functions. They confirmed acceptance of all three
  JPEG length remainders, rejection of the two malformed strings from round two, correct image substitution
  even when user text contains a deliberately known random slot, the proposal-cleaning issue below, and correct
  duration decisions at exactly 750 seconds and 751 seconds for a 750-second allowance.
- No source/test files were modified, no historical mutations were rerun in the checkout, and no live service,
  deployment, device, credential or desktop work was performed. Only this report was added.
- **JPEG padding and the earlier truncated-frame cases are fixed.** The eight-character tail contains both
  EOI bytes for every padding case. Canonical unused bits and decoded size are checked. The walk verifies
  segment extents within its window, frame length/precision/component count/dimensions, then scan-header
  length and the presence of bytes before the final EOI. No additional rejection of the app's ordinary
  re-encoded JPEG format was identified. The 256 KiB window is a deliberate header limit, not a limit on total
  image data; a larger header is rejected even for an otherwise valid JPEG.
- **JPEG validation remains a bounded preflight, not proof of a decodable image.** The entropy check is a byte
  count, not entropy decoding; component/table semantics and corrupted compressed data can still fail upstream.
  The comment's “refuses non-images” must not be interpreted as a guarantee that all malformed JPEGs are locally
  rejected. Full decoding is explicitly delegated to OpenAI; this review does not introduce a full decoder
  requirement. A real maximum-size app JPEG and deployed CPU headroom remain pending acceptance evidence.
- **Image substitution is fixed.** The exact serialized key/value anchor cannot occur unescaped inside user
  text, and the function checks that it occurs exactly once. The random slot comes from production
  `crypto.getRandomValues`. The reported plain-slot replacement mutant is effectively redundant protection
  under that unpredictability assumption, rather than a strict equivalence for every possible input/random
  value. A deterministic test can deliberately place its known slot in a name and distinguish the implementations;
  the current exact-anchor implementation passed that stronger probe. No production collision defect was found.
- **The earlier routine/scan and grapheme defects are fixed.** UUID uniqueness is normalized before comparison;
  blank/empty routine sessions, unavailable IDs/activities, targets and the session-duration estimate are checked.
  The estimate and inclusive tolerance match `AIRoutine.validated(for:)`. Grapheme counting fixes the demonstrated
  decomposed-character and emoji cases, and its extraction leaves feedback behavior unchanged. Scan identity
  normalization remains with the app, which still validates the returned result itself.
- The spec and README now agree on fixed API parameters, bounded replies, quotas and residual semantic steering.
  The 300-character proposal-reason restriction is explicit. Deployed CPU/model-adversarial checks and the app
  switch are still pending, so this is not deployment or end-to-end clearance.
- The ticket's historical mutation results have no individual logs here to inspect. The passing suite contains
  assertions aimed at each listed defect, but I did not independently reproduce those mutation runs. The
  specific boundary-evidence discrepancy below remains.

## Standards

1. **P3 — The claimed duration-boundary regression test does not test the boundary.**
   **Location:** `server/test/ai.test.ts:578–585`;
   `work-record/public-beta/issues/06-ai-proxy.md:156`.
   The test claims equality and one second over, but accepts a 1,395-second routine against a 3,375-second
   allowance, then rejects it against 1,350 seconds. That second case is 45 seconds over; neither case tests
   equality. Changing the implementation's `<=` to `<` would therefore survive this test despite the ticket's
   evidence claim. The present implementation is correct: my separate probe accepted 750 and rejected 751
   against a 750-second allowance.
   **Suggested fix:** make the committed regression exercise those actual boundaries. A ten-minute request
   with two strength sets, 540 seconds rest, and one minute of cardio has estimate
   `2 × 45 + 540 + 60 + 60 = 750`; rest of 541 gives 751. Assert acceptance/refusal and success/attempt/slot
   accounting, and keep the test name and ticket evidence consistent with the executed cases.

## Spec

2. **P3 — Proposal reasons are truncated before the app's whitespace cleaning.**
   **Location:** `server/src/ai.ts:356–357`; `WorkoutTracker/Domain/ExerciseProposal.swift:108–109`.
   The ticket says proposals are cleaned as `ExerciseProposalAPI.parse` cleans them, with the 300-character
   cap added. The app first trims surrounding whitespace/newlines; the server caps the untrimmed string and
   never trims it. A reason of 300 spaces followed by `Chest press` is returned as 300 spaces and becomes an
   empty explanation when the app trims it. The direct probe reproduced that loss, although the useful
   explanation would fit easily after the app's normal cleaning. Smaller leading padding can similarly cut
   characters from an otherwise valid explanation at the cap.
   **Suggested fix:** apply the app-equivalent surrounding-whitespace cleaning before taking the first 300
   graphemes. Add padded and whitespace-only reasons, plus a padded reason whose meaningful text is exactly
   at the cap, to the proposal-cleaning test.

Standards: one P3 evidence/test finding. Spec: one P3 proposal-cleaning finding. No remaining P0–P2 finding
was identified in this round; the two small corrections above remain before final clearance.

Verdict: not clear
