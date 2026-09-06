import Foundation
import Security
import UIKit

/// Scanner accuracy, ticket 05 — "Ask AI": the plate goes to Claude only
/// when the phone could not place it, and only when the user taps (D53).
///
/// On-device first, always: the shutter reads with Vision, and if D33
/// preselects a row nothing here runs — no network, no cost, no latency.
/// When nothing preselects, the results sheet offers one button. Tapping it
/// sends the box crop (`LabelCrop`), never the frame, with the experiment's
/// transcription prompt; the reply goes through `CatalogMatcher.rank`
/// locally. The model transcribes, the app decides, the user confirms.
///
/// The key is the developer's own, in this phone's keychain, entered once in
/// Settings. It never ships in the binary. Before anyone else can use this a
/// proxy has to stand in front of the API — which is a different endpoint
/// and header value on `AnthropicPlateTranscriber`, not a different app.
protocol PlateTranscriber: Sendable {
    func transcribe(jpeg: Data) async throws -> PlateTranscription
}

/// The Messages API over `URLSession`. Bytes only; the request and the
/// response shapes are `PlateTranscriptionAPI`, unit-tested without a key.
struct AnthropicPlateTranscriber: PlateTranscriber {
    let key: String
    var endpoint: URL = PlateTranscriptionAPI.defaultEndpoint
    var model: String = PlateTranscriptionAPI.defaultModel
    /// The experiment's calls took 2–3 s; a gym's signal is worse than a desk's.
    static let timeout: TimeInterval = 8

    func transcribe(jpeg: Data) async throws -> PlateTranscription {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue(PlateTranscriptionAPI.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try PlateTranscriptionAPI.requestBody(jpeg: jpeg, model: model)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .dnsLookupFailed,
                 .cannotFindHost, .cannotConnectToHost, .internationalRoamingOff, .dataNotAllowed:
                throw PlateTranscriptionError.offline
            case .timedOut:
                throw PlateTranscriptionError.timedOut
            default:
                throw PlateTranscriptionError.unavailable(status: error.code.rawValue)
            }
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw PlateTranscriptionAPI.error(status: http.statusCode, body: data)
        }
        return try PlateTranscriptionAPI.parse(data)
    }
}

/// Who answers an ask, and whether one is possible at all.
enum AskAI {
    /// UI-test stand-in: a stub transcriber and a stub key, so the sheet's
    /// Ask AI path runs end to end in the Simulator with no key and no
    /// network. Obeys the fixture rule (`WorkoutTrackerStore.fixtureIsEnabled`).
    static let fixtureArgument = "-uiTestAskAI"
    /// With the fixture: the ask fails as if offline / as a refusal.
    static let offlineArgument = "-uiTestAskAIOffline"
    static let refusedArgument = "-uiTestAskAIRefused"

    static var fixtureIsEnabled: Bool {
        WorkoutTrackerStore.fixtureIsEnabled(fixtureArgument)
    }

    /// True when the sheet may offer the button: a key is stored (or the
    /// fixture stands in for one).
    static var isAvailable: Bool { transcriber != nil }

    static var transcriber: PlateTranscriber? {
        if fixtureIsEnabled {
            let arguments = ProcessInfo.processInfo.arguments
            return StubPlateTranscriber(
                failure: arguments.contains(offlineArgument) ? .offline
                    : arguments.contains(refusedArgument) ? .refused : nil)
        }
        guard let key = AskAIKeyStore.read() else { return nil }
        return AnthropicPlateTranscriber(key: key)
    }
}

/// The developer's API key, in the keychain (this device only, available
/// after first unlock — a gym scan happens with the phone unlocked). Under
/// `-uiTestReset` an in-memory slot stands in, so no UI test ever touches
/// the Simulator's keychain; the Ask AI fixture pre-fills it.
enum AskAIKeyStore {
    private static let service = (Bundle.main.bundleIdentifier ?? "workouttracker") + ".askai"
    private static let account = "anthropic-api-key"
    private static var memory: String? = AskAI.fixtureIsEnabled ? "uitest-key" : nil

    static func read() -> String? {
        if WorkoutTrackerStore.isUITestReset { return memory }
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8)?.trimmed, !key.isEmpty
        else { return nil }
        return key
    }

    /// Replaces whatever is stored. An empty key deletes.
    static func write(_ key: String) throws {
        let trimmed = key.trimmed
        guard !trimmed.isEmpty else { delete(); return }
        if WorkoutTrackerStore.isUITestReset { memory = trimmed; return }
        delete()
        var attributes = baseQuery
        attributes[kSecValueData as String] = Data(trimmed.utf8)
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
        var errorDescription: String? {
            "Could not save the key to the keychain (\(status))."
        }
    }
}

/// The fixture's answer: what the experiment's stub-worthy plate came back
/// as — a Cybex Eagle NX Overhead Press, a real seeded row, read with the
/// brand the brandless fixture plate lacks.
struct StubPlateTranscriber: PlateTranscriber {
    let failure: PlateTranscriptionError?

    func transcribe(jpeg: Data) async throws -> PlateTranscription {
        try? await Task.sleep(for: .milliseconds(300))
        if let failure { throw failure }
        return PlateTranscription(
            brand: "Cybex", model: "Eagle NX Overhead Press",
            lines: ["Cybex", "Eagle NX Overhead Press"], confidence: .high)
    }
}

extension LabelCrop {
    /// The bytes an ask sends: the box (plus `margin`) cut from the upright
    /// photo, no longer than `maxSide`, JPEG. nil region = the whole photo
    /// (the library path). Runs wherever it is called; nothing is written
    /// anywhere.
    static func jpeg(_ image: UIImage, region: CGRect?) -> Data? {
        guard let upright = uprightCGImage(image) else { return nil }
        let size = CGSize(width: upright.width, height: upright.height)
        guard let cropped = upright.cropping(to: pixelRect(region: region, imageSize: size)) else { return nil }
        let cropSize = CGSize(width: cropped.width, height: cropped.height)
        let factor = scale(for: cropSize)
        let target = CGSize(
            width: max(1, (cropSize.width * factor).rounded()),
            height: max(1, (cropSize.height * factor).rounded()))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            UIImage(cgImage: cropped).draw(in: CGRect(origin: .zero, size: target))
        }
        return rendered.jpegData(compressionQuality: 0.85)
    }

    /// Pixels with the orientation tag applied, so the region — which is in
    /// the UPRIGHT photo's coordinates — indexes the right pixels.
    private static func uprightCGImage(_ image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, image.scale == 1, let cgImage = image.cgImage {
            return cgImage
        }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }.cgImage
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
