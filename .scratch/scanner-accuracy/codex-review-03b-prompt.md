Round 2 (T6) of scanner-accuracy ticket 03. Round-1 review:
.scratch/scanner-accuracy/codex-review-03.md. Boundary of the fixes: d2345e3..e7dcf9b
(the docs commit db3fbf2 and the fix commit e7dcf9b). The response to each finding is in
issues/03-capture-first.md under "Codex review 03 — response".

Scope: (1) is each round-1 finding closed exactly — above all the box mapping: it is now
pure aspect-fill geometry from the view to the UPRIGHT photo (`LabelFramingBox.visionRegion
(box:viewSize:imageSize:)`, `UIImage.size` being the oriented size). Check the arithmetic
against the numeric tests and against what an `AVCaptureVideoPreviewLayer` with
`.resizeAspectFill` actually shows of a `.photo`-preset still (is the preview's field the
photo's field? any known crop difference between preview and photo on the .photo preset?);
state clearly what remains unverifiable without a phone. (2) The capture lifecycle:
`captureRequest: UUID?` + a coordinator that adopts the current value; `captureFinished()`
as the single terminal; the 8 s timeout Task and its cancellation on every path (dismiss
mid-capture? phase change?); the one-shot focus polling on the session queue (can it
deadlock, leak, or fire capturePhoto after stop()?); `pendingFrame` read/written on which
queues. (3) Whether any fix introduced a new defect. (4) Claims: the ticket response, the
STATE head, the commit message, test counts. The full UI suite is being run locally in
chunks and its result will be appended to the ticket — do not run UI tests yourself on the
WT-iPhone simulator concurrently; the unit target is fine.

If everything is closed, say "clear" in one paragraph. Otherwise report by severity with
file:line. Do not modify source files. Write to
.scratch/scanner-accuracy/codex-review-03b.md
