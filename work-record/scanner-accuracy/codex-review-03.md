# Cross-review — scanner accuracy ticket 03

Boundary checked: `30b3702..d2345e3` is one code commit (`d2345e3`), the diff is non-empty, and `git diff --check` passes. The later prompt-repair commit is outside the review boundary.

## Standards

### High — `captureCount` is a primitive command token whose lifetime is incompatible with its consumer

`WorkoutTracker/Features/Gyms/ScanMachineLabelSheet.swift:39-42,195-200,395-399` keeps the integer across phase changes, while `WorkoutTracker/Features/Gyms/LabelCameraView.swift:31-45` gives every newly created representable coordinator a fresh `lastCapture = 0`. That is Primitive Obsession with a real behavioral consequence: after the first shot leaves `captureCount == 1`, recreating the camera makes the new consumer interpret old state as a new command and capture without a tap. Model a capture request explicitly and initialize its consumer from current state, or reset the request state when rebuilding the viewfinder.

### Medium — the repository's source-of-truth status document still says ticket 03 is merely next

`docs/STATE.md:3-24` says ticket 02 is the current uninstalled change and ticket 03 is only drafted, while this boundary marks ticket 03 built. `CLAUDE.md:3-7` designates `docs/STATE.md` as the source of truth for the project's current state; landing this commit as written would leave that source knowingly false.

### Medium — the required full local UI suite is not accounted for

This change replaces an entire screen flow, so `CLAUDE.md:90-91` requires the full local XCUITest suite before merge. `work-record/scanner-accuracy/issues/03-capture-first.md:73-75` records 670 unit tests and only the two-test `ScanMachineLabelUITests` class. That satisfies the ticket-specific gate, but not the repository-wide screen-change gate; the remaining 35 UI tests are unaccounted for.

### Low — the still and its ROI are an unmodeled data clump

`WorkoutTracker/Features/Gyms/LabelCameraView.swift:17-18,49-50`, `WorkoutTracker/Features/Gyms/ScanMachineLabelSheet.swift:198-200,414-425`, and `WorkoutTracker/Features/Gyms/MachineLabelOCR.swift:48-67` repeatedly pass `(UIImage, CGRect)` as two values that are only meaningful together. A named captured-label value would encode that the rectangle belongs to that exact still and is specifically a Vision-coordinate ROI, preventing the association from being lost or mixed when capture flow becomes concurrent.

## Spec

### High — the real-camera framing box is mapped into the wrong orientation

