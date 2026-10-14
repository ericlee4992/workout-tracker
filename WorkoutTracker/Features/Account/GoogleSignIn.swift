import AuthenticationServices
import Foundation
import UIKit

/// Public beta ticket 04: Google sign-in without Google's SDK (D60). Available when the build has an iOS OAuth client
/// ID (`WT_GOOGLE_CLIENT_ID` → Info.plist `WTGoogleClientID`), or under the UI-first sample flag.
enum GoogleSignIn {
    static var clientID: String? {
        guard let raw = (Bundle.main.object(forInfoDictionaryKey: "WTGoogleClientID") as? String)?
            .trimmingCharacters(in: .whitespaces), raw.hasSuffix(".apps.googleusercontent.com"), !raw.contains("$(")
        else { return nil }
        return raw
    }

    static var isAvailable: Bool { clientID != nil || ProfileSample.showsGoogle }

    /// Google's page in `ASWebAuthenticationSession`; the redirect to the reversed client ID ends it. Returns the
    /// callback URL. Closing the page is `.cancelled`.
    @MainActor
    static func authorize(_ oauth: GoogleOAuth, _ attempt: GoogleOAuth.Attempt) async throws(GoogleOAuth.Failure) -> URL {
        let presenter = Presenter()
        let result: Result<URL, GoogleOAuth.Failure> = await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: oauth.authorizationURL(attempt), callback: .customScheme(oauth.callbackScheme)) { url, error in
                if let url { continuation.resume(returning: .success(url)); return }
                let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                continuation.resume(returning: .failure(cancelled ? .cancelled : .invalid))
            }
            session.presentationContextProvider = presenter
            // Google's own cookies may remember the account between sign-ins (the person picks it: `select_account`).
            session.prefersEphemeralWebBrowserSession = false
            presenter.session = session
            if !session.start() { continuation.resume(returning: .failure(.invalid)) }
        }
        presenter.session = nil
        return try result.get()
    }

    /// Anchors Google's page on the app's key window; holds the session while it runs.
    private final class Presenter: NSObject, ASWebAuthenticationPresentationContextProviding {
        var session: ASWebAuthenticationSession?

        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            MainActor.assumeIsolated {
                let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
            }
        }
    }

    /// Google's token endpoint: the authorization code for the ID token (the other tokens are dropped).
    static func idToken(_ oauth: GoogleOAuth, code: String, attempt: GoogleOAuth.Attempt,
                        session: URLSession = .shared) async throws(GoogleOAuth.Failure) -> String {
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: oauth.tokenRequest(code: code, attempt: attempt)) }
        catch { throw .unreachable }
        return try GoogleOAuth.idToken(from: data, status: (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}
