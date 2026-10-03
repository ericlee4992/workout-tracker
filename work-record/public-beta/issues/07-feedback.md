# 07 — Feedback section

Type: task
Status: Codex review 07 round 1 not clear (5 findings) → all fixed; round 2 next. Form approved by the user 2026-10-03
Blocked by: — (03's server half is merged; feedback works signed out, so 03's app half is not needed)
Implementer: Claude; Reviewer: Codex (as for 01–03).
Branch: `ericlee4992/beta-07-feedback` off `main`.
Spec: [spec.md](../spec.md) → *Feedback*. Decision: D60.

## Goal

Testers send feedback from inside the app; the developer can read it.

## Scope

- **Settings → Send Feedback:** category (Bug / Idea / Other), message (required, up to 4,000 characters),
  optional screenshot from Photos, and a visible footer of what is attached: app version and build, iOS version,
  phone model, and the account when signed in. A line states what is sent and to whom. Works signed out.
- **Server:** `POST /v1/feedback` stores the text and metadata in D1 and the screenshot in R2 (PNG/JPEG, up to
  5 MB). Signed-out submissions limited to 10 per day per hashed IP. Account deletion deletes the account's
  feedback and screenshots.
- A `server/scripts` command (and README steps) to list recent feedback and fetch a screenshot.
- TestFlight's built-in feedback stays on; nothing to build for it.

## Design (ios-design skill, steps 1–4)

**Job, state, bold element.** *In the compose state this sheet exists so a tester can describe a problem or an idea
and send it in one tap; the eye lands on the message field* (the largest block, first under the category). The
runner-up is **Send**, the one accent-filled command, top-trailing in the header as in every staged-edit sheet
(`SheetHeader`), disabled until the message has text. *In the sent state it exists so the tester knows it arrived;
the eye lands on "Sent"*; Done is the only command (glass, not accent).

**Where.** Settings → Help → **Send Feedback** (a `LookRow` under Show Tour). A sheet: composing is one task with a
commit (Cancel / Send); a non-empty draft cannot be swiped away by accident (`interactiveDismissDisabled`).

```
Compose (Default)                       Sent
┌──────────────────────────────┐       ┌──────────────────────────────┐
│ (Cancel)   Feedback   [Send] │ chrome │                       (Done) │
│ [ Bug |  Idea  |  Other    ] │ pills  │                              │
│ ┌──────────────────────────┐ │        │             (✓)              │
│ │ What happened, or what   │ │ ← bold │            Sent              │ ← bold
│ │ would you change?        │ │ largest│ Thanks — every message is    │
│ │                          │ │        │ read.                        │
│ └──────────────────────────┘ │        │                              │
│ ┌ 🖼 Add Screenshot ────────┐ │ row    │                              │
│ Sent with it                 │        │                              │
│ ┌ App        Stacked 0.1.0 (1)│ list   │                              │
│ │ iOS                   27.0 │ 4 rows │                              │
│ │ iPhone          iPhone16,2 │        │                              │
│ └ Account     Not signed in ┘ │        │                              │
│ 🔒 Goes only to Stacked's developer.  │                              │
└──────────────────────────────┘       └──────────────────────────────┘
```

With a screenshot, the Add row becomes a tile: thumbnail, "Screenshot", "JPEG · 33 KB · photo details removed",
**Remove** (destructive colour, plain). At AccessibilityL the detail rows stack label over value, the screenshot
tile stacks, and the header title moves under the buttons (`reflowsTitle`). A counter ("3,612 of 4,000") appears
only from 3,500 characters; input stops at 4,000. No autofocus: the tester sees everything that will be sent
before the keyboard covers it.

**Screenshot handling.** `PhotosPicker` (no Photos permission needed; the picker runs out of process). The image is
decoded and re-encoded as JPEG (quality 0.85, stepping down to stay ≤ 5 MB), so no EXIF/location is sent (D56's
rule for photos). What the tile shows is exactly what is sent.