`WorkoutTracker/Features/Gyms/LabelCameraView.swift:110-115,143-157` and `WorkoutTracker/Features/Gyms/LabelFramingBox.swift:31-40` assume that `metadataOutputRectConverted(fromLayerRect:)` produces a rectangle in the photo's upright space. It does not. Apple's preview-layer contract defines metadata coordinates against the **unrotated** picture area, even though the conversion accounts for layer size and `.resizeAspectFill` ([Apple: preview-layer metadata conversion](https://developer.apple.com/documentation/avfoundation/avcapturevideopreviewlayer/layerrectconverted%28frommetadataoutputrect%3A%29)). Apple's rotation contract says an `AVCapturePhotoOutput` connection represents its rotation with an EXIF tag rather than physically rotating the encoded pixels ([Apple: `videoRotationAngle`](https://developer.apple.com/documentation/avfoundation/avcaptureconnection/videorotationangle)). Vision's ROI, by contrast, is normalized to the processed image with a lower-left origin ([Apple: Vision `regionOfInterest`](https://developer.apple.com/documentation/vision/vnimagebasedrequest/regionofinterest)).

For this portrait path, converting the wide horizontal preview box to an unrotated landscape sensor rectangle necessarily swaps its width and height. `visionRegion` only flips Y; it never rotates the rectangle or swaps those axes. The resulting tall sensor-space strip is then handed to Vision as though it were the wide upright band. `WorkoutTrackerTests/MachineLabelOCRTests.swift:126-135` genuinely rotates the pixel buffer and proves that an already-upright ROI follows the supplied orientation, but it never crosses the preview-to-unrotated-metadata boundary; `WorkoutTrackerTests/LabelFramingBoxTests.swift:25-38` tests only the Y flip. The ticket's core promise that only text visibly inside the box is read is therefore wrong on the only path that uses the box for OCR.

Hard-coding both connections to 90 degrees does keep preview and photo at the same fixed rotation while this app stays portrait-only; physically rotating the phone does not create a second preview/photo disagreement. It merely leaves both outputs fixed to the portrait orientation. The defect is the unrotated-metadata-to-oriented-Vision handoff that occurs even in ordinary portrait use.

### High — “Scan again” takes a photo before the user touches the shutter

`WorkoutTracker/Features/Gyms/ScanMachineLabelSheet.swift:39-42,195-200,318-322,395-399` does not reset `captureCount`. Results removed and dismantled the old camera controller; “Scan again” creates a new `LabelCameraView`, whose new coordinator starts at zero in `WorkoutTracker/Features/Gyms/LabelCameraView.swift:31-45`. With `captureCount == 1`, its first update immediately calls `controller.capture()`. This violates the explicit retake flow and the acceptance criterion that no Vision request or ranking occurs before a shutter tap. Because `restartScanning()` also sets `capturing = false`, the visible shutter remains enabled during that unsolicited capture, so a real tap can start a second concurrent request against the controller's single shared `pendingRegion` (`LabelCameraView.swift:58-60,148-157`). Neither UI test exercises “Scan again,” so the claimed retake behavior was never tested.

### Medium — focus and exposure are neither triggered nor locked at the shutter tap

The ticket requires “Autofocus/exposure locked on the box on tap.” `WorkoutTracker/Features/Gyms/LabelCameraView.swift:68-72,127-139` sets points from `viewDidLayoutSubviews` and selects continuous auto-exposure/focus; `capture()` at lines 143-159 performs no focus/exposure operation and never selects `.autoFocus`, `.autoExpose`, or a locked mode. The camera can therefore still be hunting while the still is taken, directly undermining the capture-accuracy purpose of the ticket.

### Medium — a photo-output configuration failure has no failure path and can strand `capturing`

`WorkoutTracker/Features/Gyms/LabelCameraView.swift:94-123` reports an input failure but silently ignores `session.canAddOutput(photoOutput) == false`, commits, and starts the session anyway. `capture()` checks only `session.isRunning` before invoking the unattached output at lines 151-157. Meanwhile, `WorkoutTracker/Features/Gyms/ScanMachineLabelSheet.swift:198-204,212-220` clears `capturing` only from `onPhoto`/`onFailure`; there is no timeout or other app-owned terminal path. Thus this configuration failure can raise at capture time or yield no processing callback, and the sheet has no way to recover the disabled shutter. Fail configuration immediately through `onFailure`, and make capture completion/error a single terminal state.

### Medium — the library fallback remains actionable during an in-flight camera capture

`WorkoutTracker/Features/Gyms/ScanMachineLabelSheet.swift:163-180` disables only the shutter. After tapping it, the user can still open “Choose a photo instead.” The camera callback at lines 198-200 and picker callback at lines 92-100 can then each call `read`, launching two OCR/ranking tasks whose last completion wins. That contradicts “one still, read once” and can replace the result for the image the user actually chose. All source-changing actions for the scan need to share the same in-flight gate or cancel/ignore the superseded request.

### Low — the UI coverage and screenshots do not match the ticket's stated acceptance

`WorkoutTrackerUITests/ScanMachineLabelUITests.swift:26-50,85-95,140-154` verifies the initial box, shutter, and post-tap results, but never taps “Scan again” and captures only `scan-viewfinder`, not the required results screenshot. Its fixture comments say the box is “real” without stating the material limitation that fixture OCR reads the entire rendered plate; line 7 even says the fixture substitutes for the “camera roll,” not the camera viewfinder. The ticket resolution's claim that the fixture reads whole is accurate, but the UI test itself does not state or exercise that difference.

## Checks with no finding

- Session startup is serialized correctly: configuration is enqueued from `viewDidLoad`, and a shutter request is enqueued on the same FIFO queue; the preview/photo connections are queried only after input/output insertion (`LabelCameraView.swift:94-123`). The sheet's synchronous `capturing` guard blocks ordinary double taps.
- `AVCapturePhotoOutput` holds only a weak delegate reference ([Apple WWDC16](https://developer.apple.com/videos/play/wwdc2016/501/?time=1767)). While the viewfinder remains present, SwiftUI retains the controller; after sheet dismissal, the controller may deallocate and the in-flight callback is intentionally lost rather than delivered into a dead sheet. The controller's callbacks dispatch onto main when it is still alive.
- D34 is satisfied. `fileDataRepresentation()` becomes transient `Data`/`UIImage`, no code writes it to disk or Photos, and the OCR task releases the image after reading. Default `AVCapturePhotoSettings` requests JPEG ([Apple: default photo settings](https://developer.apple.com/documentation/avfoundation/avcapturephotosettings/photosettings)) and defaults flash to `.off` ([Apple: `flashMode`](https://developer.apple.com/documentation/avfoundation/avcapturephotosettings/flashmode)), so the flash will not fire in the gym; the torch remains the only configured light.
- The sideways ROI test at `MachineLabelOCRTests.swift:126-135` does exercise physically rotated pixels plus a `.left` orientation tag. Vision observation boxes are normalized to the whole processed image, not the ROI ([Apple: observation `boundingBox`](https://developer.apple.com/documentation/vision/vndetectedobjectobservation/boundingbox)), so `heightFraction` remains a whole-image fraction.
- Deleted implementation identifiers have no surviving project/source/test references; their only remaining mentions are historical prose in the ticket resolution. Every new production identifier has a caller. Static source counts are exactly 670 unit tests and two `ScanMachineLabelUITests`; the committed harness report remains 8/5/0/28. No test log is committed, so this review did not independently authenticate the historical “green” execution claims.

## Axis summary

Standards: **not clear** — 1 high, 2 medium, 1 low.  
Spec: **not clear** — 2 high, 3 medium, 1 low.
