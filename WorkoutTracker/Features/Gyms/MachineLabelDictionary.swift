import UIKit

/// Scanner accuracy, ticket 02 — the ordinary-English-word test the reading
/// repair needs, from UIKit's spell checker. A misread logo (`HOISI`,
/// `LAMMED`, `STRENCTH`) is never a word; a real word one edit from a brand
/// (`PRICE`, `MOIST`, `START`) is a different word and must not be repaired
/// into a brand (codex-review-02 #1). `UITextChecker` is main-actor bound, so
/// the closure is built on the main actor and the callers that rank — the
/// scan sheet — are already there.
@MainActor
enum MachineLabelDictionary {
    private static let checker = UITextChecker()

    /// True when `token` (already lower-cased, letters only) is an English
    /// word the checker does not flag as misspelled.
    static func isWord(_ token: String) -> Bool {
        guard token.allSatisfy(\.isLetter), token.count >= 3 else { return false }
        let range = checker.rangeOfMisspelledWord(
            in: token, range: NSRange(location: 0, length: token.utf16.count),
            startingAt: 0, wrap: false, language: "en_US")
        return range.location == NSNotFound
    }

    /// The closure the catalog index takes.
    static var closure: (String) -> Bool {
        { token in MainActor.assumeIsolated { isWord(token) } }
    }
}
