import Foundation
import Testing

/// Where the unit tests run.
enum TestEnvironment {
    /// GitHub CI's Tests workflow. It sets `TEST_RUNNER_STACKED_CI=1`; xcodebuild drops the `TEST_RUNNER_` prefix and
    /// passes `STACKED_CI` into the test host. Unset locally, so every test runs on the Mac.
    static var isCI: Bool { ProcessInfo.processInfo.environment["STACKED_CI"] == "1" }

    /// Why on-device text recognition is skipped on CI: on GitHub's virtual Mac (the xcode-27 image, 2026-11-14) a
    /// `VNRecognizeTextRequest` never returns — the test host's stacks showed it blocked inside Vision's text reader,
    /// after "fopen failed for data file" — and the whole unit run hung until the job's limit. These tests run locally.
    static let noTextRecognition: Comment = "Vision text recognition hangs on GitHub's virtual Mac; runs locally"
}
