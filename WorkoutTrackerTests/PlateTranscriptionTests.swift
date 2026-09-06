import CoreGraphics
import Foundation
import Testing
@testable import WorkoutTracker

/// Scanner accuracy, ticket 05 — the Ask AI request, the reply, the crop,
/// and the rule that the app (not the model) still decides what preselects.
struct PlateTranscriptionTests {

    // MARK: - Request

    @Test func requestCarriesTheCropAsBase64JPEGWithStructuredOutput() throws {
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
        let body = try PlateTranscriptionAPI.requestBody(jpeg: jpeg)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object["model"] as? String == "claude-sonnet-5")
        #expect(object["max_tokens"] as? Int == 1024)
        let output = try #require(object["output_config"] as? [String: Any])
        #expect(output["effort"] as? String == "low")
        let format = try #require(output["format"] as? [String: Any])
        #expect(format["type"] as? String == "json_schema")
        let schema = try #require(format["schema"] as? [String: Any])
        #expect(Set(schema["required"] as? [String] ?? []) == ["brand", "model", "lines", "confidence"])
        #expect(schema["additionalProperties"] as? Bool == false)

        let messages = try #require(object["messages"] as? [[String: Any]])
        #expect(messages.count == 1)
        let content = try #require(messages[0]["content"] as? [[String: Any]])
        let image = try #require(content.first { $0["type"] as? String == "image" })
        let source = try #require(image["source"] as? [String: Any])
        #expect(source["media_type"] as? String == "image/jpeg")
        #expect(source["data"] as? String == jpeg.base64EncodedString())
        let text = try #require(content.first { $0["type"] as? String == "text" }?["text"] as? String)
        // The production contract, pinned whole: `tools/llm_reader.py` mirrors
        // it, and the LLM report is only a measurement of the app if the two
        // agree (codex-review-05).
        #expect(text == "This is a photo of a gym strength machine's name plate or badge. Transcribe only what identifies the machine: the manufacturer (brand) and the model or machine name, exactly as printed. If the brand appears only as a logo you recognise, give the brand name. Ignore usage instructions, warnings, serial numbers, part numbers, URLs, phone numbers and load ratings. If there is no plate or nothing identifying, return nulls and an empty list. Do not guess a model that is not printed.")
        #expect(schema["properties"].map { ($0 as? [String: Any])?.keys.contains("brand_from_logo_only") } == false)
    }

    @Test func theWireRequestCarriesTheCredentialTheProxyShapeNeeds() throws {
        let body = Data("{}".utf8)
        let direct = AnthropicMessagesClient(credential: .apiKey("sk-ant-test")).request(for: body)
        #expect(direct.url == PlateTranscriptionAPI.defaultEndpoint)
        #expect(direct.httpMethod == "POST")
        #expect(direct.value(forHTTPHeaderField: "x-api-key") == "sk-ant-test")
        #expect(direct.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(direct.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(direct.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(direct.timeoutInterval == AnthropicMessagesClient.timeout)
        #expect(direct.httpBody == body)

        let proxy = AnthropicMessagesClient(
            credential: .bearer("device-token"), endpoint: URL(string: "https://proxy.example/v1/messages")!
        ).request(for: body)
        #expect(proxy.url?.host == "proxy.example")
        #expect(proxy.value(forHTTPHeaderField: "Authorization") == "Bearer device-token")
        #expect(proxy.value(forHTTPHeaderField: "x-api-key") == nil, "the proxy never sees an Anthropic key header")
    }

    // MARK: - Reply

    private func reply(_ text: String, stopReason: String = "end_turn") -> Data {
        let object: [String: Any] = [
            "id": "msg_1", "type": "message", "role": "assistant",
            "stop_reason": stopReason,
            "content": [["type": "text", "text": text]],
            "usage": ["input_tokens": 2900, "output_tokens": 70],
        ]
        return try! JSONSerialization.data(withJSONObject: object)
    }

    @Test func parsesATranscription() throws {
        let data = reply(#"{"brand":"Hammer Strength","model":"Iso-Lateral Wide Pulldown","lines":["Hammer Strength","Iso-Lateral Wide Pulldown"],"confidence":"high"}"#)
        let transcription = try PlateTranscriptionAPI.parse(data)
        #expect(transcription.brand == "Hammer Strength")
        #expect(transcription.model == "Iso-Lateral Wide Pulldown")
        #expect(transcription.lines == ["Hammer Strength", "Iso-Lateral Wide Pulldown"])
        #expect(transcription.confidence == .high)
        #expect(transcription.labelReading == LabelReading.lines(["Hammer Strength", "Iso-Lateral Wide Pulldown"]))
    }

    @Test func nullsAndAnEmptyListAreAnEmptyReading() throws {
        let data = reply(#"{"brand":null,"model":null,"lines":[],"confidence":"low"}"#)
        let transcription = try PlateTranscriptionAPI.parse(data)
        #expect(transcription.brand == nil)
        #expect(transcription.labelReading.isEmpty)
    }

    @Test func brandAndModelStandInWhenLinesAreMissing() throws {
        // A future prompt that drops `lines`, or a model that returns none,
        // still yields something the matcher can rank — in plate order.
        let data = reply(#"{"brand":"Cybex","model":"Eagle NX Row","confidence":"whatever"}"#)
        let transcription = try PlateTranscriptionAPI.parse(data)
        #expect(transcription.confidence == .low)
        #expect(transcription.labelReading == LabelReading.lines(["Cybex", "Eagle NX Row"]))
    }

    @Test func aRefusalIsRefused() {
        #expect(throws: PlateTranscriptionError.refused) {
            try PlateTranscriptionAPI.parse(reply("", stopReason: "refusal"))
        }
    }

    @Test func anErrorObjectInTheBodyIsNotATranscription() {
        let body = Data(#"{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}"#.utf8)
        #expect(throws: PlateTranscriptionError.unauthorized) {
            try PlateTranscriptionAPI.parse(body)
        }
        #expect(PlateTranscriptionAPI.error(status: 401, body: Data()) == .unauthorized)
        #expect(PlateTranscriptionAPI.error(status: 529, body: Data()) == .unavailable(status: 529))
    }

    @Test func aReplyThatIsNotTheSchemaIsMalformed() {
        #expect(throws: PlateTranscriptionError.malformed) {
            try PlateTranscriptionAPI.parse(reply("Sure! The plate says Hammer Strength."))
        }
        #expect(throws: PlateTranscriptionError.malformed) {
            try PlateTranscriptionAPI.parse(Data("not json".utf8))
        }
    }

    // MARK: - Crop

    @Test func theCropIsTheBoxWithAMarginInTheUprightPhoto() {
        // Vision region: bottom-left origin. Box 50% wide × 25% tall, its
        // left edge at 10%, its bottom at 20% → its top at 45% from the
        // bottom = 55% from the top.
        let region = CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.25)
        let rect = LabelCrop.pixelRect(region: region, imageSize: CGSize(width: 1_000, height: 2_000))
        // Box in pixels: x 100, y 1100, w 500, h 500; margin 8% of each side = 40.
        #expect(rect == CGRect(x: 60, y: 1_060, width: 580, height: 580))
    }

    @Test func theCropIsClampedToThePhoto() throws {
        let size = CGSize(width: 1_000, height: 2_000)
        let edge = try #require(LabelCrop.pixelRect(region: CGRect(x: 0, y: 0.9, width: 1, height: 0.1), imageSize: size))
        #expect(edge.minX == 0 && edge.minY == 0 && edge.maxX == 1_000)
    }

    /// The whole photo never leaves the phone: no box, a degenerate box, or
    /// a box that IS the frame yield nothing to send (codex-review-05, high).
    @Test func noBoxMeansNothingToSend() {
        let size = CGSize(width: 1_000, height: 2_000)
        #expect(LabelCrop.pixelRect(region: .zero, imageSize: size) == nil)
        #expect(LabelCrop.pixelRect(region: CGRect(x: 0, y: 0, width: 1, height: 1), imageSize: size) == nil)
        #expect(LabelCrop.pixelRect(region: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.2), imageSize: .zero) == nil)
        #expect(LabelCrop.pixelRect(region: CGRect(x: 2, y: 2, width: 0.5, height: 0.2), imageSize: size) == nil, "a box entirely outside the photo")
        #expect(LabelCrop.pixelRect(region: CGRect(x: 0.02, y: 0.04, width: 0.96, height: 0.92), imageSize: CGSize(width: 1_600, height: 500)) == nil, "a near-frame box whose margin reaches every edge")
        #expect(LabelCrop.pixelRect(region: CGRect(x: 0.02, y: 0.3, width: 0.96, height: 0.4), imageSize: size) != nil, "a wide box that keeps top and bottom out is still a box")
    }

    @Test func theCropIsResizedToTheExperimentsLongSideAndNeverUpscaled() {
        #expect(abs(LabelCrop.scale(for: CGSize(width: 4_032, height: 1_500)) - 1_568.0 / 4_032.0) < 1e-9)
        #expect(LabelCrop.scale(for: CGSize(width: 800, height: 300)) == 1)
    }

    // MARK: - The app still decides (D33)

    /// The UI-test fixture pair: the brandless plate must NOT preselect (so
    /// the button is offered), and the stub's transcription must (so the
    /// test can prove the ask changed the outcome) — both through the real
    /// matcher on the shipped catalog, which is exactly what the sheet does.
    @Test @MainActor func theFixturePlateOffersAnAskAndTheStubsAnswerPreselects() async throws {
        let catalog = try SeedCatalog.bundled()
        let index = CatalogMatchIndex(
            models: catalog.equipmentModels.map { (id: $0.id, manufacturer: $0.manufacturer, modelName: $0.modelName) },
            isDictionaryWord: MachineLabelDictionary.closure)

        let camera = CatalogMatcher.rank(
            LabelReading.lines(["CONVERGING PLATE LOADED", "OVERHEAD PRESS", "MAX 300 LB"]), in: index)
        #expect(CatalogMatcher.preselection(from: camera) == nil, "no brand on the plate → nothing preselects")

        let stub = StubPlateTranscriber(failure: nil)
        let transcription = try await stub.transcribe(jpeg: Data())
        let ai = CatalogMatcher.rank(transcription.labelReading, in: index)
        let preselected = try #require(CatalogMatcher.preselection(from: ai))
        #expect(preselected.manufacturer == "Cybex")
        #expect(preselected.modelName == "Eagle NX Overhead Press")
    }

    @Test func noKeyMeansNoAsk() {
        // Outside the fixture the transcriber exists only when a key does;
        // the unit test process has neither, so nothing is offered.
        #expect(AskAI.fixtureIsEnabled == false)
        #expect(AskAIKeyStore.read() == nil)
        #expect(AskAI.isAvailable == false)
    }
}
