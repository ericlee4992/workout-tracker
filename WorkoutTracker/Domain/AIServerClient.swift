import Foundation

/// Public beta ticket 06 (app half): the three AI flows go to the app's server, signed in (D60). The server owns each
/// flow's instructions, schema, model and limits (server/README → AI); the app sends only the flow's input and keeps
/// validating every reply exactly as before — the server is not trusted to have checked anything.
enum AIFlow: String, CaseIterable, Sendable {
    case scanMachine = "scan-machine"
    case routineWeek = "routine-week"
    case modelExercises = "model-exercises"

    /// The plural noun in "You've used today's 60 machine scans." (the profile's tile titles, lowercased).
    var noun: String {
        switch self {
        case .scanMachine: "machine scans"
        case .routineWeek: "template weeks"
        case .modelExercises: "exercise suggestions"
        }
    }
}

/// Why an AI request did not answer, in the words the app shows. Every case leaves the manual path open.
enum AIServerError: LocalizedError, Equatable {
    /// 401: the session is unknown or expired (the phone is then signed out), or there is no session.
    case signedOut
    /// 429 `ai_limit`: today's successes are used up. The limit is the server's, when known.
    case limit(AIFlow, Int?, resetsAt: Date)
    /// 429 `ai_attempts`: twice the limit in attempts, mostly failures.
    case attempts(resetsAt: Date)
    /// 429 `ai_busy`: every remaining slot is held by a request still running.
    case busy
    /// 503 `ai_paused`: the off switch, for everyone or this account.
    case paused
    case offline
    case timedOut
    /// 5xx other than the above: OpenAI or the server failing.
    case unavailable
    /// 502 `ai_refused`: the model declined.
    case refused
    /// 502 `ai_invalid`, or a reply the app itself refuses.
    case invalid
    /// 400/413: the server refused the request's shape — a bug in the app, not the tester's doing.
    case rejected(String)

    var errorDescription: String? {
        switch self {
        case .signedOut: "Sign in to use AI."
        case .limit(let flow, let limit, let resetsAt):
            "You've used today's \(limit.map { "\($0) " } ?? "")\(flow.noun). They \(AIResetCopy.reset(at: resetsAt))."
        case .attempts(let resetsAt):
            "Too many AI tries today. Try again after \(AIResetCopy.clock(resetsAt, zone: .current)) or continue manually."
        case .busy: "Another AI request is still running. Try again in a moment."
        case .paused: "AI is paused right now. You can continue manually."
        case .offline: "Could not reach the server. Check your connection or continue manually."
        case .timedOut: "AI took too long. Try again."
        case .unavailable: "AI is unavailable right now. Try again later."
        case .refused: "AI could not help with this request. Change the request or continue manually."
        case .invalid: "AI returned an incomplete or invalid result. Try again or continue manually."
        case .rejected: "AI couldn't take this request. Continue manually."
        }
    }
}

/// The daily limits reset at midnight in New York (the server's day). Said as "midnight" where the phone's clock agrees,
/// else as the local time ("9:00 PM") — a tester in another time zone sees when it actually happens.
enum AIResetCopy {
    static let serverZone = TimeZone(identifier: "America/New_York")!

    /// The next New York midnight after `now` — what the server's `resetsAt` says, for when it is not at hand.
    static func nextReset(after now: Date = .now) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = serverZone
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: 1, to: today) ?? now.addingTimeInterval(86_400)
    }

    /// "reset at midnight" / "reset at 9:00 PM".
    static func reset(at date: Date, zone: TimeZone = .current) -> String { "reset at \(clock(date, zone: zone))" }

    /// The profile's and Ask AI's "Resets at midnight" / "Resets at 9:00 PM".
    static func resets(at date: Date, zone: TimeZone = .current) -> String { "Resets at \(clock(date, zone: zone))" }

    static func clock(_ date: Date, zone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        if parts.hour == 0 && parts.minute == 0 { return "midnight" }
        var style = Date.FormatStyle(date: .omitted, time: .shortened)
        style.timeZone = zone
        return date.formatted(style)
    }
}
