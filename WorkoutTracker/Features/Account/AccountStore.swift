import AuthenticationServices
import Foundation

/// Public beta ticket 03 (app half): the signed-in state the whole app reads — Settings' Account row, the profile
/// page, the welcome page, feedback's session. One instance, made at launch and put in the environment.
///
/// Signed out is the default and changes nothing else in the app (spec → Accounts). The session token lives only in
/// the keychain (`AccountSessionStore`); the profile is fetched from the server and kept in memory for display.
@Observable
@MainActor
final class AccountStore {
    /// Where the token is kept; a fake in unit tests.
    struct TokenSlot {
        var read: () -> String?
        var write: (String) throws -> Void
        var delete: () -> Void
        static let keychain = TokenSlot(read: AccountSessionStore.read, write: AccountSessionStore.write,
                                        delete: AccountSessionStore.delete)
    }

    enum DeleteOutcome: Equatable {
        /// Every server row is gone and Apple's tokens are revoked.
        case deleted
        /// Deleted; the user must stop Sign in with Apple in iOS Settings (Apple TN3194).
        case deletedNeedsAppleStep
        /// Nothing was deleted (or it is unknown): the message says so; still signed in.
        case failed(String)
    }

    /// Nil in a build without a server (and in UI tests): no Account row, no sign-in anywhere.
    let client: AccountClient?
    private let slot: TokenSlot

    private(set) var token: String?
    /// The last profile fetched for this session; nil while loading or signed out.
    private(set) var profile: AccountProfile?
    private(set) var signingIn = false
    /// The sign-in sheet's / welcome page's one line after a failed attempt.
    var signInFailure: String?
    private var pendingNonce: String?

    var isAvailable: Bool { client != nil || sample }
    var isSignedIn: Bool { token != nil }
    /// UI-first sample mode (ProfileSample's flags): no network, the sample profile.
    private let sample: Bool

    init(client: AccountClient?, slot: TokenSlot = .keychain) {
        self.client = client
        self.slot = slot
        self.sample = false
        token = client == nil ? nil : slot.read()
    }

    private init(sampleProfile: AccountProfile?) {
        client = nil
        slot = TokenSlot(read: { nil }, write: { _ in }, delete: {})
        sample = true
        profile = sampleProfile
        token = sampleProfile == nil ? nil : "sample"
    }

    /// The app's instance: the configured server, except under `-uiTestReset`, where the sample flags decide.
    static func forThisApp() -> AccountStore {
        if WorkoutTrackerStore.isUITestReset {
            return ProfileSample.showsAccountRow ? AccountStore(sampleProfile: ProfileSample.profile)
                : AccountStore(client: nil)
        }
        return AccountStore(client: ServerConfig.baseURL.map { AccountClient(baseURL: $0) })
    }

    // MARK: Sign in with Apple

