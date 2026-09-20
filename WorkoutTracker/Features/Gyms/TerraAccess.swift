import Foundation
import SwiftUI

/// Consent is local to this installation and can be revoked in Settings.
/// Permission to send a photograph does not authorize sending a routine profile.
enum TerraAccess {
    static let photoConsentKey = "openai.photoConsent.v1"
    static let routineConsentKey = "openai.routineConsent.v1"
    static var fixture: Bool { WorkoutTrackerStore.fixtureIsEnabled("-uiTestTerra") }
    static var bypassesConsent: Bool { fixture && !ProcessInfo.processInfo.arguments.contains("-uiTestTerraNeedsConsent") }
    static var client: TerraClient? { AskAIKeyStore.read().map { TerraClient(key: $0) } }
    static func fixtureDelay() async throws {
        let slow = ProcessInfo.processInfo.arguments.contains("-uiTestTerraSlow")
        try await Task.sleep(for: .milliseconds(slow ? 4000 : 200))
        if ProcessInfo.processInfo.arguments.contains("-uiTestTerraOffline") {
            throw TerraError.message("Could not reach OpenAI. Check your connection or continue manually.")
        }
    }
}
