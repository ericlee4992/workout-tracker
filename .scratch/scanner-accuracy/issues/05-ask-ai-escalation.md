# 05 — "Ask AI": escalate a plate to Claude when the phone cannot place it

Status: built 2026-09-06 — awaiting Codex round 1
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

Verification at this head: 684/684 unit; `AskAIUITests` 3/3 and `ScanMachineLabelUITests` 2/2.
