import CryptoKit
import Foundation
import Security

/// Public beta ticket 03 (app half): the account calls to the app's server (server/README → Endpoints). Signed-in
/// calls send `Authorization: Bearer <session>`; every error is `{ "error": "<code>" }`. Nothing here logs a token.
struct AccountClient: Sendable {
    let baseURL: URL
    var session: URLSession = .shared

    /// What Apple handed the app for one sign-in, plus the raw nonce whose SHA-256 the request carried.
    struct AppleCredential: Equatable, Sendable {
        var identityToken: String
        var authorizationCode: String
        var rawNonce: String
        /// Apple gives the name only on the first authorization, to the app; the server keeps it from then on.
        var givenName: String?
        var familyName: String?
    }

    struct SignIn: Equatable, Sendable {
        var session: String
        var expiresAt: Date
    }

    /// `GET /v1/profile`: the account and its training profile (ticket 05).
    struct Profile: Equatable, Sendable {
        var displayName: String?
        var email: String?
        var provider: String
        var memberSince: Date
        var training: TrainingProfile?
    }

    /// `GET /v1/ai/usage`.
    struct Usage: Equatable, Sendable {
        struct Flow: Equatable, Sendable { var used: Int; var limit: Int }
        var resetsAt: Date
        var paused: Bool
        var flows: [String: Flow]
    }

    /// `DELETE /v1/account`'s answer about Apple's tokens (server/README): revoked now; queued for retry; never kept.
    /// Pending and manual both mean the user is told at once how to stop Sign in with Apple in iOS Settings (TN3194).
    enum AppleRevocation: String, Equatable, Sendable { case done, pending, manual }

    enum Failure: Error, Equatable {
        /// No answer, a timeout, or the server failing (5xx): try again later.
        case unreachable
        /// The session is unknown, expired or its account gone: the app is signed out.
        case unauthorized
        /// `409 reauthorize`: a deletion claimed this sign-in's Apple token; ask Apple again.
        case reauthorize
        /// `409 deletion_in_progress`: another request is deleting this account.
        case deletionInProgress
        /// Anything else the server refused, with its code (a bug or a bad token, not the tester's doing).
        case refused(String)
    }

    // MARK: Requests

    func signInRequest(_ credential: AppleCredential) -> URLRequest {
        var body: [String: String] = ["identityToken": credential.identityToken,
                                      "authorizationCode": credential.authorizationCode,
                                      "nonce": credential.rawNonce]
        if let given = credential.givenName { body["givenName"] = given }
        if let family = credential.familyName { body["familyName"] = family }
        return request("POST", "v1/auth/apple", json: body)
    }

    /// Ticket 04: `POST /v1/auth/google` — Google's ID token and the raw nonce whose SHA-256 the authorization carried.
    func googleSignInRequest(idToken: String, rawNonce: String) -> URLRequest {
        request("POST", "v1/auth/google", json: ["idToken": idToken, "nonce": rawNonce])
    }

