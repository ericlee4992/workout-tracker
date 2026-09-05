Cross-review (T6) of scanner-accuracy ticket 03, on branch scanner-accuracy. Review
boundary: 30b3702..d2345e3 (one commit, d2345e3). Read .scratch/scanner-accuracy/spec.md,
issues/03-capture-first.md, docs/DECISIONS.md D33–D35, and docs/STATE.md's note that the
Simulator has no camera (so the real camera path cannot be run by any test here).

## What was built

Features/Gyms/LabelCameraView.swift (new): AVCaptureSession .photo preset,
AVCapturePhotoOutput, no AVCaptureVideoDataOutput; preview + photo connections rotated 90;
focus/exposure point at the framing box centre; capture() maps the box via
previewLayer.metadataOutputRectConverted(fromLayerRect:) → LabelFramingBox.visionRegion,
captures, and returns UIImage(data: photo.fileDataRepresentation()) + region on main.
Features/Gyms/LabelFramingBox.swift (new, pure): rect(in:), visionRegion(fromMetadataRect:).
MachineLabelOCR.read/perform(regionOfInterest:). ScanMachineLabelSheet: scanning phase is a
viewfinder (camera or fixture stand-in) + box overlay + shutter + library fallback; capturing
state; read(image, regionOfInterest:); stabilizer/liveText/consider removed.
Deleted: LiveLabelScannerView.swift, Domain/LiveScanStabilizer.swift, its tests.
Tests: LabelFramingBoxTests (3), 2 region tests in MachineLabelOCRTests, both UI tests tap
the shutter and assert nothing was read before it.

## Specific things to attack

1. **The coordinate chain, by reading the AVFoundation contracts** (the Simulator cannot run
   it): preview layer with videoGravity .resizeAspectFill and its connection at
   videoRotationAngle 90; photo connection at 90; metadataOutputRectConverted(fromLayerRect:)
   — is its output expressed in the photo connection's rotated space or the sensor's? Does the
   region then match the UIImage(data:) whose orientation tag Vision applies? Trace the exact
   rectangle for a portrait phone: box in the preview → metadata rect → Vision region → the
   upright photo. State whether the mapping is right, wrong, or unverifiable, with the
   documentation you relied on. Also: is the region ever applied to a photo whose orientation
   is NOT what the preview assumed (device rotated, app is portrait-only)?
2. **Session lifecycle**: capture() before the session is running; two shutter taps; the sheet
   dismissed mid-capture (dismantle stops the session — does the delegate still fire, and
   into what?); onFailure after dismiss; the photo delegate retained by AVCapturePhotoOutput
   while the controller is deallocated. isVideoRotationAngleSupported on the PREVIEW
   layer's connection — is that connection non-nil before the session has inputs (it is set
   inside the sessionQueue block after addInput — check the order).
3. **D34**: the photo is fileDataRepresentation() → UIImage; is anything written to disk or
   retained beyond read()? AVCapturePhotoSettings defaults (HEIF/JPEG, flash auto?) — is
   flash going to fire in a gym? Should it be .off with the torch as the only light?
4. **The region semantics in MachineLabelOCR**: Vision's regionOfInterest is documented in
   normalized coordinates of the image AFTER orientation? The new test asserts the sideways
   case passes — is that test actually exercising a rotated buffer, and is heightFraction
   still meaningful when the region is a band (boundingBox is relative to the whole image or
   the region)?
5. **Sheet flow**: the `capturing` flag never cleared if the camera never calls back; shutter disabled
   forever; "Scan again" from results with the camera already stopped by dismantle → does the
   view re-create the controller? The fixture path: read whole vs the real path: read inside
   the box — is the difference stated in the UI test?
6. **Deletions**: any remaining reference to LiveScanStabilizer / LiveLabelScannerView /
   scanLiveText in tests, docs (SPEC, STATE, DECISIONS) or comments? Absence-of-a-caller:
   every new identifier used?
7. Claims in the resolution and commit message, including test counts and "nothing is read
   before the shutter".

Report by severity with file:line, do not soften. Do not modify source files. Write to
.scratch/scanner-accuracy/codex-review-03.md
