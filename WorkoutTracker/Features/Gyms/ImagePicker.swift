import AVFoundation
import SwiftUI
import UIKit

/// What this device and its permissions will actually allow, resolved *before*
/// anything is presented.
///
/// Ticket 02 asks for a stated reason and a way forward in every case; silently
/// swapping the camera for the photo library (or handing a denied permission to
/// `UIImagePickerController` and hoping) is neither (codex-review, finding 6).
enum CaptureAvailability: Equatable {
    /// Camera present and usable — `.notDetermined` counts: presenting is what
    /// triggers the system prompt, which is the correct first ask.
    case camera
    /// No camera on this device (Simulator, or a restricted iPad).
    case noCamera
    /// The user turned camera access off — Settings can turn it back on.
    case cameraDenied
    /// Policy forbids the camera. Settings is not a remedy, so do not offer it
    /// (codex-review-2, finding 6).
    case cameraRestricted

    static func resolve(
        hasCamera: Bool = UIImagePickerController.isSourceTypeAvailable(.camera),
        status: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    ) -> CaptureAvailability {
        guard hasCamera else { return .noCamera }
        switch status {
        case .authorized, .notDetermined: return .camera
        case .denied: return .cameraDenied
        case .restricted: return .cameraRestricted
        @unknown default: return .cameraDenied
        }
    }

    /// Whether the camera can actually be opened.
    var allowsCamera: Bool { self == .camera }

    /// Whether opening Settings would change anything.
    var settingsCanHelp: Bool { self == .cameraDenied }

    /// What to tell the user, or nil when the camera simply works.
    var reason: String? {
        switch self {
        case .camera: nil
        case .noCamera: "This device has no camera — pick a photo of the name plate instead."
        case .cameraDenied:
            "Camera access is off for Workout Tracker. Turn it on in Settings, or pick a photo you already took."
        case .cameraRestricted:
            "Camera access is restricted on this device. Pick a photo of the name plate instead."
        }
    }
}

/// Photo machine capture, ticket 02 — a photograph of a name plate, from the
/// camera or the photo library.
///
/// `UIImagePickerController` rather than `PhotosPicker`, because this needs the
/// *camera* and PhotosPicker cannot take one; the same controller covers the
/// library fallback, so there is one presentation path instead of two.
struct ImagePicker: UIViewControllerRepresentable {
    enum Source: Equatable {
        case camera
        case photoLibrary

        /// The camera when `CaptureAvailability` says it will work, otherwise
        /// the photo library — a photo taken earlier is a perfectly good input.
        /// The *reason* for a fallback is shown by the sheet; this only picks.
        static func preferred(
            given availability: CaptureAvailability = .resolve()
        ) -> Source {
            availability.allowsCamera ? .camera : .photoLibrary
        }

        var sourceType: UIImagePickerController.SourceType {
            switch self {
            case .camera: .camera
            case .photoLibrary: .photoLibrary
            }
        }
    }

    let source: Source
    /// nil = the user backed out.
    let onPicked: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = source.sourceType
        controller.allowsEditing = false
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate,
                             UINavigationControllerDelegate {
        private let onPicked: (UIImage?) -> Void
        /// The delegate can fire twice if the user is quick; the reading is
        /// started from this callback, so it must happen exactly once.
        private var hasFinished = false

        init(onPicked: @escaping (UIImage?) -> Void) {
            self.onPicked = onPicked
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            finish(with: info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            finish(with: nil)
        }

        private func finish(with image: UIImage?) {
            guard !hasFinished else { return }
            hasFinished = true
            onPicked(image)
        }
    }
}
