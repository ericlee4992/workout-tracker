import Foundation
import Testing

@testable import WorkoutTracker

/// Asserts the built app's `Info.plist`, not the source.
///
/// WHY THIS EXISTS: on 2026-08-25 the rest alarm beeped only while the app was
/// on screen: iOS suspended the backgrounded app, so no samples arrived, the
/// sample-driven alarm never fired, and every SwiftUI timer had stopped too.
/// The fix that held queues each rest's [silence][beep] track when the rest
/// starts, played under the `audio` mode (D46); the `workout-processing` mode
/// added among the attempts was removed on 2026-10-13 because App Store Connect
/// rejects it for an iPhone app.
///
/// Nothing in the codebase could catch that. Worse, two build-setting traps had
/// already been hit in two days:
///
/// 1. `INFOPLIST_KEY_UIBackgroundModes` is accepted as a build setting, appears
///    in `-showBuildSettings`, and is silently dropped by the plist generator,
///    which only writes an allowlist of keys. Array-valued keys are not on it.
/// 2. After switching to a partial `INFOPLIST_FILE`, the first INCREMENTAL
///    build produced a plist missing both HealthKit usage strings — which is a
///    crash on the permission request, not a prompt. Only a clean build was
///    correct.
///
/// Both were caught by hand, by remembering to look. This test is what makes
/// looking automatic.
struct BackgroundModesTests {

    /// The APP bundle, not the test bundle. `Bundle(for:)` with a class defined
    /// in the test target returns the test bundle, whose plist has none of these
    /// keys — the assertions then fail for the wrong reason.
    private var infoPlist: [String: Any] {
        Bundle.main.infoDictionary ?? [:]
    }

    private var backgroundModes: [String] {
        infoPlist["UIBackgroundModes"] as? [String] ?? []
    }

    /// App Store Connect rejects an iPhone app whose `UIBackgroundModes` lists
    /// `workout-processing` ("contains an invalid value", 2026-10-13), so no
    /// TestFlight or App Store build can carry it. The screen-off rest alarm needs
    /// the `audio` mode (the next test); whether the app keeps running between
    /// rests is device behavior no plist test can show (ticket 01b).
    @Test func noModeTheAppStoreRejects() {
        #expect(
            !backgroundModes.contains("workout-processing"),
            "UIBackgroundModes is \(backgroundModes) — App Store Connect refuses the upload with workout-processing in an iPhone app")
    }

    /// Without this the alarm cannot start playing while backgrounded, which is
    /// the only time it matters.
    @Test func audioCanStartWhileBackgrounded() {
        #expect(
            backgroundModes.contains("audio"),
            "UIBackgroundModes is \(backgroundModes) — without audio the rest alarm cannot begin playback from the background")
    }

    /// A missing HealthKit usage string is a CRASH on the permission request,
    /// not a prompt — and an incremental build has already dropped these once.
    @Test func healthKitUsageStringsSurvivedThePlistMerge() {
        for key in ["NSHealthShareUsageDescription", "NSHealthUpdateUsageDescription"] {
            let value = infoPlist[key] as? String ?? ""
            #expect(
                !value.isEmpty,
                "\(key) is missing from the built plist — asking for HealthKit permission would crash. Clean build after any INFOPLIST_FILE change.")
        }
    }

    @Test func cameraUsageStringSurvivedThePlistMerge() {
        let value = infoPlist["NSCameraUsageDescription"] as? String ?? ""
        #expect(!value.isEmpty, "the scanner crashes on presentation without this")
    }
}
