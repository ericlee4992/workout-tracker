import Foundation
import Testing
@testable import WorkoutTracker

/// Public beta ticket 06 (app half): the three AI flows as the server takes them (server/README → AI) — the route,
/// the session, only the flow's input (no model, instructions, schema or key) — how its answers and refusals are read,
/// the over-limit line with the server's own limit, a refused session signing the phone out, and the reset wording.
@Suite(.serialized)
struct AIServerClientTests {
    private let base = URL(string: "https://stacked.example")!
    private func client(onUnauthorized: @escaping @Sendable (String) -> Void = { _ in }) -> AIServerClient {
        AIServerClient(baseURL: base, token: "tok-1", session: AIStub.session(), onUnauthorized: onUnauthorized)
    }
    private static func json(_ object: Any) -> Data { try! JSONSerialization.data(withJSONObject: object) }
    private static func object(_ data: Data) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }
    private static let usageJSON: [String: Any] = [
        "day": "2026-10-14", "resetsAt": 1_791_000_000_000.0, "paused": false,
        "flows": ["scan-machine": ["used": 60, "limit": 60], "routine-week": ["used": 10, "limit": 10],
                  "model-exercises": ["used": 0, "limit": 60]],
    ]

    // MARK: Requests

    @Test func eachFlowPostsToItsRouteWithTheSessionAndALongerTimeoutThanTheServers() {
        for flow in AIFlow.allCases {
            let request = client().request(flow, body: Data("{}".utf8))
            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString == "https://stacked.example/v1/ai/\(flow.rawValue)")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer tok-1")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.timeoutInterval == 75)
        }
    }

    @Test func scanSendsOnlyTheExercisesAndTheJPEG() {
        let id = UUID()
        let body = AIServerClient.scanBody(exercises: [(id: id, name: "Seated Chest Press", loadType: "weighted")],
                                           jpeg: Data([0xFF, 0xD8, 0xFF, 0xD9]))
        #expect(Set(body.keys) == ["exercises", "jpeg"])
        #expect(body["jpeg"] as? String == "/9j/2Q==")
        let rows = body["exercises"] as? [[String: String]]
        #expect(rows == [["id": id.uuidString, "name": "Seated Chest Press", "loadType": "weighted"]])
    }

    @Test func modelExercisesSendsThePlateAndTheListAndOmitsAMissingGroup() {
        let a = UUID(), b = UUID()
        let body = AIServerClient.modelExercisesBody(
            plate: PlateDescription(brand: "Cybex", model: "Eagle NX", lines: ["Cybex", "OVERHEAD PRESS"]),
            candidates: [ExerciseCandidate(id: a, name: "Machine Shoulder Press", muscleGroup: "Shoulders"),
                         ExerciseCandidate(id: b, name: "Plank", muscleGroup: nil)])
        #expect(Set(body.keys) == ["plate", "candidates"])
        let plate = body["plate"] as? [String: Any]
        #expect(plate?["brand"] as? String == "Cybex")
        #expect(plate?["lines"] as? [String] == ["Cybex", "OVERHEAD PRESS"])
        let rows = body["candidates"] as? [[String: String]]
        #expect(rows == [["id": a.uuidString, "name": "Machine Shoulder Press", "muscleGroup": "Shoulders"],
                         ["id": b.uuidString, "name": "Plank"]])
    }

    @Test func routineSendsTheRequestAsTheAppEncodesIt() async throws {
        let request = AIRoutineRequest(goals: "Build strength.", experience: "Intermediate", days: 3, minutes: 45,
                                       heightCm: nil, weightKg: 80, exercises: [], cardioActivities: [.outdoorWalk])
        let sent = SentBox()
        AIStub.respond = { request in sent.set(AIStub.body(request)); return (200, Self.json(["result": ["sessions": []]])) }
        _ = try await client().complete(.routineWeek, encodable: request)
        let body = Self.object(sent.data)
        #expect(Set(body.keys) == ["goals", "experience", "days", "minutes", "weightKg", "exercises", "cardioActivities"])
        let text = String(decoding: sent.data, as: UTF8.self)
        for absent in ["model", "instructions", "schema", "tok-1", "sk-"] { #expect(!text.contains(absent)) }
    }

    // MARK: Answers

    @Test func theResultComesBackAsTheModelsJSON() async throws {
        AIStub.respond = { _ in (200, Self.json(["result": ["identity": "generic", "label": "Chest press"]])) }
        let data = try await client().complete(.scanMachine, json: [:])
        #expect(Self.object(data)["label"] as? String == "Chest press")
    }

    @Test func anAnswerWithoutAResultIsInvalid() async {
        AIStub.respond = { _ in (200, Self.json(["ok": true])) }
        await #expect(throws: AIServerError.invalid) { try await client().complete(.scanMachine, json: [:]) }
        AIStub.respond = { _ in (200, Data("not json".utf8)) }
        await #expect(throws: AIServerError.invalid) { try await client().complete(.scanMachine, json: [:]) }
    }

    @Test func refusalsMapToTheirLines() {
        let cases: [(Int, String?, AIServerError)] = [
            (401, "unauthorized", .signedOut), (429, "ai_attempts", .attempts(resetsAt: AIResetCopy.nextReset())),
            (429, "ai_busy", .busy), (503, "ai_paused", .paused), (503, "ai_timeout", .timedOut),
            (503, "ai_unavailable", .unavailable), (503, "server_not_configured", .unavailable),
            (502, "ai_refused", .refused), (502, "ai_invalid", .invalid), (500, nil, .unavailable),
            (400, "invalid_input", .rejected("invalid_input")), (413, nil, .rejected("status_413")),
        ]
        for (status, code, expected) in cases {
            let error = AIServerClient.error(status: status, code: code, flow: .scanMachine)
            if case .attempts = expected { if case .attempts = error {} else { Issue.record("\(status) \(code ?? "")") } }
            else { #expect(error == expected, "\(status) \(code ?? "")") }
        }
        #expect(AIServerClient.error(status: 429, code: "ai_limit", flow: .routineWeek)
                == .limit(.routineWeek, nil, resetsAt: AIResetCopy.nextReset()))
    }

    @Test func overTheLimitReadsTheServersLimitAndResetTime() async {
        let paths = SentBox()
        AIStub.respond = { request in
            paths.append(request.url?.path ?? "")
            if request.url?.path == "/v1/ai/usage" {
                #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer tok-1")
                return (200, Self.json(Self.usageJSON))
            }
            return (429, Self.json(["error": "ai_limit"]))
        }
        let reset = Date(timeIntervalSince1970: 1_791_000_000)
        await #expect(throws: AIServerError.limit(.routineWeek, 10, resetsAt: reset)) {
            try await client().complete(.routineWeek, json: [:])
        }
        #expect(paths.paths == ["/v1/ai/routine-week", "/v1/ai/usage"])
    }

    @Test func overTheLimitStillReadsWhenUsageFails() async {
        AIStub.respond = { request in
            request.url?.path == "/v1/ai/usage" ? (503, Data()) : (429, Self.json(["error": "ai_limit"]))
        }
        do {
            _ = try await client().complete(.scanMachine, json: [:])
            Issue.record("expected a limit")
        } catch let error as AIServerError {
            guard case .limit(.scanMachine, nil, _) = error else { Issue.record("\(error)"); return }
            #expect(error.localizedDescription.hasPrefix("You've used today's machine scans. They reset at "))
        } catch { Issue.record("\(error)") }
    }

    @Test func aRefusedSessionIsReportedOnce() async {
        let refused = SentBox()
        AIStub.respond = { _ in (401, Self.json(["error": "unauthorized"])) }
        await #expect(throws: AIServerError.signedOut) {
            try await client(onUnauthorized: { refused.append($0) }).complete(.modelExercises, json: [:])
        }
        #expect(refused.paths == ["tok-1"])
    }

    @MainActor @Test func aRefusedSessionSignsTheAccountOut() async throws {
        var stored: String? = "tok-1"
        let account = AccountStore(client: AccountClient(baseURL: base),
                                   slot: .init(read: { stored }, write: { stored = $0 }, delete: { stored = nil }))
        let client = try #require(TerraAccess.client(account))
        #expect(client.token == "tok-1")
        client.onUnauthorized("tok-1")
        for _ in 0..<20 where account.isSignedIn { await Task.yield() }
        #expect(!account.isSignedIn)
        #expect(stored == nil)
        #expect(TerraAccess.client(account)?.token == nil)
    }

    /// codex-review-06-app F3: the over-limit follow-up's 401 is a refused session like the POST's.
    @Test func aSessionRefusedByTheUsageFollowUpSignsOut() async {
        let refused = SentBox()
        AIStub.respond = { request in
            request.url?.path == "/v1/ai/usage" ? (401, Self.json(["error": "unauthorized"]))
                : (429, Self.json(["error": "ai_limit"]))
        }
        await #expect(throws: AIServerError.signedOut) {
            try await client(onUnauthorized: { refused.append($0) }).complete(.scanMachine, json: [:])
        }
        #expect(refused.paths == ["tok-1"])
    }

    /// …and a newer session (signed out and in again meanwhile) is left alone.
    @MainActor @Test func aRefusalOfAnOlderSessionLeavesTheNewOneSignedIn() async throws {
        var stored: String? = "tok-2"
        let account = AccountStore(client: AccountClient(baseURL: base),
                                   slot: .init(read: { stored }, write: { stored = $0 }, delete: { stored = nil }))
        AIStub.respond = { request in
            request.url?.path == "/v1/ai/usage" ? (401, Self.json(["error": "unauthorized"]))
                : (429, Self.json(["error": "ai_limit"]))
        }
        let old = AIServerClient(baseURL: base, token: "tok-1", session: AIStub.session(), onUnauthorized: { refused in
            Task { @MainActor in account.invalidate(token: refused) }
        })
        await #expect(throws: AIServerError.signedOut) { try await old.complete(.scanMachine, json: [:]) }
        for _ in 0..<20 { await Task.yield() }
        #expect(account.isSignedIn)
        #expect(stored == "tok-2")
    }

    @MainActor private func account(_ token: String?) -> (AccountStore, () -> String?) {
        final class Box { var token: String?; init(_ t: String?) { token = t } }
        let box = Box(token)
        let store = AccountStore(client: AccountClient(baseURL: base, session: AIStub.session()),
                                 slot: .init(read: { box.token }, write: { box.token = $0 }, delete: { box.token = nil }))
        return (store, { box.token })
    }

    @MainActor private func routineModel() -> AIRoutineFlowModel {
        let model = AIRoutineFlowModel()
        model.goals = "Build strength."
        model.days = 1
        model.cardio = [.outdoorWalk]
        model.step = .equipment
        return model
    }

    /// codex-review-06-app F2/B1: a week whose session ends while it is out is dropped where it lands — without the
    /// sheet's token hook (which only runs later) — and the late reply changes nothing. The reply is held until the
    /// session has ended (codex-review-06-app-c C1).
    @MainActor @Test func aWeekWhoseSessionEndsWhileOutIsDropped() async throws {
        let week: [String: Any] = ["sessions": [["name": "Day 1", "strength": [], "cardio": [["activity": "outdoorWalk", "minutes": 20]]]]]
        let gate = Gate()
        AIStub.respond = { _ in gate.hold(); return (200, Self.json(["result": week])) }
        let (store, _) = account("tok-1")
        let model = routineModel()
        model.generate(options: [], gymName: nil, permitted: true, client: client(), session: .bind(store))
        await gate.untilHeld()                          // the request is at the server
        store.invalidate(token: "tok-1")
        #expect(!store.isSignedIn)
        gate.release()
        await model.generationFinished()                // the reply has landed (and been dropped)
        #expect(model.routine == nil)
        #expect(model.step != .preview)
        #expect(model.error == nil)
    }

    /// …and the same reply for a session still current lands (the binding does not drop good answers).
    @MainActor @Test func aWeekForTheCurrentSessionLands() async throws {
        let week: [String: Any] = ["sessions": [["name": "Day 1", "strength": [], "cardio": [["activity": "outdoorWalk", "minutes": 20]]]]]
        AIStub.respond = { _ in (200, Self.json(["result": week])) }
        let (store, _) = account("tok-1")
        let model = routineModel()
        model.generate(options: [], gymName: nil, permitted: true, client: client(), session: .bind(store))
        for _ in 0..<50 where model.step != .preview { try await Task.sleep(for: .milliseconds(20)) }
        #expect(model.step == .preview)
        #expect(model.routine?.sessions.count == 1)
    }

    /// codex-review-06-app B2: a refusal names the session it refused — which the sheet signs out — and a refusal
    /// arriving after the session was replaced (signed out and in again) names nothing, so the newer session stays.
    @MainActor @Test func aRefusalNamesOnlyTheSessionItRefused() async throws {
        let (store, _) = account("tok-1")
        let model = routineModel()
        model.generate(options: [], gymName: nil, permitted: true, client: nil, session: .bind(store))
        for _ in 0..<50 where model.step != .error { try await Task.sleep(for: .milliseconds(20)) }
        #expect(model.step == .error)
        #expect(model.refusedSession == "tok-1")
        #expect(model.error == "Sign in to use AI.")

        let gate = Gate()
        AIStub.respond = { request in
            switch request.url?.path {
            case "/v1/auth/apple": return (200, Self.json(["session": "tok-2", "expiresAt": 1.0e13, "profile": [:]]))
            case "/v1/profile": return (200, Self.json(["provider": "apple", "memberSince": 1.0e12]))
            case "/v1/ai/usage": return (200, Self.json(Self.usageJSON))
            default: gate.hold(); return (401, Self.json(["error": "unauthorized"]))
            }
        }
        let (replaced, stored) = account("tok-1")
        let late = routineModel()
        late.generate(options: [], gymName: nil, permitted: true, client: client(), session: .bind(replaced))
        await gate.untilHeld()                          // the old request is at the server
        // Signed out and in again while it is out; only then does its 401 arrive (codex-review-06-app-c C1).
        replaced.invalidate(token: "tok-1")
        let signedIn = await replaced.signIn(.init(identityToken: "id", authorizationCode: "code",
                                                   rawNonce: "raw-nonce-0123456789", givenName: nil, familyName: nil))
        #expect(signedIn)
        #expect(replaced.token == "tok-2")
        gate.release()
        await late.generationFinished()
        #expect(late.refusedSession == nil)
        #expect(late.error == nil)
        #expect(replaced.token == "tok-2")
        #expect(stored() == "tok-2")
    }

    // MARK: Ticket 05 — Ask AI's training-profile saves (codex-review-05d F1/F2)

    private static func training(_ goals: String) -> TrainingProfile {
        TrainingProfile(goals: goals, experience: "Beginner", days: 3, minutes: 45)
    }

    /// A server that keeps the profile: GET returns it, PUT stores the body's training (or its removal) and echoes the
    /// profile; every PUT's goal ("nil" for a removal) is logged in arrival order. `gate` holds the first PUT.
    private func profileServer(holdFirstPut gate: Gate?, failPuts: Bool = false, initial: String? = nil) -> SentBox {
        let log = SentBox()
        let first = SentBox()
        final class Stored: @unchecked Sendable { var training: Any = NSNull() }
        let stored = Stored()
        if let initial { stored.training = ["goals": initial, "experience": "Beginner", "days": 3, "minutes": 45] }
        AIStub.respond = { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/v1/profile"):
                return (200, Self.json(["provider": "apple", "memberSince": 1.0e12, "training": stored.training]))
            case ("GET", "/v1/ai/usage"):
                return (200, Self.json(Self.usageJSON))
            case ("PUT", "/v1/profile"):
                let body = Self.object(AIStub.body(request))
                if let gate, first.paths.isEmpty { first.append("held"); gate.hold() }
                let training = body["training"] as? [String: Any]
                log.append((training?["goals"] as? String ?? "nil") + "@" + (request.value(forHTTPHeaderField: "Authorization") ?? ""))
                if failPuts { return (503, Self.json(["error": "unavailable"])) }
                stored.training = training ?? NSNull()
                return (200, Self.json(["provider": "apple", "memberSince": 1.0e12, "training": stored.training]))
            default:
                return (404, Data())
            }
        }
        return log
    }

    @MainActor @Test func trainingSavesLandInTheOrderRequested() async throws {
        let gate = Gate()
        let log = profileServer(holdFirstPut: gate)
        let (store, _) = account("tok-1")
        await store.refresh()
        let a = store.queueTrainingSave(Self.training("A"), session: "tok-1")
        await gate.untilHeld()                                     // A is at the server
        let b = store.queueTrainingSave(Self.training("B"), session: "tok-1")
        try await Task.sleep(for: .milliseconds(200))              // B must wait behind A, not overtake it
        #expect(log.paths.isEmpty)
        gate.release()
        #expect(await a.value)
        #expect(await b.value)
        #expect(log.paths == ["A@Bearer tok-1", "B@Bearer tok-1"])
        #expect(store.profile?.training?.goals == "B")
    }

    @MainActor @Test func aQueuedSaveIsNotSentUnderAReplacementSession() async throws {
        let gate = Gate()
        let log = profileServer(holdFirstPut: gate)
        let (store, _) = account("tok-1")
        await store.refresh()
        let a = store.queueTrainingSave(Self.training("A"), session: "tok-1")
        await gate.untilHeld()
        let b = store.queueTrainingSave(Self.training("B"), session: "tok-1")
        // Signed out and in again (tok-2) before B starts.
        store.invalidate(token: "tok-1")
        AIStub.respond = { [respond = AIStub.respond] request in
            request.url?.path == "/v1/auth/apple"
                ? (200, Self.json(["session": "tok-2", "expiresAt": 1.0e13, "profile": [:]])) : respond!(request)
        }
        #expect(await store.signIn(.init(identityToken: "id", authorizationCode: "code", rawNonce: "raw-nonce-0123456789",
                                         givenName: nil, familyName: nil)))
        gate.release()
        _ = await a.value
        #expect(await b.value == false)
        #expect(log.paths == ["A@Bearer tok-1"], "B was never sent, and never under tok-2")
    }

    /// codex-review-05e E1: four → three (held) → four again: the second is still saved, after the first, so the
    /// newest request wins — "unchanged" is judged after the earlier save has settled.
    @MainActor @Test func aFormChangedAndChangedBackIsSavedInOrder() async {
        let gate = Gate()
        let log = profileServer(holdFirstPut: gate, initial: "four")
        let (store, _) = account("tok-1")
        await store.refresh()
        #expect(store.profile?.training?.goals == "four")
        let three = store.queueTrainingSave(Self.training("three"), session: "tok-1")
        await gate.untilHeld()
        let four = store.queueTrainingSave(Self.training("four"), session: "tok-1")
        gate.release()
        #expect(await three.value)
        #expect(await four.value)
        #expect(log.paths == ["three@Bearer tok-1", "four@Bearer tok-1"])
        #expect(store.profile?.training?.goals == "four")
    }

    /// …and a save equal to the settled profile sends nothing.
    @MainActor @Test func aSaveEqualToTheSettledProfileSendsNothing() async {
        let log = profileServer(holdFirstPut: nil)
        let (store, _) = account("tok-1")
        await store.refresh()
        #expect(await store.queueTrainingSave(Self.training("A"), session: "tok-1").value)
        #expect(await store.queueTrainingSave(Self.training("A"), session: "tok-1").value)
        #expect(log.paths == ["A@Bearer tok-1"])
    }

    /// codex-review-05e E2: the profile editor's save (here a removal) queues behind a held Ask AI save and wins.
    @MainActor @Test func anEditorSaveQueuesBehindAnAskAISave() async {
        let gate = Gate()
        let log = profileServer(holdFirstPut: gate)
        let (store, _) = account("tok-1")
        await store.refresh()
        let ask = store.queueTrainingSave(Self.training("from Ask AI"), session: "tok-1")
        await gate.untilHeld()
        let editor = store.queueTrainingSave(nil, session: "tok-1")
        gate.release()
        #expect(await ask.value)
        #expect(await editor.value)
        #expect(log.paths == ["from Ask AI@Bearer tok-1", "nil@Bearer tok-1"])
        #expect(store.profile != nil && store.profile?.training == nil)
    }

    /// codex-review-05e E3: only the latest request's save is reported on Your week.
    @MainActor @Test func onlyTheLatestRequestsSaveIsReported() {
        let model = AIRoutineFlowModel()
        let older = model.beginProfileSave(sending: true)
        let newer = model.beginProfileSave(sending: true)
        model.finishProfileSave(older, saved: false)
        #expect(!model.profileSaveFailed, "an older failure does not mark the newer week")
        model.finishProfileSave(newer, saved: true)
        #expect(!model.profileSaveFailed)
        let failing = model.beginProfileSave(sending: true)
        model.finishProfileSave(failing, saved: false)
        #expect(model.profileSaveFailed)
        let none = model.beginProfileSave(sending: false)
        #expect(!model.profileSaveFailed, "a request that saves nothing clears the line")
        model.finishProfileSave(none, saved: false)
        #expect(!model.profileSaveFailed)
    }

    @MainActor @Test func aFailedTrainingSaveReportsFalse() async {
        _ = profileServer(holdFirstPut: nil, failPuts: true)
        let (store, _) = account("tok-1")
        await store.refresh()
        #expect(await store.queueTrainingSave(Self.training("A"), session: "tok-1").value == false)
        #expect(store.isSignedIn, "a server failure does not sign out")
    }

    /// codex-review-06-app F5: every line as Scan Machine's error step and the routine's error step show it.
    @Test func everyServerLineReadsInBothErrorSteps() {
        let reset = AIResetCopy.nextReset()
        let lines: [AIServerError] = [.signedOut, .limit(.scanMachine, 60, resetsAt: reset), .attempts(resetsAt: reset),
                                      .busy, .paused, .offline, .timedOut, .unavailable, .refused, .invalid,
                                      .rejected("x")]
        for line in lines {
            let text = line.localizedDescription
            let scan = ScanErrorText.shown(text)
            #expect(!scan.localizedCaseInsensitiveContains("continue manually"), "\(scan)")
            let routine = AIRoutineErrorText.split(text)
            #expect(!(routine.next ?? "").localizedCaseInsensitiveContains("continue manually"), "\(text)")
            #expect(!routine.what.localizedCaseInsensitiveContains("continue manually"), "\(text)")
        }
        #expect(ScanErrorText.shown(AIServerError.rejected("x").localizedDescription)
                == "AI couldn't take this request. Choose a catalog model.")
        #expect(ScanErrorText.shown(AIServerError.paused.localizedDescription)
                == "AI is paused right now. You can choose a catalog model.")
        #expect(AIRoutineErrorText.split(AIServerError.paused.localizedDescription) == ("AI is paused right now.", nil))
        #expect(AIRoutineErrorText.split(AIServerError.rejected("x").localizedDescription)
                == ("AI couldn't take this request.", nil))
        #expect(AIRoutineErrorText.split(AIServerError.attempts(resetsAt: reset).localizedDescription).next?
                .hasPrefix("Try again after ") == true)
    }

    @Test func transportFailuresReadAsOfflineOrSlowAndCancellationStaysCancellation() {
        #expect(AIServerClient.transportError(URLError(.timedOut)) as? AIServerError == .timedOut)
        #expect(AIServerClient.transportError(URLError(.notConnectedToInternet)) as? AIServerError == .offline)
        #expect(AIServerClient.transportError(URLError(.cannotFindHost)) as? AIServerError == .offline)
        #expect(AIServerClient.transportError(URLError(.cancelled)) is CancellationError)
    }

    // MARK: Words

    @Test func linesTheUserApproved() {
        let midnight = AIResetCopy.nextReset(after: Date(timeIntervalSince1970: 1_791_000_000))
        let york = AIResetCopy.serverZone
        #expect(AIResetCopy.reset(at: midnight, zone: york) == "reset at midnight")
        #expect(AIResetCopy.resets(at: midnight, zone: york) == "Resets at midnight")
        let pacific = TimeZone(identifier: "America/Los_Angeles")!
        #expect(AIResetCopy.clock(midnight, zone: pacific).hasPrefix("9:00"))
        #expect(AIServerError.paused.localizedDescription == "AI is paused right now. You can continue manually.")
        #expect(AIServerError.signedOut.localizedDescription == "Sign in to use AI.")
        let limit = AIServerError.limit(.scanMachine, 60, resetsAt: midnight).localizedDescription
        #expect(limit.hasPrefix("You've used today's 60 machine scans. They reset at "))
    }

    @Test func theResetIsTheNextNewYorkMidnightAcrossDaylightSaving() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = AIResetCopy.serverZone
        // 2026-11-01 01:30, the day daylight saving ends in New York: the reset is the next local midnight.
        let before = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 1, minute: 30))!
        let reset = AIResetCopy.nextReset(after: before)
        #expect(calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reset)
                == DateComponents(year: 2026, month: 11, day: 2, hour: 0, minute: 0))
    }
}

/// Holds one stub reply until the test releases it, and tells the test when the request has arrived.
private final class Gate: @unchecked Sendable {
    private let arrived = DispatchSemaphore(value: 0)
    private let released = DispatchSemaphore(value: 0)
    func hold() { arrived.signal(); released.wait() }
    func release() { released.signal() }
    func untilHeld() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async { self.arrived.wait(); continuation.resume() }
        }
    }
}

/// What the stub was sent, across its queue.
private final class SentBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _data = Data()
    private var _paths: [String] = []
    var data: Data { lock.withLock { _data } }
    var paths: [String] { lock.withLock { _paths } }
    func set(_ data: Data) { lock.withLock { _data = data } }
    func append(_ path: String) { lock.withLock { _paths.append(path) } }
}

private final class AIStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var respond: ((URLRequest) -> (Int, Data))?

    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AIStub.self]
        return URLSession(configuration: configuration)
    }

    static func body(_ request: URLRequest) -> Data {
        if let data = request.httpBody { return data }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        guard let respond = Self.respond else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        // Answered off the loading thread, so a held reply (Gate) does not stall the others.
        let request = self.request
        DispatchQueue.global().async { [self] in
            let (status, body) = respond(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }
    }
}
