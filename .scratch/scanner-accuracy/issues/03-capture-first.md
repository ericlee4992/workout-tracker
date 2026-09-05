# 03 — Capture first: one deliberate frame, inside a box, read once

Status: ready-for-agent (drafted 2026-09-05 while ticket 02 was in review)
Blocked by: 02

## Why

The live loop reads a moving 1080p video frame ~3×/s and settles when two consecutive reads
share a top row whatever its score, so it settles on half-read plates and keeps resetting while
the camera moves. The corpus shows the read-side residue after ticket 02: a placard at ~45° lost
the word WIDE; a whole-machine shot read nothing (the placard was a fraction of the frame); the
matcher ran on the main thread per frame. The user's own words: it "sometimes feels slow", and
"could it possibly be better to let user capture it first and then it decides".

## What to build

- **Keep the live preview and the torch for framing; drop the live OCR loop.** No per-frame
  Vision, no per-frame ranking, no `LiveScanStabilizer` in the sheet's path (keep the type and
  its tests only if something still calls it — otherwise delete it; absence-of-a-caller rule).
- **A framing box** drawn over the preview, plate-shaped (~3:1), centred; the shutter reads ONLY
  text inside it (`VNRecognizeTextRequest.regionOfInterest`), so the next machine's plate, the
  frame badge and wall signage never enter the reading.
- **A one-tap shutter** (`scanShutter`) that captures a still through `AVCapturePhotoOutput` at
  the camera's photo resolution (not the 1080p video buffer), runs the SAME `MachineLabelOCR`
  configuration once, off the main thread, ranks once, and presents. Autofocus/exposure locked
  on the box on tap. A brief "Reading…" state; a Retake button on the results.
- **Burst voting**, cheap version: read the still plus the two video frames immediately before
  the tap, keep only tokens that appear in ≥ 2 of the 3 reads (line structure from the still).
  Measured by the harness only indirectly (the harness reads stills); a unit test on the vote.
- The photo-library path and the `-uiTestScanFixture` path are unchanged; the fixture drives the
  UI test through the new shutter (`scanShutter` on the fixture goes straight to `read`).
- `ScanMachineLabelUITests` updated: shutter present, results after tap, retake returns to the
  preview. Screenshots of the preview with the box, and the results.

## Acceptance criteria

- No Vision request or `CatalogMatcher.rank` runs before the shutter is tapped (assert via a
  counter in the fixture path, or by construction — no frame handler).
- Region of interest applied and unit-tested on a rendered plate with text outside the box.
- Harness: unchanged or better (it does not exercise the camera; the point is no regression in
  the still path). The vote has its own tests.
- Scan UI class green; full unit suite green; Codex clear.
- The user tries it at the gym and says whether it feels faster and whether it stops picking
  up the neighbouring machine.