    /// Apple's button's request: name and email (Apple gives them once), and the SHA-256 of a fresh nonce.
    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        signInFailure = nil
        let raw = SignInNonce.make()
        pendingNonce = raw
        request.requestedScopes = [.fullName, .email]
        request.nonce = SignInNonce.sha256Hex(raw)
    }

    /// Apple's answer → the server's sign-in → the token in the keychain → the profile. True when signed in.
    @discardableResult
    func complete(_ result: Result<ASAuthorization, any Error>) async -> Bool {
        let nonce = pendingNonce
        pendingNonce = nil
        switch result {
        case .failure(let error):
            // Closing Apple's sheet is the user's choice, not a failure to report.
            if (error as? ASAuthorizationError)?.code != .canceled { signInFailure = SignInFailure.generic }
            return false
        case .success(let authorization):
            guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identity = apple.identityToken.flatMap({ String(data: $0, encoding: .utf8) }),
                  let code = apple.authorizationCode.flatMap({ String(data: $0, encoding: .utf8) }),
                  let nonce else {
                signInFailure = SignInFailure.generic
                return false
            }
            return await signIn(AccountClient.AppleCredential(
                identityToken: identity, authorizationCode: code, rawNonce: nonce,
                givenName: apple.fullName?.givenName, familyName: apple.fullName?.familyName))
        }
    }

    func signIn(_ credential: AccountClient.AppleCredential) async -> Bool {
        guard let client, !signingIn else { return false }
        signingIn = true
        defer { signingIn = false }
        do {
            let result = try await client.signIn(credential)
            do { try slot.write(result.session) } catch {
                // Not kept, so not signed in: end the server's session rather than strand it.
                try? await client.signOut(token: result.session)
                signInFailure = SignInFailure.generic
                return false
            }
            token = result.session
            signInFailure = nil
            await refresh()
            return true
        } catch {
            signInFailure = error == .unreachable ? SignInFailure.unreachable : SignInFailure.generic
            return false
        }
    }

    // MARK: Signed in

    /// Fetches the profile and today's AI use. A session the server no longer knows signs the app out.
    func refresh() async {
        guard let client, let token else { return }
        do {
            async let fetchedProfile = client.profile(token: token)
            async let fetchedUsage = client.usage(token: token)
            let (account, usage) = try await (fetchedProfile, fetchedUsage)
            guard token == self.token else { return }   // signed out or replaced meanwhile
            profile = Self.display(account, usage: usage)
        } catch {
            // A session the server refuses is over; offline or a server failure keeps the session and whatever was
            // shown, and the next visit tries again.
            if (error as? AccountClient.Failure) == .unauthorized, token == self.token { forget() }
        }
    }

    func rename(_ name: String) async -> Bool {
        if sample { profile?.displayName = name; return true }
        return await save { (client, token) async throws(AccountClient.Failure) in
            try await client.update(token: token, displayName: name)
        }
    }

    func saveTraining(_ training: TrainingProfile?) async -> Bool {
        if sample { profile?.training = training; return true }
        return await save { (client, token) async throws(AccountClient.Failure) in
            try await client.update(token: token, training: .some(training))
        }
    }

    private func save(_ call: (AccountClient, String) async throws(AccountClient.Failure) -> AccountClient.Profile) async -> Bool {
        guard let client, let token else { return false }
        do {
            let saved = try await call(client, token)
            guard token == self.token, var shown = profile else { return true }
            let fresh = Self.display(saved, usage: nil)
            shown.displayName = fresh.displayName
            shown.training = fresh.training
            profile = shown
            return true
        } catch .unauthorized {
            if token == self.token { forget() }
            return false
        } catch {
            return false
        }
    }

    /// Ends the session on the server when it can; the phone forgets it either way (a session left on the server
    /// expires unused in 90 days).
    func signOut() async {
        if sample { return }
        guard let token else { return }
        forget()
        try? await client?.signOut(token: token)
    }

    func deleteAccount() async -> DeleteOutcome {
        // The mock shows the follow-up (the "pending" answer) and keeps the sample page behind it.
        if sample { return .deletedNeedsAppleStep }
        guard let client, let token else { return .failed(AccountDeletionCopy.failed) }
        do {
            let revocation = try await client.deleteAccount(token: token)
            forget()
            return revocation == .done ? .deleted : .deletedNeedsAppleStep
        } catch .unauthorized {
            // The session ended (expired, or the account was deleted elsewhere): nothing here was deleted, so say so.
            forget()
            return .failed(AccountDeletionCopy.signedOut)
        } catch .deletionInProgress {
            // Another request is deleting this account now; it gets the real revocation outcome, so this one gives
            // the cautious instruction.
            forget()
            return .deletedNeedsAppleStep
        } catch {
            return .failed(AccountDeletionCopy.failed)
        }
    }

    private func forget() {
        slot.delete()
        token = nil
        profile = nil
    }

    // MARK: Display

    static let flowTitles = [("scan-machine", "Machine scans"), ("routine-week", "Template weeks"),
                             ("model-exercises", "Exercise suggestions")]

    static func display(_ account: AccountClient.Profile, usage: AccountClient.Usage?) -> AccountProfile {
        AccountProfile(
            displayName: account.displayName ?? AccountDisplayCopy.unnamed,
            email: account.email ?? AccountDisplayCopy.noEmail,
            provider: account.provider == "apple" ? "Apple" : account.provider.capitalized,
            memberSince: account.memberSince,
            training: account.training,
            aiUsage: flowTitles.compactMap { flow, title in
                usage?.flows[flow].map { AccountProfile.AIUsage(flow: flow, title: title, used: $0.used, limit: $0.limit) }
            },
            aiResetsAt: usage?.resetsAt ?? .now,
            aiPaused: usage?.paused ?? false)
    }
}

/// Fallbacks when the server has no name or email for the account (Apple gives both only on the first sign-in).
enum AccountDisplayCopy {
    static let unnamed = "Your Account"
    static let noEmail = "Not shared"
    /// The Settings row while a signed-in session's profile has not loaded yet.
    static let loading = "Signed In"
    static let nameTitle = "Name"
    static let saveFailed = "Couldn't save. Check your connection and try again."
}