    func request(_ method: String, _ path: String, token: String? = nil, json: Any? = nil) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: json)
        }
        return request
    }

    // MARK: Calls

    func signIn(_ credential: AppleCredential) async throws(Failure) -> SignIn {
        try Self.signIn(from: await call(signInRequest(credential)))
    }

    func signInWithGoogle(idToken: String, rawNonce: String) async throws(Failure) -> SignIn {
        try Self.signIn(from: await call(googleSignInRequest(idToken: idToken, rawNonce: rawNonce)))
    }

    static func signIn(from object: [String: Any]) throws(Failure) -> SignIn {
        guard let token = object["session"] as? String, !token.isEmpty,
              let expires = object["expiresAt"] as? Double else { throw .refused("malformed") }
        return SignIn(session: token, expiresAt: Date(timeIntervalSince1970: expires / 1000))
    }

    func signOut(token: String) async throws(Failure) {
        _ = try await call(request("POST", "v1/auth/signout", token: token))
    }

    func profile(token: String) async throws(Failure) -> Profile {
        try Self.profile(from: await call(request("GET", "v1/profile", token: token)))
    }

    /// `PUT /v1/profile`: a new name, a training profile (`.some(nil)` removes it), or both; returns the saved profile.
    func update(token: String, displayName: String? = nil, training: TrainingProfile?? = nil) async throws(Failure) -> Profile {
        var body: [String: Any] = [:]
        if let displayName { body["displayName"] = displayName }
        if let training {
            if let training {
                guard let data = try? JSONEncoder().encode(training),
                      let object = try? JSONSerialization.jsonObject(with: data) else { throw .refused("encoding") }
                body["training"] = object
            } else {
                body["training"] = NSNull()
            }
        }
        return try Self.profile(from: await call(request("PUT", "v1/profile", token: token, json: body)))
    }

    func usage(token: String) async throws(Failure) -> Usage {
        let object = try await call(request("GET", "v1/ai/usage", token: token))
        guard let resets = object["resetsAt"] as? Double, let flows = object["flows"] as? [String: [String: Any]]
        else { throw .refused("malformed") }
        var parsed: [String: Usage.Flow] = [:]
        for (flow, value) in flows {
            guard let used = value["used"] as? Int, let limit = value["limit"] as? Int else { throw .refused("malformed") }
            parsed[flow] = Usage.Flow(used: used, limit: limit)
        }
        return Usage(resetsAt: Date(timeIntervalSince1970: resets / 1000), paused: object["paused"] as? Bool ?? false,
                     flows: parsed)
    }

    func deleteAccount(token: String) async throws(Failure) -> AppleRevocation {
        let object = try await call(request("DELETE", "v1/account", token: token))
        // An unknown answer is treated as the cautious one: the user is shown the iOS Settings route.
        return (object["appleRevocation"] as? String).flatMap(AppleRevocation.init(rawValue:)) ?? .pending
    }

    // MARK: Plumbing

    private func call(_ request: URLRequest) async throws(Failure) -> [String: Any] {
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) } catch { throw .unreachable }
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw .unreachable }
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        if (200..<300).contains(status) { return object }
        throw Self.failure(status: status, code: object["error"] as? String)
    }

    static func failure(status: Int, code: String?) -> Failure {
        switch (status, code) {
        case (401, _): .unauthorized
        case (409, "reauthorize"): .reauthorize
        case (409, "deletion_in_progress"): .deletionInProgress
        case (500..., _), (408, _), (429, _): .unreachable
        default: .refused(code ?? "status_\(status)")
        }
    }

    static func profile(from object: [String: Any]) throws(Failure) -> Profile {
        guard let provider = object["provider"] as? String, let since = object["memberSince"] as? Double
        else { throw .refused("malformed") }
        var training: TrainingProfile?
        if let raw = object["training"], !(raw is NSNull) {
            guard let data = try? JSONSerialization.data(withJSONObject: raw),
                  let decoded = try? JSONDecoder().decode(TrainingProfile.self, from: data) else { throw .refused("malformed") }
            training = decoded
        }
        return Profile(displayName: object["displayName"] as? String, email: object["email"] as? String,
                       provider: provider, memberSince: Date(timeIntervalSince1970: since / 1000), training: training)
    }
}

// MARK: - Nonce

/// The sign-in nonce (server: `claims.nonce === sha256Hex(rawNonce)`): the app keeps the raw value, gives Apple its
/// SHA-256 in lowercase hex, and sends the raw value to the server, which binds Apple's token to this sign-in.
enum SignInNonce {
    /// 32 random bytes as base64url (43 characters; the server wants 16–256).
    static func make() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed")
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func sha256Hex(_ raw: String) -> String {
        SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Session token

/// The session token in its own keychain item: this device only (never in a backup or on another phone), readable
/// after first unlock. Under `-uiTestReset` an in-memory slot stands in, so UI tests never touch the keychain.
enum AccountSessionStore {
    private static let service = (Bundle.main.bundleIdentifier ?? "workouttracker") + ".account"
    private static let account = "session"
    nonisolated(unsafe) private static var memory: String?

    static func read() -> String? {
        if WorkoutTrackerStore.isUITestReset { return memory }
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data,
              let token = String(data: data, encoding: .utf8), !token.isEmpty else { return nil }
        return token
    }

    /// Replaces whatever is stored. Fails rather than leaving the app believing it is signed in without a token.
    static func write(_ token: String) throws {
        if WorkoutTrackerStore.isUITestReset { memory = token; return }
        delete()
        var attributes = baseQuery
        attributes[kSecValueData as String] = Data(token.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    static func delete() {
        if WorkoutTrackerStore.isUITestReset { memory = nil; return }
        SecItemDelete(baseQuery as CFDictionary)
    }

    private static var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    struct KeychainError: Error, LocalizedError {
        let status: OSStatus
        var errorDescription: String? { "Could not save the sign-in to the keychain (\(status))." }
    }
}