**Proposed copy (every string is the user's decision):** Settings row **Send Feedback**; sheet title **Feedback**;
**Cancel / Send / Sending… / Done**; categories **Bug / Idea / Other** (default Bug); placeholder **What happened,
or what would you change?**; **Add Screenshot**, **Screenshot**, **Remove**; section **Sent with it** with
**App / iOS / iPhone / Account** and **Not signed in**; **Goes only to Stacked's developer.**; **Sent**, **Thanks —
every message is read.** Errors: **Couldn't send. Check your connection and try again.**; **Couldn't read that
image. Try another.**; **That image is too large to send. Try a screenshot.**; rate limit (signed out) **You've
sent 10 today. Try again tomorrow.** (30 signed in); added at implementation for the global cap: **Couldn't send
right now. Try again tomorrow.**

**The user's decisions (2026-10-03, after the captures):** the form and copy **approved as shown**; the phone shown by
its **readable name** ("iPhone 15 Pro Max"; the server keeps the identifier; a model newer than the app's table shows
its identifier); the category **starts on Bug**.

**Tells.**
- Same container on everything — absent: the message is a field, the screenshot a row/tile, the details one list;
  the category is a segmented control on the ground, the recipient line a plain notice.
- A chip where a caption would do — absent.
- All-caps label above every section — absent; one section header ("Sent with it").
- Middle-dot metadata — deliberate in the screenshot line (format · size · what was removed) and the signed-in
  account (name · email), the app's existing metadata idiom.
- Accent on so many things — the accent is Send only; Bug's selection is the neutral segment fill (a state).
- Equal-weight stacked blocks — absent: the message field is twice the height of anything else.
- Phone-sized website — absent; the Sent state is centred, one confirmation, one button.
- More than the job above the fold — the whole compose form fits one viewport at Default; at AccessibilityL the
  message and category lead and the details follow on scroll.
- A control dressed as the primary — absent; the category pills are neutral, Remove is plain text.
- Layout only at default size — AccessibilityL captured; rows and the tile stack.

## UI first

Sample captures of the form (Default and AccessibilityL, light and dark) approved before wiring.

## Acceptance

- [ ] Approved captures in `../captures/07/`.
- [ ] Server tests: validation, size and type limits, rate limit, deletion cascade.
- [ ] Sending from the Simulator and the phone, signed in and out; the developer reads it with the script.

## Verification scope

Server unit tests; targeted app UI tests for the form; captures.

## Progress

### Form mock — 2026-10-03 (Claude)

Branch `ericlee4992/beta-07-feedback`. `Features/Settings/FeedbackSheet.swift`: the sheet (compose, sending, sent,
failure line), `FeedbackDetails` (version, build, iOS, hardware identifier, account), `FeedbackScreenshot`
(re-encode, ≤ 5 MB), and the UI-test seams (`-uiTestFeedbackSample` fills it and signs in a sample "Alex Kim";
under `-uiTestReset` a stub sender succeeds after 0.4 s, or fails with `-uiTestFeedbackFail`). Settings → Help →
Send Feedback opens it. **No networking yet.** Capture test `FloodlightFeedbackUITests` (empty signed out, filled
signed in with a screenshot, sent; light/dark × Default/AccessibilityL) on **WT-Onboarding**: **4/4 passed**
(`xcodebuild test` exit 0); 18 captures in [captures/07/](../captures/07/). First pass's Sent state was a bare
check at the top of an empty sheet — now centred with a disc; retaken.

### Server — 2026-10-03 (Claude)

`server/src/feedback.ts` (route logic), `server/src/http.ts` (the shared JSON/body helpers moved out of `index.ts`;
`readBodyBytes(request, limit)` now takes the route's limit), `migrations/0003_feedback.sql` (`feedback`,
`feedback_limits`), `wrangler.jsonc` (R2 binding `FEEDBACK` → bucket `stacked-feedback`; the cron also sweeps).
- `POST /v1/feedback`, multipart; body cut off at 5 MB + 64 KB while streaming; message 1–4,000 graphemes (as Swift
  counts), no control characters but tab/newlines; detail fields pattern-checked; screenshot JPEG/PNG by its own magic
  bytes, ≤ 5 MB, one at most; R2 key `feedback/<id>.jpg|png`. Validation before any quota is spent.
- Limits per New York day: **10 signed out per address, 30 per account, 500 globally** (the last two are
  implementation choices beyond the spec, against a flood filling R2; global → `429 feedback_full`). The address
  counter key is an HMAC of `day|address` under a key derived from `TOKEN_ENC_KEY`: not reversible by enumerating
  IPv4, unlinkable across days; no address is stored. Signed-out feedback therefore needs `TOKEN_ENC_KEY` (503
  otherwise). A sent-but-invalid bearer is `401`, never filed as signed out.
- Signed-in insert only while the account exists (`INSERT … SELECT … WHERE EXISTS`); otherwise the R2 object is
  deleted at once and the request is `401`.
- **Deletion:** `claimDeletion`'s one transaction now also selects the account's screenshot keys and deletes its
  feedback rows and counter; the R2 objects are deleted right after; a failure is left to the hourly sweep, which
  deletes objects with no row once older than an hour (the grace covers an upload whose row is still being written).
- `server/scripts/feedback.mjs list | show <id> | screenshot <id>` (`--local` for `wrangler dev`); screenshots save to
  the git-ignored `server/.feedback/`. README: endpoint, limits, R2 bucket creation in the first-deploy steps, reading.
- **Tests: 82/82** (`npx vitest run`, 34 new in `test/feedback.test.ts`), `tsc --noEmit` clean. Mutation checks: with
  the R2 delete at deletion removed, the cascade test fails; with the limits loosened, 4 rate-limit tests fail.
- Local smoke (`wrangler dev`, throwaway `TOKEN_ENC_KEY` in the git-ignored `.dev.vars`): curl posts with and without
  a screenshot → 201; `feedback.mjs list/show/screenshot --local` read them back; the fetched file is byte-identical.

### App — 2026-10-03 (Claude)

- `WT_SERVER_URL` build setting (Config/Shared.xcconfig, blank; `Local.xcconfig` overrides, `https:/$()/host` for
  xcconfig's `//` comment) → Info.plist `WTServerURL` → `ServerConfig.baseURL`. **Blank hides Send Feedback** — so on
  a build without a deployed server (today's) the row is absent; under `-uiTestReset` the stub stands in.
- `Domain/FeedbackClient.swift`: `FeedbackSubmission.multipart`, `FeedbackClient.send` (typed errors mapped to the
  approved lines), `DeviceModelName` (iPhone 11 → 17e; source everymac.com, checked 2026-10-03).
- `FeedbackSheet`: the live sender (signed out until 03's app half supplies the session), failure line in the
  destructive colour (first capture showed it neutral: `SettingsNotice` sets its own colour — replaced).
  `-uiTestRealServer` (only with `-uiTestReset`) lets the smoke test use the build's server.
- **Unit: `FeedbackTests` 8/8** (multipart fields and bytes, route/headers signed in and out, error mapping and copy,
  send through a URLProtocol stub incl. no network, server-URL parsing incl. the `//` trap, model names, **the
  re-encode drops GPS and EXIF lens data**, garbage refused).
- **UI: `FloodlightFeedbackUITests` + `FloodlightSettingsUITests` (the touched Settings screen): 17 run, 16 passed,
  1 skipped (the opt-in smoke), exit 0** on WT-Onboarding; the failure-capture test rerun after the colour fix,
  passed. Captures retaken (19) in [captures/07/](../captures/07/) — now with "iPhone 15 Pro Max" and the failure line.
- **Simulator → local server smoke:** `WT_SERVER_URL=http://127.0.0.1:8799`, `TEST_RUNNER_WT_FEEDBACK_SMOKE=1`,
  `testSmokeSendsToTheBuildsServer` passed; `feedback.mjs list/show --local` showed it (bug, iPhone16,2, 33 KB
  screenshot); the fetched JPEG has no location (`mdls` latitude null). ATS needed no exception for `127.0.0.1`.
- **Not yet possible:** signed-in sending from the app (needs 03's app half and the paid team); the phone (needs a
  deployed server and the user's go-ahead); the deployed R2/D1 (the user's first deploy).

## Codex review 07 — response (round 1)

Report [codex-review-07.md](../codex-review-07.md) (HEAD `df5dd71`): **not clear**, 5 findings; all accepted and fixed.
Codex ran the server suite (82/82) and `FeedbackTests` (8/8) itself.

1. **P2 photo load race** — `FeedbackAttachment` (@MainActor, @Observable) owns the slot: a pick starts a tracked load,
   Send is disabled while it runs (a "Loading Screenshot…" row with a spinner and Remove — **new string**), a newer
   pick or Remove bumps a generation so a superseded load's result is dropped; a refused image clears the picker's
   selection. Tests: slow load, newer-wins over an older slower load, Remove mid-load, unreadable/failed transfer.
2. **P3 screenshot-only draft swiped away** — `FeedbackDraft.blocksSwipeAway`: text, a screenshot or a load in flight.
3. **P1 unbounded sweep** — no more R2 listing. A queue table `screenshot_deletions(key, due_at, claim)` (in
   `0003_feedback.sql`; edited in place — never applied outside local test/dev databases): account deletion queues
   its keys in the deletion transaction; an upload queues its key **before** the put (due in an hour) and the row
   insert un-queues it in the same batch. The cron takes ≤ 1,000 due keys, skips any whose row exists, deletes them in
   one R2 call, and clears exactly the rows it read (bounded by the last key in order and by the highest rowid read,
   so a key queued meanwhile survives). ≤ 3 D1 statements a run; counter clean-up separately; the revocation retry
   now takes 20 a run (was 50) so the shared scheduled invocation stays within Workers Free's 50 queries. Tests: 2,501
   due keys cleared in 3 runs of ≤ 3 statements (1000/1000/501 R2 calls, the last key included); an upload whose
   batch failed is deleted after its grace, not before; a queued key with a live row is never deleted; a key queued
   during a sweep survives it; counters are cleaned even when R2 fails.
4. **P2 counter recreated for a deleted account** — the account counter is written by `INSERT … SELECT … WHERE EXISTS
   (account)` (upsert); null → `401`. The racing test now also checks no `account:<id>` row; a second test drops the
   account during the upload (after the counter) and checks no row, object or queue entry remains.
5. **P2 R2's 1,000-key limit** — `deleteObjects` deletes in batches of 1,000; the claim's queue rows are removed only
   when every batch succeeded (otherwise the sweep retries; R2 deletes are idempotent). Test: 1,001 screenshots
   against a fake bucket that refuses > 1,000 keys → calls of 1,000 and 1.

Also: README intro updated (feedback is ticket 07, R2); limits described as **attempts** (counted once validated).

Verification: server **87/87**, `tsc` clean; mutation checks — the unconditional account counter fails the race test;
a single unbatched delete fails the 1,001 test. App `FeedbackTests` **13/13**; with the generation guard removed,
two tests fail. `FloodlightFeedbackUITests` rerun on the changed sheet: **7 run, 6 passed, 1 skipped (opt-in smoke),
exit 0**. The captured states show no pixel change (the loading row is a new state, not captured: PhotosPicker cannot
be driven in UI tests; it is covered by the unit tests).

## Comments
