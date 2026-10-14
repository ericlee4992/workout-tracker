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
        /// Every server row is gone and Apple's tokens are revoked; signed out.
        case deleted
        /// Deleted (or being deleted by another request); signed out; the user must stop Sign in with Apple in iOS
        /// Settings (Apple TN3194).
        case deletedNeedsAppleStep
        /// The server refused the session (expired, or the account was deleted elsewhere): nothing was deleted by
        /// this request; signed out. Never reported as a deletion.
        case signedOut
        /// No answer or a server failure: nothing is known to be deleted; still signed in; the message says so.
        case failed(String)
        /// A newer session replaced this one while the request was out (signed out and in again), or another deletion
        /// request is already out: nothing is changed or shown here.
        case superseded
    }

    /// The server's client; nil in a build without a server (no Account row, no sign-in anywhere) and for the tour's
    /// and UI tests' stores (the UI-first sample store is the exception: nil client, `isAvailable` via `sample`).
    let client: AccountClient?
    private let slot: TokenSlot

    private(set) var token: String?
    /// The last profile fetched for this session; nil while the first load runs, when it failed, or signed out. A
    /// later refresh that fails keeps the profile already shown.
    private(set) var profile: AccountProfile?
    /// Loading failed with no profile to show (offline or a server failure at the first load): the profile page offers
    /// Try Again and Sign Out instead of the profile.
    private(set) var loadFailed = false
    /// A deletion request is out: a second one is not sent (codex-review-03-app-b #1).
    private(set) var deleting = false
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

    private init(sampleProfile: AccountProfile?, unavailable: Bool = false) {
        client = nil
        slot = TokenSlot(read: { nil }, write: { _ in }, delete: {})
        sample = true
        profile = sampleProfile
        token = sampleProfile == nil && !unavailable ? nil : "sample"
        loadFailed = unavailable
    }

    /// The app's instance: the configured server, except under `-uiTestReset`, where the sample flags decide.
    static func forThisApp() -> AccountStore {
        if WorkoutTrackerStore.isUITestReset {
            return ProfileSample.showsAccountRow
                ? AccountStore(sampleProfile: ProfileSample.profile, unavailable: ProfileSample.unavailable)
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

    /// Fetches the profile and today's AI use, each judged on its own: a 401 from either signs the phone out (it wins
    /// over a transient failure of the other); the profile shows without the AI figures if only usage fails.
    func refresh() async {
        guard let client, let token else { return }
        async let profileResult = Self.attempt { () async throws(AccountClient.Failure) in try await client.profile(token: token) }
        async let usageResult = Self.attempt { () async throws(AccountClient.Failure) in try await client.usage(token: token) }
        let (account, usage) = await (profileResult, usageResult)
        guard token == self.token else { return }   // signed out or replaced meanwhile
        if case .failure(.unauthorized) = account { forget(); return }
        if case .failure(.unauthorized) = usage { forget(); return }
        guard case .success(let fetched) = account else {
            // Offline or a server failure: keep the session and whatever was shown; the page offers Try Again.
            loadFailed = profile == nil
            return
        }
        var shown = Self.display(fetched, usage: try? usage.get())
        if case .failure = usage, let previous = profile {
            shown.aiUsage = previous.aiUsage
            shown.aiResetsAt = previous.aiResetsAt
            shown.aiPaused = previous.aiPaused
        }
        profile = shown
        loadFailed = false
    }

    nonisolated private static func attempt<T: Sendable>(
        _ body: @Sendable () async throws(AccountClient.Failure) -> T
    ) async -> Result<T, AccountClient.Failure> {
        do { return .success(try await body()) } catch { return .failure(error) }
    }

    /// Ticket 04, UI-first stage: Google's sign-in is wired once the user approves the mock (no client ID yet).
    func signInWithGoogle() async -> Bool { false }

    /// UI tests only (`-uiTestSampleSignIn` on the sample store): a sign-in that succeeds at once with a new session —
    /// Apple's own sheet cannot be driven in a UI test (ticket 06: refused session → sign in → AI usable again).
    func completeSampleSignIn() {
        guard sample else { return }
        token = "sample-\(UUID().uuidString.prefix(8))"
        profile = ProfileSample.profile
    }

    /// A request elsewhere (feedback) found this session refused: forget it, unless it was already replaced.
    func invalidate(token refused: String) {
        if refused == token { forget() }
    }

    func rename(_ name: String) async -> Bool {
        if sample { profile?.displayName = name; return true }
        return await save { (client, token) async throws(AccountClient.Failure) in
            try await client.update(token: token, displayName: name)
        }
    }

    func saveTraining(_ training: TrainingProfile?, session: String? = nil) async -> Bool {
        if sample {
            guard session == nil || session == token, !ProfileSample.trainingSaveFails else { return false }
            profile?.training = training
            return true
        }
        return await save(session: session) { (client, token) async throws(AccountClient.Failure) in
            try await client.update(token: token, training: .some(training))
        }
    }

    /// The training saves Ask AI queues (ticket 05's switch), in the order they were requested.
    private var trainingSaves: Task<Bool, Never>?

    /// Ticket 05 (codex-review-05d F1, 05e E1/E2): every training-profile write — Ask AI's "Save to my training
    /// profile" and the profile page's editor. Saves run one after another in the order requested, across sheets, so
    /// an older form never overwrites a newer one on the server or here; each is sent only under the session it was
    /// requested in (signed out or replaced before it starts: not sent). Whether a save is needed is decided inside the
    /// queue, once the earlier saves have settled — a form changed and changed back is still saved after the change.
    func queueTrainingSave(_ training: TrainingProfile?, session: String) -> Task<Bool, Never> {
        let previous = trainingSaves
        let task = Task { @MainActor [weak self] () -> Bool in
            _ = await previous?.value
            guard let self else { return false }
            if self.token == session, let current = self.profile, current.training == training { return true }
            return await self.saveTraining(training, session: session)
        }
        trainingSaves = task
        return task
    }

    /// `session`: the request is sent only if that is still the current session, and under it.
    private func save(session: String? = nil,
                      _ call: (AccountClient, String) async throws(AccountClient.Failure) -> AccountClient.Profile) async -> Bool {
        guard let client, let token, session == nil || session == token else { return false }
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
        if sample { forget(); return }
        guard let token else { return }
        forget()
        try? await client?.signOut(token: token)
    }

    func deleteAccount() async -> DeleteOutcome {
        // The mock shows the follow-up (the "pending" answer) and keeps the sample page behind it.
        if sample { return .deletedNeedsAppleStep }
        guard let client, let token else { return .failed(AccountDeletionCopy.failed) }
        guard !deleting else { return .superseded }   // the request already out reports the outcome
        deleting = true
        defer { deleting = false }
        let answer: Result<AccountClient.AppleRevocation, AccountClient.Failure>
        do { answer = .success(try await client.deleteAccount(token: token)) } catch { answer = .failure(error) }
        // Only a genuinely newer session is left alone (signed out and in again meanwhile). A session merely ended
        // meanwhile — by a refresh's 401 after the server claimed the deletion, or by Sign Out — still gets this
        // answer: the account's deletion and its iOS Settings step must reach the user (codex-review-03-app-b #1).
        if let current = self.token, current != token { return .superseded }
        switch answer {
        case .success(let revocation):
            forgetIfCurrent(token)
            return revocation == .done ? .deleted : .deletedNeedsAppleStep
        case .failure(.unauthorized):
            forgetIfCurrent(token)
            return .signedOut
        case .failure(.deletionInProgress):
            // Another request is deleting this account now; it gets the real revocation outcome, so this one gives
            // the cautious instruction.
            forgetIfCurrent(token)
            return .deletedNeedsAppleStep
        case .failure:
            return .failed(AccountDeletionCopy.failed)
        }
    }

    private func forgetIfCurrent(_ token: String) {
        if self.token == token { forget() }
    }

    private func forget() {
        slot.delete()
        token = nil
        profile = nil
        loadFailed = false
    }

    /// The feedback form's "Account" line: who the feedback is sent as.
    var feedbackAccountLine: String? {
        guard isSignedIn else { return nil }
        guard let profile else { return AccountDisplayCopy.loading }
        return "\(profile.displayName) · \(profile.email)"
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
    /// The profile page when a signed-in session's profile could not be loaded.
    static let unavailable = "Couldn't load your account. Check your connection."
    static let tryAgain = "Try Again"
}
