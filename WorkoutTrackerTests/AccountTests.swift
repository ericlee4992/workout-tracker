import Foundation
import Testing
@testable import WorkoutTracker

/// Public beta ticket 03 (app half): the account requests the server takes (server/README → Endpoints), how its
/// answers are read, the sign-in nonce, and the account store's transitions — sign-in keeping the token only once
/// it is stored, a refused session signing out, sign-out, and deletion's three outcomes.
@Suite(.serialized)
struct AccountTests {
    private let base = URL(string: "https://stacked.example")!
    private var client: AccountClient { AccountClient(baseURL: base, session: AccountStub.session()) }
    private let credential = AccountClient.AppleCredential(
        identityToken: "id.token.sig", authorizationCode: "code-1", rawNonce: "raw-nonce-0123456789",
        givenName: "Alex", familyName: nil)

    private static let profileJSON: [String: Any] = [
        "displayName": "Alex Kim", "email": "alex@privaterelay.appleid.com", "provider": "apple",
        "memberSince": 1_790_985_600_000.0,
        "training": ["goals": "Pull-up by spring", "experience": "Intermediate", "days": 4, "minutes": 45,
                     "height": ["value": 70, "unit": "in"]],
    ]
    private static let usageJSON: [String: Any] = [
        "day": "2026-10-13", "resetsAt": 1_791_000_000_000.0, "paused": false,
        "flows": ["scan-machine": ["used": 3, "limit": 60], "routine-week": ["used": 1, "limit": 10],
                  "model-exercises": ["used": 0, "limit": 60]],
    ]

    private static func json(_ object: Any) -> Data { try! JSONSerialization.data(withJSONObject: object) }

    // MARK: Requests

    @Test func signInPostsTheTokenCodeRawNonceAndTheFirstName() throws {
        let request = client.signInRequest(credential)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://stacked.example/v1/auth/apple")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        let data = try #require(request.httpBody)
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(body == ["identityToken": "id.token.sig", "authorizationCode": "code-1",
                         "nonce": "raw-nonce-0123456789", "givenName": "Alex"])
    }

    @Test func signedInCallsCarryTheBearerToken() {
        let request = client.request("GET", "v1/profile", token: "tok")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
        #expect(request.httpBody == nil)
    }

