import AVFoundation
import SwiftUI
import UIKit

/// A still from the shutter and the Vision region the framing box maps to in
/// it. One value, because the rectangle is meaningless for any other image
/// (codex-review-03: the pair travelled as two loose arguments).
struct CapturedLabel {
    /// The shutter tap this still answers, so a late arrival cannot be
    /// mistaken for a newer request's (codex-review-03b).
    let requestID: UUID
    let image: UIImage
    /// `MachineLabelOCR`'s `regionOfInterest` — normalised, bottom-left
    /// origin, in the upright photo.
    let region: CGRect
}

/// Scanner accuracy, ticket 03 — the camera as a viewfinder with a shutter.
///
/// The previous scanner read every video frame and settled when two
/// consecutive reads agreed on a top row whatever its score, so it settled on
/// half-read plates and kept resetting while the camera moved; the user
/// called it slow and asked to capture first. Now nothing is read until the
/// shutter: one still at the camera's photo resolution, focused on the
/// framing box at the tap, handed back with the box as Vision's region of
/// interest. No photo is written anywhere (D34) — it exists in memory until it
/// is read.
struct LabelCameraView: UIViewControllerRepresentable {
    /// Identifies the shutter tap the sheet wants honoured; nil = none. A
    /// fresh coordinator adopts the CURRENT value, so recreating the camera
    /// after "Scan again" never replays an old tap (codex-review-03).
    let captureRequest: UUID?
    let onPhoto: (CapturedLabel) -> Void
    /// The request that failed, or nil for a failure of the camera itself
    /// (configuration), which is not tied to any tap.
    let onFailure: (UUID?, String) -> Void
    let torchOn: Bool

    func makeCoordinator() -> Coordinator { Coordinator(honoured: captureRequest) }

    func makeUIViewController(context: Context) -> LabelCameraController {
        let controller = LabelCameraController()
        controller.onPhoto = onPhoto
        controller.onFailure = onFailure
        return controller
    }

    func updateUIViewController(_ controller: LabelCameraController, context: Context) {
        controller.onPhoto = onPhoto
        controller.onFailure = onFailure
        controller.setTorch(torchOn)
        if let request = captureRequest, request != context.coordinator.honoured {
            context.coordinator.honoured = request
            controller.capture(request)
        }
    }

    static func dismantleUIViewController(_ controller: LabelCameraController, coordinator: Coordinator) {
        controller.stop()
    }

    final class Coordinator {
        var honoured: UUID?
        init(honoured: UUID?) { self.honoured = honoured }
    }
}

/// Owns the capture session, the preview and the photo output.
final class LabelCameraController: UIViewController {
    var onPhoto: ((CapturedLabel) -> Void)?
    var onFailure: ((UUID?, String) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "machine-label-scan.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var device: AVCaptureDevice?
    /// The request in flight, and the view's size and box at its shutter,
    /// for the region once the photo (and so its size) is known. Main queue.
    private var pending: (request: UUID, viewSize: CGSize, box: CGRect)?
    /// The one-shot focus is observed as a STARTED-then-SETTLED transition:
    /// `isAdjustingFocus` / `isAdjustingExposure` are current state, not a
    /// promise, and read false in the instant before the cycle begins
    /// (codex-review-03b, 03c). Up to `focusStartBudget` is allowed for the
    /// cycle to start (a lens already on target may never adjust), and up to
    /// `focusBudget` in total for it to settle; then the photo is taken anyway.
    private let focusStartBudget: TimeInterval = 0.3
    private let focusBudget: TimeInterval = 1.0
    private let focusPoll: TimeInterval = 0.03
    /// Bumped by `stop()` ON THE SESSION QUEUE, and only ever read there, so a
    /// focus wait from an earlier generation does nothing when it wakes and a
    /// dismissed sheet never takes a photo (codex-review-03c: the first cut
    /// bumped it on main and raced the read).
    private var generation = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stop()
    }

    // MARK: - Session

