import Foundation
import SwiftUI

/// Consent is local to this installation and can be revoked in Settings.
/// Permission to send a photograph does not authorize sending a routine profile.
enum TerraAccess {
    static let photoConsentKey = "openai.photoConsent.v1"
    static let exerciseConsentKey = "openai.exerciseConsent.v1"
    static let routineConsentKey = "openai.routineConsent.v1"
    static var fixture: Bool { WorkoutTrackerStore.fixtureIsEnabled("-uiTestTerra") }
    static var bypassesConsent: Bool { fixture && !ProcessInfo.processInfo.arguments.contains("-uiTestTerraNeedsConsent") }

    /// Ticket 06: AI needs a signed-in account (D60). The UI-test fixture answers locally, signed out too — unless a
    /// sample account is in play (`ProfileSample`), which then decides, so the signed-out screens can be driven.
    @MainActor static func ready(_ account: AccountStore) -> Bool {
        account.isSignedIn || (fixture && !account.isAvailable)
    }

    /// The server client for this session; nil signed out. A 401 signs the phone out (only if that session is still the
    /// current one), so every AI entry point then shows Sign In.
    @MainActor static func client(_ account: AccountStore) -> AIServerClient? {
        guard let baseURL = account.client?.baseURL, let token = account.token else { return nil }
        return AIServerClient(baseURL: baseURL, token: token, onUnauthorized: { [weak account] refused in
            Task { @MainActor in account?.invalidate(token: refused) }
        })
    }

    static func fixtureDelay() async throws {
        let arguments = ProcessInfo.processInfo.arguments
        try await Task.sleep(for: .milliseconds(arguments.contains("-uiTestTerraSlow") ? 4000 : 200))
        if let failure = fixtureFailure { throw failure }
    }

    /// The fixture's failures, one flag each, for the captures and the error-copy tests.
    static var fixtureFailure: AIServerError? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-uiTestTerraOffline") { return .offline }
        if arguments.contains("-uiTestTerraPaused") { return .paused }
        if arguments.contains("-uiTestTerraLimit") { return .limit(.scanMachine, 60, resetsAt: AIResetCopy.nextReset()) }
        if arguments.contains("-uiTestTerraRoutineLimit") { return .limit(.routineWeek, 10, resetsAt: AIResetCopy.nextReset()) }
        return nil
    }
}
