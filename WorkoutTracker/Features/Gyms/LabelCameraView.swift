import AVFoundation
import SwiftUI
import UIKit

/// Scanner accuracy, ticket 03 — the camera as a viewfinder with a shutter.
///
/// The previous scanner read every video frame and settled when two
/// consecutive reads agreed on a top row whatever its score, so it settled on
/// half-read plates and kept resetting while the camera moved; the user
/// called it slow and asked to capture first. Now nothing is read until the
/// shutter: one still at the camera's photo resolution, focused on the
/// framing box, handed back with the box as Vision's region of interest. No
/// photo is written anywhere (D34) — it exists in memory until it is read.
struct LabelCameraView: UIViewControllerRepresentable {
    /// Incremented by the sheet to take a photo.
    let captureCount: Int
    /// The still and the Vision region the framing box maps to.
    let onPhoto: (UIImage, CGRect) -> Void
    let onFailure: (String) -> Void
    let torchOn: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> LabelCameraController {
        let controller = LabelCameraController()
        controller.onPhoto = onPhoto
        controller.onFailure = onFailure
        return controller
    }

    func updateUIViewController(_ controller: LabelCameraController, context: Context) {
        controller.setTorch(torchOn)
        if captureCount != context.coordinator.lastCapture {
            context.coordinator.lastCapture = captureCount
            controller.capture()
        }
    }

    static func dismantleUIViewController(_ controller: LabelCameraController, coordinator: Coordinator) {
        controller.stop()
    }

    final class Coordinator {
        var lastCapture = 0
    }
}

/// Owns the capture session, the preview and the photo output.
final class LabelCameraController: UIViewController {
    var onPhoto: ((UIImage, CGRect) -> Void)?
    var onFailure: ((String) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "machine-label-scan.session")
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var device: AVCaptureDevice?
    /// The region for the photo in flight, decided at the shutter from the
    /// box's position on the preview at that moment.
    private var pendingRegion = CGRect(x: 0, y: 0, width: 1, height: 1)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        focusOnBox()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stop()
    }

    // MARK: - Session

    private func configureSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            onFailure?("This device has no usable camera.")
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
            } catch {
                session.commitConfiguration()
                DispatchQueue.main.async {
                    self.onFailure?("Could not open the camera: \(error.localizedDescription)")
                }
                return
            }
            if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
            // Portrait-only app: both the preview and the photo are rotated
            // upright at the source, so the box on the preview and the
            // region in the photo share one coordinate space.
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

    /// Focus and exposure on the middle of the framing box, where the plate is.
    private func focusOnBox() {
        guard let device, let previewLayer, view.bounds.width > 0 else { return }
        let box = LabelFramingBox.rect(in: view.bounds.size)
        let point = previewLayer.captureDevicePointConverted(fromLayerPoint: CGPoint(x: box.midX, y: box.midY))
        sessionQueue.async {
            try? device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported { device.focusPointOfInterest = point }
            if device.isExposurePointOfInterestSupported { device.exposurePointOfInterest = point }
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
            device.unlockForConfiguration()
        }
    }

    /// The shutter. The region is decided now, from where the box sits on the
    /// preview, so what the user framed is what gets read.
    func capture() {
        guard let previewLayer, view.bounds.width > 0 else {
            onFailure?("The camera is not ready yet.")
            return
        }
        let box = LabelFramingBox.rect(in: view.bounds.size)
        let metadataRect = previewLayer.metadataOutputRectConverted(fromLayerRect: box)
        pendingRegion = LabelFramingBox.visionRegion(fromMetadataRect: metadataRect)
        let settings = AVCapturePhotoSettings()
        sessionQueue.async { [weak self] in
            guard let self, session.isRunning else {
                DispatchQueue.main.async { self?.onFailure?("The camera is not running.") }
                return
            }
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func stop() {
        setTorch(false)
        sessionQueue.async { [session] in
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
        if let error {
            DispatchQueue.main.async { self.onFailure?("Could not take the photo: \(error.localizedDescription)") }
            return
        }
        // The encoded representation carries the orientation the photo was
        // taken at, which `MachineLabelOCR` hands to Vision (codex-review,
        // finding 5 of the original scanner: a camera image is never `.up`).
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            DispatchQueue.main.async { self.onFailure?("The photo could not be read.") }
            return
        }
        let region = pendingRegion
        DispatchQueue.main.async { self.onPhoto?(image, region) }
    }
}
