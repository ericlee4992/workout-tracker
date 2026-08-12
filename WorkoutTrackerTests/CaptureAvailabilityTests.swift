import AVFoundation
import Testing

@testable import WorkoutTracker

// Photo machine capture, ticket 02 — what the app decides *before* presenting
// anything. Pure enough to test directly, which matters because the states it
// covers (no camera, denied, restricted) are the ones a Simulator cannot
// reproduce and a user hits on a real phone.

struct CaptureAvailabilityTests {

    @Test func resolvesEveryAuthorizationState() {
        #expect(CaptureAvailability.resolve(hasCamera: true, status: .authorized) == .camera)
        // Not-determined means "ask" — presenting the picker is what asks.
        #expect(CaptureAvailability.resolve(hasCamera: true, status: .notDetermined) == .camera)
        #expect(CaptureAvailability.resolve(hasCamera: true, status: .denied) == .cameraDenied)
        #expect(
            CaptureAvailability.resolve(hasCamera: true, status: .restricted) == .cameraRestricted)
        // No hardware beats any permission state — the Simulator, or an iPad
        // with the camera stripped by policy.
        #expect(CaptureAvailability.resolve(hasCamera: false, status: .authorized) == .noCamera)
        #expect(CaptureAvailability.resolve(hasCamera: false, status: .denied) == .noCamera)
    }

    @Test func everyBlockedStateExplainsItselfAndOffersARoute() {
        #expect(CaptureAvailability.camera.reason == nil, "a working camera needs no excuse")
        for blocked in [CaptureAvailability.noCamera, .cameraDenied, .cameraRestricted] {
            let reason = blocked.reason
            #expect(reason?.isEmpty == false, "\(blocked) must say why")
            #expect(!blocked.allowsCamera)
        }
    }

    /// Settings is offered only where it is a remedy. A restricted device
    /// cannot be unrestricted from Settings, and sending someone there is worse
    /// than saying nothing.
    @Test func settingsIsOfferedOnlyWhenItWouldHelp() {
        #expect(CaptureAvailability.cameraDenied.settingsCanHelp)
        #expect(!CaptureAvailability.cameraRestricted.settingsCanHelp)
        #expect(!CaptureAvailability.noCamera.settingsCanHelp)
        #expect(!CaptureAvailability.camera.settingsCanHelp)
    }

    @Test func theSourcePickedFollowsAvailability() {
        #expect(ImagePicker.Source.preferred(given: .camera) == .camera)
        #expect(ImagePicker.Source.preferred(given: .noCamera) == .photoLibrary)
        #expect(ImagePicker.Source.preferred(given: .cameraDenied) == .photoLibrary)
        #expect(ImagePicker.Source.preferred(given: .cameraRestricted) == .photoLibrary)
    }
}
