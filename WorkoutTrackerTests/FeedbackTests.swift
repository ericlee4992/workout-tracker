import Foundation
import ImageIO
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import WorkoutTracker

/// Public beta ticket 07: the feedback request the server takes, how its answers become the form's lines, the server
/// URL setting, the phone names, and the screenshot's re-encoding (no location leaves the phone).
@Suite(.serialized)
struct FeedbackTests {

    private let submission = FeedbackSubmission(
        category: "bug", message: "Line one\r\nline two — 💪🏽", appVersion: "0.1.0", build: "7", systemVersion: "27.0",
        model: "iPhone16,2", jpeg: Data([0xFF, 0xD8, 0xFF, 0xE0, 0x01, 0xFF, 0xD9]))

    @Test func multipartCarriesEveryFieldAndTheScreenshotBytes() throws {
        let body = submission.multipart(boundary: "B")
        let text = String(decoding: body, as: UTF8.self)
        for (name, value) in [("category", "bug"), ("message", "Line one\r\nline two — 💪🏽"), ("appVersion", "0.1.0"),
                              ("build", "7"), ("systemVersion", "27.0"), ("model", "iPhone16,2")] {
            #expect(text.contains("--B\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n"))
        }
        #expect(text.contains("name=\"screenshot\"; filename=\"screenshot.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n"))
        #expect(body.range(of: submission.jpeg!) != nil)
        #expect(text.hasSuffix("--B--\r\n"))
        var without = submission
        without.jpeg = nil
        #expect(!String(decoding: without.multipart(boundary: "B"), as: UTF8.self).contains("screenshot"))
    }

    @Test func requestTargetsTheFeedbackRouteAndSendsTheSessionOnlyWhenSignedIn() throws {
        let base = URL(string: "https://stacked.example.workers.dev")!
        let signedOut = FeedbackClient(baseURL: base, sessionToken: nil).request(submission, boundary: "B")
        #expect(signedOut.url?.absoluteString == "https://stacked.example.workers.dev/v1/feedback")
        #expect(signedOut.httpMethod == "POST")
        #expect(signedOut.value(forHTTPHeaderField: "Content-Type") == "multipart/form-data; boundary=B")
        #expect(signedOut.value(forHTTPHeaderField: "Authorization") == nil)
        let signedIn = FeedbackClient(baseURL: base, sessionToken: "tok").request(submission, boundary: "B")
        #expect(signedIn.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
    }

    @Test func serverAnswersBecomeTheFormsLines() {
        func error(_ status: Int, _ code: String?) -> FeedbackClientError {
            FeedbackClient.error(status: status, body: code.map { Data("{\"error\":\"\($0)\"}".utf8) } ?? Data())
        }
        #expect(error(429, "rate_limited") == .dailyLimit)
        #expect(error(429, "feedback_full") == .full)
        #expect(error(413, "screenshot_too_large") == .screenshotTooLarge)
        #expect(error(413, "body_too_large") == .refused)
        #expect(error(400, "invalid_screenshot") == .screenshotUnreadable)
        #expect(error(400, "invalid_message") == .refused)
        #expect(error(503, "server_not_configured") == .unreachable)
        #expect(error(502, nil) == .unreachable)
        #expect(FeedbackClientError.dailyLimit.message(signedIn: false) == "You've sent 10 today. Try again tomorrow.")
        #expect(FeedbackClientError.dailyLimit.message(signedIn: true) == "You've sent 30 today. Try again tomorrow.")
        #expect(FeedbackClientError.unreachable.message(signedIn: false) == "Couldn't send. Check your connection and try again.")
    }

    @Test func sendReportsSuccessAndFailureFromTheServer() async throws {
        let session = StubProtocol.session()
        let client = FeedbackClient(baseURL: URL(string: "https://stacked.test")!, sessionToken: nil, session: session)
        StubProtocol.respond = { request in
            #expect(request.url?.path == "/v1/feedback")
            return (201, Data("{\"id\":\"x\"}".utf8))
        }
        try await client.send(submission)
        StubProtocol.respond = { _ in (429, Data("{\"error\":\"rate_limited\"}".utf8)) }
        await #expect(throws: FeedbackClientError.dailyLimit) { try await client.send(submission) }
        StubProtocol.respond = nil  // the protocol fails the load: no network
        await #expect(throws: FeedbackClientError.unreachable) { try await client.send(submission) }
    }

    @Test func serverURLComesFromTheBuildSettingOrIsAbsent() {
        #expect(ServerConfig.url(from: "https://stacked-server.someone.workers.dev")?.host == "stacked-server.someone.workers.dev")
        #expect(ServerConfig.url(from: "http://127.0.0.1:8787")?.port == 8787)
        #expect(ServerConfig.url(from: "") == nil)
        #expect(ServerConfig.url(from: nil) == nil)
        #expect(ServerConfig.url(from: "$(WT_SERVER_URL)") == nil)   // an unexpanded setting
        #expect(ServerConfig.url(from: "https:") == nil)              // `//` cut off as an xcconfig comment
        #expect(ServerConfig.url(from: "ftp://example.com") == nil)
    }

    @Test func phoneNamesWithTheIdentifierAsFallback() {
        #expect(DeviceModelName.name(for: "iPhone16,2") == "iPhone 15 Pro Max")
        #expect(DeviceModelName.name(for: "iPhone18,4") == "iPhone Air")
        #expect(DeviceModelName.name(for: "iPhone99,9") == "iPhone99,9")
        #expect(DeviceModelName.name(for: "arm64") == "arm64")
    }

    @Test func screenshotIsReencodedWithoutLocationOrCameraDetails() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 80)).image { context in
            UIColor.systemPurple.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 80))
        }
        let original = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(original, UTType.jpeg.identifier as CFString, 1, nil))
        let gps: [CFString: Any] = [kCGImagePropertyGPSLatitude: 40.44, kCGImagePropertyGPSLatitudeRef: "N",
                                    kCGImagePropertyGPSLongitude: 79.94, kCGImagePropertyGPSLongitudeRef: "W"]
        let exif: [CFString: Any] = [kCGImagePropertyExifLensModel: "Secret Lens"]
        CGImageDestinationAddImage(destination, try #require(image.cgImage),
                                   [kCGImagePropertyGPSDictionary: gps, kCGImagePropertyExifDictionary: exif] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        #expect(properties(of: original as Data)[kCGImagePropertyGPSDictionary] != nil, "the fixture carries a location")

        let shot = try FeedbackScreenshot.make(from: original as Data).get()
        let sent = properties(of: shot.data)
        #expect(sent[kCGImagePropertyGPSDictionary] == nil)
        #expect((sent[kCGImagePropertyExifDictionary] as? [CFString: Any])?[kCGImagePropertyExifLensModel] == nil)
        #expect(shot.data.starts(with: [0xFF, 0xD8, 0xFF]))
        #expect(shot.data.count <= FeedbackScreenshot.maxBytes)
    }

    @Test func unreadableImagesAreRefusedOnThePhone() {
        guard case .failure(.unreadable) = FeedbackScreenshot.make(from: Data("not an image".utf8)) else {
            Issue.record("garbage was accepted")
            return
        }
    }

    private func properties(of data: Data) -> [CFString: Any] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return [:] }
        return properties
    }
}

/// Answers every request in-process; with no responder the load fails (as with no network).
private final class StubProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var respond: ((URLRequest) -> (Int, Data))?

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return URLSession(configuration: configuration)
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
