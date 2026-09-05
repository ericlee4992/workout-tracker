# Cross-review — scanner accuracy ticket 03, round 2

Boundary checked: `d2345e3..e7dcf9b` resolves to three commits (`25a9c25`, `db3fbf2`, `e7dcf9b`) and a non-empty diff. The later docs-only `4120444` is outside the fix boundary and records the user-confirmed 37/37 UI run on exactly `e7dcf9b`.

## Standards

Clear. All four round-1 Standards findings are closed: `WorkoutTracker/Features/Gyms/LabelCameraView.swift:5-13` introduces `CapturedLabel`, eliminating the image/ROI data clump; `LabelCameraView.swift:25-60` replaces the replay-prone integer counter with an explicitly named UUID request whose new coordinator adopts the current value; `WorkoutTracker/Features/Gyms/ScanMachineLabelSheet.swift:217-242,417-421` clears it through one terminal helper; and `docs/STATE.md:3-29` now accurately marks ticket 03 built and under review. The post-boundary UI record satisfies `CLAUDE.md:90-91`. No new documented-standard violation or material baseline smell was found.

## Spec

### Medium — focus completion and dismissal are not lifecycle-safe

The requirement at `.scratch/scanner-accuracy/issues/03-capture-first.md:23-26` says **“Autofocus/exposure locked on the box on tap.”** `WorkoutTracker/Features/Gyms/LabelCameraView.swift:163-190` sets the one-shot modes and immediately treats both `isAdjustingFocus == false` and `isAdjustingExposure == false` as completion. Apple documents these only as current, KVO-observable state ([`isAdjustingFocus`](https://developer.apple.com/documentation/avfoundation/avcapturedevice/isadjustingfocus)); if adjustment has not transitioned to `true` yet, the still fires immediately rather than after focus/exposure lock.

The same poll can outlive dismissal. `LabelCameraView.swift:184-205` does not recheck `session.isRunning` before its delayed continuation calls `capturePhoto`; dismissal/view disappearance can enqueue and synchronously complete `stopRunning()` first ([Apple: `stopRunning()`](https://developer.apple.com/documentation/avfoundation/avcapturesession/stoprunning%28%29)). The output is then not ready for capture ([Apple: `sessionNotRunning`](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/capturereadiness-swift.enum/sessionnotrunning)). `WorkoutTracker/Features/Gyms/ScanMachineLabelSheet.swift:82-84,225-242` also has no disappearance cleanup, so the eight-second timeout survives dismissal. The fix can therefore request a photo and later mutate capture state after the user canceled. Invalidate the focus continuation in `stop()`, recheck the session immediately before capture, and cancel the sheet timeout on disappearance.

### Medium — “first wins” is false for failure callbacks

The response at `.scratch/scanner-accuracy/issues/03-capture-first.md:100-103` says **“`captureFinished()` ends the in-flight capture exactly once (photo, failure or timeout — first wins).”** Success correctly guards on the helper's result, but `WorkoutTracker/Features/Gyms/ScanMachineLabelSheet.swift:203-210` discards the result in `onFailure` and always assigns `.failed`. A late failure after timeout, dismissal, or a retry can therefore overwrite newer state; if a retry is currently capturing, it can even finish the new request on behalf of the old one. Capture callbacks need the request identity, and capture-specific failure must return unless that exact request wins termination. Initial camera-configuration failure should remain a separate ungated path.

### Low — the ticket's committed resolution still reports the pre-fix test counts

`.scratch/scanner-accuracy/issues/03-capture-first.md:73-75` says **“`LabelFramingBoxTests` (3) … 670 unit green.”** The fix leaves five framing-box tests and 672 unit tests. The `e7dcf9b` commit message correctly says 672, this review reran `WorkoutTrackerTests` successfully at 672/672, and the later ticket record correctly reports UI 37/37; only the ticket's active Resolution paragraph remains stale.

### Checked without a finding

The new aspect-fill arithmetic at `WorkoutTracker/Features/Gyms/LabelFramingBox.swift:46-63` and both numeric expectations at `WorkoutTrackerTests/LabelFramingBoxTests.swift:32-55` are correct. Apple documents `UIImage.size` as orientation-aware ([Apple: `UIImage.size`](https://developer.apple.com/documentation/uikit/uiimage/size)), so the function receives the upright aspect ratio. The UUID coordinator closes the replayed-retake bug, `pendingFrame` is written by main-thread `capture()` and read/cleared in the dispatched main block, output-add failure and the library race are closed, and the focus poll itself neither blocks nor strongly retains the controller.

What remains phone-only is material but already disclosed: `.photo` promises high-resolution photo quality, not exact preview/still field-of-view identity ([Apple: `.photo`](https://developer.apple.com/documentation/avfoundation/avcapturesession/preset/photo)); automatic still stabilization defaults on and may add digital processing ([Apple: still stabilization](https://developer.apple.com/documentation/avfoundation/avcapturephotosettings/isautostillimagestabilizationenabled)). The pure tests prove the transform only. Exact box landing against the processed still, arm's-length focus, and perceived speed remain unverifiable without the real phone/gym trial required by the ticket. No unrelated scope creep was found.

Standards: **clear — 0 findings.** Spec: **not clear — 3 findings; worst is Medium (focus/dismissal lifecycle and stale-failure arbitration).**
