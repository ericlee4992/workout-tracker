import CryptoKit
import Foundation
import Security

/// Public beta ticket 04: Google's OAuth 2.0 authorization-code flow with PKCE for an **iOS client**, without Google's
/// SDK (D60). The pure parts — the authorization URL, the callback, the token request and answer — so they are tested
/// without a browser or the network. The app keeps no Google token: it sends the ID token to the server and forgets
/// the rest.
struct GoogleOAuth: Equatable, Sendable {
    /// `<number>-<id>.apps.googleusercontent.com`.
    let clientID: String

    static let authorizationEndpoint = URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    static let tokenEndpoint = URL(string: "https://oauth2.googleapis.com/token")!

    /// An iOS client's redirect scheme: the client ID reversed, `com.googleusercontent.apps.<number>-<id>`.
    var callbackScheme: String {
        clientID.split(separator: ".").reversed().joined(separator: ".")
    }

    var redirectURI: String { "\(callbackScheme):/oauth2redirect" }

    /// One sign-in's secrets: the PKCE verifier, the state echoed by the callback, and the raw nonce (its SHA-256 goes
    /// to Google and comes back in the ID token; the raw value goes to the server, as for Apple).
    struct Attempt: Equatable, Sendable {
        var verifier: String
        var state: String
        var rawNonce: String

        static func make() -> Attempt {
            Attempt(verifier: random(32), state: random(16), rawNonce: SignInNonce.make())
        }

        /// base64url of `bytes` random bytes (32 → 43 characters: a valid PKCE verifier).
        static func random(_ bytes: Int) -> String {
            var data = [UInt8](repeating: 0, count: bytes)
            let status = SecRandomCopyBytes(kSecRandomDefault, data.count, &data)
            precondition(status == errSecSuccess, "SecRandomCopyBytes failed")
            return GoogleOAuth.base64URL(Data(data))
        }
    }

    /// PKCE S256: base64url(SHA-256(verifier)) (RFC 7636).
    static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    func authorizationURL(_ attempt: Attempt) -> URL {
        var components = URLComponents(url: Self.authorizationEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: Self.challenge(for: attempt.verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: attempt.state),
            URLQueryItem(name: "nonce", value: SignInNonce.sha256Hex(attempt.rawNonce)),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        return components.url!
    }

    enum Failure: Error, Equatable {
        /// The person closed Google's page or declined: not an error to report.
        case cancelled
        /// Anything else wrong with the callback or Google's answer.
        case invalid
        /// Google's token endpoint could not be reached or failed.
        case unreachable
    }

    /// The authorization code from Google's redirect. The callback must come back to exactly `redirectURI` and carry
    /// this attempt's state before anything in it is believed — a code or an error alike (RFC 8252 §8.9–8.10;
    /// codex-review-04 Standards #1).
    func code(from callback: URL, attempt: Attempt) throws(Failure) -> String {
        guard let parts = URLComponents(url: callback, resolvingAgainstBaseURL: false),
              let expected = URLComponents(string: redirectURI),
              parts.scheme?.lowercased() == expected.scheme?.lowercased(),
              parts.percentEncodedHost ?? "" == "", parts.port == nil, parts.user == nil, parts.password == nil,
              parts.percentEncodedPath == expected.percentEncodedPath,
              let items = parts.queryItems else { throw .invalid }
        let value = { (name: String) in items.first { $0.name == name }?.value }
        guard value("state") == attempt.state else { throw .invalid }
        if let error = value("error") { throw error == "access_denied" ? .cancelled : .invalid }
        guard let code = value("code"), !code.isEmpty else { throw .invalid }
        return code
    }

    /// The code exchange (an iOS client has no secret: the PKCE verifier proves the request).
    func tokenRequest(code: String, attempt: Attempt) -> URLRequest {
        var request = URLRequest(url: Self.tokenEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code_verifier", value: attempt.verifier),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
        ]
        // `+` is a space in a form body: encode it (and `&`, `=`) explicitly.
        let body = form.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B") ?? ""
        request.httpBody = Data(body.utf8)
        return request
    }

    /// The ID token from Google's token answer; the access and refresh tokens are ignored (never kept).
    static func idToken(from data: Data, status: Int) throws(Failure) -> String {
        guard (200..<300).contains(status) else { throw status >= 500 ? .unreachable : .invalid }
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let token = object["id_token"] as? String, token.split(separator: ".").count == 3 else { throw .invalid }
        return token
    }
}
