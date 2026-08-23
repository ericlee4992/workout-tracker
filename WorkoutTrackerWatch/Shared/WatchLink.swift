import Foundation

// Milestone 7, ticket 04's wire format — compiled into BOTH the iOS app and the
// watchOS app, so the two cannot drift. It lives under WorkoutTrackerWatch/
// rather than under WorkoutTracker/ because that folder is a buildable folder
// (T4): everything inside it belongs to the iOS target automatically, and a
// file that must belong to two targets needs to sit outside it.
//
// Dictionaries, not Codable payloads, because `WCSession` speaks
// [String: Any] natively and a hand-rolled encoding is one more thing that can
// disagree across a version skew — the watch app and the phone app are signed
// and installed separately and WILL be out of step at some point.

enum WatchLink {

    /// Message keys. Raw strings are the wire format: never change one once a
    /// build carrying it has been installed, or a newer phone silently ignores
    /// an older watch's samples and the screen simply shows nothing.
    enum Key {
        static let kind = "kind"
        static let bpm = "bpm"
        static let timestamp = "ts"
        static let workoutActive = "workoutActive"
        static let restEndsAt = "restEndsAt"
        /// Which workout a message belongs to. `transferUserInfo` QUEUES when
        /// the watch is out of range, so a sample recorded during workout A can
        /// be delivered in the middle of workout B — and would otherwise be
        /// folded into B's average and maximum (codex-review 3.4).
        static let workoutID = "workoutID"
    }

    enum Kind: String {
        /// Watch → phone: one heart-rate reading.
        case heartRate
        /// Phone → watch: the workout started, ended, or its rest changed.
        case workoutState
    }

    static func heartRateMessage(
        bpm: Int, at date: Date, workoutID: String? = nil
    ) -> [String: Any] {
        var message: [String: Any] = [
            Key.kind: Kind.heartRate.rawValue,
            Key.bpm: bpm,
            Key.timestamp: date.timeIntervalSince1970,
        ]
        if let workoutID { message[Key.workoutID] = workoutID }
        return message
    }

    static func workoutStateMessage(
        isActive: Bool, restEndsAt: Date?, workoutID: String? = nil
    ) -> [String: Any] {
        var message: [String: Any] = [
            Key.kind: Kind.workoutState.rawValue,
            Key.workoutActive: isActive,
        ]
        if let workoutID { message[Key.workoutID] = workoutID }
        if let restEndsAt {
            message[Key.restEndsAt] = restEndsAt.timeIntervalSince1970
        }
        return message
    }

    /// Parses a heart-rate message. Returns nil for anything it does not
    /// recognise — including a message from a future version of the other app.
    /// Ignoring the unparseable is the only safe behaviour when the two ends
    /// ship separately.
    static func heartRate(
        from message: [String: Any]
    ) -> (bpm: Int, date: Date, workoutID: String?)? {
        guard message[Key.kind] as? String == Kind.heartRate.rawValue,
              let bpm = message[Key.bpm] as? Int, bpm > 0,
              let ts = message[Key.timestamp] as? TimeInterval
        else { return nil }
        return (bpm, Date(timeIntervalSince1970: ts), message[Key.workoutID] as? String)
    }

    static func workoutState(
        from message: [String: Any]
    ) -> (isActive: Bool, restEndsAt: Date?, workoutID: String?)? {
        guard message[Key.kind] as? String == Kind.workoutState.rawValue,
              let isActive = message[Key.workoutActive] as? Bool
        else { return nil }
        let rest = (message[Key.restEndsAt] as? TimeInterval).map(Date.init(timeIntervalSince1970:))
        return (isActive, rest, message[Key.workoutID] as? String)
    }
}
