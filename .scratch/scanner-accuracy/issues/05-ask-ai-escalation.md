# 05 — "Ask AI": escalate a plate to Claude when the phone cannot place it

Status: built 2026-09-06 — Codex rounds 1–3 answered, awaiting round 4 (reviewed with ticket 06)
Blocked by: —

Decisions (user, 2026-09-06): **button first** (no automatic send); **developer-only keychain key now**, other users planned later — so the client is proxy-shaped from day one (endpoint + header on `PlateTranscriptionAPI`), D53.

## Why

The experiment (`issues/llm-reader-experiment.md`, 2026-09-06): on the same 41 plates Claude
Sonnet 5 read the brand on every logo-only plate Vision garbled, produced no junk lines and no
invented names, and through the app's own matcher took top-1 from 8 → 10 of 12 and preselection
5 → 6 with zero wrong preselections, at ≈ 0.7¢ a plate. The user's complaint — logos read as
text, brands misread — is exactly the part Claude fixes.

## What to build — an escalation path, not a replacement

- **On-device first, always.** The shutter reads with Vision as today. If D33 preselects, nothing
  else happens — no network, no cost, no latency.
- **"Ask AI" only when nothing preselects.** A button on the results sheet (and automatically when
  the user opts in under Settings → Scanner). It sends the **box crop** from the shutter tap —
  never the whole frame — with the same transcription prompt, gets the structured reading back,
  and runs it through `CatalogMatcher.rank` locally. The ranking, D33's preselection rule and the
  confirm tap are unchanged: the model transcribes, the app decides.
