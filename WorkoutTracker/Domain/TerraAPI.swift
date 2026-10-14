import Foundation

/// A reply the app's own validation refuses (routine, scan), in the words shown. The transport's errors are
/// `AIServerError` (public beta ticket 06: no OpenAI call or key on the phone).
enum TerraError: LocalizedError {
    case message(String)
    case invalidResponse
    var errorDescription: String? {
        switch self {
        case .message(let text): text
        case .invalidResponse: "AI returned an incomplete or invalid result. Try again or continue manually."
        }
    }
}
