import Foundation

/// The app's server (public beta, D60): one build setting, `WT_SERVER_URL` (Config/Shared.xcconfig, overridden in the
/// git-ignored Local.xcconfig), carried into Info.plist as `WTServerURL`. Empty means this build has no server: the
/// features that need it stay hidden rather than failing.
enum ServerConfig {
    static var baseURL: URL? { url(from: Bundle.main.object(forInfoDictionaryKey: "WTServerURL") as? String) }

    static func url(from raw: String?) -> URL? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty, !raw.contains("$("),
              let url = URL(string: raw), let scheme = url.scheme, ["https", "http"].contains(scheme), url.host != nil
        else { return nil }
        return url
    }
}

/// Public beta ticket 07: one feedback submission as the server takes it (`POST /v1/feedback`, multipart).
struct FeedbackSubmission: Equatable {
    var category: String
    var message: String
    var appVersion: String
    var build: String
    var systemVersion: String
    /// The hardware identifier (`iPhone16,2`); the form shows `DeviceModelName.name(for:)`.
    var model: String
    /// A JPEG already re-encoded without metadata, or nil.
    var jpeg: Data?

    func multipart(boundary: String) -> Data {
        var body = Data()
        func append(_ text: String) { body.append(Data(text.utf8)) }
        let fields = [("category", category), ("message", message), ("appVersion", appVersion), ("build", build),
                      ("systemVersion", systemVersion), ("model", model)]
        for (name, value) in fields {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        if let jpeg {
            append("--\(boundary)\r\nContent-Disposition: form-data; name=\"screenshot\"; filename=\"screenshot.jpg\"\r\n")
            append("Content-Type: image/jpeg\r\n\r\n")
            body.append(jpeg)
            append("\r\n")
        }
        append("--\(boundary)--\r\n")
        return body
    }
}

enum FeedbackClientError: Error, Equatable {
    /// Network trouble or a server failure: the draft stays for another try.
    case unreachable
    /// This sender's daily limit (10 signed out, 30 per account).
    case dailyLimit
    /// Everyone's daily limit.
    case full
    case screenshotTooLarge
    case screenshotUnreadable
    /// Anything else the server refused (a malformed request: a bug, not the tester's doing).
    case refused

    /// The tester-facing line (ticket 07's approved copy; `.full` added at implementation).
    func message(signedIn: Bool) -> String {
        switch self {
        case .unreachable, .refused: "Couldn't send. Check your connection and try again."
        case .dailyLimit: "You've sent \(signedIn ? 30 : 10) today. Try again tomorrow."
        case .full: "Couldn't send right now. Try again tomorrow."
        case .screenshotTooLarge: "That image is too large to send. Try a screenshot."
        case .screenshotUnreadable: "Couldn't read that image. Try another."
        }
    }
}

struct FeedbackClient: Sendable {
    let baseURL: URL
    /// The signed-in session token (ticket 03's app half); nil signed out.
    var sessionToken: String?
    var session: URLSession = .shared

    func request(_ submission: FeedbackSubmission, boundary: String = "Stacked-\(UUID().uuidString)") -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: "v1/feedback"))
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let sessionToken { request.setValue("Bearer \(sessionToken)", forHTTPHeaderField: "Authorization") }
        request.httpBody = submission.multipart(boundary: boundary)
        return request
    }

    func send(_ submission: FeedbackSubmission) async throws(FeedbackClientError) {
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request(submission)) } catch { throw .unreachable }
        guard let status = (response as? HTTPURLResponse)?.statusCode else { throw .unreachable }
        if (200..<300).contains(status) { return }
        throw Self.error(status: status, body: data)
    }

    static func error(status: Int, body: Data) -> FeedbackClientError {
        let code = (try? JSONSerialization.jsonObject(with: body) as? [String: Any])?["error"] as? String
        switch (status, code) {
        case (429, "feedback_full"): return .full
        case (429, _): return .dailyLimit
        case (413, "screenshot_too_large"): return .screenshotTooLarge
        case (400, "invalid_screenshot"): return .screenshotUnreadable
        case (500..., _), (408, _): return .unreachable
        default: return .refused
        }
    }
}

/// The phone's marketing name for its hardware identifier — shown on the feedback form (the user's choice,
/// 2026-10-03); the server keeps the identifier. A model newer than this table shows its identifier.
enum DeviceModelName {
    static func name(for identifier: String) -> String { names[identifier] ?? identifier }

    /// iPhones that run iOS 26 and later (iPhone 11 onward). Source: everymac.com's identifier lists, 2026-10-03.
    static let names: [String: String] = [
        "iPhone12,1": "iPhone 11", "iPhone12,3": "iPhone 11 Pro", "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2nd generation)",
        "iPhone13,1": "iPhone 12 mini", "iPhone13,2": "iPhone 12", "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",
        "iPhone14,4": "iPhone 13 mini", "iPhone14,5": "iPhone 13", "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max", "iPhone14,6": "iPhone SE (3rd generation)",
        "iPhone14,7": "iPhone 14", "iPhone14,8": "iPhone 14 Plus", "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15", "iPhone15,5": "iPhone 15 Plus", "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",
        "iPhone17,3": "iPhone 16", "iPhone17,4": "iPhone 16 Plus", "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max", "iPhone17,5": "iPhone 16e",
        "iPhone18,3": "iPhone 17", "iPhone18,4": "iPhone Air", "iPhone18,1": "iPhone 17 Pro",
        "iPhone18,2": "iPhone 17 Pro Max", "iPhone18,5": "iPhone 17e",
    ]
}