    @Test func theNonceIsRandomBase64URLAndItsHashIsLowercaseHex() {
        let a = SignInNonce.make(), b = SignInNonce.make()
        #expect(a != b)
        #expect(a.count == 43)
        #expect(a.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil)
        // FIPS 180-2's "abc" vector: the server compares this exact form (sha256Hex).
        #expect(SignInNonce.sha256Hex("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    // MARK: Answers

    @Test func failuresMapToWhatTheAppDoes() {
        #expect(AccountClient.failure(status: 401, code: "unauthorized") == .unauthorized)
        #expect(AccountClient.failure(status: 409, code: "reauthorize") == .reauthorize)
        #expect(AccountClient.failure(status: 409, code: "deletion_in_progress") == .deletionInProgress)
        #expect(AccountClient.failure(status: 503, code: "server_not_configured") == .unreachable)
        #expect(AccountClient.failure(status: 502, code: nil) == .unreachable)
        #expect(AccountClient.failure(status: 429, code: nil) == .unreachable)
        #expect(AccountClient.failure(status: 400, code: "invalid_token") == .refused("invalid_token"))
        #expect(AccountClient.failure(status: 404, code: nil) == .refused("status_404"))
    }

    @Test func theProfileIsReadWithItsTrainingAndMillisecondDates() throws {
        let profile = try AccountClient.profile(from: Self.profileJSON)
        #expect(profile.displayName == "Alex Kim")
        #expect(profile.memberSince == Date(timeIntervalSince1970: 1_790_985_600))
        #expect(profile.training?.height == BodyMeasure(value: 70, unit: .inches))
        #expect(profile.training?.weight == nil)
        var bare = Self.profileJSON
        bare["displayName"] = NSNull(); bare["email"] = NSNull(); bare["training"] = NSNull()
        let unnamed = try AccountClient.profile(from: bare)
        #expect(unnamed.displayName == nil && unnamed.email == nil && unnamed.training == nil)
        #expect(throws: AccountClient.Failure.refused("malformed")) { try AccountClient.profile(from: ["provider": "apple"]) }
    }

    @MainActor @Test func theDisplayFallsBackAndOrdersTheAIFigures() throws {
        var bare = Self.profileJSON
        bare["displayName"] = NSNull(); bare["email"] = NSNull()
        let usage = AccountClient.Usage(resetsAt: .now, paused: true, flows: [
            "model-exercises": .init(used: 0, limit: 60), "scan-machine": .init(used: 3, limit: 60),
            "routine-week": .init(used: 1, limit: 10)])
        let shown = AccountStore.display(try AccountClient.profile(from: bare), usage: usage)
        #expect(shown.displayName == AccountDisplayCopy.unnamed)
        #expect(shown.email == AccountDisplayCopy.noEmail)
        #expect(shown.provider == "Apple")
        #expect(shown.aiUsage.map(\.flow) == ["scan-machine", "routine-week", "model-exercises"])
        #expect(shown.aiUsage.map(\.title) == ["Machine scans", "Template weeks", "Exercise suggestions"])
        #expect(shown.aiPaused)
    }

    @Test func updateSendsOnlyWhatChangesAndNullRemovesTraining() async throws {
        var bodies: [[String: Any]] = []
        AccountStub.respond = { request in
            bodies.append((try? JSONSerialization.jsonObject(with: AccountStub.body(request))) as? [String: Any] ?? [:])
            return (200, Self.json(Self.profileJSON))
        }
        defer { AccountStub.respond = nil }
        _ = try await client.update(token: "t", displayName: "Sam")
        _ = try await client.update(token: "t", training: .some(nil))
        _ = try await client.update(token: "t", training: .some(TrainingProfile.empty))
        #expect(bodies[0].keys.sorted() == ["displayName"])
        #expect(bodies[1]["training"] is NSNull && bodies[1].count == 1)
        #expect((bodies[2]["training"] as? [String: Any])?["days"] as? Int == 3)
    }

    @Test(arguments: [("done", AccountClient.AppleRevocation.done), ("pending", .pending), ("manual", .manual),
                      ("surprise", .pending)])
    func deletionReadsAppleRevocationCautiously(raw: String, expected: AccountClient.AppleRevocation) async throws {
        AccountStub.respond = { request in
            #expect(request.httpMethod == "DELETE")
            return (200, Self.json(["deleted": true, "appleRevocation": raw]))
        }
        defer { AccountStub.respond = nil }
        #expect(try await client.deleteAccount(token: "t") == expected)
    }

    @Test func noConnectionIsUnreachable() async {
        AccountStub.respond = nil
        await #expect(throws: AccountClient.Failure.unreachable) { try await client.signIn(credential) }
    }

    // MARK: The store

    @MainActor
    private func store(token: String? = nil, writeFails: Bool = false) -> (AccountStore, Box) {
        let box = Box(token: token)
        let slot = AccountStore.TokenSlot(
            read: { box.token },
            write: { if writeFails { throw AskAIKeyStore.KeychainError(status: -25300) }; box.token = $0 },
            delete: { box.token = nil })
        return (AccountStore(client: client, slot: slot), box)
    }

    @MainActor private final class Box { var token: String?; init(token: String?) { self.token = token } }

    /// Answers by route: sign-in, profile, usage, sign-out, delete.
    private func serve(signIn: (Int, Any) = (200, ["session": "s1", "expiresAt": 1.0e12, "profile": [:]]),
                       profile: (Int, Any) = (200, AccountTests.profileJSON),
                       delete: (Int, Any) = (200, ["deleted": true, "appleRevocation": "done"])) -> SignOutLog {
        let log = SignOutLog()
        AccountStub.respond = { request in
            let answer: (Int, Any) = switch (request.httpMethod ?? "", request.url?.path ?? "") {
            case ("POST", "/v1/auth/apple"): signIn
            case ("GET", "/v1/profile"): profile
            case ("GET", "/v1/ai/usage"): (200, AccountTests.usageJSON)
            case ("POST", "/v1/auth/signout"): { log.count += 1; return (200, ["ok": true]) }()
            case ("DELETE", "/v1/account"): delete
            default: (404, ["error": "not_found"])
            }
            return (answer.0, AccountTests.json(answer.1))
        }
        return log
    }

    final class SignOutLog: @unchecked Sendable { var count = 0 }

    @MainActor @Test func signInKeepsTheTokenThenLoadsTheProfile() async {
        _ = serve()
        defer { AccountStub.respond = nil }
        let (store, box) = store()
        #expect(!store.isSignedIn)
        #expect(await store.signIn(credential))
        #expect(box.token == "s1" && store.isSignedIn)
        #expect(store.profile?.displayName == "Alex Kim")
        #expect(store.profile?.aiUsage.first?.used == 3)
        #expect(store.signInFailure == nil)
    }

    @MainActor @Test func aTokenTheKeychainRefusesIsNotASignIn() async {
        let log = serve()
        defer { AccountStub.respond = nil }
        let (store, box) = store(writeFails: true)
        #expect(!(await store.signIn(credential)))
        #expect(!store.isSignedIn && box.token == nil)
        #expect(log.count == 1, "the server's session is ended rather than stranded")
        #expect(store.signInFailure == SignInFailure.generic)
    }

    @MainActor @Test func signInFailuresSayWhy() async {
        _ = serve(signIn: (503, ["error": "server_not_configured"]))
        let (down, _) = store()
        #expect(!(await down.signIn(credential)))
        #expect(down.signInFailure == SignInFailure.unreachable)
        _ = serve(signIn: (409, ["error": "reauthorize"]))
        let (claimed, _) = store()
        #expect(!(await claimed.signIn(credential)))
        #expect(claimed.signInFailure == SignInFailure.generic)
        AccountStub.respond = nil
    }

    @MainActor @Test func aSessionTheServerRefusesSignsOutButOfflineKeepsIt() async {
        _ = serve(profile: (401, ["error": "unauthorized"]))
        let (refused, box) = store(token: "old")
        await refused.refresh()
        #expect(!refused.isSignedIn && box.token == nil)

        AccountStub.respond = nil   // no connection
        let (offline, kept) = store(token: "old")
        await offline.refresh()
        #expect(offline.isSignedIn && kept.token == "old")
    }

    @MainActor @Test func signOutForgetsEvenWithoutAConnection() async {
        AccountStub.respond = nil
        let (store, box) = store(token: "t")
        await store.signOut()
        #expect(!store.isSignedIn && box.token == nil)
    }

    @MainActor @Test func deletionOutcomes() async {
        _ = serve(delete: (200, ["deleted": true, "appleRevocation": "done"]))
        let (done, doneBox) = store(token: "t")
        #expect(await done.deleteAccount() == .deleted)
        #expect(!done.isSignedIn && doneBox.token == nil)

        _ = serve(delete: (200, ["deleted": true, "appleRevocation": "pending"]))
        let (pending, _) = store(token: "t")
        #expect(await pending.deleteAccount() == .deletedNeedsAppleStep)

        // An expired session deleted nothing: signed out, and the message says so (never "Account Deleted").
        _ = serve(delete: (401, ["error": "unauthorized"]))
        let (expired, expiredBox) = store(token: "t")
        #expect(await expired.deleteAccount() == .failed(AccountDeletionCopy.signedOut))
        #expect(expiredBox.token == nil)

        // Offline: nothing deleted, still signed in.
        AccountStub.respond = nil
        let (offline, offlineBox) = store(token: "t")
        #expect(await offline.deleteAccount() == .failed(AccountDeletionCopy.failed))
        #expect(offline.isSignedIn && offlineBox.token == "t")
    }
}

private final class AccountStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var respond: ((URLRequest) -> (Int, Data))?

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AccountStub.self]
        return URLSession(configuration: configuration)
    }

    /// URLSession moves a request's body into a stream before a protocol sees it.
    static func body(_ request: URLRequest) -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let respond = Self.respond else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let (status, body) = respond(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }
}
