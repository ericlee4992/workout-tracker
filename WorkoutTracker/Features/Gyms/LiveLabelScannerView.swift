import AVFoundation
import SwiftUI
import UIKit
import Vision

/// Live in-app scanning: point the phone at a name plate and it reads
/// continuously, no shutter and no photo.
///
/// This replaces taking a picture for the primary path. A camera picker means
/// shutter → review → "Use Photo" before the app has read a single word, which
/// is three taps too many when you are standing at a machine, and it produces a
/// photograph that then has to be thrown away (D34). Live frames are never
/// written anywhere — they exist in a buffer and are gone.
struct LiveLabelScannerView: UIViewControllerRepresentable {
    /// Called on the main actor for each reading, several times a second.
    let onReading: (LabelReading) -> Void
    /// Called if the camera cannot be started at all.
    let onFailure: (String) -> Void
    /// Drives the torch, for the dim corner of the gym where the plate lives.
    let torchOn: Bool

    func makeUIViewController(context: Context) -> LiveLabelScannerController {
        let controller = LiveLabelScannerController()
        controller.onReading = onReading
        controller.onFailure = onFailure
        return controller
    }

    func updateUIViewController(_ controller: LiveLabelScannerController, context: Context) {
        controller.setTorch(torchOn)
    }

    static func dismantleUIViewController(
        _ controller: LiveLabelScannerController, coordinator: Coordinator
    ) {
        controller.stop()
    }
}

/// Owns the capture session and runs Vision over its frames.
final class LiveLabelScannerController: UIViewController {
    var onReading: ((LabelReading) -> Void)?
    var onFailure: ((String) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "machine-label-scan.session")
    private let frameQueue = DispatchQueue(label: "machine-label-scan.frames")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var device: AVCaptureDevice?
    /// Frames arrive at 30/second and each recognition costs far more than
    /// 1/30s, so all but a few would queue up behind the one being worked on.
    private var lastProcessed = Date.distantPast
    private var isProcessing = false
    private let interval: TimeInterval = 0.35

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
        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back)
        else {
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
            session.sessionPreset = .hd1920x1080

            do {
                let input = try AVCaptureDeviceInput(device: device)
                guard session.canAddInput(input) else {
                    throw NSError(domain: "scan", code: 1)
                }
                session.addInput(input)
            } catch {
                session.commitConfiguration()
                DispatchQueue.main.async {
                    self.onFailure?("Could not open the camera: \(error.localizedDescription)")
                }
                return
            }

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: frameQueue)
            if session.canAddOutput(output) { session.addOutput(output) }
            // Portrait-only app: rotate the buffers upright at the source so
            // Vision reads level text and the line order means what it says.
            if let connection = output.connection(with: .video),
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }

            // Text at arm's length on a name plate is close-focus work.
            try? device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }
            device.unlockForConfiguration()

            session.commitConfiguration()
            session.startRunning()
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

// MARK: - Reading frames

extension LiveLabelScannerController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !isProcessing, Date().timeIntervalSince(lastProcessed) >= interval,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }
        isProcessing = true
        lastProcessed = Date()
        defer { isProcessing = false }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Same settings as the still path, so a live read and a photographed
        // read feed the matcher the same kind of text.
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]

        // Buffers are already upright (the connection rotates them), so no
        // further orientation is applied here.
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        guard (try? handler.perform([request])) != nil else { return }

        let lines = (request.results ?? []).compactMap {
            observation -> (line: LabelReading.Line, top: CGFloat)? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return (
                LabelReading.Line(
                    text: text,
                    confidence: Double(candidate.confidence),
                    heightFraction: Double(observation.boundingBox.height)),
                observation.boundingBox.maxY)
        }
        guard !lines.isEmpty else { return }
        let reading = LabelReading(lines: lines.sorted { $0.top > $1.top }.map(\.line))
        DispatchQueue.main.async { [weak self] in
            self?.onReading?(reading)
        }
    }
}
