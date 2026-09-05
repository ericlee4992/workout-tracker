# Scanner accuracy 03 — Codex review, round 3

Boundary reviewed: `4120444..c744dbd` (one commit).

## Standards

### Medium — the verification gate is not established at the reviewed head

`CLAUDE.md:88-92` makes the local run the real gate and explicitly requires the full XCUITest suite before merging a screen-touching change. The recorded 37/37 UI result in `.scratch/scanner-accuracy/issues/03-capture-first.md:111-114` is for `e7dcf9b`, while `c744dbd` changes the sheet/camera lifecycle and records only the targeted Scan UI class (2/2). Its full-unit invocation also ended with 671 passing tests and one failure; an isolated retry establishes likely flakiness, but not a green full-suite run at this head. Record 672/672 unit and 37/37 UI at `c744dbd` before merge.

### Low — Duplicated Code

`WorkoutTracker/Features/Gyms/ScanMachineLabelSheet.swift:243-249,432-437` repeats the same four-field capture teardown in `captureFinished(_:)` and `abandonCapture()`. After validating the request, `captureFinished(_:)` can call `abandonCapture()` and return `true`.

## Spec

### Medium — the focus fix still guesses when adjustment has begun

The ticket requires “Autofocus/exposure locked on the box on tap” (`.scratch/scanner-accuracy/issues/03-capture-first.md:23-26`), and the round-2 response claims the 150 ms settle closes the false-before-start race (`.scratch/scanner-accuracy/issues/03-capture-first.md:119-123`). `WorkoutTracker/Features/Gyms/LabelCameraView.swift:176-205` merely sleeps for a fixed 150 ms and then treats both adjustment flags being false as completion. Those flags describe only current state; nothing here establishes that the requested focus/exposure cycle must have entered its adjusting state within 150 ms. A device that begins later still captures before the requested lock. Observe a started-then-settled transition, retaining the one-second deadline as fallback, instead of relying on the undocumented delay.

### Medium — the dismissal generation guard is raced across queues

The response says the continuation rechecks a `generation` that `stop()` bumps so a dismissed sheet never takes a photo (`.scratch/scanner-accuracy/issues/03-capture-first.md:120-123`). `WorkoutTracker/Features/Gyms/LabelCameraView.swift:170-182` reads that value on `sessionQueue`, while `stop()` mutates it on the main thread at `WorkoutTracker/Features/Gyms/LabelCameraView.swift:219-224`, without synchronization. If dismissal occurs while a settle/poll continuation is running, `session.isRunning` can remain true until the queued `stopRunning()` executes, and the unsynchronized generation read is not guaranteed to observe the bump. `capturePhoto` can therefore still be issued after dismissal. Serialize the cancellation token with the session work, or otherwise synchronize its visibility before using it as the terminal guard.

The remaining requested traces are clear. An old request's photo or request-bound failure is rejected by `captureFinished(request)` while a new request is in flight; a nil configuration failure deliberately lands unconditionally; and the fixture path creates neither a camera request nor a timeout and reads once. Dismissal cancels the sheet timeout. When the settle/poll guard wins, it silently drops the continuation; when dismissal occurs after `capturePhoto`, the delegate clears `pending` and the sheet rejects the abandoned request. A capture that never reaches the delegate can leave `pending` set, but it holds only request/geometry data and the phase change or dismissal tears down that controller before another request, so it causes neither replay nor a retained photo. The corrected 5/672 counts are accurate, and no unrelated scope creep was found.

Summary: Standards — 2 findings (worst: Medium verification gate); Spec — 2 findings (worst: Medium focus/cancellation correctness).
