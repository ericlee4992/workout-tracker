# 03 — Capture first: one deliberate frame, inside a box, read once

Status: built — awaiting Codex review
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
- ~~Burst voting~~ — **deferred to ticket 04**: it needs the video-frame output this ticket
  removes, and the single still should be measured at the gym first.
- The photo-library path is unchanged. Under `-uiTestScanFixture` the viewfinder is a stand-in
  (no camera in the Simulator) and the shutter reads the rendered plate whole, so the box and the
  shutter are driven by the UI tests; the real camera's box → region mapping is only verifiable
  at the gym.
- `ScanMachineLabelUITests` updated: shutter present, results after tap, retake returns to the
  preview. Screenshots of the preview with the box, and the results.

## Acceptance criteria

- No Vision request or `CatalogMatcher.rank` runs before the shutter is tapped (assert via a
  counter in the fixture path, or by construction — no frame handler).
- Region of interest applied and unit-tested on a rendered plate with text outside the box.
- Harness: unchanged (it does not exercise the camera; the point is no regression in the still
  path).
- Scan UI class green; full unit suite green; Codex clear.
- The user tries it at the gym and says whether it feels faster and whether it stops picking
  up the neighbouring machine.


## Resolution (2026-09-05)

- **`Features/Gyms/LabelCameraView.swift`** replaces `LiveLabelScannerView`: an `AVCaptureSession`
  at the `.photo` preset with an `AVCapturePhotoOutput` and NO video-frame output — nothing is read
  until `capture()`. Preview and photo connections are both rotated upright so the box on the
  preview and the region in the photo share one space; focus/exposure point of interest sit at
  the box centre, near-range autofocus. The shutter decides the region at that instant
  (`metadataOutputRectConverted` → `LabelFramingBox.visionRegion`), captures one still, and hands
  back `UIImage(data: fileDataRepresentation())` with its orientation tag plus the region.
- **`Features/Gyms/LabelFramingBox.swift`**: the box geometry (88% width, 2.6:1, a little above
  centre, clamped inside the view) and the metadata-rect → Vision-region flip. The overlay and the
  camera call the same function.
- **`MachineLabelOCR.read/perform(regionOfInterest:)`**: Vision's `regionOfInterest`, in the
  UPRIGHT image's coordinates — proven by a test on a sideways-tagged photo.
- **`ScanMachineLabelSheet`**: the scanning phase is a viewfinder — camera (or the fixture's
  stand-in), the box overlay (`scanFramingBox`), a status line, the shutter (`scanShutter`), the
  library fallback. Shutter → `capturing` (spinner on the button, camera stays alive until the
  photo arrives) → `read(image, regionOfInterest:)` once → results. "Scan again" returns to the
  viewfinder. The stabilizer, `liveText` and `consider` are gone; `LiveScanStabilizer` and its
  tests deleted (no caller left).
- Fixture: `-uiTestScanFixture` now shows the viewfinder and the shutter reads the rendered plate
  whole; both UI tests tap the shutter and assert nothing was read before it. Screenshot
  `scan-viewfinder`.
- Burst voting deferred to ticket 04 (needs the frame loop this removes).

Tests: `LabelFramingBoxTests` (3), `MachineLabelOCRTests` +2 (region reads only the middle band;
same on a sideways-tagged photo). **670 unit green** (the harness reports unchanged: 8/5/0/28);
**ScanMachineLabel UI 2/2** — both from the log's `** TEST SUCCEEDED **`.

**Only the gym can verify**: that the box → region mapping lands on the plate through the real
preview layer, focus at arm's length, and whether it feels faster. The Simulator has no camera.


## Codex review 03 — response (2026-09-05)

`codex-review-03.md`: standards 1 high, 2 medium, 1 low; spec 2 high, 3 medium, 1 low. All real:

- **Box mapped in the unrotated sensor space (spec high).** `metadataOutputRectConverted`
  returns metadata coordinates — the UNROTATED picture — so on a portrait phone the wide box
  became a tall strip. Replaced outright: `LabelFramingBox.visionRegion(box:viewSize:imageSize:)`
  maps the box into the UPRIGHT photo (`UIImage.size` is the oriented size) by the same
  aspect-fill arithmetic the preview layer uses to show it; nothing from AVFoundation's
  coordinate conversions is used. Pinned with numeric tests for both overflow directions, and a
  "wide box stays wide" assertion. Still only verifiable at the gym that the preview's field
  equals the photo's (the `.photo` preset's contract), which is stated in the resolution.
- **"Scan again" replayed the last tap (spec high / standards high).** The counter is now a
  `captureRequest: UUID?`, nil when nothing is pending; the camera's coordinator adopts the
  CURRENT value on creation, and `restartScanning` clears it. The UI test now taps "Scan again",
  holds two seconds on the viewfinder asserting nothing was read, then taps the shutter again.
- **Focus not triggered at the tap (medium).** `capture()` does a one-shot `.autoFocus` /
  `.autoExpose` at the box centre, waits (polling on the session queue, ≤ 1 s) until the lens
  stops adjusting, takes the still, then resumes continuous modes.
- **Output-add failure silent; `capturing` could strand (medium ×2).** `canAddOutput` false now
  fails through `onFailure`; `capture()` checks the output is attached; the sheet has an 8 s
  timeout that fails the capture; `captureFinished()` ends the in-flight capture exactly once
  (photo, failure or timeout — first wins). "Choose a photo instead" is disabled while capturing.
- **Data clump (standards low).** `CapturedLabel { image, region }`.
- **STATE stale (standards medium).** Head updated. **Full UI suite (standards medium):** run in
  chunks before merge — recorded below when done.
- **UI test coverage (low).** Results screenshot added; header comment corrected (viewfinder
  stand-in, reads whole); "Scan again" exercised.
