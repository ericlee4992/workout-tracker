import Foundation
import Testing
import UIKit
@testable import WorkoutTracker

/// Public beta ticket 04: Google's OAuth for an iOS client without Google's SDK — PKCE, the authorization URL, the
/// callback (state, cancel, errors), the code exchange and its answer, and the server request.
struct GoogleOAuthTests {
    private let oauth = GoogleOAuth(clientID: "123456789-abcdef.apps.googleusercontent.com")
    private let attempt = GoogleOAuth.Attempt(verifier: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk",
                                              state: "state-123", rawNonce: "raw-nonce-0123456789abcdef")

    @Test func pkceMatchesRFC7636sExample() {
        #expect(GoogleOAuth.challenge(for: attempt.verifier) == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        let made = GoogleOAuth.Attempt.make()
        #expect(made.verifier.count == 43 && made.state.count == 22)
        #expect(made.verifier.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
    }

    @Test func theRedirectIsTheReversedClientID() {
        #expect(oauth.callbackScheme == "com.googleusercontent.apps.123456789-abcdef")
        #expect(oauth.redirectURI == "com.googleusercontent.apps.123456789-abcdef:/oauth2redirect")
    }

    @Test func theAuthorizationURLAsksForACodeWithPKCEAndTheHashedNonce() throws {
        let url = oauth.authorizationURL(attempt)
        #expect(url.absoluteString.hasPrefix("https://accounts.google.com/o/oauth2/v2/auth?"))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        #expect(query == [
            "client_id": oauth.clientID, "redirect_uri": oauth.redirectURI, "response_type": "code",
            "scope": "openid email profile", "code_challenge": "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
            "code_challenge_method": "S256", "state": "state-123",
            "nonce": SignInNonce.sha256Hex("raw-nonce-0123456789abcdef"), "prompt": "select_account",
        ])
        #expect(!url.absoluteString.contains(attempt.verifier), "the verifier never leaves the phone before the exchange")
        #expect(!url.absoluteString.contains(attempt.rawNonce))
    }

    @Test func theCallbackGivesTheCodeOnlyForThisAttempt() throws {
        let scheme = oauth.callbackScheme
        #expect(try oauth.code(from: URL(string: "\(scheme):/oauth2redirect?state=state-123&code=4%2F0Abc")!, attempt: attempt)
                == "4/0Abc")
        #expect(throws: GoogleOAuth.Failure.invalid) {
            try oauth.code(from: URL(string: "\(scheme):/oauth2redirect?state=other&code=x")!, attempt: attempt)
        }
        #expect(throws: GoogleOAuth.Failure.invalid) {
            try oauth.code(from: URL(string: "\(scheme):/oauth2redirect?state=state-123")!, attempt: attempt)
        }
        #expect(throws: GoogleOAuth.Failure.invalid) {
            try oauth.code(from: URL(string: "evil.scheme:/oauth2redirect?state=state-123&code=x")!, attempt: attempt)
        }
        #expect(throws: GoogleOAuth.Failure.cancelled) {
            try oauth.code(from: URL(string: "\(scheme):/oauth2redirect?error=access_denied&state=state-123")!, attempt: attempt)
        }
        #expect(throws: GoogleOAuth.Failure.invalid) {
            try oauth.code(from: URL(string: "\(scheme):/oauth2redirect?error=server_error&state=state-123")!, attempt: attempt)
        }
    }

    /// codex-review-04 Standards #1: only exactly the redirect URI, and the state checked before a code or an error.
    @Test func theCallbackMustReturnToTheRedirectURIWithThisAttemptsState() throws {
        let scheme = oauth.callbackScheme
        #expect(try oauth.code(from: URL(string: "\(scheme.uppercased()):/oauth2redirect?state=state-123&code=c")!,
                               attempt: attempt) == "c", "a URL scheme is case-insensitive")
        for wrong in ["\(scheme):/wrong-path?state=state-123&code=c",
                      "\(scheme):/oauth2redirect/extra?state=state-123&code=c",
                      "\(scheme)://evil.example/oauth2redirect?state=state-123&code=c",
                      "\(scheme)://user@/oauth2redirect?state=state-123&code=c",
                      "\(scheme):oauth2redirect?state=state-123&code=c",
                      "\(scheme):/oauth2redirect",
                      // An error is believed only with this attempt's state: a forged "access_denied" is no cancel.
                      "\(scheme):/oauth2redirect?error=access_denied",
                      "\(scheme):/oauth2redirect?error=access_denied&state=other"] {
            #expect(throws: GoogleOAuth.Failure.invalid, "\(wrong)") {
                try oauth.code(from: URL(string: wrong)!, attempt: attempt)
            }
        }
    }

    @Test func theExchangeSendsTheVerifierAndNoSecret() throws {
        let request = oauth.tokenRequest(code: "4/0A+b&c=d", attempt: attempt)
        #expect(request.url == GoogleOAuth.tokenEndpoint)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        let body = try #require(request.httpBody.map { String(decoding: $0, as: UTF8.self) })
        let form = Dictionary(uniqueKeysWithValues: (URLComponents(string: "?" + body)?.queryItems ?? []).map {
            ($0.name, $0.value ?? "")
        })
        #expect(form == ["code": "4/0A+b&c=d", "client_id": oauth.clientID, "code_verifier": attempt.verifier,
                         "grant_type": "authorization_code", "redirect_uri": oauth.redirectURI])
        #expect(!body.contains("client_secret"))
        // A form body reads `+` as a space: the code's `+` must travel as %2B (URLComponents above would not notice).
        #expect(body.contains("code=4/0A%2Bb%26c%3Dd"))
    }

    @Test func theAnswerYieldsOnlyTheIDToken() throws {
        let ok = try JSONSerialization.data(withJSONObject: ["access_token": "a", "refresh_token": "r",
                                                               "id_token": "h.p.s", "token_type": "Bearer"])
        #expect(try GoogleOAuth.idToken(from: ok, status: 200) == "h.p.s")
        #expect(throws: GoogleOAuth.Failure.invalid) { try GoogleOAuth.idToken(from: Data("{}".utf8), status: 200) }
        #expect(throws: GoogleOAuth.Failure.invalid) {
            try GoogleOAuth.idToken(from: Data(#"{"id_token":"not-a-jwt"}"#.utf8), status: 200)
        }
        #expect(throws: GoogleOAuth.Failure.invalid) {
            try GoogleOAuth.idToken(from: Data(#"{"error":"invalid_grant"}"#.utf8), status: 400)
        }
        #expect(throws: GoogleOAuth.Failure.unreachable) { try GoogleOAuth.idToken(from: Data(), status: 503) }
    }

    @Test func theServerGetsTheIDTokenAndTheRawNonce() throws {
        let client = AccountClient(baseURL: URL(string: "https://stacked.example")!)
        let request = client.googleSignInRequest(idToken: "h.p.s", rawNonce: attempt.rawNonce)
        #expect(request.url?.absoluteString == "https://stacked.example/v1/auth/google")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        let data = try #require(request.httpBody)
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(body == ["idToken": "h.p.s", "nonce": "raw-nonce-0123456789abcdef"])
    }

    /// codex-review-04 Standards #3: the button's Google Sans Medium is in the app, or SwiftUI quietly falls back to
    /// the system font.
    @Test @MainActor func theButtonsFontIsBundled() throws {
        let font = try #require(UIFont(name: GoogleSignInButton.fontName, size: 20))
        #expect(font.fontName == GoogleSignInButton.fontName)
    }
}