    private func configureSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            onFailure?(nil, "This device has no usable camera.")
            return
        }
        self.device = device

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer

        sessionQueue.async { [weak self] in
            guard let self else { return }
            session.beginConfiguration()
            session.sessionPreset = .photo
            do {
                let input = try AVCaptureDeviceInput(device: device)
                guard session.canAddInput(input) else { throw NSError(domain: "scan", code: 1) }
                session.addInput(input)
                guard session.canAddOutput(photoOutput) else { throw NSError(domain: "scan", code: 2) }
                session.addOutput(photoOutput)
            } catch {
                session.commitConfiguration()
                DispatchQueue.main.async {
                    self.onFailure?(nil, "Could not open the camera: \(error.localizedDescription)")
                }
                return
            }
            // Portrait-only app: preview and photo are both presented upright.
            // The photo's pixels stay in sensor orientation with an EXIF tag,
            // which `UIImage(data:)` carries and Vision applies; the box is
            // mapped into that UPRIGHT image by `LabelFramingBox`.
            for connection in [photoOutput.connection(with: .video), layer.connection].compactMap({ $0 })
            where connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            // Text at arm's length on a name plate is close-focus work.
            try? device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isAutoFocusRangeRestrictionSupported { device.autoFocusRangeRestriction = .near }
            device.unlockForConfiguration()
            session.commitConfiguration()
            session.startRunning()
        }
    }

    /// The shutter: a one-shot focus and exposure on the box, then one still.
    /// The box's position is captured NOW, from the preview the user is
    /// looking at, and turned into the region once the photo's size is known.
    func capture(_ request: UUID) {
        guard view.bounds.width > 0, let previewLayer else {
            onFailure?(request, "The camera is not ready yet.")
            return
        }
        let box = LabelFramingBox.rect(in: view.bounds.size)
        pending = (request, view.bounds.size, box)
        let point = previewLayer.captureDevicePointConverted(fromLayerPoint: CGPoint(x: box.midX, y: box.midY))
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off  // the torch is the only light in a gym
        sessionQueue.async { [weak self] in
            guard let self, session.isRunning, session.outputs.contains(photoOutput) else {
                DispatchQueue.main.async { self?.onFailure?(request, "The camera is not running.") }
                return
            }
            let generation = self.generation
            focusOnce(at: point)
            let started = Date()
            waitForFocus(
                started: started, sawAdjusting: false
            ) { [weak self] in
                // Re-checked at the last moment, on the session queue: the
                // sheet may have been dismissed (and the session stopped)
                // while the lens moved.
                guard let self, self.generation == generation, session.isRunning else { return }
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    /// One-shot focus and exposure at the box (ticket: "locked on the box on
    /// tap"); continuous mode resumes after the photo is taken.
    private func focusOnce(at point: CGPoint) {
        guard let device, (try? device.lockForConfiguration()) != nil else { return }
        if device.isFocusPointOfInterestSupported { device.focusPointOfInterest = point }
        if device.isFocusModeSupported(.autoFocus) { device.focusMode = .autoFocus }
        if device.isExposurePointOfInterestSupported { device.exposurePointOfInterest = point }
        if device.isExposureModeSupported(.autoExpose) { device.exposureMode = .autoExpose }
        device.unlockForConfiguration()
    }

    /// Polls on the session queue for the one-shot cycle to START and then
    /// SETTLE, then runs `then` on the session queue. Falls through when the
    /// cycle never starts within `focusStartBudget` (the lens was already on
    /// target) or has not settled by `focusBudget`.
    private func waitForFocus(started: Date, sawAdjusting: Bool, then: @escaping () -> Void) {
        guard let device else { then(); return }
        let adjusting = device.isAdjustingFocus || device.isAdjustingExposure
        let elapsed = Date().timeIntervalSince(started)
        let seen = sawAdjusting || adjusting
        if seen, !adjusting { then(); return }           // started, then settled
        if !seen, elapsed >= focusStartBudget { then(); return }  // never started
        if elapsed >= focusBudget { then(); return }     // still hunting: take it anyway
        sessionQueue.asyncAfter(deadline: .now() + focusPoll) { [weak self] in
            self?.waitForFocus(started: started, sawAdjusting: seen, then: then)
        }
    }

    private func resumeContinuousFocus() {
        guard let device, (try? device.lockForConfiguration()) != nil else { return }
        if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
        if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
        device.unlockForConfiguration()
    }

    func stop() {
        setTorch(false)
        sessionQueue.async { [weak self] in
            guard let self else { return }
            generation += 1
            if session.isRunning { session.stopRunning() }
        }
    }

    func setTorch(_ on: Bool) {
        guard let device, device.hasTorch, device.isTorchAvailable else { return }
        sessionQueue.async {
            try? device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        }
    }
}

extension LabelCameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        resumeContinuousFocus()
        // The encoded representation carries the orientation the photo was
        // taken at; `UIImage(data:)` keeps it and `MachineLabelOCR` hands it
        // to Vision, whose region is then in the upright image's coordinates.
        let decoded = error == nil ? photo.fileDataRepresentation().flatMap(UIImage.init(data:)) : nil
        let failure = error.map { "Could not take the photo: \($0.localizedDescription)" }
            ?? (decoded == nil ? "The photo could not be read." : nil)
        DispatchQueue.main.async {
            guard let pending = self.pending else { return }  // stopped or superseded: nothing to report
            self.pending = nil
            if let failure {
                self.onFailure?(pending.request, failure)
                return
            }
            guard let image = decoded else { return }
            // `image.size` is the UPRIGHT size (orientation applied).
            let region = LabelFramingBox.visionRegion(box: pending.box, viewSize: pending.viewSize, imageSize: image.size)
            self.onPhoto?(CapturedLabel(requestID: pending.request, image: image, region: region))
        }
    }
}