- **Constrained output.** The model returns brand / model / lines exactly as printed (the
  experiment's schema minus `brand_from_logo_only`, which was never true). It never picks a
  catalog row and never names a machine that is not on the plate; "unsure" is a valid answer.
- **Fail closed.** Offline, a timeout (~6 s), a refusal or an error leave the sheet exactly as
  the on-device pass left it, with a one-line note. Nothing is retried in the background.
- **The key cannot ship in the app.** For the developer's own phone a key in the keychain
  (entered once in Settings) is acceptable; for anyone else a proxy with per-device quotas is a
  prerequisite. Ticket scope: keychain key, Settings toggle, proxy-shaped client (a base URL and a
  bearer, so a proxy is a config change).
- **D34 is reopened deliberately**, not drifted from: "a scan reads the photo and discards it"
  stays true on the phone (nothing written), but the crop leaves the device when the user asks.
  Record the amendment in DECISIONS with the opt-in and the crop-only rule.

## Decisions the user must make first

1. Escalation only, or a Settings switch to send every non-preselected plate automatically?
   (Recommendation: button first; automatic later if the button is tapped every time.)
2. Developer-only (key in keychain) now, proxy later — or proxy first? (Recommendation:
   developer-only now; the app has one user.)

## Acceptance criteria

- No network call before the shutter's on-device read finishes without a preselection, ever
  (assert via a counting client in the fixture path).
- The request carries the box crop only; unit test on the crop geometry.
- Harness mode `TEST_RUNNER_SCANNER_LLM=1` keeps working from `llm-readings.json` (no live calls
  in tests); the LLM report stays ≥ the 2026-09-06 numbers whenever the prompt or schema changes.
- Offline / timeout / refusal each leave the sheet usable; UI test with the client stubbed.
- Codex clear; the user tries it at the gym on the plates that failed on-device.

## Out of scope (own tickets)

- Catalog alias ROC-IT → Hoist (`h108`); a floor so one generic word cannot reach 44% (`q1_15`).
- The model proposing exercises for a new machine — ticket 06.
- The on-device brand prior + brand chip (spec's original item 5) — still worth doing, now
  ticket 07; it is what makes the escalation rarely needed.


## Resolution (2026-09-06)

- **`Domain/PlateTranscription.swift`** — `PlateTranscription` (brand / model / lines /
  confidence; tolerant `Decodable`) and its `labelReading` (the lines, top-first, as the harness fed
  the experiment; brand+model as the fallback); `PlateTranscriptionError` (offline, timedOut,
  unauthorized, refused, unavailable(status), malformed — every case user-facing);
  `PlateTranscriptionAPI` — the Messages API request (Sonnet 5, effort low, structured output with
  the experiment's schema minus `brand_from_logo_only`, the prompt verbatim) and the reply parser
  (refusal → `.refused`; an error object / 401 / 403 → `.unauthorized`; anything else non-2xx →
  `.unavailable`; a 2xx that is not the schema → `.malformed`). Pure; no key needed to test.
- **`Domain/LabelCrop.swift`** — the box → pixel rectangle in the upright photo with an 8 % margin,
  clamped; nil region (the library path) = the whole photo; scale to ≤ 1568 px, never up.
- **`Features/Gyms/AskAI.swift`** — `PlateTranscriber` protocol; `AnthropicPlateTranscriber`
  (URLSession, 8 s timeout, `URLError` → offline / timedOut; endpoint and model are parameters);
  `AskAI` (is an ask possible? who answers?); `AskAIKeyStore` (keychain,
  `AfterFirstUnlockThisDeviceOnly`; an in-memory slot under `-uiTestReset` so no UI test touches the
  Simulator keychain); `StubPlateTranscriber` for `-uiTestAskAI` (+ `-uiTestAskAIOffline` /
  `-uiTestAskAIRefused`); `LabelCrop.jpeg` (orientation applied, crop, resize, JPEG 0.85).
- **`ScanMachineLabelSheet`** — `Results` carries `source` (camera / ai), `preselectedID` (what D33
  chose when presented, so a candidate tap does not hide the button), the `crop` (computed only when
  an ask is possible, kept only while the results are up, never written) and `askNote`. The Ask AI
  section renders only for a CAMERA reading with NO preselection; tapping runs one call, the reply is
  ranked by `CatalogMatcher.rank` and presented as a fresh reading titled "What AI read"; an empty
  reading or any error leaves the camera's results with a note under the button. A rescan in flight
  drops the reply (`crop` identity check).
- **Settings** — "Ask AI about plates" row (On/Off) → `AskAISettingsSheet`: SecureField, Save,
  Remove; the key is never shown back; the footer says what is sent and when.
- **`ScanFixture`** gains `-uiTestScanFixtureNoBrand` (the corpus's g022 placard: brand as a logo).
- **DECISIONS**: D53 added; D34 amended for this one path. CLAUDE.md range → D53.
- **Tests** — `PlateTranscriptionTests` (12): request shape, parse success / nulls / missing lines /
  refusal / error body / malformed, crop rect with margin and clamping, resize factor, and the D33
  pair on the shipped catalog (the brandless fixture plate does NOT preselect; the stub's answer
  DOES — Cybex Eagle NX Overhead Press), plus "no key → no ask". `AskAIUITests` (3): the full path
  (button offered → ask → AI reading ranked and preselected → Use This → the New Machine sheet
  shows the model), offline fails closed (note, button stays, camera results untouched, create-new
  reachable), and a preselected plate never offers the button (+ the Settings row reads On).

Verification at `ba130b6`: 684/684 unit; `AskAIUITests` 3/3 and `ScanMachineLabelUITests` 2/2.

## Codex review 05 — response (2026-09-06)

`codex-review-05.md`: do not merge yet — two highs, both real.

- **High, the library photo left the phone whole.** `LabelCrop.pixelRect(nil, …)` returned the
  whole image and the picker path has no box. Fixed by failing CLOSED: `pixelRect(region:imageSize:)`
  now takes a real region and returns nil for no box, a degenerate box or a box that IS the frame;
  `LabelCrop.jpeg` returns nil then; the sheet computes a crop only when the read had a region — so
  the library path and any degenerate geometry get NO Ask AI at all. The whole photo now never leaves
  the phone, matching D34/D53 and the Settings text. The fixture's shutter passes the rendered
  plate's own edges as its region (inset, a box not the frame), so the crop path runs for real in the
  UI tests. Pinned: `noBoxMeansNothingToSend`, `theFrameItselfIsNeverEncoded`.
- **High, an ask outlived a rescan/dismissal; `Data` equality as identity.** The ask is now a
  retained `Task` with a `UUID`; `restartScanning`, a new `read` and `onDisappear` cancel it
  (`URLSession` honours cancellation; the stub throws on it); only the request whose id is still in
  flight may touch the sheet, and only it releases `asking`. Pinned by the new UI test
  `testARescanDropsTheAskInFlight` (`-uiTestAskAISlow`: a 4 s stub, rescan through it, the old reply
  never lands and the button is offered anew).
- **Medium, not proxy-shaped.** `AnthropicMessagesClient.Credential` — `.apiKey` (x-api-key) or
  `.bearer` (Authorization) — plus the endpoint; `request(for:)` is pure and pinned by
  `theWireRequestCarriesTheCredentialTheProxyShapeNeeds` (a proxy sees a bearer and never an
  Anthropic key header).
- **Medium, tests did not pin the safety claims.** Added: the wire request; the pixels
  (`LabelCropRenderingTests`: a sensor image tagged `.right`, the top box comes back red and the
  bottom box blue — orientation applied — plus the resize and the never-the-frame rule); UI tests
  for refusal and for the rescan-cancels-the-ask rule. The "counting client" criterion is met by
  construction plus the rescan test: the only call site is the button action, the button exists only
  for a camera reading with no preselection, and one task at a time is enforced by identity. Timeout
  and 401 share the offline/refusal path (`PlateTranscriptionError` → note), unit-tested at the
  parser; not repeated as UI tests.
- **Medium, `ScanFixture.isEnabled` ungated.** Now `WorkoutTrackerStore.fixtureIsEnabled`, and
  `plateNamesNoBrand` requires it too.
- **Low, prompt/schema drift.** `llm_reader.py` now mirrors `PlateTranscriptionAPI` (comment in
  both places), the Swift test pins the whole prompt and the absence of `brand_from_logo_only`, and
  the corpus was re-read with the production contract — see `llm-sonnet-2026-09-06b.md` below.
- **Low, duplicated `trimmed`; divergent change in `AskAI.swift`.** One private helper remains
  (Domain); the keychain moved to `AskAIKeyStore.swift`, the UIKit crop to
  `LabelCropRendering.swift`; `AskAI.swift` is transport + who-answers.

## Codex review 05b — response (2026-09-06)

`codex-review-05b.md` (05 round 2 + 06 round 1): do not merge yet — three mediums, one low.

- **Medium, the margin could turn a near-frame box into the frame.** `pixelRect` now also returns
  nil when the clamped crop touches all four edges — something of the photo must stay out. The
  fixture that proved the hole is changed: the plate is now drawn on a 2000 × 800 canvas
  (`plateRegion` = the plate's edges, 0.1/0.1875/0.8/0.625), so its box survives the margin and the
  crop path runs on a real box. Pinned: `theFrameItselfIsNeverEncoded` (the near-frame case and the
  fixture's own box), `noBoxMeansNothingToSend` (near-frame nil; a wide box that keeps top and
  bottom out is still a box).
- **Medium, the proposal request could outlive Cancel/Add.** `AddModelSheet` retains
  `proposalTask`; Cancel, Add and `onDisappear` call `abandonProposal()` (cancel + release); the
  task touches nothing once cancelled.
- **Medium, SPEC/DECISIONS still said "nothing leaves the phone".** SPEC's scan bullet now states
  the two opt-in sends (box crop; plate text + exercise list), "Technical direction" reads "offline
  for everything except the opt-in Ask AI taps (D53)" and "talks to nothing but the device … except
  the opt-in Ask AI taps"; D53 now records ticket 06's disclosure too.
- **Low, the counting client and a timeout test.** Under `-uiTestAskAI` the stubs count every call
  (`AskAIFixtureLedger`) and the results sheet shows "AI calls: N" (`scanAskAICalls`);
  `testAPreselectedPlateNeverOffersAskAI` asserts 0 after a preselected read, the happy path asserts
  0 before the tap and 1 after — a counting client, as specified. `-uiTestAskAITimeout` +
  `testATimedOutAskIsSaidPlainly` cover the third failure mode.

Verification at this head: 697/697 unit; `AskAIUITests` 7/7 + `ScanMachineLabelUITests` 2/2. The
FULL UI suite ran once on `6242324` (before these fixes): 43 tests, 42 passed, the one failure a
cold-first-launch flake in the Ask AI happy path's gym-creation helper (the typed name never
became a row; passes on every focused run) — the helper now waits for the keyboard and verifies
the field before saving.

## Codex review 05c — response (2026-09-06)

`codex-review-05c.md`: do not merge yet — two mediums, one low.

- **Medium, the frame guard closed equality only** (a box leaving one pixel column passed). Now a
  crop may cover at most 90 % of the photo's AREA (`LabelCrop.maximumAreaShare`) — a tenth of the
  photo must stay out. The real box on a portrait phone spans well under half the photo; the fixture
  plate is ≈ 67 % with its margin. Pinned: the one-column case, a 90 %-before-margin box (nil), the
  wide box and the fixture box (crops).
- **Medium, the disclosures were not exact.** SPEC, D53, the scan sheet's footer, the Settings
  sheet and the New Model footer now say what leaves: the box plus an 8 % margin and at most nine
  tenths of the photo; and for 06 the manufacturer and model as typed, the plate's lines, and the
  exercise list (ids, names, muscle groups).
- **Low, the STATE placeholder.** Gone; STATE names every round's verdict.

Verification after round 3: the FULL UI suite on `e5ef77c` — **44 tests, 0 failures** (24 min);
at this head `AskAIUITests` 7/7 and the unit suite green (the two heart-rate timing tests fail
only under load, straight after a UI run, and pass alone every time).
