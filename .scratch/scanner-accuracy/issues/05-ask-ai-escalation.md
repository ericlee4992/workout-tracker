# 05 — "Ask AI": escalate a plate to Claude when the phone cannot place it

Status: DRAFT — measured, not started; needs the user's go and two decisions (below)
Blocked by: 03 (gym-verified), the proxy decision

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
