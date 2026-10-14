import Foundation

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
}
